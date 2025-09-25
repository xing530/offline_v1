-- hjx
use realtime_v1_hive;
DROP TABLE IF EXISTS dwd_trade_cart_add_inc;
CREATE EXTERNAL TABLE dwd_trade_cart_add_inc
(
    `id`                  STRING COMMENT '编号',
    `user_id`            STRING COMMENT '用户ID',
    `sku_id`             STRING COMMENT 'SKU_ID',
    `date_id`            STRING COMMENT '日期ID',
    `create_time`        STRING COMMENT '加购时间',
    `sku_num`            BIGINT COMMENT '加购物车件数'
) COMMENT '交易域加购事务事实表'
    PARTITIONED BY (`ds` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_cart_add_inc/'
    TBLPROPERTIES ('orc.compress' = 'snappy');

set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table dwd_trade_cart_add_inc partition (ds = '20250920')
select
    id,
    user_id,
    sku_id,
    date_format(create_time,'yyyy-MM-dd') date_id,
    create_time,
    sku_num
from ods_cart_info_inc
where ds = ${d};

select * from dwd_trade_cart_add_inc;

DROP TABLE IF EXISTS dwd_trade_order_detail_inc;
CREATE EXTERNAL TABLE dwd_trade_order_detail_inc
(
    `id`                     STRING COMMENT '编号',
    `order_id`              STRING COMMENT '订单ID',
    `user_id`               STRING COMMENT '用户ID',
    `sku_id`                STRING COMMENT '商品ID',
    `province_id`          STRING COMMENT '省份ID',
    `activity_id`          STRING COMMENT '参与活动ID',
    `activity_rule_id`    STRING COMMENT '参与活动规则ID',
    `coupon_id`             STRING COMMENT '使用优惠券ID',
    `date_id`               STRING COMMENT '下单日期ID',
    `create_time`           STRING COMMENT '下单时间',
    `sku_num`                BIGINT COMMENT '商品数量',
    `split_original_amount` DECIMAL(16, 2) COMMENT '原始价格',
    `split_activity_amount` DECIMAL(16, 2) COMMENT '活动优惠分摊',
    `split_coupon_amount`   DECIMAL(16, 2) COMMENT '优惠券优惠分摊',
    `split_total_amount`    DECIMAL(16, 2) COMMENT '最终价格分摊'
) COMMENT '交易域下单事务事实表'
    PARTITIONED BY (`ds` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_order_detail_inc/'
    TBLPROPERTIES ('orc.compress' = 'snappy');

set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table dwd_trade_order_detail_inc partition (ds = '20250920')
select
    od.id,
    order_id,
    user_id,
    sku_id,
    province_id,
    activity_id,
    activity_rule_id,
    coupon_id,
    date_format(create_time, 'yyyy-MM-dd') date_id,
    create_time,
    sku_num,
    split_original_amount,
    nvl(split_activity_amount,0.0),
    nvl(split_coupon_amount,0.0),
    split_total_amount
from
    (
        select
            id,
            order_id,
            sku_id,
            create_time,
            sku_num,
            sku_num * order_price split_original_amount,
            split_total_amount,
            split_activity_amount,
            split_coupon_amount
        from ods_order_detail_inc
        where ds = ${d}
    ) od
        left join
    (
        select
            id,
            user_id,
            province_id
        from ods_order_info_inc
        where ds = ${d}
    ) oi
    on od.order_id = oi.id
        left join
    (
        select
            order_detail_id,
            activity_id,
            activity_rule_id
        from ods_order_detail_activity_inc
        where ds = ${d}
    ) act
    on od.id = act.order_detail_id
        left join
    (
        select
            order_detail_id,
            coupon_id
        from ods_order_detail_coupon_inc
        where ds = ${d}
    ) cou
    on od.id = cou.order_detail_id;

DROP TABLE IF EXISTS dwd_trade_pay_detail_suc_inc;
CREATE EXTERNAL TABLE dwd_trade_pay_detail_suc_inc
(
    `id`                      STRING COMMENT '编号',
    `order_id`               STRING COMMENT '订单ID',
    `user_id`                STRING COMMENT '用户ID',
    `sku_id`                 STRING COMMENT 'SKU_ID',
    `province_id`           STRING COMMENT '省份ID',
    `activity_id`           STRING COMMENT '参与活动ID',
    `activity_rule_id`     STRING COMMENT '参与活动规则ID',
    `coupon_id`              STRING COMMENT '使用优惠券ID',
    `payment_type_code`     STRING COMMENT '支付类型编码',
    `payment_type_name`     STRING COMMENT '支付类型名称',
    `date_id`                STRING COMMENT '支付日期ID',
    `callback_time`         STRING COMMENT '支付成功时间',
    `sku_num`                 BIGINT COMMENT '商品数量',
    `split_original_amount` DECIMAL(16, 2) COMMENT '应支付原始金额',
    `split_activity_amount` DECIMAL(16, 2) COMMENT '支付活动优惠分摊',
    `split_coupon_amount`   DECIMAL(16, 2) COMMENT '支付优惠券优惠分摊',
    `split_payment_amount`  DECIMAL(16, 2) COMMENT '支付金额'
) COMMENT '交易域支付成功事务事实表'
    PARTITIONED BY (`ds` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_pay_detail_suc_inc/'
    TBLPROPERTIES ('orc.compress' = 'snappy');

set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table dwd_trade_pay_detail_suc_inc partition (ds = '20250920')
select
    od.id,
    od.order_id,
    user_id,
    sku_id,
    province_id,
    activity_id,
    activity_rule_id,
    coupon_id,
    payment_type,
    pay_dic.dic_name,
    date_format(callback_time,'yyyy-MM-dd') date_id,
    callback_time,
    sku_num,
    split_original_amount,
    nvl(split_activity_amount,0.0),
    nvl(split_coupon_amount,0.0),
    split_total_amount
from
    (
        select
            id,
            order_id,
            sku_id,
            sku_num,
            sku_num * order_price split_original_amount,
            split_total_amount,
            split_activity_amount,
            split_coupon_amount
        from ods_order_detail_inc
        where ds = ${d}
    ) od
        join
    (
        select
            user_id,
            order_id,
            payment_type,
            callback_time
        from ods_payment_info_inc
        where ds=${d}
          and payment_status='1602'
    ) pi
    on od.order_id=pi.order_id
        left join
    (
        select
            id,
            province_id
        from ods_order_info_inc
        where ds = ${d}
    ) oi
    on od.order_id = oi.id
        left join
    (
        select
            order_detail_id,
            activity_id,
            activity_rule_id
        from ods_order_detail_activity_inc
        where ds = ${d}
    ) act
    on od.id = act.order_detail_id
        left join
    (
        select
            order_detail_id,
            coupon_id
        from ods_order_detail_coupon_inc
        where ds = ${d}
    ) cou
    on od.id = cou.order_detail_id
        left join
    (
        select
            dic_code,
            dic_name
        from ods_base_dic_full
        where ds=${d}
          and parent_code='11'
    ) pay_dic
    on pi.payment_type=pay_dic.dic_code;

DROP TABLE IF EXISTS dwd_trade_cart_full;
CREATE EXTERNAL TABLE dwd_trade_cart_full
(
    `id`         STRING COMMENT '编号',
    `user_id`   STRING COMMENT '用户ID',
    `sku_id`    STRING COMMENT 'SKU_ID',
    `sku_name`  STRING COMMENT '商品名称',
    `sku_num`   BIGINT COMMENT '现存商品件数'
) COMMENT '交易域购物车周期快照事实表'
    PARTITIONED BY (`ds` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_cart_full/'
    TBLPROPERTIES ('orc.compress' = 'snappy');

insert overwrite table dwd_trade_cart_full partition(ds='20250920')
select
    id,
    user_id,
    sku_id,
    sku_name,
    sku_num
from ods_cart_info_full
where ds=${d}
  and is_ordered='0';


DROP TABLE IF EXISTS dwd_trade_trade_flow_acc;
CREATE EXTERNAL TABLE dwd_trade_trade_flow_acc
(
    `order_id`               STRING COMMENT '订单ID',
    `user_id`                STRING COMMENT '用户ID',
    `province_id`           STRING COMMENT '省份ID',
    `order_date_id`         STRING COMMENT '下单日期ID',
    `order_time`             STRING COMMENT '下单时间',
    `payment_date_id`        STRING COMMENT '支付日期ID',
    `payment_time`           STRING COMMENT '支付时间',
    `finish_date_id`         STRING COMMENT '确认收货日期ID',
    `finish_time`             STRING COMMENT '确认收货时间',
    `order_original_amount` DECIMAL(16, 2) COMMENT '下单原始价格',
    `order_activity_amount` DECIMAL(16, 2) COMMENT '下单活动优惠分摊',
    `order_coupon_amount`   DECIMAL(16, 2) COMMENT '下单优惠券优惠分摊',
    `order_total_amount`    DECIMAL(16, 2) COMMENT '下单最终价格分摊',
    `payment_amount`         DECIMAL(16, 2) COMMENT '支付金额'
) COMMENT '交易域交易流程累积快照事实表'
    PARTITIONED BY (`ds` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_trade_flow_acc/'
    TBLPROPERTIES ('orc.compress' = 'snappy');

set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table dwd_trade_trade_flow_acc partition(ds = '20250920')
select
    oi.id,
    user_id,
    province_id,
    date_format(create_time,'yyyy-MM-dd'),
    create_time,
    date_format(callback_time,'yyyy-MM-dd'),
    callback_time,
    finish_time,
    original_total_amount,
    activity_reduce_amount,
    coupon_reduce_amount,
    total_amount,
    nvl(payment_amount,0.0),
    nvl(date_format(finish_time,'yyyy-MM-dd'),'9999-12-31')
from
    (
        select
            id,
            user_id,
            province_id,
            create_time,
            original_total_amount,
            activity_reduce_amount,
            coupon_reduce_amount,
            total_amount
        from ods_order_info_inc
        where ds=${d}
    )oi
        left join
    (
        select
            order_id,
            callback_time,
            total_amount payment_amount
        from ods_payment_info_inc
        where ds=${d}
          and payment_status='1602'
    )pi
    on oi.id=pi.order_id
        left join
    (
        select
            order_id,
            create_time finish_time
        from ods_order_status_log_inc
        where ds=${d}
          and order_status='1004'
    )log
    on oi.id=log.order_id;

DROP TABLE IF EXISTS dwd_tool_coupon_used_inc;
CREATE EXTERNAL TABLE dwd_tool_coupon_used_inc
(
    `id`           STRING COMMENT '编号',
    `coupon_id`    STRING COMMENT '优惠券ID',
    `user_id`      STRING COMMENT '用户ID',
    `order_id`     STRING COMMENT '订单ID',
    `date_id`      STRING COMMENT '日期ID',
    `payment_time` STRING COMMENT '使用(支付)时间'
) COMMENT '优惠券使用（支付）事务事实表'
    PARTITIONED BY (`ds` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_tool_coupon_used_inc/'
    TBLPROPERTIES ("orc.compress" = "snappy");

set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table dwd_tool_coupon_used_inc partition(ds = '20250920')
select
    id,
    coupon_id,
    user_id,
    order_id,
    date_format(used_time,'yyyy-MM-dd') date_id,
    used_time
from ods_coupon_use_inc
where ds=${d}
  and used_time is not null;


DROP TABLE IF EXISTS dwd_interaction_favor_add_inc;
CREATE EXTERNAL TABLE dwd_interaction_favor_add_inc
(
    `id`          STRING COMMENT '编号',
    `user_id`     STRING COMMENT '用户ID',
    `sku_id`      STRING COMMENT 'SKU_ID',
    `date_id`     STRING COMMENT '日期ID',
    `create_time` STRING COMMENT '收藏时间'
) COMMENT '互动域收藏商品事务事实表'
    PARTITIONED BY (`ds` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_interaction_favor_add_inc/'
    TBLPROPERTIES ("orc.compress" = "snappy");

set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table dwd_interaction_favor_add_inc partition (ds = '20250920')
select
    id,
    user_id,
    sku_id,
    date_format(create_time,'yyyy-MM-dd') date_id,
    create_time
from ods_favor_info_inc
where ds=${d};


DROP TABLE IF EXISTS dwd_traffic_page_view_inc;
CREATE EXTERNAL TABLE dwd_traffic_page_view_inc
(
    `province_id`    STRING COMMENT '省份ID',
    `brand`           STRING COMMENT '手机品牌',
    `channel`         STRING COMMENT '渠道',
    `is_new`          STRING COMMENT '是否首次启动',
    `model`           STRING COMMENT '手机型号',
    `mid_id`          STRING COMMENT '设备ID',
    `operate_system` STRING COMMENT '操作系统',
    `user_id`         STRING COMMENT '会员ID',
    `version_code`   STRING COMMENT 'APP版本号',
    `page_item`       STRING COMMENT '目标ID',
    `page_item_type` STRING COMMENT '目标类型',
    `last_page_id`    STRING COMMENT '上页ID',
    `page_id`          STRING COMMENT '页面ID ',
    `from_pos_id`     STRING COMMENT '点击坑位ID',
    `from_pos_seq`    STRING COMMENT '点击坑位位置',
    `refer_id`         STRING COMMENT '营销渠道ID',
    `date_id`          STRING COMMENT '日期ID',
    `view_time`       STRING COMMENT '跳入时间',
    `session_id`      STRING COMMENT '所属会话ID',
    `during_time`     BIGINT COMMENT '持续时间毫秒'
) COMMENT '流量域页面浏览事务事实表'
    PARTITIONED BY (`ds` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_traffic_page_view_inc'
    TBLPROPERTIES ('orc.compress' = 'snappy');

insert overwrite table dwd_traffic_page_view_inc partition (ds='20250920')
select
    get_json_object(log, '$.common.ar') as province_id,
    get_json_object(log, '$.common.ba') as brand,
    get_json_object(log, '$.common.ch') as channel,
    get_json_object(log, '$.common.is_new') as is_new,
    get_json_object(log, '$.common.md') as model,
    get_json_object(log, '$.common.mid') as mid_id,
    get_json_object(log, '$.common.os') as operate_system,
    get_json_object(log, '$.common.uid') as user_id,
    get_json_object(log, '$.common.vc') as version_code,
    get_json_object(log, '$.page.item') as page_item,
    get_json_object(log, '$.page.item_type') as page_item_type,
    get_json_object(log, '$.page.last_page_id') as last_page_id,
    get_json_object(log, '$.page.page_id') as page_id,
    get_json_object(log, '$.page.from_pos_id') as from_pos_id,
    get_json_object(log, '$.page.from_pos_seq') as from_pos_seq,
    get_json_object(log, '$.page.refer_id') as refer_id,
    date_format(from_utc_timestamp(get_json_object(log, '$.ts'), 'GMT+8'), 'yyyy-MM-dd') as date_id,
    date_format(from_utc_timestamp(get_json_object(log, '$.ts'), 'GMT+8'), 'yyyy-MM-dd HH:mm:ss') as view_time,
    get_json_object(log, '$.common.sid') as session_id,
    get_json_object(log, '$.page.during_time') as during_time
from ods_z_log_inc
where ds=${d}
  and get_json_object(log, '$.page') is not null;


DROP TABLE IF EXISTS dwd_user_register_inc;
CREATE EXTERNAL TABLE dwd_user_register_inc
(
    `user_id`          STRING COMMENT '用户ID',
    `date_id`          STRING COMMENT '日期ID',
    `create_time`     STRING COMMENT '注册时间',
    `channel`          STRING COMMENT '应用下载渠道',
    `province_id`     STRING COMMENT '省份ID',
    `version_code`    STRING COMMENT '应用版本',
    `mid_id`           STRING COMMENT '设备ID',
    `brand`            STRING COMMENT '设备品牌',
    `model`            STRING COMMENT '设备型号',
    `operate_system` STRING COMMENT '设备操作系统'
) COMMENT '用户域用户注册事务事实表'
    PARTITIONED BY (`ds` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_user_register_inc/'
    TBLPROPERTIES ("orc.compress" = "snappy");

set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table dwd_user_register_inc partition(ds)
select
    ui.user_id,
    date_format(ui.create_time, 'yyyy-MM-dd') as date_id,
    ui.create_time,
    nvl(log.channel, 'unknown') as channel,  -- 处理 NULL 值
    nvl(log.province_id, 'unknown') as province_id,
    nvl(log.version_code, 'unknown') as version_code,
    nvl(log.mid_id, 'unknown') as mid_id,
    nvl(log.brand, 'unknown') as brand,
    nvl(log.model, 'unknown') as model,
    nvl(log.operate_system, 'unknown') as operate_system,
    '20250920' as ds  -- 明确分区字段值，与过滤条件一致
from
    (
        -- 用户注册主信息（解析 data 字段）
        select
            id as user_id,
            create_time as create_time
        from ods_user_info_inc
        where ds=${d}
    ) ui
        left join
    (
        -- 注册相关日志信息（解析 common 和 page 字段）
        select
            get_json_object(log, '$common.ar') as province_id,
            get_json_object(log, '$common.ba') as brand,
            get_json_object(log, '$common.ch') as channel,
            get_json_object(log, '$common.md') as model,
            get_json_object(log, '$common.mid') as mid_id,
            get_json_object(log, '$common.os') as operate_system,
            get_json_object(log, '$common.uid') as user_id,  -- 关联用户 ID
            get_json_object(log, '$common.vc') as version_code
        from ods_z_log_inc
        where ds = '20250920'
          and get_json_object(log, '$page.page_id') = 'register'  -- 解析 page 字段
          and get_json_object(log, '$common.uid') is not null  -- 过滤有效用户
    ) log
    on ui.user_id = log.user_id;


DROP TABLE IF EXISTS dwd_user_login_inc;
CREATE EXTERNAL TABLE dwd_user_login_inc
(
    `user_id`         STRING COMMENT '用户ID',
    `date_id`         STRING COMMENT '日期ID',
    `login_time`     STRING COMMENT '登录时间',
    `channel`         STRING COMMENT '应用下载渠道',
    `province_id`    STRING COMMENT '省份ID',
    `version_code`   STRING COMMENT '应用版本',
    `mid_id`          STRING COMMENT '设备ID',
    `brand`           STRING COMMENT '设备品牌',
    `model`           STRING COMMENT '设备型号',
    `operate_system` STRING COMMENT '设备操作系统'
) COMMENT '用户域用户登录事务事实表'
    PARTITIONED BY (`ds` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_user_login_inc/'
    TBLPROPERTIES ("orc.compress" = "snappy");

insert overwrite table dwd_user_login_inc partition (ds = '20250920')
select user_id,
       -- 解析后的 ts 用于时间格式化
       date_format(from_utc_timestamp(cast(ts as bigint), 'GMT+8'), 'yyyy-MM-dd') date_id,
       date_format(from_utc_timestamp(cast(ts as bigint), 'GMT+8'), 'yyyy-MM-dd HH:mm:ss') login_time,
       channel,
       province_id,
       version_code,
       mid_id,
       brand,
       model,
       operate_system
from (
         select user_id,
                channel,
                province_id,
                version_code,
                mid_id,
                brand,
                model,
                operate_system,
                ts  -- 传递解析后的 ts
         from (select
                   get_json_object(log, '$common.uid') user_id,
                   get_json_object(log, '$common.ch') channel,
                   get_json_object(log, '$common.ar') province_id,
                   get_json_object(log, '$common.vc') version_code,
                   get_json_object(log, '$common.mid') mid_id,
                   get_json_object(log, '$common.ba') brand,
                   get_json_object(log, '$common.md') model,
                   get_json_object(log, '$common.os') operate_system,
                   -- 关键：解析 ts 字段（假设在 log 字段下）
                   get_json_object(log, '$.ts') as ts,
                   -- 解析 sid 用于分区（如果 sid 也在 common 里）
                   row_number() over (partition by get_json_object(log, '$common.sid') order by get_json_object(log, '$.ts')) rn
               from ods_z_log_inc
               where ds=${d}
                 and get_json_object(log, '$.page') is not null  -- 解析 page 非空
                 and get_json_object(log, '$common.uid') is not null
              ) t1
         where rn = 1
     ) t2;
