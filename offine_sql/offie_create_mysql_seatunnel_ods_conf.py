import os
import pymysql
from jinja2 import Template
import textwrap

# ===== MySQL 连接 =====
MYSQL_HOST = "192.168.200.32"
MYSQL_PORT = 3306
MYSQL_USER = "root"
MYSQL_PASS = "root"
MYSQL_DB   = "realtime_v1"

# ===== Hive 参数 =====
HIVE_DB        = "realtime_v1_hive"
HIVE_METASTORE = "thrift://192.168.200.32:9083"
HDFS_BASE      = "/user/hive/warehouse/ods/"

# ===== 输出目录 =====
OUT_DDL = "output/ddl"
OUT_ST  = "output/seatunnel"
os.makedirs(OUT_DDL, exist_ok=True)
os.makedirs(OUT_ST,  exist_ok=True)


# ===== 所有字段强制为 STRING =====
def mysql_type_to_hive(_):
    return "STRING"


# ===== Hive DDL 模板（TextFile + Gzip） =====
DDL_TEMPLATE = Template("""CREATE DATABASE IF NOT EXISTS {{ hive_db }};
USE {{ hive_db }};

CREATE EXTERNAL TABLE IF NOT EXISTS {{ hive_db }}.ods_{{ table }} (
{% for col in cols -%}
  `{{ col.name }}` STRING{% if not loop.last %},{% endif %}
{% endfor %}
)
PARTITIONED BY (`ds` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\\001'
STORED AS TEXTFILE
LOCATION '{{ hdfs_base }}ods_{{ table }}'
TBLPROPERTIES ("compression"="gzip");
""")


# ===== SeaTunnel 配置模板（TextFile + Gzip） =====
ST_TEMPLATE = textwrap.dedent('''\
    env {
      job.mode = "BATCH"
      parallelism = 2
    }

    source {
      Jdbc {
        url = "jdbc:mysql://{{ mysql_host }}:{{ mysql_port }}/{{ mysql_db }}?serverTimezone=UTC&useSSL=false"
        driver = "com.mysql.cj.jdbc.Driver"
        user = "{{ mysql_user }}"
        password = "{{ mysql_pass }}"
        query = """
    {{ query_sql }}
        """
        partition_column = "{{ part_col }}"
        partition_num  = 4
        fetch_size = 10000
      }
    }

    sink {
      Hive {
        metastore_uri = "{{ hive_metastore }}"
        database = "{{ hive_db }}"
        table_name = "{{ hive_db }}.ods_{{ table }}"
        save_mode = "overwrite"
        file_format = "text"
        field_delimiter = "\\u0001"
        partition_by = ["ds"]
        compression_codec = "gzip"
      }
    }
''')


# ===== 工具函数 =====
def fetch_tables(cur):
    cur.execute(f"SHOW TABLES FROM {MYSQL_DB}")
    return [r[0] for r in cur.fetchall()]

def fetch_cols(cur, table):
    cur.execute(f"SHOW COLUMNS FROM {MYSQL_DB}.{table}")
    return [{"name": r[0]} for r in cur.fetchall()]

def build_query(table: str, cols: list) -> str:
    select_list = [f"`{c['name']}`" for c in cols]
    select_list.append("DATE_FORMAT(NOW(),'%Y%m%d') AS ds")
    return "SELECT\n  " + ",\n  ".join(select_list) + f"\nFROM {table}"


# ===== 主函数 =====
def main():
    conn = pymysql.connect(host=MYSQL_HOST, port=MYSQL_PORT,
                           user=MYSQL_USER, password=MYSQL_PASS,
                           database=MYSQL_DB, charset='utf8mb4')
    cur = conn.cursor()

    tables = fetch_tables(cur)
    for tbl in tables:
        cols = fetch_cols(cur, tbl)

        # 1. 生成 Hive DDL（TextFile + Gzip）
        ddl = DDL_TEMPLATE.render(
            hive_db=HIVE_DB, table=tbl, cols=cols, hdfs_base=HDFS_BASE
        )
        ddl_path = os.path.join(OUT_DDL, f"ods_{tbl}.sql")
        with open(ddl_path, "w", encoding="utf-8") as f:
            f.write(ddl)

        # 2. 生成 SeaTunnel 配置（TextFile + Gzip）
        part_col = cols[0]["name"]
        query_sql = build_query(tbl, cols)
        st_conf = Template(ST_TEMPLATE).render(
            mysql_host=MYSQL_HOST,
            mysql_port=MYSQL_PORT,
            mysql_db=MYSQL_DB,
            mysql_user=MYSQL_USER,
            mysql_pass=MYSQL_PASS,
            table=tbl,
            hive_db=HIVE_DB,
            hive_metastore=HIVE_METASTORE,
            query_sql=query_sql,
            part_col=part_col
        )
        st_path = os.path.join(OUT_ST, f"{tbl}.conf")
        with open(st_path, "w", encoding="utf-8") as f:
            f.write(st_conf.strip())

        print(f"[OK] {ddl_path}  |  {st_path}")

    cur.close()
    conn.close()


if __name__ == "__main__":
    main()
