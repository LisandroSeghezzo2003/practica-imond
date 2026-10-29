-- =====================================================================
-- 04_data_marts.sql — Capa de Data Marts
-- Regla de venta: is_sale = 1
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Data Mart de Pedidos Efectivos (marts_orders)
-- Alimenta: Total Ventas, Ticket Promedio, Pedidos Vendidos y Mapa
-- ---------------------------------------------------------------------
CREATE TABLE marts_orders AS
SELECT
    o.order_id,
    o.date_key,
    d.fecha AS full_date,
    d.year,
    d.month,
    d.month_name,
    o.customer_key,
    o.channel_key,
    ch.name AS channel_name,
    o.province_key,
    p.name AS province_name,
    o.subtotal AS ventas_sin_impuestos,
    o.tax_amount AS impuestos,
    (o.subtotal + o.tax_amount) AS ventas_sin_envio,
    o.shipping_fee AS costo_envio,
    o.total_amount AS ventas_totales
FROM fact_orders o
JOIN dim_date d      ON o.date_key = d.date_key
JOIN dim_channel ch  ON o.channel_key = ch.channel_key
JOIN dim_province p  ON o.province_key = p.province_key
WHERE o.is_sale = 1;

-- ---------------------------------------------------------------------
-- 2. Data Mart de Ventas por Producto (marts_sales_products)
-- Alimenta: Gráfico de anillo por Producto y Evolución Mensual
-- ---------------------------------------------------------------------
CREATE TABLE marts_sales_products AS
SELECT
    s.order_item_id,
    s.order_id,
    s.date_key,
    d.fecha AS full_date,
    d.year,
    d.month,
    d.month_name,
    s.product_key,
    pr.name AS product_name,
    pr.category AS product_category,
    s.channel_key,
    ch.name AS channel_name,
    s.province_key,
    p.name AS province_name,
    s.quantity AS unidades_vendidas,
    s.line_total AS ventas_producto
FROM fact_sales s
JOIN dim_date d      ON s.date_key = d.date_key
JOIN dim_product pr  ON s.product_key = pr.product_key
JOIN dim_channel ch  ON s.channel_key = ch.channel_key
JOIN dim_province p  ON s.province_key = p.province_key
WHERE s.is_sale = 1;

-- ---------------------------------------------------------------------
-- 3. Data Mart de Usuarios Activos Web (marts_web_active_users)
-- Alimenta: Tarjeta Usuarios Activos y Evolución Mensual
-- ---------------------------------------------------------------------
CREATE TABLE marts_web_active_users AS
SELECT
    ws.session_id,
    ws.date_key,
    d.fecha AS full_date,
    d.year,
    d.month,
    d.month_name,
    ws.customer_key,
    ws.source_key,
    ws.device_key,
    CASE
        WHEN ws.customer_key IS NOT NULL AND ws.customer_key <> -1
            THEN 'CUST-' || CAST(ws.customer_key AS VARCHAR) -- Identificado
        ELSE 'ANON-' || CAST(ws.session_id AS VARCHAR) -- Anónimo
    END AS usuario_activo_id,
    CASE
        WHEN ws.customer_key IS NOT NULL AND ws.customer_key <> -1
            THEN 'Identificado'
        ELSE 'Anónimo'
    END AS tipo_usuario
FROM fact_web_session ws
JOIN dim_date d ON ws.date_key = d.date_key;

-- ---------------------------------------------------------------------
-- 4. Data Mart de Satisfacción NPS (marts_nps)
-- Alimenta: Medidor de Puntos NPS (usando Promedio de puntos_nps)
-- Promotor: 9-10 | Pasivo: 7-8 | Detractor: 0-6
-- ---------------------------------------------------------------------
CREATE TABLE marts_nps AS
SELECT
    n.nps_id,
    n.date_key,
    d.fecha AS full_date,
    d.year,
    d.month,
    d.month_name,
    n.customer_key,
    n.channel_key,
    ch.name AS channel_name,
    n.score,
    CASE
        WHEN n.score >= 9 THEN 'Promotor'
        WHEN n.score >= 7 THEN 'Pasivo'
        ELSE 'Detractor'
    END AS nps_category,
    CASE
        WHEN n.score >= 9 THEN 100.0
        WHEN n.score >= 7 THEN 0.0
        ELSE -100.0
    END AS puntos_nps
FROM fact_nps n
JOIN dim_date d     ON n.date_key = d.date_key
JOIN dim_channel ch ON n.channel_key = ch.channel_key;
