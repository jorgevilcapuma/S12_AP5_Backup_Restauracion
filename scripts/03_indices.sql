/* =====================================================================
   Sistema de Control de Asistencia de Personal
   Script 03 - INDICES
   Las PK ya generan indices CLUSTERED y las UNIQUE indices NONCLUSTERED.
   Aqui se agregan indices para las FK y las busquedas mas frecuentes.
   Requiere: 02_restricciones.sql
   ===================================================================== */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE db_control_asistencia;
GO

/* ---------------------------------------------------------------------
   1. Indices sobre claves foraneas (aceleran los JOIN y las validaciones
      de integridad al borrar/actualizar en la tabla padre)
   --------------------------------------------------------------------- */
CREATE NONCLUSTERED INDEX ix_staff_position_id ON dbo.staff (position_id);
CREATE NONCLUSTERED INDEX ix_staff_area_id     ON dbo.staff (area_id);
CREATE NONCLUSTERED INDEX ix_staff_site_id     ON dbo.staff (site_id);

CREATE NONCLUSTERED INDEX ix_attendance_attendance_config_id ON dbo.attendance (attendance_config_id);
-- attendance.staff_id ya queda cubierto por uq_attendance_staff_date (staff_id, attendance_date)

CREATE NONCLUSTERED INDEX ix_justification_attendance_id ON dbo.justification (attendance_id);
CREATE NONCLUSTERED INDEX ix_justification_reason_id     ON dbo.justification (reason_id);
GO

/* ---------------------------------------------------------------------
   2. Indices para consultas frecuentes
   --------------------------------------------------------------------- */
-- Reporte diario: "quien marco hoy y con cuanta tardanza"
CREATE NONCLUSTERED INDEX ix_attendance_date
    ON dbo.attendance (attendance_date)
    INCLUDE (staff_id, entry_time, exit_time, lateness_minutes);

-- Busqueda de personal por apellidos y nombres
CREATE NONCLUSTERED INDEX ix_staff_full_name
    ON dbo.staff (last_name, first_name);

-- Solo personal vigente (no eliminado logicamente): indice FILTRADO
CREATE NONCLUSTERED INDEX ix_staff_active
    ON dbo.staff (status, area_id)
    INCLUDE (last_name, first_name)
    WHERE deleted_at IS NULL;

-- Solo tardanzas (lateness_minutes > 0): indice FILTRADO
CREATE NONCLUSTERED INDEX ix_attendance_late
    ON dbo.attendance (staff_id, attendance_date)
    INCLUDE (lateness_minutes)
    WHERE lateness_minutes > 0;

-- Regla de negocio: solo UNA configuracion vigente por anio escolar
CREATE UNIQUE NONCLUSTERED INDEX ux_attendance_config_school_year_active
    ON dbo.attendance_config (school_year)
    WHERE active = 1;
GO

/* ---------------------------------------------------------------------
   3. Indice espacial (consultas de distancia sobre la ubicacion de sedes)
   --------------------------------------------------------------------- */
CREATE SPATIAL INDEX sx_site_location
    ON dbo.site (location)
    USING GEOGRAPHY_AUTO_GRID;
GO

/* ---------------------------------------------------------------------
   4. Ver los indices creados
   --------------------------------------------------------------------- */
SELECT  t.name  AS tabla,
        i.name  AS indice,
        i.type_desc AS tipo,
        i.is_unique AS es_unico,
        i.has_filter AS filtrado,
        i.filter_definition AS filtro,
        STUFF((SELECT ', ' + c.name
               FROM sys.index_columns ic
               JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
               WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
               ORDER BY ic.key_ordinal
               FOR XML PATH('')), 1, 2, '') AS columnas
FROM sys.indexes i
JOIN sys.tables  t ON t.object_id = i.object_id
WHERE i.type > 0
ORDER BY t.name, i.index_id;
GO
