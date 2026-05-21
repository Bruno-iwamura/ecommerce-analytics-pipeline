with orders as (
    select * from {{ ref('stg_orders') }}
),

order_items as (
    select * from {{ ref('stg_order_items') }}
),

order_payments as (
    select * from {{ ref('stg_order_payments') }}
),

daily_revenue as (
    select
        order_id,
        sum(amount) as total_amount
    from order_payments
    group by order_id
),

final as (
    select
        date(o.purchased_at)        as order_date,
        count(distinct o.order_id)  as total_orders,
        count(distinct case when o.order_status = 'delivered'
            then o.order_id end)    as delivered_orders,
        count(distinct case when o.order_status = 'canceled'
            then o.order_id end)    as canceled_orders,
        round(coalesce(sum(p.total_amount), 0), 2)  as gross_revenue,
        round(coalesce(avg(p.total_amount), 0), 2)  as avg_order_value
    from orders o
    left join daily_revenue p on o.order_id = p.order_id
    where o.purchased_at is not null
    group by order_date
)

select * from final
order by order_date