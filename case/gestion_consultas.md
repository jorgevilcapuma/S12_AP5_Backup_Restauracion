# Gestión de consultas, índices, triggers y backup

Guía de lo que resuelve cada script de [`scripts/`](../scripts/).

## Consultas: [06_consultas.sql](../scripts/06_consultas.sql)

### A. Filtros con WHERE

| # | Pregunta de negocio |
|---|---|
| A1 | ¿Qué personal está activo y trabaja de forma presencial? |
| A2 | ¿Quién llegó más de 5 minutos tarde en la semana del 16 al 20 de noviembre? |
| A3 | ¿Qué registros son inasistencias (sin hora de entrada)? |
| A4 | ¿Qué trabajadores tienen un apellido que empieza con C o M y celular registrado? |
| A5 | ¿Qué motivos de justificación exigen documento de sustento? |
| A6 | ¿Qué marcaciones se hicieron a más de 30 m de la sede? |

### B. Agrupaciones con GROUP BY / HAVING

| # | Pregunta de negocio |
|---|---|
| B1 | ¿Cuánto personal hay por modalidad y estado? |
| B2 | ¿Quiénes llegaron tarde más de 2 veces y cuántos minutos acumulan? |
| B3 | Resumen diario: asistentes, faltas, tardanzas y promedio de tardanza. |
| B4 | ¿Cuántas justificaciones hay por motivo? |

### C. Combinaciones con JOIN

| # | Tipo | Pregunta de negocio |
|---|---|---|
| C1 | INNER (4 tablas) | Ficha del trabajador con cargo, área, sede y hora de entrada aplicada. |
| C2 | INNER | Reporte de asistencia de un día, con estado PUNTUAL / TARDANZA / FALTA. |
| C3 | INNER (4 tablas) | Justificaciones con trabajador, incidencia y motivo. |
| C4 | LEFT | Faltas o tardanzas **sin justificar**. |
| C5 | LEFT | Personal que **no** tiene registro de asistencia en una fecha. |
| C6 | RIGHT | Todos los cargos y cuántas personas los ocupan, incluidos los cargos vacíos. |

### D. Reportes de gestión (JOIN + GROUP BY)

| # | Reporte |
|---|---|
| D1 | Ranking de tardanzas por área. |
| D2 | Reporte mensual por trabajador: días, faltas, tardanzas, minutos y justificadas. |
| D3 | Distancia promedio y máxima de las marcaciones por sede frente al radio permitido. |

## Índices: [03_indices.sql](../scripts/03_indices.sql)

| Tipo | Ejemplo | Para qué |
|---|---|---|
| Sobre FK | `ix_staff_area_id` | Acelerar JOIN con los catálogos. |
| De cobertura | `ix_attendance_date ... INCLUDE (...)` | El reporte diario no necesita leer la tabla. |
| Filtrado | `ix_attendance_late WHERE lateness_minutes > 0` | Índice pequeño, solo con las tardanzas. |
| Único filtrado | `ux_attendance_config_school_year_active` | Solo una configuración vigente por año. |
| Espacial | `sx_site_location` | Consultas de distancia sobre sedes. |

## Triggers: [04_triggers.sql](../scripts/04_triggers.sql)

| Trigger | Se dispara | Resultado |
|---|---|---|
| `tr_attendance_validate_and_calculate` | INSERT/UPDATE en `attendance` | Calcula la tardanza y la distancia; rechaza personal inactivo, configuraciones no vigentes y marcaciones fuera del radio. |
| `tr_justification_validate` | INSERT/UPDATE en `justification` | Exige sustento si el motivo lo requiere; rechaza motivos inactivos. |
| `tr_staff_soft_delete` | DELETE en `staff` | No borra la fila: registra `deleted_at` y pone `status = 'I'`. |
| `tr_staff_audit_dates` | UPDATE en `staff` | Registra `updated_at` y `restored_at`. |

Las pruebas de cada trigger están al final de [05_datos.sql](../scripts/05_datos.sql).

## Backup y restauración: [07_backup_restauracion.sql](../scripts/07_backup_restauracion.sql)

```
FULL ──► cambios ──► DIFERENCIAL ──► cambio válido ──► [punto T] ──► DELETE por error ──► LOG
                                                                                         │
Restauración a un punto en el tiempo:  FULL (NORECOVERY) ► DIFF (NORECOVERY) ► LOG STOPAT = T
```

| Paso | Comando | Resultado obtenido |
|---|---|---|
| Backup completo | `BACKUP DATABASE ... WITH CHECKSUM` | Archivo `_FULL.bak` |
| Backup diferencial | `BACKUP DATABASE ... WITH DIFFERENTIAL` | Archivo `_DIFF.bak` |
| Backup de log | `BACKUP LOG` | Archivo `_LOG.trn` |
| Verificación | `RESTORE VERIFYONLY / HEADERONLY / FILELISTONLY` | "The backup set on file 1 is valid." |
| Restauración en otra BD | `RESTORE DATABASE ..._copia WITH MOVE` | Copia con 12 trabajadores, 78 asistencias y 7 justificaciones |
| Restauración a un punto en el tiempo | `RESTORE LOG ... WITH STOPAT` | Se recuperan las 7 justificaciones borradas y se conserva el motivo creado antes del error |

> Requisito: la base debe estar en modelo de recuperación **FULL** (se configura en `01_estructura.sql`).
