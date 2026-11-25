# S16 · AP5 · Backup y Restauración

**Sistema de Control de Asistencia de Personal**: base de datos en Microsoft SQL Server para el control de asistencia del personal de una institución educativa (personal, cargos, áreas, sedes con validación geográfica, marcaciones diarias, tardanzas y justificaciones).

## Estructura del repositorio

```
S12_AP5_Backup_Restauracion/
├── case/
│   ├── design_database.md          Caso, requerimientos, entidades y relaciones
│   └── gestion_consultas.md        Consultas, índices, triggers y backup explicados
├── documentation/
│   └── Diccionario_de_datos.md     Diccionario de base de datos
├── image/
│   ├── Sistema_Control_Asistencia_FISICO.png
│   └── Sistema_Control_Asistencia_LOGICO.png
├── resources/
│   ├── Sistema_Control_Asistencia_FISICO.pdf
│   └── Sistema_Control_Asistencia_LOGICO.pdf
├── scripts/
│   ├── 01_estructura.sql
│   ├── 02_restricciones.sql
│   ├── 03_indices.sql
│   ├── 04_triggers.sql
│   ├── 05_datos.sql
│   ├── 06_consultas.sql
│   ├── 07_backup_restauracion.sql
│   └── 08_diccionario_datos.sql
└── README.md
```

## Entregables

| # | Entregable | Archivo |
|---|---|---|
| 1 | Diseño de base de datos (lógico y físico) | [case/design_database.md](case/design_database.md) · [image/](image/) · [resources/](resources/) (PDF) |
| 2 | Diccionario de base de datos | [documentation/Diccionario_de_datos.md](documentation/Diccionario_de_datos.md) · [scripts/08_diccionario_datos.sql](scripts/08_diccionario_datos.sql) |
| 3 | Script de estructura | [scripts/01_estructura.sql](scripts/01_estructura.sql) |
| 4 | Script de restricciones | [scripts/02_restricciones.sql](scripts/02_restricciones.sql) |
| 5 | Índices | [scripts/03_indices.sql](scripts/03_indices.sql) |
| 6 | Triggers | [scripts/04_triggers.sql](scripts/04_triggers.sql) |
| 7 | Script de datos (incluye pruebas de triggers) | [scripts/05_datos.sql](scripts/05_datos.sql) |
| 8 | Consultas (WHERE, GROUP BY, JOIN) | [scripts/06_consultas.sql](scripts/06_consultas.sql) |
| 9 | Generación de backup y restauración | [scripts/07_backup_restauracion.sql](scripts/07_backup_restauracion.sql) |

> Los scripts están numerados en **orden de ejecución**. Los índices y triggers van antes de los datos para que los triggers calculen la tardanza y la distancia de cada marcación durante la carga.

## Modelo

8 tablas, 7 relaciones y 8 secuencias (una por cada PK).

```
position ─┐
area ─────┼──< staff ──< attendance >── attendance_config
site ─────┘                 │
                            └──< justification >── justification_reason
```

## Cómo ejecutar

Requisito: SQL Server 2019 o 2022 (Developer o Express) y SSMS o Azure Data Studio.

1. Abrir y ejecutar (F5) cada script en orden, de `01` a `08`.
2. `01_estructura.sql` **elimina y vuelve a crear** la base `db_control_asistencia`, así que se puede ejecutar todo de nuevo desde cero.
3. Con `sqlcmd`:
   ```bash
   for f in scripts/0*.sql; do sqlcmd -S localhost -E -C -b -i "$f"; done
   ```

## Qué demuestra cada parte

**Restricciones**: 8 PK, 7 FK, 6 UNIQUE (incluidas compuestas: documento y trabajador+fecha), 19 CHECK (DNI de 8 dígitos, celular que empieza con 9, mayoría de edad, horarios coherentes, fecha no futura, tolerancia entre 0 y 60…) y DEFAULT con secuencias.

**Índices**: sobre FK, de cobertura (`INCLUDE`), filtrados (`WHERE`), único filtrado (una configuración vigente por año) y espacial (`geography`).

**Triggers**:
- `tr_attendance_validate_and_calculate`: calcula los minutos de tardanza y la distancia a la sede, y rechaza personal inactivo, configuraciones no vigentes y marcaciones presenciales fuera del radio.
- `tr_justification_validate`: exige el archivo de sustento si el motivo lo requiere.
- `tr_staff_soft_delete`: un `DELETE` hace una eliminación lógica.
- `tr_staff_audit_dates`: registra `updated_at` y `restored_at`.

**Backup y restauración** (`07`), en un flujo completo:
1. Backup **FULL** → cambios → backup **DIFERENCIAL** → cambios → backup de **LOG**.
2. Se simula un desastre (`DELETE FROM justification`).
3. `RESTORE VERIFYONLY`, `HEADERONLY` y `FILELISTONLY`.
4. **Restauración A**: copia en otra base (`db_control_asistencia_copia`) con `WITH MOVE`.
5. **Restauración B**: restauración **a un punto en el tiempo** (`FULL → DIFF → LOG WITH STOPAT`), que recupera las justificaciones borradas sin perder el cambio válido hecho antes del error.
6. Historial en `msdb` (`backupset`, `restorehistory`).

Los backups se guardan en la carpeta de backups por defecto de la instancia (`SERVERPROPERTY('InstanceDefaultBackupPath')`). Para usar otra carpeta, cambia `@ruta` al inicio del script 07.
