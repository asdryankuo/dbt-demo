-- 原先一開始的樣子：
select
    id as order_id,
    user_id as customer_id,
    order_date,
    status
from {{ source ( 'jaffle_shop', 'orders' ) }}

-- 如果後續要新增一個欄位，is_valid (Y/N)

-- status = placed, shipped, completed ---> is_valid = Y
-- status = returned, return_pending ---> is_valid = N

-- 方法一：
-- select
--     id as order_id,
--     user_id as customer_id,
--     order_date,
--     status,
--     case
--         when status in ('placed', 'shipped', 'completed')
--             then 'Y'
--         when status in ('returned', 'return_pending')
--             then 'N'
--     end as is_valid

-- from {{ source('jaffle_shop', 'orders') }}


-- 用CTE方式：
-- with source as (
--     select
--         id as order_id,
--         user_id as customer_id,
--         order_date,
--         status
--     from {{ source('jaffle_shop', 'orders') }}
-- ),

-- transformed as (
--     select
--         order_id,
--         customer_id,
--         order_date,
--         status,
--         case
--             when status in ('placed', 'shipped', 'completed')
--                 then 'Y'
--             when status in ('returned', 'return_pending')
--                 then 'N'
--         end as is_valid
--     from source
-- )

-- select * from transformed


-- 用seed 的做法：
with source as (
    select
        id as order_id,
        user_id as customer_id,
        order_date,
        status
    from {{ source('jaffle_shop', 'orders') }}
),

order_status_mapping as (select * from {{ ref('seed_order_statuses') }}),

transformed as (
    select
        t0.order_id,
        t0.customer_id,
        t0.order_date,
        t0.status,
        t1.is_valid
    from source as t0
    left join order_status_mapping as t1 on t0.status = t1.status
)

select * from transformed
