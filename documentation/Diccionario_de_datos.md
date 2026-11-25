# Diccionario de datos

**Sistema de Control de Asistencia de Personal** · Base de datos `db_control_asistencia` · Microsoft SQL Server · Modelo físico v2.4

> Este diccionario también está guardado dentro de la base de datos como propiedades extendidas (`MS_Description`). Para regenerarlo desde SQL Server, ejecuta [`scripts/08_diccionario_datos.sql`](../scripts/08_diccionario_datos.sql).

Convenciones: **PK** clave primaria · **FK** clave foránea · **UQ** única · **NN** NOT NULL · **N** admite NULL.

---

## 1. Tablas

| Tabla | Descripción | Secuencia de la PK |
|---|---|---|
| `staff` | Información personal y laboral del personal docente y administrativo, con su horario asignado. | `staff_seq` |
| `attendance` | Asistencia diaria: entrada, refrigerio, salida, tardanza y ubicación de marcación. Máximo un registro por trabajador y día. | `attendance_seq` |
| `attendance_config` | Horarios por defecto, año escolar y tolerancia de tardanza. | `attendance_config_seq` |
| `justification` | Justificaciones de faltas, tardanzas y otras incidencias. | `justification_seq` |
| `justification_reason` | Catálogo de motivos de justificación. | `justification_reason_seq` |
| `area` | Catálogo de áreas de trabajo. | `area_seq` |
| `position` | Catálogo de cargos. | `position_seq` |
| `site` | Catálogo de sedes con ubicación geográfica y radio permitido de marcación. | `site_seq` |

---

## 2. Columnas

### 2.1 `staff`

| Columna | Tipo | Nulo | Clave | Default | Regla / descripción |
|---|---|---|---|---|---|
| staff_id | bigint | NN | PK | `NEXT VALUE FOR staff_seq` | Identificador del trabajador. |
| last_name | nvarchar(70) | NN | | | Apellidos. |
| first_name | nvarchar(70) | NN | | | Nombres. |
| document_type | char(3) | NN | UQ* | | `DNI`, `CE` o `PAS`. |
| document_number | varchar(12) | NN | UQ* | | DNI = 8 dígitos; CE/PAS = 6–12 alfanuméricos. |
| sex | char(1) | NN | | | `M` o `F`. |
| birth_date | date | N | | | Mayor de 18 años. |
| mobile_phone | char(9) | N | | | 9 dígitos, empieza con 9. |
| position_id | int | NN | FK → position | | Cargo. |
| area_id | int | NN | FK → area | | Área. |
| site_id | int | NN | FK → site | | Sede. |
| work_modality | varchar(20) | NN | | `'PRESENCIAL'` | `PRESENCIAL`, `REMOTO`, `HIBRIDO`. |
| entry_time | time(0) | N | | | Si es NULL se usa `attendance_config.default_entry_time`. |
| exit_time | time(0) | N | | | Debe ser mayor que `entry_time`. |
| break_start_time | time(0) | N | | | Inicio de refrigerio. |
| break_end_time | time(0) | N | | | Debe ser mayor que `break_start_time`. |
| additional_information | nvarchar(max) | N | | | Datos adicionales en JSON. |
| status | char(1) | NN | | `'A'` | `A` activo, `I` inactivo. |
| created_at | datetime | NN | | `GETDATE()` | Fecha de creación. |
| updated_at | datetime | N | | | Lo llena el trigger `tr_staff_audit_dates`. |
| deleted_at | datetime | N | | | Eliminación lógica (`tr_staff_soft_delete`). NULL = vigente. |
| restored_at | datetime | N | | | Lo llena el trigger al restaurar. |

\* UQ compuesta: `(document_type, document_number)`.

### 2.2 `attendance`

| Columna | Tipo | Nulo | Clave | Default | Regla / descripción |
|---|---|---|---|---|---|
| attendance_id | bigint | NN | PK | `NEXT VALUE FOR attendance_seq` | Identificador de la asistencia. |
| staff_id | bigint | NN | FK → staff, UQ* | | Trabajador que marca. |
| attendance_config_id | int | NN | FK → attendance_config | | Configuración aplicada (debe estar vigente). |
| attendance_date | date | NN | UQ* | | No puede ser una fecha futura. |
| entry_time | time(0) | N | | | Hora real de entrada. NULL = inasistencia. |
| break_start_time | time(0) | N | | | Salida al refrigerio. |
| break_end_time | time(0) | N | | | Retorno del refrigerio (> inicio). |
| exit_time | time(0) | N | | | Hora real de salida (> entrada). |
| lateness_minutes | smallint | NN | | `0` | ≥ 0. **Lo calcula el trigger**: entrada real − (hora asignada + tolerancia). |
| check_in_location | geography | N | | | Punto (lat, long, SRID 4326) de la marcación. |
| distance_from_site_m | decimal(10,2) | N | | | ≥ 0. **Lo calcula el trigger** con `STDistance`. |
| observation | nvarchar(200) | N | | | Observaciones. |

\* UQ compuesta: `(staff_id, attendance_date)`, un registro por trabajador y día.

### 2.3 `attendance_config`

| Columna | Tipo | Nulo | Clave | Default | Regla / descripción |
|---|---|---|---|---|---|
| attendance_config_id | int | NN | PK | `NEXT VALUE FOR attendance_config_seq` | Identificador. |
| school_year | smallint | NN | UQ filtrado** | | Entre 2000 y 2100. |
| tolerance_minutes | tinyint | NN | | `0` | Entre 0 y 60. |
| default_entry_time | time(0) | NN | | | Entrada por defecto. |
| default_exit_time | time(0) | NN | | | Salida por defecto (> entrada). |
| default_break_start_time | time(0) | N | | | Inicio de refrigerio. |
| default_break_end_time | time(0) | N | | | Fin de refrigerio (> inicio). |
| active | bit | NN | | `1` | 1 = vigente. |

\*\* Índice único filtrado `ux_attendance_config_school_year_active`: solo una configuración vigente por año escolar.

### 2.4 `justification`

| Columna | Tipo | Nulo | Clave | Default | Regla / descripción |
|---|---|---|---|---|---|
| justification_id | bigint | NN | PK | `NEXT VALUE FOR justification_seq` | Identificador. |
| attendance_id | bigint | NN | FK → attendance | | Asistencia justificada. |
| reason_id | int | NN | FK → justification_reason | | Motivo (debe estar activo). |
| details | nvarchar(300) | N | | | Descripción. |
| supporting_file | nvarchar(255) | N | | | Obligatorio si el motivo tiene `requires_document = 1` (trigger). |
| justified_at | datetime | NN | | `GETDATE()` | Fecha de registro. |

### 2.5 `justification_reason`

| Columna | Tipo | Nulo | Clave | Default | Regla / descripción |
|---|---|---|---|---|---|
| reason_id | int | NN | PK | `NEXT VALUE FOR justification_reason_seq` | Identificador. |
| name | nvarchar(60) | NN | UQ | | Nombre del motivo. |
| requires_document | bit | NN | | `0` | 1 = exige sustento. |
| active | bit | NN | | `1` | 1 = disponible. |

### 2.6 `area`

| Columna | Tipo | Nulo | Clave | Default | Regla / descripción |
|---|---|---|---|---|---|
| area_id | int | NN | PK | `NEXT VALUE FOR area_seq` | Identificador. |
| name | nvarchar(60) | NN | UQ | | Nombre del área. |
| active | bit | NN | | `1` | 1 = activa. |

### 2.7 `position`

| Columna | Tipo | Nulo | Clave | Default | Regla / descripción |
|---|---|---|---|---|---|
| position_id | int | NN | PK | `NEXT VALUE FOR position_seq` | Identificador. |
| name | nvarchar(40) | NN | UQ | | Nombre del cargo. |
| description | nvarchar(150) | N | | | Funciones del cargo. |
| active | bit | NN | | `1` | 1 = activo. |

### 2.8 `site`

| Columna | Tipo | Nulo | Clave | Default | Regla / descripción |
|---|---|---|---|---|---|
| site_id | int | NN | PK | `NEXT VALUE FOR site_seq` | Identificador. |
| name | nvarchar(80) | NN | UQ | | Nombre de la sede. |
| address | nvarchar(150) | N | | | Dirección. |
| location | geography | N | | | Punto (lat, long, SRID 4326). Índice espacial `sx_site_location`. |
| allowed_radius_m | decimal(10,2) | NN | | | Radio máximo de marcación, > 0. |
| active | bit | NN | | `1` | 1 = activa. |

---

## 3. Relaciones

| Relación (FK) | Tabla hija.columna | Tabla padre.columna | Cardinalidad |
|---|---|---|---|
| fk_attendance_attendance_config | attendance.attendance_config_id | attendance_config.attendance_config_id | 1 : 0..* |
| fk_attendance_staff | attendance.staff_id | staff.staff_id | 1 : 0..* |
| fk_justification_reason | justification.reason_id | justification_reason.reason_id | 1 : 0..* |
| fk_staff_position | staff.position_id | position.position_id | 1 : 0..* |
| fk_staff_area | staff.area_id | area.area_id | 1 : 0..* |
| fk_staff_site | staff.site_id | site.site_id | 1 : 0..* |
| fk_justification_attendance | justification.attendance_id | attendance.attendance_id | 1 : 0..* |

---

## 4. Índices

| Índice | Tabla | Columnas | Tipo / propósito |
|---|---|---|---|
| ix_staff_position_id / ix_staff_area_id / ix_staff_site_id | staff | FK | Aceleran JOIN con catálogos. |
| ix_attendance_attendance_config_id | attendance | attendance_config_id | FK. |
| ix_justification_attendance_id / ix_justification_reason_id | justification | FK | Aceleran JOIN. |
| ix_attendance_date | attendance | attendance_date INCLUDE (staff_id, entry_time, exit_time, lateness_minutes) | Reporte diario (índice de cobertura). |
| ix_staff_full_name | staff | last_name, first_name | Búsqueda por nombre. |
| ix_staff_active | staff | status, area_id WHERE deleted_at IS NULL | Filtrado: solo personal vigente. |
| ix_attendance_late | attendance | staff_id, attendance_date WHERE lateness_minutes > 0 | Filtrado: solo tardanzas. |
| ux_attendance_config_school_year_active | attendance_config | school_year WHERE active = 1 | Único filtrado: una config. vigente por año. |
| sx_site_location | site | location | Espacial (GEOGRAPHY_AUTO_GRID). |

---

## 5. Triggers

| Trigger | Tabla / evento | Qué hace |
|---|---|---|
| tr_attendance_validate_and_calculate | attendance · AFTER INSERT, UPDATE | Rechaza personal inactivo/eliminado (50001), configuración no vigente (50002) y marcación PRESENCIAL fuera del radio de la sede (50003). Calcula `lateness_minutes` y `distance_from_site_m`. |
| tr_justification_validate | justification · AFTER INSERT, UPDATE | Rechaza motivo inactivo (50011) y exige `supporting_file` si el motivo lo requiere (50012). |
| tr_staff_soft_delete | staff · INSTEAD OF DELETE | Eliminación lógica: registra `deleted_at` y pone `status = 'I'`. |
| tr_staff_audit_dates | staff · AFTER UPDATE | Registra `updated_at`; si `deleted_at` vuelve a NULL registra `restored_at` y reactiva (`status = 'A'`). |
