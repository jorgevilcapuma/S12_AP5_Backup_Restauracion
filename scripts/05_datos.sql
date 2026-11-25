/* =====================================================================
   Sistema de Control de Asistencia de Personal
   Script 05 - DATOS (carga inicial + pruebas de triggers)
   Requiere: 04_triggers.sql
   Todos los nombres y documentos son ficticios.
   ===================================================================== */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE db_control_asistencia;
GO
SET NOCOUNT ON;
GO

/* =====================================================================
   1. CATALOGOS
   ===================================================================== */
INSERT INTO dbo.position (name, description) VALUES
 (N'Director',              N'Dirige y representa a la institucion educativa.'),
 (N'Subdirector',           N'Apoya a la direccion en la gestion pedagogica.'),
 (N'Docente',               N'Planifica y desarrolla las sesiones de aprendizaje.'),
 (N'Auxiliar de educacion', N'Apoya la disciplina y el cuidado de los estudiantes.'),
 (N'Secretaria',            N'Gestiona la documentacion y atencion al publico.'),
 (N'Psicologo',             N'Brinda orientacion y soporte socioemocional.'),
 (N'Personal de limpieza',  N'Mantiene la limpieza de los ambientes.');

INSERT INTO dbo.area (name) VALUES
 (N'Direccion'), (N'Inicial'), (N'Primaria'), (N'Secundaria'),
 (N'Administracion'), (N'Mantenimiento');

-- geography::Point(latitud, longitud, SRID 4326 = WGS84)
INSERT INTO dbo.site (name, address, location, allowed_radius_m) VALUES
 (N'Sede Central', N'Av. Principal 120, San Vicente de Canete', geography::Point(-13.075600, -76.387000, 4326), 100.00),
 (N'Sede Anexo',   N'Jr. Los Olivos 345, San Vicente de Canete', geography::Point(-13.082000, -76.390500, 4326),  80.00);

INSERT INTO dbo.justification_reason (name, requires_document) VALUES
 (N'Descanso medico',        1),
 (N'Comision de servicio',   1),
 (N'Capacitacion',           1),
 (N'Duelo familiar',         1),
 (N'Permiso personal',       0),
 (N'Problemas de transporte',0);

-- Configuracion 2025 (historica, no vigente) y 2026 (vigente)
INSERT INTO dbo.attendance_config
 (school_year, tolerance_minutes, default_entry_time, default_exit_time, default_break_start_time, default_break_end_time, active)
VALUES
 (2025, 5,  '07:45', '14:00', '10:30', '10:50', 0),
 (2026, 10, '07:30', '14:30', '10:30', '10:50', 1);
GO

/* =====================================================================
   2. PERSONAL
   entry_time NULL => se aplica la hora por defecto de la configuracion
   ===================================================================== */
INSERT INTO dbo.staff
 (last_name, first_name, document_type, document_number, sex, birth_date, mobile_phone,
  position_id, area_id, site_id, work_modality, entry_time, exit_time, break_start_time, break_end_time,
  additional_information, status)
SELECT v.last_name, v.first_name, v.doc_type, v.doc_number, v.sex, v.birth_date, v.phone,
       p.position_id, a.area_id, t.site_id, v.modality, v.entry_time, v.exit_time, v.break_start, v.break_end,
       v.extra, v.status
FROM (VALUES
 (N'Ramirez Soto',     N'Carlos Alberto', 'DNI', '41234567', 'M', '1975-03-14', '987654321', N'Director',              N'Direccion',      N'Sede Central', 'PRESENCIAL', '07:00', '15:00', '12:00', '12:30', N'{"titulo":"Magister en Gestion Educativa"}', 'A'),
 (N'Quispe Huaman',    N'Rosa Elena',     'DNI', '42345678', 'F', '1980-07-22', '987111222', N'Subdirector',           N'Direccion',      N'Sede Central', 'PRESENCIAL', NULL,    NULL,    NULL,    NULL,    NULL, 'A'),
 (N'Torres Vega',      N'Luis Miguel',    'DNI', '43456789', 'M', '1985-11-02', '986333444', N'Docente',               N'Secundaria',     N'Sede Central', 'PRESENCIAL', NULL,    NULL,    NULL,    NULL,    N'{"especialidad":"Matematica"}', 'A'),
 (N'Flores Paredes',   N'Ana Lucia',      'DNI', '44567890', 'F', '1988-01-30', '985555666', N'Docente',               N'Primaria',       N'Sede Central', 'PRESENCIAL', NULL,    NULL,    NULL,    NULL,    N'{"grado":"3ro"}', 'A'),
 (N'Mendoza Rojas',    N'Jorge Luis',     'DNI', '45678901', 'M', '1990-05-18', '984777888', N'Docente',               N'Secundaria',     N'Sede Anexo',   'PRESENCIAL', NULL,    NULL,    NULL,    NULL,    N'{"especialidad":"Comunicacion"}', 'A'),
 (N'Castillo Rios',    N'Maria Fernanda', 'DNI', '46789012', 'F', '1992-09-09', '983999000', N'Docente',               N'Inicial',        N'Sede Anexo',   'PRESENCIAL', '08:00', '13:00', NULL,    NULL,    NULL, 'A'),
 (N'Chavez Lopez',     N'Pedro Pablo',    'DNI', '47890123', 'M', '1987-12-12', '982121212', N'Auxiliar de educacion', N'Secundaria',     N'Sede Central', 'PRESENCIAL', NULL,    NULL,    NULL,    NULL,    NULL, 'A'),
 (N'Gutierrez Salas',  N'Carmen Rosa',    'DNI', '48901234', 'F', '1983-04-25', '981343434', N'Secretaria',            N'Administracion', N'Sede Central', 'PRESENCIAL', '08:00', '16:00', '13:00', '14:00', NULL, 'A'),
 (N'Herrera Campos',   N'Diego Andres',   'CE',  '001234567','M', '1991-06-06', '980565656', N'Psicologo',             N'Administracion', N'Sede Anexo',   'PRESENCIAL', NULL,    NULL,    NULL,    NULL,    N'{"colegiatura":"CPsP-12345"}', 'A'),
 (N'Vargas Medina',    N'Sofia Isabel',   'DNI', '49012345', 'F', '1994-02-17', '979787878', N'Docente',               N'Primaria',       N'Sede Central', 'HIBRIDO',    NULL,    NULL,    NULL,    NULL,    NULL, 'A'),
 (N'Diaz Morales',     N'Ricardo Jose',   'DNI', '40123456', 'M', '1979-10-10', NULL,        N'Docente',               N'Secundaria',     N'Sede Central', 'REMOTO',     NULL,    NULL,    NULL,    NULL,    N'{"curso":"Ingles virtual"}', 'A'),
 (N'Sanchez Poma',     N'Julio Cesar',    'DNI', '41112223', 'M', '1970-08-08', '978909090', N'Personal de limpieza',  N'Mantenimiento',  N'Sede Central', 'PRESENCIAL', '06:30', '14:30', NULL,    NULL,    NULL, 'I')
) AS v(last_name, first_name, doc_type, doc_number, sex, birth_date, phone, position_name, area_name, site_name,
       modality, entry_time, exit_time, break_start, break_end, extra, status)
JOIN dbo.position p ON p.name = v.position_name
JOIN dbo.area     a ON a.name = v.area_name
JOIN dbo.site     t ON t.name = v.site_name;
GO

/* =====================================================================
   3. ASISTENCIA (2 semanas habiles de noviembre 2026)
   - Las horas varian de forma deterministica para generar puntuales y
     tardanzas. lateness_minutes y distance_from_site_m los calcula el
     trigger tr_attendance_validate_and_calculate.
   - El personal REMOTO no registra ubicacion.
   - Algunas combinaciones quedan como INASISTENCIA (sin horas).
   ===================================================================== */
DECLARE @config_id int = (SELECT attendance_config_id FROM dbo.attendance_config WHERE school_year = 2026 AND active = 1);

;WITH dias AS (
    SELECT n, CAST(d AS date) AS dt
    FROM (VALUES (1,'2026-11-16'),(2,'2026-11-17'),(3,'2026-11-18'),(4,'2026-11-19'),
                 (5,'2026-11-20'),(6,'2026-11-23'),(7,'2026-11-24')) AS x(n, d)
)
INSERT INTO dbo.attendance
 (staff_id, attendance_config_id, attendance_date, entry_time, break_start_time, break_end_time, exit_time,
  check_in_location, observation)
SELECT s.staff_id,
       c.attendance_config_id,
       d.dt,
       -- Asistio: hora asignada -8 a +22 minutos
       CASE WHEN (s.staff_id + d.n) % 9 = 0 THEN NULL
            ELSE DATEADD(MINUTE, ((s.staff_id * 7 + d.n * 13) % 31) - 8, COALESCE(s.entry_time, c.default_entry_time)) END,
       CASE WHEN (s.staff_id + d.n) % 9 = 0 THEN NULL
            ELSE COALESCE(s.break_start_time, c.default_break_start_time) END,
       CASE WHEN (s.staff_id + d.n) % 9 = 0 THEN NULL
            ELSE DATEADD(MINUTE, (s.staff_id + d.n) % 4, COALESCE(s.break_end_time, c.default_break_end_time)) END,
       CASE WHEN (s.staff_id + d.n) % 9 = 0 THEN NULL
            ELSE DATEADD(MINUTE, (s.staff_id * 3 + d.n) % 15, COALESCE(s.exit_time, c.default_exit_time)) END,
       -- Punto de marcacion: a pocos metros de la sede (0.0001 grados ~ 11 m)
       CASE WHEN (s.staff_id + d.n) % 9 = 0 OR s.work_modality = 'REMOTO' THEN NULL
            ELSE geography::Point(t.location.Lat + ((s.staff_id + d.n) % 5) * 0.0001, t.location.Long, 4326) END,
       CASE WHEN (s.staff_id + d.n) % 9 = 0 THEN N'Inasistencia' END
FROM dbo.staff s
JOIN dbo.site  t ON t.site_id = s.site_id
CROSS JOIN dias d
CROSS JOIN dbo.attendance_config c
WHERE c.attendance_config_id = @config_id
  AND s.status = 'A';
GO

/* =====================================================================
   4. JUSTIFICACIONES
   Se ubican por documento del trabajador + fecha de asistencia.
   ===================================================================== */
INSERT INTO dbo.justification (attendance_id, reason_id, details, supporting_file)
SELECT a.attendance_id, r.reason_id, v.details, v.supporting_file
FROM (VALUES
 ('42345678', '2026-11-24', N'Descanso medico',        N'Inasistencia por cuadro gripal. Certificado medico adjunto.', N'sustentos/2026/dm_42345678_20261124.pdf'),
 ('43456789', '2026-11-20', N'Capacitacion',            N'Asistencia a taller UGEL de evaluacion formativa.',         N'sustentos/2026/cap_43456789_20261120.pdf'),
 ('44567890', '2026-11-20', N'Duelo familiar',         N'Fallecimiento de familiar directo.',                         N'sustentos/2026/duelo_44567890.pdf'),
 ('45678901', '2026-11-19', N'Comision de servicio',   N'Comision a la UGEL Canete para tramite documentario.',      N'sustentos/2026/com_45678901.pdf'),
 ('46789012', '2026-11-23', N'Permiso personal',        N'Tramite personal autorizado por direccion.',                NULL),
 ('47890123', '2026-11-18', N'Problemas de transporte', N'Paro de transportistas en la Panamericana Sur.',            NULL),
 ('43456789', '2026-11-18', N'Problemas de transporte', N'Congestion vehicular por obras.',                           NULL)
) AS v(doc_number, att_date, reason_name, details, supporting_file)
JOIN dbo.staff s                ON s.document_number = v.doc_number
JOIN dbo.attendance a           ON a.staff_id = s.staff_id AND a.attendance_date = CAST(v.att_date AS date)
JOIN dbo.justification_reason r ON r.name = v.reason_name;
GO

/* Resumen de la carga */
SELECT 'position' AS tabla, COUNT(*) AS filas FROM dbo.position
UNION ALL SELECT 'area',                 COUNT(*) FROM dbo.area
UNION ALL SELECT 'site',                 COUNT(*) FROM dbo.site
UNION ALL SELECT 'justification_reason', COUNT(*) FROM dbo.justification_reason
UNION ALL SELECT 'attendance_config',    COUNT(*) FROM dbo.attendance_config
UNION ALL SELECT 'staff',                COUNT(*) FROM dbo.staff
UNION ALL SELECT 'attendance',           COUNT(*) FROM dbo.attendance
UNION ALL SELECT 'justification',        COUNT(*) FROM dbo.justification;
GO


/* =====================================================================
   5. PRUEBAS DE TRIGGERS
   Cada prueba que debe FALLAR esta dentro de TRY/CATCH y muestra el
   mensaje del trigger.
   ===================================================================== */

-- Prueba 1: asistencia de personal INACTIVO -> error 50001
BEGIN TRY
    INSERT INTO dbo.attendance (staff_id, attendance_config_id, attendance_date, entry_time)
    SELECT s.staff_id, c.attendance_config_id, '2026-11-25', '06:30'
    FROM dbo.staff s CROSS JOIN dbo.attendance_config c
    WHERE s.document_number = '41112223' AND c.school_year = 2026;
    PRINT 'Prueba 1: NO se esperaba exito';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    PRINT CONCAT('Prueba 1 OK -> ', ERROR_NUMBER(), ': ', ERROR_MESSAGE());
END CATCH;
GO

-- Prueba 2: marcacion PRESENCIAL fuera del radio (~1.1 km) -> error 50003
BEGIN TRY
    INSERT INTO dbo.attendance (staff_id, attendance_config_id, attendance_date, entry_time, check_in_location)
    SELECT s.staff_id, c.attendance_config_id, '2026-11-25', '07:25',
           geography::Point(-13.065600, -76.387000, 4326)
    FROM dbo.staff s CROSS JOIN dbo.attendance_config c
    WHERE s.document_number = '43456789' AND c.school_year = 2026;
    PRINT 'Prueba 2: NO se esperaba exito';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    PRINT CONCAT('Prueba 2 OK -> ', ERROR_NUMBER(), ': ', ERROR_MESSAGE());
END CATCH;
GO

-- Prueba 3: marcacion valida con tardanza -> el trigger calcula tardanza y distancia
--   Hora por defecto 07:30 + 10 min de tolerancia = 07:40; llega 07:52 -> 12 minutos
INSERT INTO dbo.attendance (staff_id, attendance_config_id, attendance_date, entry_time, check_in_location, observation)
SELECT s.staff_id, c.attendance_config_id, '2026-11-25', '07:52',
       geography::Point(-13.075900, -76.387000, 4326), N'Prueba de calculo de tardanza'
FROM dbo.staff s CROSS JOIN dbo.attendance_config c
WHERE s.document_number = '43456789' AND c.school_year = 2026;

SELECT s.last_name, a.attendance_date, a.entry_time, a.lateness_minutes, a.distance_from_site_m
FROM dbo.attendance a JOIN dbo.staff s ON s.staff_id = a.staff_id
WHERE s.document_number = '43456789' AND a.attendance_date = '2026-11-25';
GO

-- Prueba 4: justificacion que requiere documento SIN archivo -> error 50012
BEGIN TRY
    INSERT INTO dbo.justification (attendance_id, reason_id, details, supporting_file)
    SELECT TOP (1) a.attendance_id, r.reason_id, N'Sin certificado', NULL
    FROM dbo.attendance a CROSS JOIN dbo.justification_reason r
    WHERE r.name = N'Descanso medico' AND a.lateness_minutes > 0;
    PRINT 'Prueba 4: NO se esperaba exito';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    PRINT CONCAT('Prueba 4 OK -> ', ERROR_NUMBER(), ': ', ERROR_MESSAGE());
END CATCH;
GO

-- Prueba 5: DELETE = eliminacion logica; luego restauracion
DELETE FROM dbo.staff WHERE document_number = '49012345';

SELECT staff_id, last_name, status, deleted_at, restored_at, updated_at
FROM dbo.staff WHERE document_number = '49012345';   -- la fila sigue existiendo, status = 'I'

UPDATE dbo.staff SET deleted_at = NULL WHERE document_number = '49012345';

SELECT staff_id, last_name, status, deleted_at, restored_at, updated_at
FROM dbo.staff WHERE document_number = '49012345';   -- status = 'A' y restored_at registrado
GO
