with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

order_payments as (
    select * from {{ ref('stg_order_payments') }}
),

customer_orders as (
    select
        o.customer_id,
        count(distinct o.order_id)              as total_orders,
        min(date(o.purchased_at))               as first_order_date,
        max(date(o.purchased_at))               as last_order_date,
        round(sum(p.amount), 2)                 as lifetime_value,
        round(avg(p.amount), 2)                 as avg_order_value,
        countif(o.order_status = 'delivered')   as delivered_orders,
        countif(o.order_status = 'canceled')    as canceled_orders
    from orders o
    left join order_payments p on o.order_id = p.order_id
    group by o.customer_id
),

final as (
    select
        c.customer_id,
        c.customer_unique_id,
        c.city,
        c.state,
        co.total_orders,
        co.first_order_date,
        co.last_order_date,
        date_diff(co.last_order_date, co.first_order_date, day) as customer_age_days,
        co.lifetime_value,
        co.avg_order_value,
        co.delivered_orders,
        co.canceled_orders,
        case
            when co.lifetime_value >= 500  then 'high'
            when co.lifetime_value >= 200  then 'mid'
            else 'low'
        end as ltv_segment
    from customers c
    inner join customer_orders co on c.customer_id = co.customer_id
)

select * from final