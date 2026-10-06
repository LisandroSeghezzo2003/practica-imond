# EcoBottle AR — Data Warehouse (Modelo Estrella)

Trabajo práctico de **Introducción al Marketing Online y los Negocios Digitales**.

Se arma un data warehouse con modelo estrella (Kimball) a partir de los datos de ventas de EcoBottle AR (online + tiendas físicas), para alimentar un dashboard con los KPIs: Ventas, Usuarios Activos, Ticket Promedio, NPS, Ventas por Provincia y Ranking Mensual por Producto.

- **Autor:** Lisandro Seghezzo
- **Dashboard:** `<pegar enlace o ver capturas en /docs>`

---

## 1. Estructura del repositorio

```
raw/               datos de origen (un CSV por tabla). No se modifican.
sql/
  01_dimensiones.sql   tablas de dimensiones
  02_hechos.sql        tablas de hechos (con FOREIGN KEY a las dimensiones)
  03_consultas.sql     controles de calidad y consultas de los KPIs
run_sql.py         ejecuta los SQL y arma el data warehouse
requirements.txt   dependencias (DuckDB)
dw/                data warehouse en CSV (se genera al ejecutar)
generator/         generador de los datos de raw/ (no se usa en la práctica)
```

## 2. Instrucciones de ejecución

Requisitos: Python 3.9 o superior y Git.

```powershell
# 1. Clonar el fork
git clone https://github.com/LisandroSeghezzo2003/practica-imond.git
cd practica-imond

# 2. Crear y activar el entorno virtual (Windows PowerShell)
python -m venv .venv
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.venv\Scripts\Activate.ps1

# 3. Instalar dependencias
pip install -r requirements.txt

# 4. Construir el data warehouse
python run_sql.py
```

En Mac/Linux la activación es `source .venv/bin/activate`.

`python run_sql.py` arma todo desde cero en cada ejecución: crea `warehouse.duckdb`, ejecuta los archivos de `sql/` en orden, muestra el resultado de cada `SELECT` y exporta cada tabla creada como CSV en `dw/`. Esos CSV son la fuente del dashboard.

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

```
dim_date ───────┐
dim_channel ────┤
dim_province ───┼── fact_orders ── fact_sales ── dim_product
dim_customer ───┤        │
dim_store ──────┘        ├── fact_payment ── dim_payment_method
                         └── fact_shipment

dim_date, dim_customer, dim_source, dim_device ── fact_web_session
dim_date, dim_customer, dim_channel ─────────── fact_nps
```

El diagrama generado automáticamente está en `dw/modelo_estrella.md`.

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

- Los datos son una foto del sistema al 30/09/2025 23:59:59 y cubren pedidos del 01/01/2024 al 30/09/2025. `dim_date` cubre exactamente ese rango (639 días).
- Montos en pesos argentinos. Los precios de lista y `line_total` no incluyen IVA; `total_amount` incluye IVA (21 %) y envío.
- **Solo cuentan como venta** los pedidos `PAID` y `FULFILLED` (`is_sale = 1`). `CREATED`, `CANCELLED` y `REFUNDED` no.
- Ventas y Ticket Promedio usan `total_amount`, como define la consigna. El ranking por producto usa `line_total` (sin IVA ni envío), por lo que no suma el mismo valor que Ventas.
- Se mantienen en `dim_customer` los clientes dados de baja (`status = 'I'`): sus compras siguen en los datos.
- 276 clientes no tienen teléfono (campo opcional); se mantienen como `NULL`.
- **No se usó fila "Desconocido" (`-1`)** en ninguna dimensión. Donde la clave puede venir vacía por definición (tienda en pedidos online, cliente en sesiones y NPS anónimos) la clave foránea admite `NULL`.
- Todos los pedidos tienen dirección de envío y toda dirección tiene provincia; por eso `province_key` es obligatoria. En compras en tienda, la dirección de envío es la de la tienda.
- Se omitió `dim_carrier` porque `shipment.carrier` tiene un único valor (Correo Argentino); queda como atributo de `fact_shipment`.
- Los estados (pedido, pago, envío) se dejaron como atributo de los hechos, sin dimensión propia.
- **Usuarios activos:** se cuentan clientes distintos con sesión más sesiones anónimas por `session_id`.
- `fact_orders` y `fact_sales` tienen grano distinto: los importes del pedido (envío, IVA, total) viven solo en `fact_orders` para no contarlos dos veces.
- Cada tabla usa clave subrogada (`_key`) generada con `ROW_NUMBER()`, siguiendo el ejemplo `dim_product`.

## 6. Consultas clave (KPIs)

Están en `sql/03_consultas.sql`.

**Total Ventas**
```sql
SELECT SUM(f.total_amount) AS total_ventas
FROM fact_orders AS f
WHERE f.status IN ('PAID', 'FULFILLED');
```

**Ticket Promedio**
```sql
SELECT SUM(total_amount) / COUNT(*) AS ticket_promedio
FROM fact_orders
WHERE status IN ('PAID', 'FULFILLED');
```

**Usuarios Activos**
```sql
SELECT
    COUNT(DISTINCT customer_key)
  + COUNT(DISTINCT CASE WHEN customer_key IS NULL THEN session_id END) AS usuarios_activos
FROM fact_web_session;
```

**NPS**
```sql
SELECT ROUND(100.0 * (
         SUM(CASE WHEN score >= 9 THEN 1 ELSE 0 END)
       - SUM(CASE WHEN score <= 6 THEN 1 ELSE 0 END)
       ) / COUNT(*), 1) AS nps
FROM fact_nps;
```

**Ventas por provincia**
```sql
SELECT p.name AS provincia, SUM(f.total_amount) AS ventas
FROM fact_orders AS f
JOIN dim_province AS p ON p.province_key = f.province_key
WHERE f.status IN ('PAID', 'FULFILLED')
GROUP BY p.name
ORDER BY ventas DESC;
```

**Ranking mensual por producto**
```sql
SELECT d.year, d.month, p.name AS producto,
       SUM(f.line_total) AS ventas,
       RANK() OVER (PARTITION BY d.year, d.month ORDER BY SUM(f.line_total) DESC) AS ranking
FROM fact_sales AS f
JOIN dim_date    AS d ON d.date_key    = f.date_key
JOIN dim_product AS p ON p.product_key = f.product_key
WHERE f.is_sale = 1
GROUP BY d.year, d.month, p.name
ORDER BY d.year, d.month, ranking;
```

## 7. Controles de calidad

`sql/03_consultas.sql` incluye controles que se muestran al ejecutar `run_sql.py`:

- Cantidad de filas de cada hecho y dimensión contra el origen (diferencia esperada: 0).
- Suma de `total_amount` y `line_total` del hecho contra el origen (diferencia esperada: 0).
- Conteo de nulos por columna en las dimensiones (solo `phone` tiene nulos: 276).
- Ventas por provincia, canal y mes suman lo mismo que el KPI de Ventas.

## 8. Dashboard

- Herramienta: `<Power BI / Looker Studio>`
- Fuente: los CSV de `dw/`
- Filtros: fecha, canal, provincia y producto
- Vistas: Ventas, Usuarios Activos, Ticket Promedio, NPS, Ventas por Provincia y Ranking mensual por Producto
- Enlace / capturas: `<completar>`

## 9. Convención de commits

Se usan *conventional commits*: `tipo: descripción`.

| Tipo | Uso |
|---|---|
| `feat` | nueva dimensión, hecho o consulta |
| `fix` | corrección de un error |
| `refactor` | reordenar código sin cambiar el resultado |
| `docs` | README y documentación |
| `chore` | tareas menores (requirements, .gitignore) |

Toda la gestión del repositorio se hace por consola.