/* =====================================================================
   Sistema de Control de Asistencia de Personal
   Script 07 - GENERACION DE BACKUP Y RESTAURACION
   Requiere: 05_datos.sql  (la BD debe estar en RECOVERY FULL, ver 01)

   Flujo:
     0. Ruta de backups
     1. Backup FULL
     2. Cambios + backup DIFERENCIAL
     3. Cambios + marca de tiempo + "desastre" + backup de LOG
     4. Verificacion de los archivos de backup
     5. Restauracion A: copia en otra base de datos (WITH MOVE)
     6. Restauracion B: restauracion a un punto en el tiempo (STOPAT)
        sobre la base original, para recuperar los datos borrados
     7. Historial de backups (msdb)

   Ejecutar el script COMPLETO de una sola vez (F5): los pasos usan
   SESSION_CONTEXT para compartir la ruta y la marca de tiempo.
   ===================================================================== */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

USE master;
GO

/* =====================================================================
   0. RUTA DE BACKUPS
   Por defecto se usa la carpeta de backups de la instancia, donde la
   cuenta de servicio de SQL Server ya tiene permisos, por ejemplo:
     Windows: C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\
     Linux  : /var/opt/mssql/data/
   Para usar otra carpeta (p. ej. 'D:\Backups\'), asignala en @ruta.
   ===================================================================== */
DECLARE @ruta nvarchar(260) = NULL;   -- <- opcional: 'D:\Backups\'

IF @ruta IS NULL
    SET @ruta = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(260));

-- Agregar separador final segun el sistema operativo
IF RIGHT(@ruta, 1) NOT IN ('\', '/')
    SET @ruta += CASE WHEN LEFT(@ruta, 1) = '/' THEN '/' ELSE '\' END;

EXEC sp_set_session_context @key = N'ruta_backup', @value = @ruta;
PRINT CONCAT('Ruta de backups: ', @ruta);
GO

/* =====================================================================
   1. BACKUP FULL (copia completa)
   ===================================================================== */
DECLARE @archivo nvarchar(400) = CAST(SESSION_CONTEXT(N'ruta_backup') AS nvarchar(260)) + N'db_control_asistencia_FULL.bak';

BACKUP DATABASE db_control_asistencia
TO DISK = @archivo
WITH FORMAT, INIT,
     NAME        = N'db_control_asistencia - Backup FULL',
     DESCRIPTION = N'Copia completa del Sistema de Control de Asistencia',
     CHECKSUM,
     STATS = 25;
GO

/* =====================================================================
   2. CAMBIOS + BACKUP DIFERENCIAL
   El diferencial solo guarda lo que cambio desde el ultimo FULL.
   ===================================================================== */
USE db_control_asistencia;

INSERT INTO dbo.attendance (staff_id, attendance_config_id, attendance_date, entry_time, check_in_location, observation)
SELECT s.staff_id, c.attendance_config_id, CAST(GETDATE() AS date), '07:35',
       geography::Point(-13.075700, -76.387000, 4326), N'Registro posterior al backup FULL'
FROM dbo.staff s
CROSS JOIN dbo.attendance_config c
WHERE s.document_number = '44567890' AND c.active = 1
  AND NOT EXISTS (SELECT 1 FROM dbo.attendance x
                  WHERE x.staff_id = s.staff_id AND x.attendance_date = CAST(GETDATE() AS date));

USE master;

DECLARE @archivo nvarchar(400) = CAST(SESSION_CONTEXT(N'ruta_backup') AS nvarchar(260)) + N'db_control_asistencia_DIFF.bak';

BACKUP DATABASE db_control_asistencia
TO DISK = @archivo
WITH DIFFERENTIAL, FORMAT, INIT,
     NAME = N'db_control_asistencia - Backup DIFERENCIAL',
     CHECKSUM,
     STATS = 25;
GO

/* =====================================================================
   3. CAMBIOS + PUNTO EN EL TIEMPO + "DESASTRE" + BACKUP DE LOG
   ===================================================================== */
USE db_control_asistencia;

-- Cambio valido: nuevo motivo de justificacion
IF NOT EXISTS (SELECT 1 FROM dbo.justification_reason WHERE name = N'Cita en ESSALUD')
    INSERT INTO dbo.justification_reason (name, requires_document) VALUES (N'Cita en ESSALUD', 1);

WAITFOR DELAY '00:00:02';

-- Momento "bueno" al que luego se volvera (antes del error)
DECLARE @punto datetime = GETDATE();
EXEC sp_set_session_context @key = N'punto_restauracion', @value = @punto;
PRINT CONCAT('Punto de restauracion: ', CONVERT(varchar(23), @punto, 121));

WAITFOR DELAY '00:00:02';

-- "DESASTRE": se borran por error todas las justificaciones
DELETE FROM dbo.justification;

SELECT 'Despues del desastre' AS momento,
       (SELECT COUNT(*) FROM dbo.justification)        AS justificaciones,
       (SELECT COUNT(*) FROM dbo.justification_reason) AS motivos;

USE master;

-- Backup del log de transacciones (contiene el cambio valido y el DELETE)
DECLARE @archivo nvarchar(400) = CAST(SESSION_CONTEXT(N'ruta_backup') AS nvarchar(260)) + N'db_control_asistencia_LOG.trn';

BACKUP LOG db_control_asistencia
TO DISK = @archivo
WITH FORMAT, INIT,
     NAME = N'db_control_asistencia - Backup LOG',
     CHECKSUM,
     STATS = 25;
GO

/* =====================================================================
   4. VERIFICACION DE LOS BACKUPS
   ===================================================================== */
DECLARE @ruta nvarchar(260) = CAST(SESSION_CONTEXT(N'ruta_backup') AS nvarchar(260));
DECLARE @full nvarchar(400) = @ruta + N'db_control_asistencia_FULL.bak',
        @diff nvarchar(400) = @ruta + N'db_control_asistencia_DIFF.bak',
        @log  nvarchar(400) = @ruta + N'db_control_asistencia_LOG.trn';

-- Comprueba que el archivo es legible y que los CHECKSUM son correctos
RESTORE VERIFYONLY FROM DISK = @full WITH CHECKSUM;
RESTORE VERIFYONLY FROM DISK = @diff WITH CHECKSUM;
RESTORE VERIFYONLY FROM DISK = @log  WITH CHECKSUM;

-- Cabecera del backup (tipo, fecha, LSN, tamanio)
RESTORE HEADERONLY FROM DISK = @full;

-- Archivos logicos que contiene el backup (se usan en WITH MOVE)
RESTORE FILELISTONLY FROM DISK = @full;
GO

/* =====================================================================
   5. RESTAURACION A: COPIA EN UNA BASE DE DATOS NUEVA
   Se restaura el FULL con otro nombre, moviendo los archivos fisicos.
   Util para pruebas o para revisar datos sin tocar produccion.
   ===================================================================== */
IF DB_ID('db_control_asistencia_copia') IS NOT NULL
BEGIN
    ALTER DATABASE db_control_asistencia_copia SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE db_control_asistencia_copia;
END

DECLARE @full nvarchar(400) = CAST(SESSION_CONTEXT(N'ruta_backup') AS nvarchar(260)) + N'db_control_asistencia_FULL.bak';
DECLARE @dir_datos nvarchar(260) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS nvarchar(260));
DECLARE @mdf nvarchar(400) = @dir_datos + N'db_control_asistencia_copia.mdf',
        @ldf nvarchar(400) = @dir_datos + N'db_control_asistencia_copia_log.ldf';

RESTORE DATABASE db_control_asistencia_copia
FROM DISK = @full
WITH MOVE N'db_control_asistencia_data' TO @mdf,
     MOVE N'db_control_asistencia_log'  TO @ldf,
     RECOVERY,
     STATS = 25;

-- La copia tiene los datos del momento del FULL
SELECT 'Copia (solo FULL)' AS base,
       (SELECT COUNT(*) FROM db_control_asistencia_copia.dbo.staff)         AS personal,
       (SELECT COUNT(*) FROM db_control_asistencia_copia.dbo.attendance)    AS asistencias,
       (SELECT COUNT(*) FROM db_control_asistencia_copia.dbo.justification) AS justificaciones;
GO

/* =====================================================================
   6. RESTAURACION B: PUNTO EN EL TIEMPO SOBRE LA BASE ORIGINAL
   Secuencia: FULL (NORECOVERY) -> DIFERENCIAL (NORECOVERY)
              -> LOG (STOPAT = antes del DELETE, RECOVERY)
   Resultado: vuelven las justificaciones borradas y se conserva el
              cambio valido hecho antes del error.
   ===================================================================== */
DECLARE @ruta  nvarchar(260) = CAST(SESSION_CONTEXT(N'ruta_backup') AS nvarchar(260));
DECLARE @punto datetime      = CAST(SESSION_CONTEXT(N'punto_restauracion') AS datetime);
DECLARE @full nvarchar(400) = @ruta + N'db_control_asistencia_FULL.bak',
        @diff nvarchar(400) = @ruta + N'db_control_asistencia_DIFF.bak',
        @log  nvarchar(400) = @ruta + N'db_control_asistencia_LOG.trn';

-- Cerrar conexiones abiertas a la base
ALTER DATABASE db_control_asistencia SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE db_control_asistencia FROM DISK = @full WITH REPLACE, NORECOVERY, STATS = 25;
RESTORE DATABASE db_control_asistencia FROM DISK = @diff WITH NORECOVERY, STATS = 25;
RESTORE LOG      db_control_asistencia FROM DISK = @log  WITH STOPAT = @punto, RECOVERY;

ALTER DATABASE db_control_asistencia SET MULTI_USER;

SELECT 'Original restaurada (STOPAT)' AS base,
       (SELECT COUNT(*) FROM db_control_asistencia.dbo.staff)                AS personal,
       (SELECT COUNT(*) FROM db_control_asistencia.dbo.attendance)           AS asistencias,
       (SELECT COUNT(*) FROM db_control_asistencia.dbo.justification)        AS justificaciones,
       (SELECT COUNT(*) FROM db_control_asistencia.dbo.justification_reason) AS motivos;
GO

/* =====================================================================
   7. HISTORIAL DE BACKUPS Y RESTAURACIONES (msdb)
   ===================================================================== */
SELECT TOP (10)
       bs.database_name,
       CASE bs.type WHEN 'D' THEN 'FULL' WHEN 'I' THEN 'DIFERENCIAL' WHEN 'L' THEN 'LOG' END AS tipo,
       bs.backup_start_date,
       bs.backup_finish_date,
       CAST(bs.backup_size / 1024.0 / 1024.0 AS decimal(10,2)) AS tamanio_mb,
       bmf.physical_device_name AS archivo
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = 'db_control_asistencia'
ORDER BY bs.backup_finish_date DESC;

SELECT TOP (10)
       rh.destination_database_name AS base_destino,
       rh.restore_date,
       CASE rh.restore_type WHEN 'D' THEN 'DATABASE' WHEN 'I' THEN 'DIFERENCIAL' WHEN 'L' THEN 'LOG' END AS tipo,
       rh.stop_at
FROM msdb.dbo.restorehistory rh
WHERE rh.destination_database_name LIKE 'db_control_asistencia%'
ORDER BY rh.restore_date DESC;
GO
