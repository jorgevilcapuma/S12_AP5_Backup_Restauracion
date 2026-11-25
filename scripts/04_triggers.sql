/* =====================================================================
   Sistema de Control de Asistencia de Personal
   Script 04 - TRIGGERS
   Requiere: 03_indices.sql
   Las pruebas de cada trigger estan al final de 05_datos.sql
   ===================================================================== */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE db_control_asistencia;
GO

/* =====================================================================
   TRIGGER 1: tr_attendance_validate_and_calculate
   Tabla   : attendance  (AFTER INSERT, UPDATE)
   Objetivo:
     a) Impedir marcar asistencia a personal inactivo o eliminado.
     b) Impedir usar una configuracion de asistencia no vigente.
     c) Calcular la distancia (m) entre el punto de marcacion y la sede.
     d) Rechazar la marcacion de personal PRESENCIAL fuera del radio
        permitido de su sede.
     e) Calcular los minutos de tardanza:
        hora real - (hora asignada + tolerancia). Si el trabajador no
        tiene hora asignada se usa la hora por defecto de la configuracion.
   ===================================================================== */
CREATE OR ALTER TRIGGER dbo.tr_attendance_validate_and_calculate
ON dbo.attendance
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    -- Solo se recalcula si cambian columnas que afectan el calculo
    IF NOT (UPDATE(staff_id) OR UPDATE(attendance_config_id) OR UPDATE(entry_time) OR UPDATE(check_in_location))
        RETURN;

    -- a) Personal inactivo o eliminado
    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN dbo.staff s ON s.staff_id = i.staff_id
               WHERE s.status = 'I' OR s.deleted_at IS NOT NULL)
    BEGIN
        ;THROW 50001, 'No se puede registrar asistencia de personal inactivo o eliminado.', 1;
    END

    -- b) Configuracion no vigente
    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN dbo.attendance_config c ON c.attendance_config_id = i.attendance_config_id
               WHERE c.active = 0)
    BEGIN
        ;THROW 50002, 'La configuracion de asistencia indicada no esta vigente.', 1;
    END

    -- d) Marcacion fuera del radio permitido (solo PRESENCIAL)
    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN dbo.staff s ON s.staff_id = i.staff_id
               JOIN dbo.site  t ON t.site_id  = s.site_id
               WHERE s.work_modality = 'PRESENCIAL'
                 AND i.check_in_location IS NOT NULL
                 AND t.location IS NOT NULL
                 AND t.location.STDistance(i.check_in_location) > t.allowed_radius_m)
    BEGIN
        ;THROW 50003, 'Marcacion rechazada: el punto de marcacion esta fuera del radio permitido de la sede.', 1;
    END

    -- c) y e) Calculo de distancia y tardanza
    UPDATE a
    SET distance_from_site_m =
            CASE WHEN i.check_in_location IS NULL OR t.location IS NULL THEN NULL
                 ELSE CAST(t.location.STDistance(i.check_in_location) AS decimal(10,2))
            END,
        lateness_minutes =
            CASE WHEN i.entry_time IS NULL THEN 0
                 WHEN i.entry_time > DATEADD(MINUTE, c.tolerance_minutes, COALESCE(s.entry_time, c.default_entry_time))
                      THEN DATEDIFF(MINUTE,
                                    DATEADD(MINUTE, c.tolerance_minutes, COALESCE(s.entry_time, c.default_entry_time)),
                                    i.entry_time)
                 ELSE 0
            END
    FROM dbo.attendance a
    JOIN inserted i               ON i.attendance_id = a.attendance_id
    JOIN dbo.staff s              ON s.staff_id = i.staff_id
    JOIN dbo.site  t              ON t.site_id  = s.site_id
    JOIN dbo.attendance_config c  ON c.attendance_config_id = i.attendance_config_id;
END;
GO

/* =====================================================================
   TRIGGER 2: tr_justification_validate
   Tabla   : justification  (AFTER INSERT, UPDATE)
   Objetivo:
     a) Impedir usar un motivo de justificacion inactivo.
     b) Exigir archivo de sustento cuando el motivo lo requiere
        (justification_reason.requires_document = 1).
   ===================================================================== */
CREATE OR ALTER TRIGGER dbo.tr_justification_validate
ON dbo.justification
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN dbo.justification_reason r ON r.reason_id = i.reason_id
               WHERE r.active = 0)
    BEGIN
        ;THROW 50011, 'El motivo de justificacion no esta activo.', 1;
    END

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN dbo.justification_reason r ON r.reason_id = i.reason_id
               WHERE r.requires_document = 1
                 AND NULLIF(LTRIM(RTRIM(i.supporting_file)), '') IS NULL)
    BEGIN
        ;THROW 50012, 'El motivo seleccionado requiere adjuntar un archivo de sustento.', 1;
    END
END;
GO

/* =====================================================================
   TRIGGER 3: tr_staff_soft_delete
   Tabla   : staff  (INSTEAD OF DELETE)
   Objetivo: Eliminacion LOGICA. Un DELETE no borra la fila: registra
             deleted_at y cambia el estado a 'I' (inactivo). Asi se
             conserva el historial de asistencia del trabajador.
   ===================================================================== */
CREATE OR ALTER TRIGGER dbo.tr_staff_soft_delete
ON dbo.staff
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE s
    SET deleted_at = GETDATE(),
        status     = 'I'
    FROM dbo.staff s
    JOIN deleted d ON d.staff_id = s.staff_id
    WHERE s.deleted_at IS NULL;
END;
GO

/* =====================================================================
   TRIGGER 4: tr_staff_audit_dates
   Tabla   : staff  (AFTER UPDATE)
   Objetivo:
     a) Registrar updated_at en cada modificacion.
     b) Si deleted_at pasa de un valor a NULL (restauracion), registrar
        restored_at y reactivar al trabajador (status = 'A').
   Nota: RECURSIVE_TRIGGERS esta en OFF (ver 01_estructura.sql), por eso
         el UPDATE interno no vuelve a disparar este mismo trigger.
   ===================================================================== */
CREATE OR ALTER TRIGGER dbo.tr_staff_audit_dates
ON dbo.staff
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE s
    SET updated_at  = GETDATE(),
        restored_at = CASE WHEN d.deleted_at IS NOT NULL AND i.deleted_at IS NULL
                           THEN GETDATE() ELSE s.restored_at END,
        status      = CASE WHEN d.deleted_at IS NOT NULL AND i.deleted_at IS NULL
                           THEN 'A' ELSE s.status END
    FROM dbo.staff s
    JOIN inserted i ON i.staff_id = s.staff_id
    JOIN deleted  d ON d.staff_id = s.staff_id;
END;
GO

/* Ver los triggers creados */
SELECT  tr.name                AS trigger_name,
        OBJECT_NAME(tr.parent_id) AS tabla,
        CASE WHEN tr.is_instead_of_trigger = 1 THEN 'INSTEAD OF' ELSE 'AFTER' END AS tipo,
        STUFF((SELECT ', ' + te.type_desc FROM sys.trigger_events te
               WHERE te.object_id = tr.object_id FOR XML PATH('')), 1, 2, '') AS eventos,
        tr.is_disabled         AS deshabilitado
FROM sys.triggers tr
WHERE tr.parent_class = 1
ORDER BY tabla, trigger_name;
GO
