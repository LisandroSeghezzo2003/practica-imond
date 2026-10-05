-- =====================================================================
-- 02_hechos.sql — Tablas de HECHOS del modelo estrella
-- =====================================================================
-- Este archivo se ejecuta después de 01_dimensiones.sql porque los hechos
-- apuntan a las dimensiones con FOREIGN KEY (REFERENCES).
--
-- Para cada tabla de hechos:
--   1. Definí el GRANO: ¿qué representa UNA fila?
--      (ej.: un producto dentro de un pedido, una sesión web, una respuesta NPS)
--   2. CREATE TABLE con:
--        - PRIMARY KEY
--        - una FOREIGN KEY por cada dimensión:  product_key INTEGER REFERENCES dim_product (product_key)
--        - las métricas (cantidades, importes, puntajes...)
--   3. INSERT INTO ... SELECT uniendo las tablas de origen (raw.) con las dimensiones
--      para obtener las claves.
--
-- Patrón para obtener la clave de una dimensión:
--
--   SELECT i.order_item_id, p.product_key, i.quantity, i.line_total
--   FROM raw.sales_order_item AS i
--   JOIN dim_product AS p ON p.product_id = i.product_id
--
-- Si una FOREIGN KEY apunta a una clave que no existe en la dimensión,
-- DuckDB rechaza la carga y run_sql.py te muestra el error.
-- =====================================================================


-- TU TURNO: creá acá las tablas de hechos.

-- ---------------------------------------------------------------------
-- fact_orders
-- Grano: una fila por pedido (raw.sales_order)
-- ---------------------------------------------------------------------
CREATE TABLE fact_orders (
    order_id BIGINT PRIMARY KEY,
    date_key INTEGER NOT NULL REFERENCES dim_date (date_key),
    customer_key INTEGER NOT NULL REFERENCES dim_customer (customer_key),
    channel_key INTEGER NOT NULL REFERENCES dim_channel (channel_key),
    store_key INTEGER REFERENCES dim_store (store_key),
    province_key INTEGER NOT NULL REFERENCES dim_province (province_key),
    status VARCHAR,    
    is_sale INTEGER,
    subtotal DECIMAL(12, 2),
    tax_amount DECIMAL(12, 2),
    shipping_fee DECIMAL(12, 2),
    total_amount DECIMAL(12, 2)
);



INSERT INTO fact_orders
SELECT
    o.order_id,
    dd.date_key,
    dc.customer_key,
    dch.channel_key,
    ds.store_key,
    dp.province_key,
    o.status,
    CASE WHEN o.status IN ('PAID', 'FULFILLED') THEN 1 ELSE 0 END,
    o.subtotal,
    o.tax_amount,
    o.shipping_fee,
    o.total_amount
FROM raw.sales_order AS o
JOIN dim_date     AS dd  ON dd.fecha = CAST(o.order_date AS DATE)
JOIN dim_customer AS dc  ON dc.customer_id = o.customer_id
JOIN dim_channel  AS dch ON dch.channel_id = o.channel_id
LEFT JOIN dim_store AS ds ON ds.store_id = o.store_id
JOIN raw.address  AS a   ON a.address_id = o.shipping_address_id
JOIN dim_province AS dp  ON dp.province_id = a.province_id;

-- ---------------------------------------------------------------------
-- fact_sales
-- Grano: una fila por producto dentro de un pedido (raw.sales_order_item)
-- ------------------------------------------------------------------------
CREATE TABLE fact_sales (
    order_item_id  BIGINT PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES fact_orders (order_id),
    date_key INTEGER NOT NULL REFERENCES dim_date (date_key),
    product_key INTEGER NOT NULL REFERENCES dim_product (product_key),
    channel_key INTEGER NOT NULL REFERENCES dim_channel (channel_key),
    province_key INTEGER NOT NULL REFERENCES dim_province (province_key),
    is_sale INTEGER,
    quantity INTEGER,
    unit_price DECIMAL(12, 2),
    discount_amount DECIMAL(12, 2),
    line_total DECIMAL(12, 2) 
);  

INSERT INTO fact_sales
SELECT
    i.order_item_id,
    i.order_id,
    fo.date_key,
    dp.product_key,
    fo.channel_key,
    fo.province_key,
    fo.is_sale,
    i.quantity,
    i.unit_price,
    i.discount_amount,
    i.line_total
FROM raw.sales_order_item AS i
JOIN fact_orders AS fo ON fo.order_id = i.order_id
JOIN dim_product AS dp ON dp.product_id = i.product_id;


-- ---------------------------------------------------------------------
-- fact_web_session
-- grano: una fila por sesion  web iniciada
-- ---------------------------------------------------------------------

CREATE TABLE fact_web_session (
    session_id BIGINT PRIMARY KEY,
    date_key INTEGER NOT NULL REFERENCES dim_date (date_key),
    customer_key INTEGER REFERENCES dim_customer (customer_key),
    source_key INTEGER REFERENCES dim_source (source_key),
    device_key INTEGER REFERENCES dim_device (device_key),
    started_at TIMESTAMP,
    ended_at TIMESTAMP
);
INSERT INTO fact_web_session
SELECT
    w.session_id,
    dd.date_key,
    dc.customer_key,
    dsr.source_key,
    ddv.device_key,
    w.started_at,
    w.ended_at
FROM raw.web_session AS w
JOIN dim_date AS dd ON dd.fecha = CAST(w.started_at AS DATE)
LEFT JOIN dim_customer AS dc  ON dc.customer_id = w.customer_id
LEFT JOIN dim_source   AS dsr ON dsr.source     = w.source
LEFT JOIN dim_device   AS ddv ON ddv.device     = w.device;

-- ---------------------------------------------------------------------
-- fact_nps
-- Grano: una fila por respuesta NPS (raw.nps_response)
-- ---------------------------------------------------------------------


CREATE TABLE fact_nps (
    nps_id BIGINT PRIMARY KEY,
    date_key INTEGER NOT NULL REFERENCES dim_date (date_key),
    customer_key INTEGER REFERENCES dim_customer (customer_key),
    channel_key INTEGER NOT NULL REFERENCES dim_channel (channel_key),
    score SMALLINT
);

INSERT INTO fact_nps
SELECT
    n.nps_id,
    dd.date_key,
    dc.customer_key,
    dch.channel_key,
    n.score
FROM raw.nps_response AS n
JOIN dim_date AS dd ON dd.fecha = CAST(n.responded_at AS DATE)
JOIN dim_channel AS dch ON dch.channel_id = n.channel_id
LEFT JOIN dim_customer AS dc ON dc.customer_id = n.customer_id;

-- -------------------------------------------------------------------
-- fact_payment
-- Grano: una fila por pago (raw.payment). Cada pedido tiene un pago
-- -------------------------------------------------------------------

CREATE TABLE fact_payment (
    payment_id BIGINT PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES fact_orders (order_id),
    date_key INTEGER REFERENCES dim_date (date_key),
    payment_method_key INTEGER REFERENCES dim_payment_method (payment_method_key),
    status VARCHAR,
    amount DECIMAL(12, 2),
    paid_at TIMESTAMP
);

INSERT INTO fact_payment
SELECT
    p.payment_id,
    p.order_id,
    dd.date_key,
    dm.payment_method_key,
    p.status,
    p.amount,
    p.paid_at
FROM raw.payment AS p
JOIN fact_orders AS fo ON fo.order_id = p.order_id
LEFT JOIN dim_date AS dd ON dd.fecha = CAST(p.paid_at AS DATE)
LEFT JOIN dim_payment_method AS dm ON dm.method = p.method;

