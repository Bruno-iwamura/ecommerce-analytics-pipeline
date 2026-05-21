with orders as (
    select * from {{ ref('stg_orders') }}
),

final as (
    select
        date(purchased_at)                          as order_date,
        count(distinct order_id)                    as total_orders,

        countif(order_status = 'delivered')         as delivered_orders,

        countif(
            order_status = 'delivered'
            and delivered_customer_at <= estimated_delivery_at
        )                                           as on_time_deliveries,

        countif(
            order_status = 'delivered'
            and delivered_customer_at > estimated_delivery_at
        )                                           as late_deliveries,

        round(
            safe_divide(
                countif(
                    order_status = 'delivered'
                    and delivered_customer_at <= estimated_delivery_at
                ),
                nullif(countif(order_status = 'delivered'), 0)
            ) * 100, 2
        )                                           as on_time_rate_pct,

        round(avg(
            case when order_status = 'delivered'
                then date_diff(
                    date(delivered_customer_at),
                    date(purchased_at),
                    day)
            end
        ), 1)                                       as avg_delivery_days

    from orders
    where purchased_at is not null
    group by order_date
)

select * from final
order by order_date