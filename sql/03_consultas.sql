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

SELECT COUNT(*) AS filas FROM dim_customer;

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
