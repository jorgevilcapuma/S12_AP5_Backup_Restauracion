/* =====================================================================
   Sistema de Control de Asistencia de Personal
   Script 08 - DICCIONARIO DE DATOS
   1. Registra la descripcion de cada tabla y columna como
      propiedad extendida (MS_Description) dentro de la base de datos.
   2. Genera el diccionario de datos consultando el catalogo del sistema.
   Requiere: 02_restricciones.sql (puede ejecutarse en cualquier momento
   despues; se puede volver a ejecutar sin errores).
   ===================================================================== */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE db_control_asistencia;
GO
SET NOCOUNT ON;

DECLARE @dic TABLE (tabla sysname, columna sysname NULL, descripcion nvarchar(500));

INSERT INTO @dic (tabla, columna, descripcion) VALUES
-- staff
('staff', NULL,                     N'Informacion personal y laboral de docentes y personal administrativo, con su horario asignado.'),
('staff', 'staff_id',               N'Identificador unico del trabajador. PK (staff_seq).'),
('staff', 'last_name',              N'Apellidos del trabajador.'),
('staff', 'first_name',             N'Nombres del trabajador.'),
('staff', 'document_type',          N'Tipo de documento de identidad: DNI, CE, PAS.'),
('staff', 'document_number',        N'Numero de documento. Unico junto con document_type. DNI = 8 digitos.'),
('staff', 'sex',                    N'Sexo: M = masculino, F = femenino.'),
('staff', 'birth_date',             N'Fecha de nacimiento (mayor de 18 anios).'),
('staff', 'mobile_phone',           N'Celular de 9 digitos que empieza con 9.'),
('staff', 'position_id',            N'Cargo del trabajador. FK a position.'),
('staff', 'area_id',                N'Area de trabajo. FK a area.'),
('staff', 'site_id',                N'Sede donde labora. FK a site.'),
('staff', 'work_modality',          N'Modalidad: PRESENCIAL, REMOTO, HIBRIDO. Default PRESENCIAL.'),
('staff', 'entry_time',             N'Hora de entrada asignada. Si es NULL se usa la de attendance_config.'),
('staff', 'exit_time',              N'Hora de salida asignada.'),
('staff', 'break_start_time',       N'Inicio de refrigerio asignado.'),
('staff', 'break_end_time',         N'Fin de refrigerio asignado.'),
('staff', 'additional_information', N'Informacion adicional en formato JSON.'),
('staff', 'status',                 N'Estado: A = activo, I = inactivo. Default A.'),
('staff', 'created_at',             N'Fecha y hora de creacion. Default GETDATE().'),
('staff', 'updated_at',             N'Fecha y hora de la ultima modificacion (trigger tr_staff_audit_dates).'),
('staff', 'deleted_at',             N'Fecha de eliminacion logica (trigger tr_staff_soft_delete). NULL = vigente.'),
('staff', 'restored_at',            N'Fecha en que se restauro el registro.'),
-- attendance
('attendance', NULL,                   N'Asistencia diaria: entrada, refrigerio, salida, tardanza y ubicacion de marcacion. Maximo un registro por trabajador y dia.'),
('attendance', 'attendance_id',        N'Identificador unico de la asistencia. PK (attendance_seq).'),
('attendance', 'staff_id',             N'Trabajador que marca. FK a staff.'),
('attendance', 'attendance_config_id', N'Configuracion de horario y tolerancia aplicada. FK a attendance_config.'),
('attendance', 'attendance_date',      N'Fecha de asistencia. Unica junto con staff_id. No puede ser futura.'),
('attendance', 'entry_time',           N'Hora real de entrada. NULL = inasistencia.'),
('attendance', 'break_start_time',     N'Hora real de salida al refrigerio.'),
('attendance', 'break_end_time',       N'Hora real de retorno del refrigerio.'),
('attendance', 'exit_time',            N'Hora real de salida.'),
('attendance', 'lateness_minutes',     N'Minutos de tardanza sobre hora asignada + tolerancia. Calculado por trigger. 0 = puntual.'),
('attendance', 'check_in_location',    N'Punto geografico (lat/long, SRID 4326) de la marcacion.'),
('attendance', 'distance_from_site_m', N'Distancia en metros entre la marcacion y la sede. Calculado por trigger.'),
('attendance', 'observation',          N'Observaciones del registro.'),
-- attendance_config
('attendance_config', NULL,                       N'Horarios por defecto, anio escolar y tolerancia de tardanza.'),
('attendance_config', 'attendance_config_id',     N'Identificador de la configuracion. PK (attendance_config_seq).'),
('attendance_config', 'school_year',              N'Anio escolar (2000-2100). Solo una configuracion vigente por anio.'),
('attendance_config', 'tolerance_minutes',        N'Minutos de tolerancia (0-60). Default 0.'),
('attendance_config', 'default_entry_time',       N'Hora de entrada por defecto.'),
('attendance_config', 'default_exit_time',        N'Hora de salida por defecto.'),
('attendance_config', 'default_break_start_time', N'Inicio de refrigerio por defecto.'),
('attendance_config', 'default_break_end_time',   N'Fin de refrigerio por defecto.'),
('attendance_config', 'active',                   N'1 = vigente, 0 = no vigente. Default 1.'),
-- justification
('justification', NULL,               N'Justificaciones de faltas, tardanzas y otras incidencias.'),
('justification', 'justification_id', N'Identificador de la justificacion. PK (justification_seq).'),
('justification', 'attendance_id',    N'Asistencia justificada. FK a attendance.'),
('justification', 'reason_id',        N'Motivo de la justificacion. FK a justification_reason.'),
('justification', 'details',          N'Descripcion de la justificacion.'),
('justification', 'supporting_file',  N'Ruta del archivo de sustento. Obligatorio si el motivo lo requiere (trigger).'),
('justification', 'justified_at',     N'Fecha y hora de registro. Default GETDATE().'),
-- justification_reason
('justification_reason', NULL,                N'Catalogo de motivos de justificacion.'),
('justification_reason', 'reason_id',         N'Identificador del motivo. PK (justification_reason_seq).'),
('justification_reason', 'name',              N'Nombre del motivo. Unico.'),
('justification_reason', 'requires_document', N'1 = exige documento de sustento. Default 0.'),
('justification_reason', 'active',            N'1 = disponible. Default 1.'),
-- area
('area', NULL,      N'Catalogo de areas de trabajo de la institucion.'),
('area', 'area_id', N'Identificador del area. PK (area_seq).'),
('area', 'name',    N'Nombre del area. Unico.'),
('area', 'active',  N'1 = activa. Default 1.'),
-- position
('position', NULL,          N'Catalogo de cargos asignables al personal.'),
('position', 'position_id', N'Identificador del cargo. PK (position_seq).'),
('position', 'name',        N'Nombre del cargo. Unico.'),
('position', 'description', N'Funciones del cargo.'),
('position', 'active',      N'1 = activo. Default 1.'),
-- site
('site', NULL,               N'Catalogo de sedes con ubicacion geografica y radio permitido de marcacion.'),
('site', 'site_id',          N'Identificador de la sede. PK (site_seq).'),
('site', 'name',             N'Nombre de la sede. Unico.'),
('site', 'address',          N'Direccion fisica.'),
('site', 'location',         N'Punto geografico (lat/long, SRID 4326) de la sede.'),
('site', 'allowed_radius_m', N'Distancia maxima en metros para aceptar una marcacion (> 0).'),
('site', 'active',           N'1 = activa. Default 1.');

/* Registrar (o actualizar) cada descripcion como MS_Description */
DECLARE @t sysname, @c sysname, @d nvarchar(500), @lt varchar(128);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT tabla, columna, descripcion FROM @dic;
OPEN cur;
FETCH NEXT FROM cur INTO @t, @c, @d;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @lt = CASE WHEN @c IS NULL THEN NULL ELSE N'COLUMN' END;
    IF EXISTS (SELECT 1 FROM sys.extended_properties
               WHERE major_id = OBJECT_ID('dbo.' + @t)
                 AND minor_id = ISNULL(COLUMNPROPERTY(OBJECT_ID('dbo.' + @t), @c, 'ColumnId'), 0)
                 AND name = 'MS_Description')
        EXEC sp_updateextendedproperty @name = N'MS_Description', @value = @d,
             @level0type = N'SCHEMA', @level0name = N'dbo',
             @level1type = N'TABLE',  @level1name = @t,
             @level2type = @lt, @level2name = @c;
    ELSE
        EXEC sp_addextendedproperty @name = N'MS_Description', @value = @d,
             @level0type = N'SCHEMA', @level0name = N'dbo',
             @level1type = N'TABLE',  @level1name = @t,
             @level2type = @lt, @level2name = @c;
    FETCH NEXT FROM cur INTO @t, @c, @d;
END
CLOSE cur;
DEALLOCATE cur;
GO

/* =====================================================================
   DICCIONARIO DE DATOS - TABLAS
   ===================================================================== */
SELECT t.name AS tabla,
       CAST(ep.value AS nvarchar(500)) AS descripcion,
       (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) AS columnas
FROM sys.tables t
LEFT JOIN sys.extended_properties ep
       ON ep.major_id = t.object_id AND ep.minor_id = 0 AND ep.name = 'MS_Description'
ORDER BY t.name;

/* =====================================================================
   DICCIONARIO DE DATOS - COLUMNAS
   ===================================================================== */
SELECT t.name AS tabla,
       c.column_id AS n,
       c.name AS columna,
       CASE
         WHEN ty.name IN ('varchar', 'char')   THEN ty.name + '(' + IIF(c.max_length = -1, 'max', CAST(c.max_length AS varchar)) + ')'
         WHEN ty.name IN ('nvarchar', 'nchar') THEN ty.name + '(' + IIF(c.max_length = -1, 'max', CAST(c.max_length / 2 AS varchar)) + ')'
         WHEN ty.name IN ('decimal', 'numeric') THEN ty.name + '(' + CAST(c.precision AS varchar) + ',' + CAST(c.scale AS varchar) + ')'
         WHEN ty.name = 'time' THEN 'time(' + CAST(c.scale AS varchar) + ')'
         ELSE ty.name
       END AS tipo,
       IIF(c.is_nullable = 1, 'NULL', 'NOT NULL') AS nulo,
       CONCAT_WS(', ',
           IIF(pk.column_id IS NOT NULL, 'PK', NULL),
           IIF(fk.parent_column_id IS NOT NULL, 'FK -> ' + OBJECT_NAME(fk.referenced_object_id), NULL),
           IIF(uq.column_id IS NOT NULL, 'UQ', NULL)) AS clave,
       OBJECT_DEFINITION(c.default_object_id) AS valor_defecto,
       CAST(ep.value AS nvarchar(500)) AS descripcion
FROM sys.tables t
JOIN sys.columns c  ON c.object_id = t.object_id
JOIN sys.types   ty ON ty.user_type_id = c.user_type_id
LEFT JOIN (SELECT ic.object_id, ic.column_id
           FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
           WHERE i.is_primary_key = 1) pk
       ON pk.object_id = c.object_id AND pk.column_id = c.column_id
LEFT JOIN sys.foreign_key_columns fk
       ON fk.parent_object_id = c.object_id AND fk.parent_column_id = c.column_id
LEFT JOIN (SELECT DISTINCT ic.object_id, ic.column_id
           FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
           WHERE i.is_unique_constraint = 1) uq
       ON uq.object_id = c.object_id AND uq.column_id = c.column_id
LEFT JOIN sys.extended_properties ep
       ON ep.major_id = c.object_id AND ep.minor_id = c.column_id AND ep.name = 'MS_Description'
ORDER BY t.name, c.column_id;

/* =====================================================================
   DICCIONARIO DE DATOS - RESTRICCIONES CHECK
   ===================================================================== */
SELECT OBJECT_NAME(parent_object_id) AS tabla, name AS restriccion, definition AS regla
FROM sys.check_constraints
ORDER BY tabla, restriccion;

/* =====================================================================
   DICCIONARIO DE DATOS - RELACIONES (FK)
   ===================================================================== */
SELECT fk.name AS relacion,
       OBJECT_NAME(fk.parent_object_id)     AS tabla_hija,
       COL_NAME(fkc.parent_object_id, fkc.parent_column_id)         AS columna_fk,
       OBJECT_NAME(fk.referenced_object_id) AS tabla_padre,
       COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS columna_pk
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
ORDER BY tabla_hija;

/* =====================================================================
   DICCIONARIO DE DATOS - SECUENCIAS
   ===================================================================== */
SELECT name AS secuencia, TYPE_NAME(user_type_id) AS tipo, start_value, increment, current_value
FROM sys.sequences
ORDER BY name;
GO
