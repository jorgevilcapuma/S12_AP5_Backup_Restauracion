/* =====================================================================
   Sistema de Control de Asistencia de Personal
   Script 02 - RESTRICCIONES
   PRIMARY KEY, FOREIGN KEY, UNIQUE, CHECK y DEFAULT
   Requiere: 01_estructura.sql
   ===================================================================== */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE db_control_asistencia;
GO

/* =====================================================================
   1. CLAVES PRIMARIAS (PK)
   ===================================================================== */
ALTER TABLE dbo.position             ADD CONSTRAINT pk_position             PRIMARY KEY (position_id);
ALTER TABLE dbo.area                 ADD CONSTRAINT pk_area                 PRIMARY KEY (area_id);
ALTER TABLE dbo.site                 ADD CONSTRAINT pk_site                 PRIMARY KEY (site_id);
ALTER TABLE dbo.justification_reason ADD CONSTRAINT pk_justification_reason PRIMARY KEY (reason_id);
ALTER TABLE dbo.attendance_config    ADD CONSTRAINT pk_attendance_config    PRIMARY KEY (attendance_config_id);
ALTER TABLE dbo.staff                ADD CONSTRAINT pk_staff                PRIMARY KEY (staff_id);
ALTER TABLE dbo.attendance           ADD CONSTRAINT pk_attendance           PRIMARY KEY (attendance_id);
ALTER TABLE dbo.justification        ADD CONSTRAINT pk_justification        PRIMARY KEY (justification_id);
GO

/* =====================================================================
   2. CLAVES FORANEAS (FK) - una por cada referencia del modelo
   ===================================================================== */
-- 3.4 position_staff
ALTER TABLE dbo.staff ADD CONSTRAINT fk_staff_position
    FOREIGN KEY (position_id) REFERENCES dbo.position (position_id);
-- 3.5 area_staff
ALTER TABLE dbo.staff ADD CONSTRAINT fk_staff_area
    FOREIGN KEY (area_id) REFERENCES dbo.area (area_id);
-- 3.6 site_staff
ALTER TABLE dbo.staff ADD CONSTRAINT fk_staff_site
    FOREIGN KEY (site_id) REFERENCES dbo.site (site_id);
-- 3.2 staff_attendance
ALTER TABLE dbo.attendance ADD CONSTRAINT fk_attendance_staff
    FOREIGN KEY (staff_id) REFERENCES dbo.staff (staff_id);
-- 3.1 attendance_attendance_config
ALTER TABLE dbo.attendance ADD CONSTRAINT fk_attendance_attendance_config
    FOREIGN KEY (attendance_config_id) REFERENCES dbo.attendance_config (attendance_config_id);
-- 3.7 attendance_justification
ALTER TABLE dbo.justification ADD CONSTRAINT fk_justification_attendance
    FOREIGN KEY (attendance_id) REFERENCES dbo.attendance (attendance_id);
-- 3.3 justification_reason_justification
ALTER TABLE dbo.justification ADD CONSTRAINT fk_justification_reason
    FOREIGN KEY (reason_id) REFERENCES dbo.justification_reason (reason_id);
GO

/* =====================================================================
   3. RESTRICCIONES UNICAS (UNIQUE)
   ===================================================================== */
ALTER TABLE dbo.position             ADD CONSTRAINT uq_position_name             UNIQUE (name);
ALTER TABLE dbo.area                 ADD CONSTRAINT uq_area_name                 UNIQUE (name);
ALTER TABLE dbo.site                 ADD CONSTRAINT uq_site_name                 UNIQUE (name);
ALTER TABLE dbo.justification_reason ADD CONSTRAINT uq_justification_reason_name UNIQUE (name);
-- Un documento de identidad no se repite (tipo + numero)
ALTER TABLE dbo.staff      ADD CONSTRAINT uq_staff_document         UNIQUE (document_type, document_number);
-- Un trabajador tiene como maximo un registro de asistencia por dia
ALTER TABLE dbo.attendance ADD CONSTRAINT uq_attendance_staff_date UNIQUE (staff_id, attendance_date);
GO

/* =====================================================================
   4. RESTRICCIONES DE VALIDACION (CHECK)
   ===================================================================== */
-- staff -----------------------------------------------------------------
ALTER TABLE dbo.staff ADD CONSTRAINT ck_staff_document_type
    CHECK (document_type IN ('DNI', 'CE', 'PAS'));

ALTER TABLE dbo.staff ADD CONSTRAINT ck_staff_document_number
    CHECK (
        (document_type = 'DNI' AND document_number LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
     OR (document_type IN ('CE', 'PAS') AND LEN(document_number) BETWEEN 6 AND 12
         AND document_number NOT LIKE '%[^A-Za-z0-9]%')
    );

ALTER TABLE dbo.staff ADD CONSTRAINT ck_staff_sex
    CHECK (sex IN ('M', 'F'));

-- Celular peruano: 9 digitos y empieza con 9
ALTER TABLE dbo.staff ADD CONSTRAINT ck_staff_mobile_phone
    CHECK (mobile_phone IS NULL OR mobile_phone LIKE '9[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]');

-- Mayor de edad al momento del registro
ALTER TABLE dbo.staff ADD CONSTRAINT ck_staff_birth_date
    CHECK (birth_date IS NULL OR birth_date <= DATEADD(YEAR, -18, CAST(GETDATE() AS date)));

ALTER TABLE dbo.staff ADD CONSTRAINT ck_staff_work_modality
    CHECK (work_modality IN ('PRESENCIAL', 'REMOTO', 'HIBRIDO'));

ALTER TABLE dbo.staff ADD CONSTRAINT ck_staff_status
    CHECK (status IN ('A', 'I'));

ALTER TABLE dbo.staff ADD CONSTRAINT ck_staff_schedule
    CHECK (entry_time IS NULL OR exit_time IS NULL OR exit_time > entry_time);

ALTER TABLE dbo.staff ADD CONSTRAINT ck_staff_break
    CHECK (break_start_time IS NULL OR break_end_time IS NULL OR break_end_time > break_start_time);

-- attendance ------------------------------------------------------------
ALTER TABLE dbo.attendance ADD CONSTRAINT ck_attendance_lateness
    CHECK (lateness_minutes >= 0);

ALTER TABLE dbo.attendance ADD CONSTRAINT ck_attendance_distance
    CHECK (distance_from_site_m IS NULL OR distance_from_site_m >= 0);

ALTER TABLE dbo.attendance ADD CONSTRAINT ck_attendance_exit
    CHECK (entry_time IS NULL OR exit_time IS NULL OR exit_time > entry_time);

ALTER TABLE dbo.attendance ADD CONSTRAINT ck_attendance_break
    CHECK (break_start_time IS NULL OR break_end_time IS NULL OR break_end_time > break_start_time);

-- No se registra asistencia de fechas futuras
ALTER TABLE dbo.attendance ADD CONSTRAINT ck_attendance_date
    CHECK (attendance_date <= CAST(GETDATE() AS date));

-- attendance_config -----------------------------------------------------
ALTER TABLE dbo.attendance_config ADD CONSTRAINT ck_attendance_config_school_year
    CHECK (school_year BETWEEN 2000 AND 2100);

ALTER TABLE dbo.attendance_config ADD CONSTRAINT ck_attendance_config_tolerance
    CHECK (tolerance_minutes BETWEEN 0 AND 60);

ALTER TABLE dbo.attendance_config ADD CONSTRAINT ck_attendance_config_schedule
    CHECK (default_exit_time > default_entry_time);

ALTER TABLE dbo.attendance_config ADD CONSTRAINT ck_attendance_config_break
    CHECK (default_break_start_time IS NULL OR default_break_end_time IS NULL
           OR default_break_end_time > default_break_start_time);

-- site ------------------------------------------------------------------
ALTER TABLE dbo.site ADD CONSTRAINT ck_site_allowed_radius
    CHECK (allowed_radius_m > 0);
GO

/* =====================================================================
   5. VALORES POR DEFECTO (DEFAULT)
   Las claves primarias toman su valor de las secuencias.
   ===================================================================== */
ALTER TABLE dbo.position             ADD CONSTRAINT df_position_id             DEFAULT (NEXT VALUE FOR dbo.position_seq)             FOR position_id;
ALTER TABLE dbo.area                 ADD CONSTRAINT df_area_id                 DEFAULT (NEXT VALUE FOR dbo.area_seq)                 FOR area_id;
ALTER TABLE dbo.site                 ADD CONSTRAINT df_site_id                 DEFAULT (NEXT VALUE FOR dbo.site_seq)                 FOR site_id;
ALTER TABLE dbo.justification_reason ADD CONSTRAINT df_justification_reason_id DEFAULT (NEXT VALUE FOR dbo.justification_reason_seq) FOR reason_id;
ALTER TABLE dbo.attendance_config    ADD CONSTRAINT df_attendance_config_id    DEFAULT (NEXT VALUE FOR dbo.attendance_config_seq)    FOR attendance_config_id;
ALTER TABLE dbo.staff                ADD CONSTRAINT df_staff_id                DEFAULT (NEXT VALUE FOR dbo.staff_seq)                FOR staff_id;
ALTER TABLE dbo.attendance           ADD CONSTRAINT df_attendance_id           DEFAULT (NEXT VALUE FOR dbo.attendance_seq)           FOR attendance_id;
ALTER TABLE dbo.justification        ADD CONSTRAINT df_justification_id        DEFAULT (NEXT VALUE FOR dbo.justification_seq)        FOR justification_id;

ALTER TABLE dbo.position             ADD CONSTRAINT df_position_active                 DEFAULT (1)            FOR active;
ALTER TABLE dbo.area                 ADD CONSTRAINT df_area_active                     DEFAULT (1)            FOR active;
ALTER TABLE dbo.site                 ADD CONSTRAINT df_site_active                     DEFAULT (1)            FOR active;
ALTER TABLE dbo.justification_reason ADD CONSTRAINT df_justification_reason_requires   DEFAULT (0)            FOR requires_document;
ALTER TABLE dbo.justification_reason ADD CONSTRAINT df_justification_reason_active     DEFAULT (1)            FOR active;
ALTER TABLE dbo.attendance_config    ADD CONSTRAINT df_attendance_config_tolerance     DEFAULT (0)            FOR tolerance_minutes;
ALTER TABLE dbo.attendance_config    ADD CONSTRAINT df_attendance_config_active        DEFAULT (1)            FOR active;
ALTER TABLE dbo.staff                ADD CONSTRAINT df_staff_work_modality             DEFAULT ('PRESENCIAL') FOR work_modality;
ALTER TABLE dbo.staff                ADD CONSTRAINT df_staff_status                    DEFAULT ('A')          FOR status;
ALTER TABLE dbo.staff                ADD CONSTRAINT df_staff_created_at                DEFAULT (GETDATE())    FOR created_at;
ALTER TABLE dbo.attendance           ADD CONSTRAINT df_attendance_lateness             DEFAULT (0)            FOR lateness_minutes;
ALTER TABLE dbo.justification        ADD CONSTRAINT df_justification_justified_at      DEFAULT (GETDATE())    FOR justified_at;
GO

PRINT 'Restricciones creadas correctamente.';
GO
