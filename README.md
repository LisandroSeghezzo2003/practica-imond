# EcoBottle AR — Data Warehouse (Modelo Estrella)

Trabajo práctico de **Introducción al Marketing Online y los Negocios Digitales**.

Se arma un data warehouse con modelo estrella (Kimball) a partir de los datos de ventas de EcoBottle AR (online + tiendas físicas), para alimentar un dashboard con los KPIs: Ventas, Usuarios Activos, Ticket Promedio, NPS, Ventas por Provincia y Ranking Mensual por Producto.

El proyecto transforma tablas transaccionales (un CSV por tabla en `raw/`) en un modelo dimensional listo para análisis. Todo el proceso es reproducible: un solo comando reconstruye el warehouse desde cero y exporta los resultados a CSV, que son la fuente del dashboard.

- **Autor:** Lisandro Seghezzo
- **Dashboard:** archivo de Power BI en [`dashboard/EcoBottle_Dashboard.pbix`](dashboard/EcoBottle_Dashboard.pbix) (ver la [sección 8](#8-dashboard-y-archivo-binario))

---

## 1. Estructura del repositorio

```
.
├── raw/                    # Datos de origen (un CSV por tabla). No se modifican.
├── sql/
│   ├── 01_dimensiones.sql  # Tablas de dimensiones
│   ├── 02_hechos.sql       # Tablas de hechos (con FOREIGN KEY a las dimensiones)
│   ├── 03_consultas.sql    # Controles de calidad y consultas de los KPIs
│   └── 04_data_marts.sql   # Data marts: tablas con los KPIs calculados para Power BI
├── dashboard/              # Tablero de Power BI (archivo binario .pbix)
├── dw/                     # Data warehouse en CSV (se genera al ejecutar)
├── generator/              # Generador de los datos de raw/
├── run_sql.py              # Ejecuta los SQL y arma el data warehouse
└── requirements.txt        # Dependencias (DuckDB)

```
## 2. Instrucciones de ejecución

Requisitos: Python 3.9 o superior y Git.

```powershell
# 1. Clonar el fork
git clone https://github.com/LisandroSeghezzo2003/practica-imond.git
cd practica-imond

# 2. Crear y activar el entorno virtual
python -m venv .venv
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.venv\Scripts\Activate.ps1

# 3. Instalar dependencias
pip install -r requirements.txt

# 4. Construir el data warehouse
python run_sql.py
```

En Mac/Linux la activación es `source .venv/bin/activate`.

### ¿Qué hace `python run_sql.py`?

Reconstruye todo desde cero en cada ejecución:

1. Crea `warehouse.duckdb`.
2. Ejecuta los archivos de `sql/` en orden.
3. Muestra por consola el resultado de cada `SELECT`.
4. Exporta cada tabla creada como CSV en `dw/` (fuente del dashboard).

Otros modos:

| Comando | Qué hace |
|---|---|
| `python run_sql.py --explorar` | Abre DuckDB en el navegador con las tablas de origen (`raw.*`) |
| `python run_sql.py --ui` | Arma el warehouse y abre DuckDB con las tablas del modelo y las de origen |

## 3. Modelo estrella

### Dimensiones

| Dimensión | Fuente | Clave subrogada | Clave natural |
|---|---|---|---|
| `dim_date` | generada (01/01/2024 – 30/09/2025) | `date_key` (AAAAMMDD) | `fecha` |
| `dim_channel` | `raw.channel` | `channel_key` | `channel_id` |
| `dim_province` | `raw.province` | `province_key` | `province_id` |
| `dim_product` | `raw.product` + `raw.product_category` | `product_key` | `product_id` |
| `dim_customer` | `raw.customer` | `customer_key` | `customer_id` |
| `dim_store` | `raw.store` + `raw.address` + `raw.province` | `store_key` | `store_id` |
| `dim_payment_method` | valores distintos de `raw.payment.method` | `payment_method_key` | `method` |
| `dim_source` | valores distintos de `raw.web_session.source` | `source_key` | `source` |
| `dim_device` | valores distintos de `raw.web_session.device` | `device_key` | `device` |

### Hechos

| Hecho | Grano (una fila es...) | Fuente | Alimenta |
|---|---|---|---|
| `fact_orders` | un pedido | `raw.sales_order` | Ventas, Ticket Promedio, Ventas por Provincia |
| `fact_sales` | un producto dentro de un pedido | `raw.sales_order_item` | Ranking mensual por producto |
| `fact_web_session` | una sesión web | `raw.web_session` | Usuarios Activos |
| `fact_nps` | una respuesta de encuesta | `raw.nps_response` | NPS |
| `fact_payment` | un pago | `raw.payment` | Conciliación ventas vs. pagos |
| `fact_shipment` | un envío por correo | `raw.shipment` | Logística y tiempos de entrega |

### Relaciones principales

Todas las relaciones son de **muchos a uno** (N:1): muchas filas del hecho apuntan a una fila de la dimensión. "Obligatoria" significa que la clave foránea nunca es `NULL`; "Opcional" significa que puede ser `NULL` por definición del negocio.

| Hecho | Clave foránea | Referencia a | Tipo | Cuándo es `NULL` |
|---|---|---|---|---|
| `fact_orders` | `date_key` | `dim_date` | Obligatoria | — |
| | `customer_key` | `dim_customer` | Obligatoria | — |
| | `channel_key` | `dim_channel` | Obligatoria | — |
| | `province_key` | `dim_province` | Obligatoria | — |
| | `store_key` | `dim_store` | Opcional | Pedidos online (no hay tienda) |
| `fact_sales` | `order_id` | `fact_orders` | Obligatoria | — |
| | `product_key` | `dim_product` | Obligatoria | — |
| | `date_key`, `channel_key`, `province_key` | `dim_date`, `dim_channel`, `dim_province` | Obligatoria | — |
| `fact_payment` | `order_id` | `fact_orders` | Obligatoria | — |
| | `payment_method_key` | `dim_payment_method` | Obligatoria | — |
| | `date_key` | `dim_date` | Opcional | Pago no concretado |
| `fact_shipment` | `order_id` | `fact_orders` | Obligatoria | — |
| | `shipped_date_key`, `delivered_date_key` | `dim_date` | Opcional | Envío aún no despachado o no entregado |
| `fact_web_session` | `date_key` | `dim_date` | Obligatoria | — |
| | `customer_key` | `dim_customer` | Opcional | Visitante anónimo |
| | `source_key`, `device_key` | `dim_source`, `dim_device` | Opcional | Sin dato de origen o dispositivo |
| `fact_nps` | `date_key`, `channel_key` | `dim_date`, `dim_channel` | Obligatoria | — |
| | `customer_key` | `dim_customer` | Opcional | Respuesta anónima |

**Cómo leerlas**

- **Pedidos como eje central**: `fact_orders` conecta con fecha, cliente, canal, provincia y tienda. De él cuelgan las líneas del pedido (`fact_sales`), los pagos (`fact_payment`) y los envíos (`fact_shipment`), todos vinculados por `order_id`.
- **Un pedido, muchas líneas**: un pedido tiene una o más líneas en `fact_sales` (una por producto). También puede tener varios pagos, por ejemplo un intento fallido y uno exitoso.
- **Dimensiones compartidas**: `dim_date` se usa en todos los hechos, y `dim_customer` y `dim_channel` en varios. Eso permite cruzar métricas, por ejemplo ventas y NPS por canal y mes.
- **Fechas con rol**: `fact_shipment` usa `dim_date` dos veces, una para el despacho (`shipped_date_key`) y otra para la entrega (`delivered_date_key`).


> El diagrama completo generado automáticamente está en [`dw/modelo_estrella.md`](dw/modelo_estrella.md).

## 4. Diccionario de datos

### dim_date
| Columna | Tipo | Descripción |
|---|---|---|
| date_key | INTEGER (PK) | Fecha como número, ej. 20240131 |
| fecha | DATE | Fecha |
| year, quarter, month | INTEGER | Año, trimestre y mes |
| month_name, day_name | VARCHAR | Nombre del mes y del día |

### dim_channel
| Columna | Tipo | Descripción |
|---|---|---|
| channel_key | INTEGER (PK) | Clave del warehouse |
| channel_id | INTEGER | ID del sistema de origen |
| code | VARCHAR | `ONLINE` / `OFFLINE` |
| name | VARCHAR | Nombre del canal |

### dim_province
| Columna | Tipo | Descripción |
|---|---|---|
| province_key | INTEGER (PK) | Clave del warehouse |
| province_id | INTEGER | ID de origen |
| name, code | VARCHAR | Nombre y código de la provincia |

### dim_product
| Columna | Tipo | Descripción |
|---|---|---|
| product_key | INTEGER (PK) | Clave del warehouse |
| product_id | INTEGER | ID de origen |
| sku, name | VARCHAR | SKU y nombre |
| category | VARCHAR | Classic / Sport |
| family | VARCHAR | Bottles |
| list_price | DECIMAL(12,2) | Precio de lista, sin IVA |

### dim_customer
| Columna | Tipo | Descripción |
|---|---|---|
| customer_key | INTEGER (PK) | Clave del warehouse |
| customer_id | INTEGER | ID de origen |
| first_name, last_name, email | VARCHAR | Datos del cliente |
| phone | VARCHAR | Opcional (hay clientes sin teléfono) |
| status | VARCHAR | `A` activo / `I` dado de baja |
| created_at | TIMESTAMP | Fecha de alta |

### dim_store
| Columna | Tipo | Descripción |
|---|---|---|
| store_key | INTEGER (PK) | Clave del warehouse |
| store_id | INTEGER | ID de origen |
| name, city, province | VARCHAR | Nombre, ciudad y provincia de la tienda |

### dim_payment_method / dim_source / dim_device
Cada una tiene una clave (`payment_method_key`, `source_key`, `device_key`) y una columna con el valor (`method`, `source`, `device`).

### fact_orders
| Columna | Tipo | Descripción |
|---|---|---|
| order_id | BIGINT (PK) | Pedido |
| date_key, customer_key, channel_key, province_key | INTEGER (FK) | Dimensiones (obligatorias) |
| store_key | INTEGER (FK, admite NULL) | NULL en pedidos online |
| status | VARCHAR | CREATED, PAID, CANCELLED, FULFILLED, REFUNDED |
| is_sale | INTEGER | 1 si el estado es PAID o FULFILLED |
| subtotal, tax_amount, shipping_fee, total_amount | DECIMAL(12,2) | Importes del pedido |

### fact_sales
| Columna | Tipo | Descripción |
|---|---|---|
| order_item_id | BIGINT (PK) | Línea de pedido |
| order_id | BIGINT (FK) | Pedido (`fact_orders`) |
| date_key, product_key, channel_key, province_key | INTEGER (FK) | Dimensiones |
| is_sale | INTEGER | 1 si cuenta como venta |
| quantity | INTEGER | Cantidad |
| unit_price, discount_amount, line_total | DECIMAL(12,2) | `line_total = cantidad × precio − descuento` |

### fact_web_session
| Columna | Tipo | Descripción |
|---|---|---|
| session_id | BIGINT (PK) | Sesión |
| date_key | INTEGER (FK) | Fecha de inicio |
| customer_key, source_key, device_key | INTEGER (FK, admiten NULL) | NULL en visitantes anónimos o sin dato |
| started_at, ended_at | TIMESTAMP | Inicio y fin de la sesión |

### fact_nps
| Columna | Tipo | Descripción |
|---|---|---|
| nps_id | BIGINT (PK) | Respuesta |
| date_key, channel_key | INTEGER (FK) | Fecha y canal |
| customer_key | INTEGER (FK, admite NULL) | NULL en respuestas anónimas |
| score | SMALLINT | 0 a 10 |

### fact_payment
| Columna | Tipo | Descripción |
|---|---|---|
| payment_id | BIGINT (PK) | Pago |
| order_id | BIGINT (FK) | Pedido |
| date_key | INTEGER (FK, admite NULL) | NULL si el pago no se concretó |
| payment_method_key | INTEGER (FK) | Método de pago |
| status | VARCHAR | PENDING, PAID, FAILED, REFUNDED |
| amount | DECIMAL(12,2) | Monto |
| paid_at | TIMESTAMP | Fecha de pago |

### fact_shipment
| Columna | Tipo | Descripción |
|---|---|---|
| shipment_id | BIGINT (PK) | Envío |
| order_id | BIGINT (FK) | Pedido |
| shipped_date_key, delivered_date_key | INTEGER (FK, admiten NULL) | Fechas de despacho y entrega |
| carrier | VARCHAR | Transportista (siempre Correo Argentino) |
| status | VARCHAR | READY, SHIPPED, DELIVERED, CANCELLED |
| days_to_deliver | INTEGER | Días entre despacho y entrega |

## 5. Supuestos y decisiones

### Datos y negocio

- Los datos son una foto del sistema al **30/09/2025 23:59:59** y cubren pedidos del 01/01/2024 al 30/09/2025. `dim_date` cubre exactamente ese rango (639 días).
- Montos en pesos argentinos. Los precios de lista y `line_total` **no incluyen IVA**; `total_amount` **incluye IVA (21 %) y envío**.
- **Solo cuentan como venta** los pedidos `PAID` y `FULFILLED` (`is_sale = 1`). `CREATED`, `CANCELLED` y `REFUNDED` no.
- Ventas y Ticket Promedio usan `total_amount`, como define la consigna. El ranking por producto usa `line_total` (sin IVA ni envío), por lo que **no suma el mismo valor que Ventas**.
- Usuarios activos: clientes distintos con sesión **más** sesiones anónimas contadas por `session_id`.

### Modelado

- Cada tabla usa clave subrogada (`_key`) generada con `ROW_NUMBER()`, siguiendo el ejemplo de `dim_product`.
- `fact_orders` y `fact_sales` tienen grano distinto: los importes del pedido (envío, IVA, total) viven solo en `fact_orders` para no contarlos dos veces.
- **No se usó fila "Desconocido" (`-1`)** en ninguna dimensión. Donde la clave puede venir vacía por definición (tienda en pedidos online, cliente en sesiones y NPS anónimos) la clave foránea admite `NULL`.
- Todos los pedidos tienen dirección de envío y toda dirección tiene provincia, por eso `province_key` es obligatoria. En compras en tienda, la dirección de envío es la de la tienda.
- Se omitió `dim_carrier` porque `shipment.carrier` tiene un único valor (Correo Argentino); queda como atributo de `fact_shipment`.
- Los estados (pedido, pago, envío) se dejaron como atributo de los hechos, sin dimensión propia.

### Calidad de datos

- Se mantienen en `dim_customer` los clientes dados de baja (`status = 'I'`): sus compras siguen en los datos.
- 276 clientes no tienen teléfono (campo opcional); se mantienen como `NULL`.

## 6. Consultas clave (KPIs)

Todas las consultas están en [`sql/03_consultas.sql`](sql/03_consultas.sql).

Estas consultas definen y documentan cada KPI. El tablero no las ejecuta: consume los data marts de la [sección 7](#7-data-marts-capa-de-kpis), que materializan los mismos cálculos en tablas.

### Ventas totales

```sql
SELECT
  SUM(total_amount) AS total_ventas,
  SUM(shipping_fee) AS total_envios,
  SUM(tax_amount)   AS total_impuestos
FROM fact_orders
WHERE is_sale = 1;
```

### Ticket promedio

```sql
SELECT AVG(total_amount) AS ticket_promedio
FROM fact_orders
WHERE is_sale = 1;
```

### Usuarios activos (identificados + anónimos)

```sql
SELECT
  COUNT(DISTINCT customer_key)
  + COUNT(DISTINCT CASE WHEN customer_key IS NULL THEN session_id END) AS usuarios_activos
FROM fact_web_session;
```

### NPS

`NPS = %Promotores (9–10) − %Detractores (0–6)`

```sql
SELECT ROUND(100.0 * (
    SUM(CASE WHEN score >= 9 THEN 1 ELSE 0 END)
  - SUM(CASE WHEN score <= 6 THEN 1 ELSE 0 END)
) / COUNT(*), 1) AS nps
FROM fact_nps;
```

### Ventas por provincia

```sql
SELECT
  p.name AS provincia,
  SUM(f.total_amount) AS ventas
FROM fact_orders AS f
JOIN dim_province AS p ON p.province_key = f.province_key
WHERE f.is_sale = 1
GROUP BY p.name
ORDER BY ventas DESC;
```

### Ranking mensual por producto

```sql
SELECT
  d.year,
  d.month,
  p.name AS producto,
  SUM(f.line_total) AS ventas,
  RANK() OVER (
    PARTITION BY d.year, d.month
    ORDER BY SUM(f.line_total) DESC
  ) AS ranking
FROM fact_sales AS f
JOIN dim_date    AS d ON d.date_key    = f.date_key
JOIN dim_product AS p ON p.product_key = f.product_key
WHERE f.is_sale = 1
GROUP BY d.year, d.month, p.name
ORDER BY d.year, d.month, ranking;
```

## 7. Data marts (capa de KPIs)

Por criterio de la cátedra, los cálculos de los KPIs se resuelven en SQL (proceso ELT) y Power BI se usa para visualizar, sin medidas DAX. Para eso, [`sql/04_data_marts.sql`](sql/04_data_marts.sql) crea cuatro **data marts**: tablas construidas sobre los hechos y las dimensiones, con los campos calculados ya materializados. Se exportan a `dw/` junto con el resto del warehouse.

```
raw/  →  dimensiones y hechos (modelo estrella)  →  data marts  →  dashboard
```

Los hechos y las dimensiones se usan para datos sin agrupar ni calcular. Los marts se usan para indicadores y campos calculados.

### Marts disponibles

| Mart | Una fila es... | Fuente | Filtro aplicado | Alimenta |
|---|---|---|---|---|
| `marts_orders` | un pedido vendido | `fact_orders` + `dim_date` + `dim_channel` + `dim_province` | `is_sale = 1` | Total Ventas, Ticket Promedio, Pedidos Vendidos, Ventas por Provincia, IVA y envío |
| `marts_sales_products` | una línea de pedido vendida | `fact_sales` + `dim_date` + `dim_product` + `dim_channel` + `dim_province` | `is_sale = 1` | Participación y evolución mensual por producto, ranking |
| `marts_web_active_users` | una sesión web | `fact_web_session` + `dim_date` | ninguno | Usuarios Activos (identificados y anónimos) |
| `marts_nps` | una respuesta de encuesta | `fact_nps` + `dim_date` + `dim_channel` | ninguno | NPS |

### Decisiones de diseño

- **La regla de venta se aplica en SQL.** `marts_orders` y `marts_sales_products` solo contienen pedidos `PAID` y `FULFILLED`, así que el tablero no necesita filtrar por estado.
- **Los marts están desnormalizados.** Traen año, mes, nombre del canal, de la provincia y del producto, por lo que no dependen de relaciones con las dimensiones para filtrar.
- **Los campos calculados se crean en SQL**: `ventas_sin_envio`, `usuario_activo_id`, `tipo_usuario`, `nps_category` y `puntos_nps`.
- **Power BI solo aplica la agregación básica de cada columna** (Suma, Promedio, Recuento distinto), sin escribir medidas DAX.

### Cómo se obtiene cada KPI en el tablero

| KPI | Mart y columna | Agregación en Power BI |
|---|---|---|
| Total Ventas | `marts_orders[ventas_totales]` | Suma |
| Ticket Promedio | `marts_orders[ventas_totales]` | Promedio |
| Pedidos Vendidos | `marts_orders[order_id]` | Recuento |
| Ventas por Provincia | `marts_orders[province_name]` y `ventas_totales` | Suma |
| IVA y envío | `marts_orders[impuestos]` y `costo_envio` | Suma |
| Ventas por producto | `marts_sales_products[ventas_producto]` por `product_name` | Suma |
| Unidades vendidas | `marts_sales_products[unidades_vendidas]` | Suma |
| Usuarios Activos | `marts_web_active_users[usuario_activo_id]` | Recuento (distinto) |
| NPS | `marts_nps[puntos_nps]` | Promedio |

Por qué cada agregación da el valor que define la consigna:

- **Ticket Promedio:** como `marts_orders` solo tiene pedidos vendidos, el promedio de `ventas_totales` equivale a `SUM(total_amount) / COUNT(*)`.
- **Usuarios Activos:** `usuario_activo_id` vale `CUST-<customer_key>` para clientes identificados y `ANON-<session_id>` para anónimos. El recuento distinto equivale a clientes distintos más sesiones anónimas.
- **NPS:** `puntos_nps` vale 100 para promotores (9–10), 0 para pasivos (7–8) y −100 para detractores (0–6). Su promedio es `(%Promotores − %Detractores) × 100`.

### Diccionario de los marts

#### marts_orders
| Columna | Tipo | Descripción |
|---|---|---|
| order_id | BIGINT | Pedido |
| date_key, full_date, year, month, month_name | — | Fecha del pedido y sus partes |
| customer_key, channel_key, province_key | INTEGER | Claves del cliente, canal y provincia |
| channel_name, province_name | VARCHAR | Nombre del canal y de la provincia de envío |
| ventas_sin_impuestos | DECIMAL(12,2) | `subtotal` del pedido |
| impuestos | DECIMAL(12,2) | IVA (`tax_amount`) |
| ventas_sin_envio | DECIMAL(12,2) | `subtotal + tax_amount` |
| costo_envio | DECIMAL(12,2) | `shipping_fee` |
| ventas_totales | DECIMAL(12,2) | `total_amount` (subtotal + IVA + envío) |

#### marts_sales_products
| Columna | Tipo | Descripción |
|---|---|---|
| order_item_id, order_id | BIGINT | Línea y pedido |
| date_key, full_date, year, month, month_name | — | Fecha del pedido y sus partes |
| product_key, product_name, product_category | — | Producto y su categoría |
| channel_key, channel_name, province_key, province_name | — | Canal y provincia |
| unidades_vendidas | INTEGER | `quantity` |
| ventas_producto | DECIMAL(12,2) | `line_total`, sin IVA ni envío |

#### marts_web_active_users
| Columna | Tipo | Descripción |
|---|---|---|
| session_id | BIGINT | Sesión |
| date_key, full_date, year, month, month_name | — | Fecha de inicio y sus partes |
| customer_key, source_key, device_key | INTEGER | Claves; pueden ser `NULL` |
| usuario_activo_id | VARCHAR | `CUST-<customer_key>` o `ANON-<session_id>` |
| tipo_usuario | VARCHAR | `Identificado` o `Anónimo` |

#### marts_nps
| Columna | Tipo | Descripción |
|---|---|---|
| nps_id | BIGINT | Respuesta |
| date_key, full_date, year, month, month_name | — | Fecha de la respuesta y sus partes |
| customer_key, channel_key, channel_name | — | Cliente (puede ser `NULL`) y canal |
| score | SMALLINT | Puntaje de 0 a 10 |
| nps_category | VARCHAR | `Promotor`, `Pasivo` o `Detractor` |
| puntos_nps | DECIMAL | 100, 0 o −100 |

### Qué filtro mueve a cada mart

| Filtro | `marts_orders` | `marts_sales_products` | `marts_web_active_users` | `marts_nps` |
|---|---|---|---|---|
| Fecha | Sí | Sí | Sí | Sí |
| Canal | Sí | Sí | No | Sí |
| Provincia | Sí | Sí | No | No |
| Producto | No | Sí | No | No |

- **Usuarios Activos** responde solo a la fecha: la sesión web no tiene canal ni provincia.
- **NPS** no responde a la provincia: la encuesta no está asociada a un pedido ni a una dirección.
- **Total Ventas y Ticket Promedio** no responden al filtro de producto, porque `marts_orders` tiene una fila por pedido y un pedido puede incluir varios productos.
- **Ventas por producto** usa `ventas_producto` (`line_total`, sin IVA ni envío), por lo que no suma lo mismo que Total Ventas. La diferencia son el IVA y el envío.
- **Anónimos:** cada sesión anónima cuenta como un usuario distinto, porque no hay forma de saber si dos sesiones son de la misma persona. Por eso la cifra de anónimos son, en realidad, sesiones.

### Verificación de los marts

```sql
SELECT SUM(ventas_totales) AS total_ventas, COUNT(*) AS pedidos, AVG(ventas_totales) AS ticket
FROM marts_orders;                                    -- 382.410.636 y 10.998 pedidos

SELECT SUM(ventas_producto) FROM marts_sales_products; -- unos 309,9 millones

SELECT COUNT(DISTINCT usuario_activo_id) FROM marts_web_active_users;

SELECT ROUND(AVG(puntos_nps), 1) AS nps FROM marts_nps; -- 30,0
```

Los valores tienen que coincidir con las consultas de KPIs de la [sección 6](#6-consultas-clave-kpis).

## 8. Dashboard y archivo binario

El tablero se desarrolló en **Power BI Desktop** y está en [`dashboard/EcoBottle_Dashboard.pbix`](dashboard/EcoBottle_Dashboard.pbix). Toma como fuente los CSV de la carpeta `dw/`: los data marts y las dimensiones que usan los filtros.

### Por qué hay un archivo binario en el repositorio

El `.pbix` es el **entregable principal** del trabajo (el tablero que pide la consigna), y se versiona junto con el código para que quien corrige pueda abrirlo directamente. Es un archivo **binario**: un formato comprimido que guarda el diseño de las páginas, el modelo de datos y una copia de los datos cargados.

### Cómo abrirlo con datos actualizados

El `.pbix` guarda los datos tal como estaban al momento de guardarlo. Para regenerarlos:

1. Ejecutar `python run_sql.py`, que reconstruye `dw/`.
2. Abrir `dashboard/EcoBottle_Dashboard.pbix` en Power BI Desktop.
3. Si la ruta de origen no existe en la computadora, ir a **Inicio → Transformar datos → Configuración del origen de datos** y apuntar a la carpeta `dw/` local.
4. Hacer clic en **Actualizar**.

### Nota sobre los decimales

Los CSV de `dw/` usan **punto** como separador decimal. En Power BI las columnas de importes se importan con la configuración regional **Inglés (Estados Unidos)**. Si se importan con la configuración en español, el punto se interpreta como separador de miles y los importes quedan multiplicados por 100.

## 9. Controles de calidad

`sql/03_consultas.sql` incluye controles que se muestran al ejecutar `run_sql.py`:

| Control | Resultado esperado |
|---|---|
| Cantidad de filas de cada hecho y dimensión vs. origen | Diferencia = 0 |
| Suma de `total_amount` y `line_total` vs. origen | Diferencia = 0 |
| Conteo de nulos por columna en dimensiones | Solo `phone` tiene nulos (276) |
| Ventas por provincia, canal y mes vs. KPI de Ventas | Suman el mismo total |

## 10. Convención de commits

Se usan *conventional commits*: `tipo: descripción`.

| Tipo | Uso |
|---|---|
| `feat` | nueva dimensión, hecho o consulta |
| `fix` | corrección de un error |
| `refactor` | reordenar código sin cambiar el resultado |
| `docs` | README y documentación |
| `chore` | tareas menores (requirements, .gitignore) |
