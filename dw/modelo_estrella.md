# Modelo estrella

Generado por `run_sql.py` a partir de las tablas de `warehouse.duckdb`.

```mermaid
erDiagram
    dim_channel ||--o{ fact_nps : "channel_key"
    dim_channel ||--o{ fact_orders : "channel_key"
    dim_channel ||--o{ fact_sales : "channel_key"
    dim_customer ||--o{ fact_nps : "customer_key"
    dim_customer ||--o{ fact_orders : "customer_key"
    dim_customer ||--o{ fact_web_session : "customer_key"
    dim_date ||--o{ fact_nps : "date_key"
    dim_date ||--o{ fact_orders : "date_key"
    dim_date ||--o{ fact_payment : "date_key"
    dim_date ||--o{ fact_sales : "date_key"
    dim_date ||--o{ fact_shipment : "delivered_date_key"
    dim_date ||--o{ fact_shipment : "shipped_date_key"
    dim_date ||--o{ fact_web_session : "date_key"
    dim_device ||--o{ fact_web_session : "device_key"
    dim_payment_method ||--o{ fact_payment : "payment_method_key"
    dim_product ||--o{ fact_sales : "product_key"
    dim_province ||--o{ fact_orders : "province_key"
    dim_province ||--o{ fact_sales : "province_key"
    dim_source ||--o{ fact_web_session : "source_key"
    dim_store ||--o{ fact_orders : "store_key"
    fact_orders ||--o{ fact_payment : "order_id"
    fact_orders ||--o{ fact_sales : "order_id"
    fact_orders ||--o{ fact_shipment : "order_id"
    dim_channel {
        INTEGER channel_key PK
        INTEGER channel_id
        VARCHAR code
        VARCHAR name
    }
    dim_customer {
        INTEGER customer_key PK
        INTEGER customer_id
        VARCHAR first_name
        VARCHAR last_name
        VARCHAR email
        VARCHAR phone
        VARCHAR status
        TIMESTAMP created_at
    }
    dim_date {
        INTEGER date_key PK
        DATE fecha
        INTEGER year
        INTEGER quarter
        INTEGER month
        VARCHAR month_name
        VARCHAR day_name
    }
    dim_device {
        INTEGER device_key PK
        VARCHAR device
    }
    dim_payment_method {
        INTEGER payment_method_key PK
        VARCHAR method
    }
    dim_product {
        INTEGER product_key PK
        INTEGER product_id
        VARCHAR sku
        VARCHAR name
        VARCHAR category
        VARCHAR family
        DECIMAL list_price
    }
    dim_province {
        INTEGER province_key PK
        INTEGER province_id
        VARCHAR name
        VARCHAR code
    }
    dim_source {
        INTEGER source_key PK
        VARCHAR source
    }
    dim_store {
        INTEGER store_key PK
        INTEGER store_id
        VARCHAR name
        VARCHAR city
        VARCHAR province
    }
    fact_nps {
        BIGINT nps_id PK
        INTEGER date_key FK
        INTEGER customer_key FK
        INTEGER channel_key FK
        SMALLINT score
    }
    fact_orders {
        BIGINT order_id PK
        INTEGER date_key FK
        INTEGER customer_key FK
        INTEGER channel_key FK
        INTEGER store_key FK
        INTEGER province_key FK
        VARCHAR status
        INTEGER is_sale
        DECIMAL subtotal
        DECIMAL tax_amount
        DECIMAL shipping_fee
        DECIMAL total_amount
    }
    fact_payment {
        BIGINT payment_id PK
        BIGINT order_id FK
        INTEGER date_key FK
        INTEGER payment_method_key FK
        VARCHAR status
        DECIMAL amount
        TIMESTAMP paid_at
    }
    fact_sales {
        BIGINT order_item_id PK
        BIGINT order_id FK
        INTEGER date_key FK
        INTEGER product_key FK
        INTEGER channel_key FK
        INTEGER province_key FK
        INTEGER is_sale
        INTEGER quantity
        DECIMAL unit_price
        DECIMAL discount_amount
        DECIMAL line_total
    }
    fact_shipment {
        BIGINT shipment_id PK
        BIGINT order_id FK
        INTEGER shipped_date_key FK
        INTEGER delivered_date_key FK
        VARCHAR carrier
        VARCHAR status
        INTEGER days_to_deliver
    }
    fact_web_session {
        BIGINT session_id PK
        INTEGER date_key FK
        INTEGER customer_key FK
        INTEGER source_key FK
        INTEGER device_key FK
        TIMESTAMP started_at
        TIMESTAMP ended_at
    }
    marts_nps {
        BIGINT nps_id
        INTEGER date_key
        DATE full_date
        INTEGER year
        INTEGER month
        VARCHAR month_name
        INTEGER customer_key
        INTEGER channel_key
        VARCHAR channel_name
        SMALLINT score
        VARCHAR nps_category
        DECIMAL puntos_nps
    }
    marts_orders {
        BIGINT order_id
        INTEGER date_key
        DATE full_date
        INTEGER year
        INTEGER month
        VARCHAR month_name
        INTEGER customer_key
        INTEGER channel_key
        VARCHAR channel_name
        INTEGER province_key
        VARCHAR province_name
        DECIMAL ventas_sin_impuestos
        DECIMAL impuestos
        DECIMAL ventas_sin_envio
        DECIMAL costo_envio
        DECIMAL ventas_totales
    }
    marts_sales_products {
        BIGINT order_item_id
        BIGINT order_id
        INTEGER date_key
        DATE full_date
        INTEGER year
        INTEGER month
        VARCHAR month_name
        INTEGER product_key
        VARCHAR product_name
        VARCHAR product_category
        INTEGER channel_key
        VARCHAR channel_name
        INTEGER province_key
        VARCHAR province_name
        INTEGER unidades_vendidas
        DECIMAL ventas_producto
    }
    marts_web_active_users {
        BIGINT session_id
        INTEGER date_key
        DATE full_date
        INTEGER year
        INTEGER month
        VARCHAR month_name
        INTEGER customer_key
        INTEGER source_key
        INTEGER device_key
        VARCHAR usuario_activo_id
        VARCHAR tipo_usuario
    }
```
