-- =====================================================================
-- 03_consultas.sql — Consultas para revisar el modelo y calcular KPIs
-- =====================================================================
-- Cada SELECT de este archivo se muestra en la terminal al ejecutar
-- run_sql.py. Usalo para:
--   * comprobar que las tablas se cargaron bien (cantidad de filas, nulos...)
--   * escribir las consultas clave de los KPIs que pide la consigna
--     (ventas, usuarios activos, ticket promedio, NPS, ventas por provincia,
--     ranking mensual por producto) usando las tablas del modelo estrella.
-- =====================================================================


-- Ejemplo: revisar la dimensión producto
SELECT product_key, name, category, family, list_price
FROM dim_product
ORDER BY product_key;


-- TU TURNO: agregá acá tus consultas.

-- ==========================================================

-- Revisar la dimension canal (dim_channel)
SELECT channel_key, channel_id, code, name
FROM dim_channel
ORDER BY  channel_key;

-- Revisar la dimension provincia(dim_province)
SELECT province_key,  province_id, name, code
FROM dim_province
ORDER BY province_key;

-- Revisar la dimensión cliente (dim_customer) 

SELECT customer_key, customer_id, first_name, last_name, email, phone, status, created_at 
FROM dim_customer
ORDER BY customer_key
LIMIT 10;

SELECT COUNT(*) AS filas FROM dim_customer; --> 3471 filas

-- nullos
SELECT
-- cantidad de filas totales menos cantidad de filas tienen datos en una columna en especifico ( nos da los null)
    COUNT(*) - COUNT(customer_key) AS sin_key,
    COUNT(*) - COUNT(customer_id)  AS sin_id,
    COUNT(*) - COUNT(first_name)   AS sin_first_name,
    COUNT(*) - COUNT(last_name)    AS sin_last_name,
    COUNT(*) - COUNT(email)        AS sin_email,
    COUNT(*) - COUNT(phone)        AS sin_phone, --> Tiene 276 nulos
    COUNT(*) - COUNT(status)       AS sin_status,
    COUNT(*) - COUNT(created_at)   AS sin_created_at
FROM dim_customer;

-- Revisar la dimensión tienda (dim_store)
SELECT store_key, store_id, name, city, province
FROM dim_store
ORDER BY store_key;

-- Revisar la dimension fecha (dim_date)

SELECT date_key, fecha, year, quarter, month, month_name, day_name
FROM dim_date
ORDER BY date_key
LIMIT 10;

SELECT COUNT(*) AS filas FROM dim_date;

-- ==========================================================

-- CONTROL DE DIMENSIONES NO NECESARIAS:


-- Revisar la dimensión metodo de pago
SELECT payment_method_key, method
FROM dim_payment_method
ORDER BY payment_method_key;


-- Revisar la dimensión origen de visita (dim_Source)
SELECT source_key, source
FROM dim_source
ORDER BY source_key;


-- revisar la dimension dispositivo
SELECT device_key, device
FROM dim_device
ORDER BY device_key;

-- Filas: hecho y origen

SELECT 'orders' AS hecho, (SELECT COUNT(*) FROM fact_orders)       - (SELECT COUNT(*) FROM raw.sales_order)      AS diferencia
UNION ALL SELECT 'sales',    (SELECT COUNT(*) FROM fact_sales)        - (SELECT COUNT(*) FROM raw.sales_order_item)
UNION ALL SELECT 'sessions', (SELECT COUNT(*) FROM fact_web_session)  - (SELECT COUNT(*) FROM raw.web_session)
UNION ALL SELECT 'nps',      (SELECT COUNT(*) FROM fact_nps)          - (SELECT COUNT(*) FROM raw.nps_response)
UNION ALL SELECT 'payment',  (SELECT COUNT(*) FROM fact_payment)      - (SELECT COUNT(*) FROM raw.payment)
UNION ALL SELECT 'shipment', (SELECT COUNT(*) FROM fact_shipment)     - (SELECT COUNT(*) FROM raw.shipment);

-- Importes: hecho  y origen
SELECT (SELECT SUM(total_amount) FROM fact_orders) - (SELECT SUM(total_amount) FROM raw.sales_order)     AS diferencia_pedidos;
SELECT (SELECT SUM(line_total)   FROM fact_sales)  - (SELECT SUM(line_total)   FROM raw.sales_order_item) AS diferencia_lineas;