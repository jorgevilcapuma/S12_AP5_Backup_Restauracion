/* =====================================================================
   Sistema de Control de Asistencia de Personal
   Script 01 - ESTRUCTURA (base de datos, secuencias y tablas)
   Motor : Microsoft SQL Server 2019 / 2022
   Modelo: Fisico v2.4

   Este script crea solo la base de datos, las secuencias y las tablas
   (columnas, tipos y nulabilidad). Las claves primarias, foraneas,
   UNIQUE, CHECK y DEFAULT se crean en 02_restricciones.sql.
   ===================================================================== */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE master;
GO

/* ---------------------------------------------------------------------
   1. Base de datos
   --------------------------------------------------------------------- */
IF DB_ID('db_control_asistencia') IS NOT NULL
BEGIN
    ALTER DATABASE db_control_asistencia SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE db_control_asistencia;
END
GO

-- Se crea en la ruta por defecto de la instancia (sirve en Windows y Linux)
CREATE DATABASE db_control_asistencia;
GO

-- Nombres logicos: db_control_asistencia_data y db_control_asistencia_log
-- (se usan luego en RESTORE ... WITH MOVE)
ALTER DATABASE db_control_asistencia MODIFY FILE (NAME = db_control_asistencia, NEWNAME = db_control_asistencia_data);
GO

-- Modelo de recuperacion FULL: necesario para backups de log y restauracion a un punto en el tiempo
ALTER DATABASE db_control_asistencia SET RECOVERY FULL;
-- Evita que un trigger se dispare a si mismo al actualizar su propia tabla
ALTER DATABASE db_control_asistencia SET RECURSIVE_TRIGGERS OFF;
GO

USE db_control_asistencia;
GO

/* ---------------------------------------------------------------------
   2. Secuencias (generan las claves primarias)
   --------------------------------------------------------------------- */
CREATE SEQUENCE dbo.staff_seq                AS bigint START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.attendance_seq           AS bigint START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.attendance_config_seq    AS int    START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.justification_seq        AS bigint START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.justification_reason_seq AS int    START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.area_seq                 AS int    START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.position_seq             AS int    START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dbo.site_seq                 AS int    START WITH 1 INCREMENT BY 1;
GO

/* ---------------------------------------------------------------------
   3. Tablas catalogo
   --------------------------------------------------------------------- */
CREATE TABLE dbo.position (
    position_id  int            NOT NULL,
    name         nvarchar(40)   NOT NULL,
    description  nvarchar(150)  NULL,
    active       bit            NOT NULL
);
GO

CREATE TABLE dbo.area (
    area_id  int           NOT NULL,
    name     nvarchar(60)  NOT NULL,
    active   bit           NOT NULL
);
GO

CREATE TABLE dbo.site (
    site_id           int             NOT NULL,
    name              nvarchar(80)    NOT NULL,
    address           nvarchar(150)   NULL,
    location          geography       NULL,
    allowed_radius_m  decimal(10,2)   NOT NULL,
    active            bit             NOT NULL
);
GO

CREATE TABLE dbo.justification_reason (
    reason_id          int           NOT NULL,
    name               nvarchar(60)  NOT NULL,
    requires_document  bit           NOT NULL,
    active             bit           NOT NULL
);
GO

CREATE TABLE dbo.attendance_config (
    attendance_config_id        int       NOT NULL,
    school_year                 smallint  NOT NULL,
    tolerance_minutes           tinyint   NOT NULL,
    default_entry_time          time(0)   NOT NULL,
    default_exit_time           time(0)   NOT NULL,
    default_break_start_time    time(0)   NULL,
    default_break_end_time      time(0)   NULL,
    active                      bit       NOT NULL
);
GO

/* ---------------------------------------------------------------------
   4. Tablas principales
   --------------------------------------------------------------------- */
CREATE TABLE dbo.staff (
    staff_id                bigint         NOT NULL,
    last_name               nvarchar(70)   NOT NULL,
    first_name              nvarchar(70)   NOT NULL,
    document_type           char(3)        NOT NULL,
    document_number         varchar(12)    NOT NULL,
    sex                     char(1)        NOT NULL,
    birth_date              date           NULL,
    mobile_phone            char(9)        NULL,
    position_id             int            NOT NULL,
    area_id                 int            NOT NULL,
    site_id                 int            NOT NULL,
    work_modality           varchar(20)    NOT NULL,
    entry_time              time(0)        NULL,
    exit_time               time(0)        NULL,
    break_start_time        time(0)        NULL,
    break_end_time          time(0)        NULL,
    additional_information  nvarchar(max)  NULL,
    status                  char(1)        NOT NULL,
    created_at              datetime       NOT NULL,
    updated_at              datetime       NULL,
    deleted_at              datetime       NULL,
    restored_at             datetime       NULL
);
GO

CREATE TABLE dbo.attendance (
    attendance_id         bigint          NOT NULL,
    staff_id              bigint          NOT NULL,
    attendance_config_id  int             NOT NULL,
    attendance_date       date            NOT NULL,
    entry_time            time(0)         NULL,
    break_start_time      time(0)         NULL,
    break_end_time        time(0)         NULL,
    exit_time             time(0)         NULL,
    lateness_minutes      smallint        NOT NULL,
    check_in_location     geography       NULL,
    distance_from_site_m  decimal(10,2)   NULL,
    observation           nvarchar(200)   NULL
);
GO

CREATE TABLE dbo.justification (
    justification_id  bigint          NOT NULL,
    attendance_id     bigint          NOT NULL,
    reason_id         int             NOT NULL,
    details           nvarchar(300)   NULL,
    supporting_file   nvarchar(255)   NULL,
    justified_at      datetime        NOT NULL
);
GO

PRINT 'Estructura creada correctamente.';
GO
