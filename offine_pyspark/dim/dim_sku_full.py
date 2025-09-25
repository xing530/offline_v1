from pyspark.sql import SparkSession
from pyspark.sql.functions import lit, col

def get_spark_session():
    import os
    os.environ["HADOOP_HOME"] = "E:\\soft\\hadoop-3.3.0"
    os.environ["PATH"] += os.pathsep + os.path.join(os.environ["HADOOP_HOME"], "bin")
    spark = (SparkSession.builder
             .appName("HiveETL")
             .config("hive.metastore.uris", "thrift://192.168.200.32:9083")
             .config("spark.sql.hive.convertMetastoreOrc", "false")
             .config("spark.sql.orc.impl", "native")
             .config("spark.sql.orc.write.format", "0.12")
             .config("hive.exec.dynamic.partition.mode", "nonstrict")
             .config("spark.sql.orc.writer.version", "0.12")
             .config("spark.sql.orc.enableVectorizedReader", "false")
             .enableHiveSupport()
             .getOrCreate())
    spark.sparkContext.setLogLevel("WARN")
    spark.sql("USE realtime_v1_pyspark")
    spark.sql("SET hive.exec.dynamic.partition.mode=nonstrict")
    return spark

def select_to_hive(df, table, ds):
    # 仅插入数据，动态分区会自动创建/修复元数据，无需手动 ADD PARTITION
    df.write.mode("append").insertInto(f"realtime_v1_pyspark.{table}")

def execute_hive_insert(ds: str, table: str):
    spark = get_spark_session()

    sql = f"""
    WITH
    sku AS (SELECT id, price, sku_name, sku_desc, weight,
                   CAST(is_sale AS BOOLEAN) AS is_sale,
                   spu_id, category3_id, tm_id, create_time
            FROM ods_sku_info_full
            WHERE ds='{ds}'),
    spu AS (SELECT id, spu_name FROM ods_spu_info_full WHERE ds='{ds}'),
    c3  AS (SELECT id, name, category2_id FROM ods_base_category3_full WHERE ds='{ds}'),
    c2  AS (SELECT id, name, category1_id FROM ods_base_category2_full WHERE ds='{ds}'),
    c1  AS (SELECT id, name FROM ods_base_category1_full WHERE ds='{ds}'),
    tm  AS (SELECT id, tm_name FROM ods_base_trademark_full WHERE ds='{ds}'),
    attr AS (SELECT sku_id,
                    collect_set(named_struct(
                        'attr_id',      CAST(attr_id AS STRING),
                        'value_id',     CAST(value_id AS STRING),
                        'attr_name',    attr_name,
                        'value_name',   value_name)) attrs
             FROM ods_sku_attr_value_full
             WHERE ds='{ds}'
             GROUP BY sku_id),
    sale_attr AS (SELECT sku_id,
                         collect_set(named_struct(
                             'sale_attr_id',         CAST(sale_attr_id AS STRING),
                             'sale_attr_value_id',   CAST(sale_attr_value_id AS STRING),
                             'sale_attr_name',       sale_attr_name,
                             'sale_attr_value_name', sale_attr_value_name)) sale_attrs
                  FROM ods_sku_sale_attr_value_full
                  WHERE ds='{ds}'
                  GROUP BY sku_id)
    SELECT sku.id,
           sku.price,
           sku.sku_name,
           sku.sku_desc,
           sku.weight,
           sku.is_sale,
           sku.spu_id,
           spu.spu_name,
           sku.category3_id,
           c3.name              AS category3_name,
           c3.category2_id,
           c2.name              AS category2_name,
           c2.category1_id,
           c1.name              AS category1_name,
           sku.tm_id,
           tm.tm_name,
           attr.attrs           AS sku_attr_values,
           sale_attr.sale_attrs AS sku_sale_attr_values,
           sku.create_time
    FROM sku
    LEFT JOIN spu        ON sku.spu_id  = spu.id
    LEFT JOIN c3         ON sku.category3_id = c3.id
    LEFT JOIN c2         ON c3.category2_id  = c2.id
    LEFT JOIN c1         ON c2.category1_id  = c1.id
    LEFT JOIN tm         ON sku.tm_id   = tm.id
    LEFT JOIN attr       ON sku.id      = attr.sku_id
    LEFT JOIN sale_attr  ON sku.id      = sale_attr.sku_id
    """

    df = spark.sql(sql).withColumn("ds", lit(ds))
    df.show(5, truncate=False)
    select_to_hive(df, table, ds)
    print(f"[INFO] 分区 ds={ds} 数据已写入 realtime_v1_pyspark.{table}")

if __name__ == "__main__":
    execute_hive_insert("20250918", "dim_sku_full")