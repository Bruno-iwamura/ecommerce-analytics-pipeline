with products as (
    select * from {{ ref('stg_products') }}
),

order_items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

product_sales as (
    select
        oi.product_id,
        count(distinct oi.order_id)             as total_orders,
        sum(oi.price)                           as gross_revenue,
        sum(oi.freight_value)                   as total_freight,
        round(avg(oi.price), 2)                 as avg_price,
        count(oi.order_item_id)                 as units_sold
    from order_items oi
    inner join orders o on oi.order_id = o.order_id
    where o.order_status not in ('canceled', 'unavailable')
    group by oi.product_id
),

final as (
    select
        p.product_id,
        coalesce(p.category, 'uncategorized')   as category,
        ps.total_orders,
        ps.units_sold,
        round(ps.gross_revenue, 2)              as gross_revenue,
        round(ps.total_freight, 2)              as total_freight,
        ps.avg_price,
        round(
            safe_divide(ps.gross_revenue,
                sum(ps.gross_revenue) over ()
            ) * 100, 4
        )                                       as revenue_share_pct
    from products p
    inner join product_sales ps on p.product_id = ps.product_id
)

select * from final
order by gross_revenue desc