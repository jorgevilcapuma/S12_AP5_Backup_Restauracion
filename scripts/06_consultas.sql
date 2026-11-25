/* =====================================================================
   Sistema de Control de Asistencia de Personal
   Script 06 - CONSULTAS (WHERE, GROUP BY / HAVING, JOIN)
   Requiere: 05_datos.sql
   ===================================================================== */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE db_control_asistencia;
GO

/* =====================================================================
   A. CONSULTAS CON WHERE
   ===================================================================== */

-- A1. Personal activo (no eliminado) que trabaja en modalidad PRESENCIAL
SELECT staff_id, last_name, first_name, document_type, document_number, work_modality
FROM dbo.staff
WHERE status = 'A'
  AND deleted_at IS NULL
  AND work_modality = 'PRESENCIAL'
ORDER BY last_name, first_name;

-- A2. Tardanzas de mas de 5 minutos en un rango de fechas
SELECT attendance_id, staff_id, attendance_date, entry_time, lateness_minutes
FROM dbo.attendance
WHERE lateness_minutes > 5
  AND attendance_date BETWEEN '2026-11-16' AND '2026-11-20'
ORDER BY lateness_minutes DESC;

-- A3. Inasistencias (registro sin hora de entrada)
SELECT attendance_id, staff_id, attendance_date, observation
FROM dbo.attendance
WHERE entry_time IS NULL
ORDER BY attendance_date;

-- A4. Personal cuyo apellido empieza con 'C' o 'M' y tiene celular registrado
SELECT last_name, first_name, mobile_phone
FROM dbo.staff
WHERE (last_name LIKE 'C%' OR last_name LIKE 'M%')
  AND mobile_phone IS NOT NULL;

-- A5. Motivos de justificacion que exigen documento de sustento
SELECT reason_id, name
FROM dbo.justification_reason
WHERE requires_document = 1 AND active = 1;

-- A6. Marcaciones que se quedaron cerca del limite del radio (> 30 m)
SELECT attendance_id, staff_id, attendance_date, distance_from_site_m
FROM dbo.attendance
WHERE distance_from_site_m > 30
ORDER BY distance_from_site_m DESC;


/* =====================================================================
   B. CONSULTAS CON GROUP BY / HAVING
   ===================================================================== */

-- B1. Cantidad de personal por modalidad y estado
SELECT work_modality, status, COUNT(*) AS cantidad
FROM dbo.staff
GROUP BY work_modality, status
ORDER BY work_modality, status;

-- B2. Total de tardanzas y minutos acumulados por trabajador (solo quien tiene mas de 2)
SELECT staff_id,
       COUNT(*)              AS veces_tarde,
       SUM(lateness_minutes) AS minutos_acumulados,
       MAX(lateness_minutes) AS mayor_tardanza
FROM dbo.attendance
WHERE lateness_minutes > 0
GROUP BY staff_id
HAVING COUNT(*) > 2
ORDER BY minutos_acumulados DESC;

-- B3. Resumen diario: asistentes, faltas, tardanzas y promedio de tardanza
SELECT attendance_date,
       SUM(CASE WHEN entry_time IS NOT NULL THEN 1 ELSE 0 END)     AS asistieron,
       SUM(CASE WHEN entry_time IS NULL     THEN 1 ELSE 0 END)     AS faltaron,
       SUM(CASE WHEN lateness_minutes > 0   THEN 1 ELSE 0 END)     AS llegaron_tarde,
       CAST(AVG(CAST(lateness_minutes AS decimal(6,2))) AS decimal(6,2)) AS promedio_min_tardanza
FROM dbo.attendance
GROUP BY attendance_date
ORDER BY attendance_date;

-- B4. Justificaciones registradas por motivo
SELECT reason_id, COUNT(*) AS cantidad
FROM dbo.justification
GROUP BY reason_id
ORDER BY cantidad DESC;


/* =====================================================================
   C. CONSULTAS CON JOIN
   ===================================================================== */

-- C1. INNER JOIN (4 tablas): ficha del personal con cargo, area y sede
SELECT s.staff_id,
       CONCAT(s.last_name, ', ', s.first_name) AS trabajador,
       p.name  AS cargo,
       a.name  AS area,
       t.name  AS sede,
       s.work_modality,
       COALESCE(s.entry_time, c.default_entry_time) AS hora_entrada_aplicada
FROM dbo.staff s
INNER JOIN dbo.position p ON p.position_id = s.position_id
INNER JOIN dbo.area     a ON a.area_id     = s.area_id
INNER JOIN dbo.site     t ON t.site_id     = s.site_id
CROSS JOIN dbo.attendance_config c
WHERE c.active = 1
ORDER BY a.name, trabajador;

-- C2. INNER JOIN: reporte de asistencia de un dia con datos del trabajador y su sede
SELECT a.attendance_date,
       CONCAT(s.last_name, ', ', s.first_name) AS trabajador,
       t.name AS sede,
       a.entry_time, a.break_start_time, a.break_end_time, a.exit_time,
       a.lateness_minutes,
       a.distance_from_site_m,
       CASE WHEN a.entry_time IS NULL THEN 'FALTA'
            WHEN a.lateness_minutes > 0 THEN 'TARDANZA'
            ELSE 'PUNTUAL' END AS estado_asistencia
FROM dbo.attendance a
INNER JOIN dbo.staff s ON s.staff_id = a.staff_id
INNER JOIN dbo.site  t ON t.site_id  = s.site_id
WHERE a.attendance_date = '2026-11-20'
ORDER BY a.lateness_minutes DESC, trabajador;

-- C3. INNER JOIN (4 tablas): justificaciones con trabajador, fecha y motivo
SELECT j.justification_id,
       CONCAT(s.last_name, ', ', s.first_name) AS trabajador,
       a.attendance_date,
       CASE WHEN a.entry_time IS NULL THEN 'FALTA' ELSE CONCAT('TARDANZA ', a.lateness_minutes, ' min') END AS incidencia,
       r.name AS motivo,
       j.details,
       j.supporting_file,
       j.justified_at
FROM dbo.justification j
INNER JOIN dbo.attendance           a ON a.attendance_id = j.attendance_id
INNER JOIN dbo.staff                s ON s.staff_id      = a.staff_id
INNER JOIN dbo.justification_reason r ON r.reason_id     = j.reason_id
ORDER BY a.attendance_date;

-- C4. LEFT JOIN: incidencias (faltas o tardanzas) SIN justificar
SELECT CONCAT(s.last_name, ', ', s.first_name) AS trabajador,
       a.attendance_date,
       CASE WHEN a.entry_time IS NULL THEN 'FALTA' ELSE 'TARDANZA' END AS incidencia,
       a.lateness_minutes
FROM dbo.attendance a
INNER JOIN dbo.staff s       ON s.staff_id = a.staff_id
LEFT  JOIN dbo.justification j ON j.attendance_id = a.attendance_id
WHERE (a.entry_time IS NULL OR a.lateness_minutes > 0)
  AND j.justification_id IS NULL
ORDER BY a.attendance_date, trabajador;

-- C5. LEFT JOIN: personal que NO tiene registro de asistencia en una fecha
SELECT s.staff_id, CONCAT(s.last_name, ', ', s.first_name) AS trabajador, s.status
FROM dbo.staff s
LEFT JOIN dbo.attendance a
       ON a.staff_id = s.staff_id AND a.attendance_date = '2026-11-25'
WHERE a.attendance_id IS NULL
ORDER BY trabajador;

-- C6. RIGHT JOIN: todos los cargos y cuantas personas los ocupan (incluye cargos vacios)
SELECT p.name AS cargo, COUNT(s.staff_id) AS cantidad_personal
FROM dbo.staff s
RIGHT JOIN dbo.position p ON p.position_id = s.position_id
GROUP BY p.name
ORDER BY cantidad_personal DESC, cargo;


/* =====================================================================
   D. JOIN + GROUP BY (reportes de gestion)
   ===================================================================== */

-- D1. Ranking de tardanzas por area
SELECT ar.name                    AS area,
       COUNT(DISTINCT s.staff_id) AS personal,
       SUM(CASE WHEN a.lateness_minutes > 0 THEN 1 ELSE 0 END) AS tardanzas,
       SUM(a.lateness_minutes)    AS minutos_totales
FROM dbo.area ar
INNER JOIN dbo.staff      s ON s.area_id  = ar.area_id
INNER JOIN dbo.attendance a ON a.staff_id = s.staff_id
GROUP BY ar.name
ORDER BY minutos_totales DESC;

-- D2. Reporte mensual por trabajador (noviembre 2026)
SELECT CONCAT(s.last_name, ', ', s.first_name)                     AS trabajador,
       p.name                                                      AS cargo,
       COUNT(a.attendance_id)                                      AS dias_registrados,
       SUM(CASE WHEN a.entry_time IS NULL THEN 1 ELSE 0 END)       AS faltas,
       SUM(CASE WHEN a.lateness_minutes > 0 THEN 1 ELSE 0 END)     AS tardanzas,
       SUM(a.lateness_minutes)                                     AS minutos_tardanza,
       COUNT(j.justification_id)                                   AS justificadas
FROM dbo.staff s
INNER JOIN dbo.position   p ON p.position_id = s.position_id
INNER JOIN dbo.attendance a ON a.staff_id    = s.staff_id
LEFT  JOIN dbo.justification j ON j.attendance_id = a.attendance_id
WHERE a.attendance_date >= '2026-11-01' AND a.attendance_date < '2026-12-01'
GROUP BY s.last_name, s.first_name, p.name
ORDER BY minutos_tardanza DESC;

-- D3. Asistencia por sede: promedio de distancia de marcacion vs radio permitido
SELECT t.name AS sede,
       t.allowed_radius_m,
       COUNT(a.attendance_id)                                AS marcaciones_con_gps,
       CAST(AVG(a.distance_from_site_m) AS decimal(10,2))    AS distancia_promedio_m,
       MAX(a.distance_from_site_m)                           AS distancia_maxima_m
FROM dbo.site t
INNER JOIN dbo.staff      s ON s.site_id  = t.site_id
INNER JOIN dbo.attendance a ON a.staff_id = s.staff_id
WHERE a.check_in_location IS NOT NULL
GROUP BY t.name, t.allowed_radius_m;
GO
