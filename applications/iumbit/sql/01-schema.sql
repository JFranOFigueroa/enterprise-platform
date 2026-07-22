-- liquibase formatted sql

-- changeset jurgen-garrido:v0001-2026-06-25-db-schema-init

-- rollback ALTER TABLE "event_type" DROP CONSTRAINT "event_type_parent_fk";
-- rollback ALTER TABLE "event_type" DROP CONSTRAINT "event_type_company_fk";
-- rollback ALTER TABLE "event" DROP CONSTRAINT "event_event_type_fk";
-- rollback ALTER TABLE "event" DROP CONSTRAINT "event_employee_fk";
-- rollback ALTER TABLE "event" DROP CONSTRAINT "event_device_fk";
-- rollback ALTER TABLE "hr"."slot" DROP CONSTRAINT "slot_schedule_fk";
-- rollback ALTER TABLE "hr"."slot" DROP CONSTRAINT "slot_category_fk";
-- rollback ALTER TABLE "hr"."schedule_category" DROP CONSTRAINT "schedule_category_company_fk";
-- rollback ALTER TABLE "hr"."position" DROP CONSTRAINT "position_department_fk";
-- rollback ALTER TABLE "hr"."invitation_code" DROP CONSTRAINT "invitation_code_employee_fk";
-- rollback ALTER TABLE "hr"."employee" DROP CONSTRAINT "employee_user_fk";
-- rollback ALTER TABLE "hr"."employee" DROP CONSTRAINT "employee_position_fk";
-- rollback ALTER TABLE "hr"."employee_health_insurance" DROP CONSTRAINT "employee_health_insurance_health_insurance_fk";
-- rollback ALTER TABLE "hr"."employee_health_insurance" DROP CONSTRAINT "employee_health_insurance_employee_fk";
-- rollback ALTER TABLE "hr"."employee" DROP CONSTRAINT "employee_employee_fk";
-- rollback ALTER TABLE "hr"."department" DROP CONSTRAINT "department_department_fk";
-- rollback ALTER TABLE "hr"."department" DROP CONSTRAINT "department_company_fk";
-- rollback ALTER TABLE "hr"."company_work_days" DROP CONSTRAINT "company_work_days_company_fk";
-- rollback ALTER TABLE "hr"."branch" DROP CONSTRAINT "branch_admin_user_fk";
-- rollback ALTER TABLE "hr"."branch" DROP CONSTRAINT "branch_company_fk";
-- rollback ALTER TABLE "auth"."user_role" DROP CONSTRAINT "user_role_user_fk";
-- rollback ALTER TABLE "auth"."user_role" DROP CONSTRAINT "user_role_role_fk";
-- rollback ALTER TABLE "auth"."user_company" DROP CONSTRAINT "user_company_user_fk";
-- rollback ALTER TABLE "auth"."user_company" DROP CONSTRAINT "user_company_company_fk";
-- rollback ALTER TABLE "auth"."role_permission" DROP CONSTRAINT "role_permission_role_fk";
-- rollback ALTER TABLE "auth"."role_permission" DROP CONSTRAINT "role_permission_permission_fk";
-- rollback ALTER TABLE "auth"."oauth_account" DROP CONSTRAINT "oauth_account_user_fk";
-- rollback ALTER TABLE "auth"."refresh_token" DROP CONSTRAINT "fk_refresh_token_user";
-- rollback ALTER TABLE "audit"."audit_trail" DROP CONSTRAINT "audit_trail_user_fk";

-- rollback DROP TABLE "event_type";
-- rollback DROP TABLE "event";
-- rollback DROP TABLE "device";
-- rollback DROP TABLE "hr"."slot";
-- rollback DROP TABLE "hr"."schedule_category";
-- rollback DROP TABLE "hr"."schedule";
-- rollback DROP TABLE "hr"."position";
-- rollback DROP TABLE "hr"."invitation_code";
-- rollback DROP TABLE "hr"."health_insurance";
-- rollback DROP TABLE "hr"."employee_health_insurance";
-- rollback DROP TABLE "hr"."employee";
-- rollback DROP TABLE "hr"."department";
-- rollback DROP TABLE "hr"."company_work_days";
-- rollback DROP TABLE "hr"."company";
-- rollback DROP TABLE "hr"."daily_attendance_record";
-- rollback DROP TABLE "hr"."branch";
-- rollback DROP TABLE "auth"."user_role";
-- rollback DROP TABLE "auth"."user_company";
-- rollback DROP TABLE "auth"."user";
-- rollback DROP TABLE "auth"."role_permission";
-- rollback DROP TABLE "auth"."role";
-- rollback DROP TABLE "auth"."refresh_token";
-- rollback DROP TABLE "auth"."permission";
-- rollback DROP TABLE "auth"."oauth_account";
-- rollback DROP TABLE "audit"."audit_trail";


-- rollback DROP FUNCTION public.uuid_v7();
-- rollback DROP EXTENSION IF EXISTS pgcrypto;

-- rollback DROP SCHEMA "hr" CASCADE;
-- rollback DROP SCHEMA "auth" CASCADE;
-- rollback DROP SCHEMA "audit" CASCADE;

SET TIME ZONE 'UTC';

CREATE SCHEMA "audit";
CREATE SCHEMA "auth";
CREATE SCHEMA "hr";

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION public.uuid_v7 () RETURNS uuid AS $$
DECLARE
    millis BIGINT := (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT;
    time_bytes BYTEA;
    random_bytes BYTEA;
    uuid_bytes BYTEA;
BEGIN
    time_bytes := decode(lpad(to_hex(millis), 12, '0'), 'hex');
    random_bytes := gen_random_bytes(10);
    uuid_bytes := time_bytes || random_bytes;
    uuid_bytes := set_byte(uuid_bytes, 6, (get_byte(uuid_bytes, 6) & 15) | 112);
    uuid_bytes := set_byte(uuid_bytes, 8, (get_byte(uuid_bytes, 8) & 63) | 128);
    RETURN encode(uuid_bytes, 'hex')::uuid;
END;
$$ LANGUAGE plpgsql VOLATILE;

CREATE TABLE "audit"."audit_trail" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "entity_name" VARCHAR(100) NOT NULL,
    "entity_id" VARCHAR(255) NOT NULL,
    "action" VARCHAR(20) NOT NULL,
    "old_values" JSONB,
    "new_values" JSONB,
    "ip_address" VARCHAR(45),
    "user_agent" TEXT,
    "fk_user_id" UUID,
    "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE "auth"."oauth_account" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "provider" VARCHAR(50) NOT NULL,
    "provider_user_id" VARCHAR(255) NOT NULL,
    "fk_user_id" UUID,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

CREATE TABLE "auth"."permission" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(50) UNIQUE NOT NULL,
    "description" TEXT,
    "status" BOOLEAN,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

CREATE TABLE "auth"."refresh_token" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "token" VARCHAR(255) UNIQUE NOT NULL,
    "expiry_date" TIMESTAMP NOT NULL,
    "client_type" VARCHAR(50) NOT NULL,
    "fk_user_id" UUID NOT NULL,
    "status" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

CREATE TABLE "auth"."role" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(50) UNIQUE NOT NULL,
    "description" TEXT,
    "status" BOOLEAN,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

CREATE TABLE "auth"."role_permission" (
    "fk_role_id" UUID NOT NULL,
    "fk_permission_id" UUID NOT NULL,
    "status" BOOLEAN,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP,
    PRIMARY KEY ("fk_role_id", "fk_permission_id")
);

CREATE TABLE "auth"."user" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "full_name" VARCHAR(100),
    "password" TEXT NOT NULL,
    "email" VARCHAR(255) UNIQUE,
    "timezone" VARCHAR(50) DEFAULT 'UTC',
    "mfa_enabled" BOOLEAN DEFAULT false,
    "failed_login_attempts" INTEGER DEFAULT 0,
    "locked_until" TIMESTAMP,
    "last_login_at" TIMESTAMP,
    "status" BOOLEAN,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

CREATE TABLE "auth"."user_company" (
    "fk_user_id" UUID NOT NULL,
    "fk_company_id" UUID NOT NULL,
    "status" BOOLEAN,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP,
    PRIMARY KEY ("fk_user_id", "fk_company_id")
);

CREATE TABLE "auth"."user_role" (
    "fk_user_id" UUID NOT NULL,
    "fk_role_id" UUID NOT NULL,
    "status" BOOLEAN,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP,
    PRIMARY KEY ("fk_user_id", "fk_role_id")
);

CREATE TABLE "hr"."company" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "business_name" VARCHAR(255) UNIQUE NOT NULL,
    "trade_name" VARCHAR(255) UNIQUE NOT NULL,
    "tax_identifier" VARCHAR(50) UNIQUE,
    "registration_number" VARCHAR(100),
    "email" VARCHAR(255) UNIQUE NOT NULL,
    "phone_number" VARCHAR(20),
    "website" VARCHAR(255),
    "address_line_1" VARCHAR(255),
    "address_line_2" VARCHAR(255),
    "city" VARCHAR(100),
    "state_province" VARCHAR(100),
    "postal_code" VARCHAR(20),
    "country" VARCHAR(100) DEFAULT 'México',
    "industry_sector" VARCHAR(100),
    "logo" TEXT,
    "description" TEXT,
    "timezone" VARCHAR(50) DEFAULT 'UTC',
    "weekly_work_hours" SMALLINT NOT NULL DEFAULT 48,
    "daily_break_minutes" SMALLINT NOT NULL DEFAULT 60,
    "work_modality" VARCHAR(50) NOT NULL DEFAULT 'IN_PERSON',
    "location_latitude" DOUBLE PRECISION,
    "location_longitude" DOUBLE PRECISION,
    "status" BOOLEAN,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

CREATE TABLE "hr"."company_work_days" (
    "company_id" UUID NOT NULL,
    "day_of_week" VARCHAR(20) NOT NULL,
    "status" BOOLEAN,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP,
    PRIMARY KEY ("company_id", "day_of_week")
);

CREATE TABLE "hr"."department" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(50),
    "description" TEXT,
    "parent_department_id" UUID,
    "fk_company_id" UUID,
    "fk_branch_id" UUID,
    "status" BOOLEAN,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

CREATE TABLE "hr"."employee" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "code" VARCHAR(50),
    "name" VARCHAR(100),
    "last_name" VARCHAR(100),
    "second_surname" VARCHAR(100),
    "email" VARCHAR(255) UNIQUE NOT NULL,
    "national_identifier" VARCHAR(50),
    "tax_identifier" VARCHAR(50) UNIQUE,
    "ssn" VARCHAR(50),
    "phone_number" VARCHAR(20),
    "hire_date" DATE,
    "termination_date" DATE,
    "manager_id" UUID,
    "remote_location_latitude" DOUBLE PRECISION,
    "remote_location_longitude" DOUBLE PRECISION,
    "fk_position_id" UUID,
    "fk_user_id" UUID,
    "status" BOOLEAN,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

CREATE TABLE "hr"."employee_health_insurance" (
    "fk_employee_id" UUID NOT NULL,
    "fk_health_insurance_id" UUID NOT NULL,
    "policy_number" VARCHAR(100),
    "status" BOOLEAN,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP,
    PRIMARY KEY ("fk_employee_id", "fk_health_insurance_id")
);

CREATE TABLE "hr"."health_insurance" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(50),
    "description" TEXT,
    "status" BOOLEAN,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

CREATE TABLE "hr"."invitation_code" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "code" VARCHAR(20) UNIQUE NOT NULL,
    "expires_at" TIMESTAMP NOT NULL,
    "fk_employee_id" UUID,
    "status" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

CREATE TABLE "hr"."position" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "title" VARCHAR(50),
    "description" TEXT,
    "fk_department_id" UUID,
    "status" BOOLEAN,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

CREATE TABLE "hr"."schedule" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(255) NOT NULL,
    "description" TEXT,
    "tolerance" SMALLINT,
    "absent_tolerance" SMALLINT,
    "entity_level" VARCHAR(50) NOT NULL,
    "entity_id" UUID NOT NULL,
    "effective_date" DATE,
    "deactivation_date" DATE,
    "status" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

CREATE TABLE "hr"."schedule_category" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(255) NOT NULL,
    "color" VARCHAR(255) NOT NULL,
    "is_system" BOOLEAN NOT NULL DEFAULT false,
    "system_code" VARCHAR(50),
    "fk_company_id" UUID,
    "status" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

CREATE TABLE "hr"."slot" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "day_of_week" VARCHAR(20) NOT NULL,
    "work_mode" VARCHAR(50) NOT NULL,
    "start_time" TIME NOT NULL,
    "end_time" TIME NOT NULL,
    "fk_category_id" UUID NOT NULL,
    "fk_schedule_id" UUID NOT NULL,
    "status" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

CREATE TABLE "device" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(50),
    "description" TEXT,
    "ip_address" VARCHAR(15),
    "mac_address" VARCHAR(17),
    "status" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

CREATE TABLE "event" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "event_date" TIMESTAMP,
    "status" VARCHAR(100),
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "fk_device_id" UUID,
    "fk_event_type_id" UUID,
    "fk_employee_id" UUID,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

CREATE TABLE "event_type" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(50),
    "description" TEXT,
    "event_parent_id" UUID,
    "is_repetitive" BOOLEAN NOT NULL DEFAULT false,
    "limit" SMALLINT,
    "icon" VARCHAR(50),
    "color" VARCHAR(20),
    "fk_company_id" UUID,
    "status" BOOLEAN,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

-- NUEVAS IMPLEMENTACIONES
CREATE TABLE "hr"."daily_attendance_record" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "date" DATE NOT NULL,
    "schedule_snapshot_name" VARCHAR(255),
    "employee_id" UUID NOT NULL,
    "company_id" UUID NOT NULL,
    "department_id" UUID NOT NULL,
    "hours_worked" NUMERIC(5, 2) NOT NULL DEFAULT 0.0,
    "overtime_hours" NUMERIC(5, 2) NOT NULL DEFAULT 0.0,
    "status" VARCHAR(50) NOT NULL, -- Valores: PRESENT, ABSENT, LATE, DAY_OFF
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

CREATE TABLE "hr"."branch" (
    "id" UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(100) NOT NULL,
    "address_line_1" VARCHAR(255),
    "address_line_2" VARCHAR(255),
    "city" VARCHAR(100),
    "state_province" VARCHAR(100),
    "postal_code" VARCHAR(20),
    "country" VARCHAR(100) DEFAULT 'México',
    "location_latitude" DOUBLE PRECISION,
    "location_longitude" DOUBLE PRECISION,
    "fk_company_id" UUID NOT NULL,
    "fk_admin_user_id" UUID NOT NULL,
    "status" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP
);

ALTER TABLE "audit"."audit_trail" ADD CONSTRAINT "audit_trail_user_fk" FOREIGN KEY ("fk_user_id") REFERENCES "auth"."user" ("id") ON DELETE SET NULL DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "auth"."refresh_token" ADD CONSTRAINT "fk_refresh_token_user" FOREIGN KEY ("fk_user_id") REFERENCES "auth"."user" ("id") ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "auth"."oauth_account" ADD CONSTRAINT "oauth_account_user_fk" FOREIGN KEY ("fk_user_id") REFERENCES "auth"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "auth"."role_permission" ADD CONSTRAINT "role_permission_permission_fk" FOREIGN KEY ("fk_permission_id") REFERENCES "auth"."permission" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "auth"."role_permission" ADD CONSTRAINT "role_permission_role_fk" FOREIGN KEY ("fk_role_id") REFERENCES "auth"."role" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "auth"."user_company" ADD CONSTRAINT "user_company_company_fk" FOREIGN KEY ("fk_company_id") REFERENCES "hr"."company" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "auth"."user_company" ADD CONSTRAINT "user_company_user_fk" FOREIGN KEY ("fk_user_id") REFERENCES "auth"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "auth"."user_role" ADD CONSTRAINT "user_role_role_fk" FOREIGN KEY ("fk_role_id") REFERENCES "auth"."role" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "auth"."user_role" ADD CONSTRAINT "user_role_user_fk" FOREIGN KEY ("fk_user_id") REFERENCES "auth"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "hr"."company_work_days" ADD CONSTRAINT "company_work_days_company_fk" FOREIGN KEY ("company_id") REFERENCES "hr"."company" ("id") ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "hr"."department" ADD CONSTRAINT "department_company_fk" FOREIGN KEY ("fk_company_id") REFERENCES "hr"."company" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "hr"."department" ADD CONSTRAINT "fk_department_branch" FOREIGN KEY ("fk_branch_id") REFERENCES "hr"."branch"(id) DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "hr"."department" ADD CONSTRAINT "department_department_fk" FOREIGN KEY ("parent_department_id") REFERENCES "hr"."department" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "hr"."employee" ADD CONSTRAINT "employee_employee_fk" FOREIGN KEY ("manager_id") REFERENCES "hr"."employee" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "hr"."employee_health_insurance" ADD CONSTRAINT "employee_health_insurance_employee_fk" FOREIGN KEY ("fk_employee_id") REFERENCES "hr"."employee" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "hr"."employee_health_insurance" ADD CONSTRAINT "employee_health_insurance_health_insurance_fk" FOREIGN KEY ("fk_health_insurance_id") REFERENCES "hr"."health_insurance" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "hr"."employee" ADD CONSTRAINT "employee_position_fk" FOREIGN KEY ("fk_position_id") REFERENCES "hr"."position" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "hr"."employee" ADD CONSTRAINT "employee_user_fk" FOREIGN KEY ("fk_user_id") REFERENCES "auth"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "hr"."invitation_code" ADD CONSTRAINT "invitation_code_employee_fk" FOREIGN KEY ("fk_employee_id") REFERENCES "hr"."employee" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "hr"."position" ADD CONSTRAINT "position_department_fk" FOREIGN KEY ("fk_department_id") REFERENCES "hr"."department" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "hr"."schedule_category" ADD CONSTRAINT "schedule_category_company_fk" FOREIGN KEY ("fk_company_id") REFERENCES "hr"."company" ("id") ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "hr"."slot" ADD CONSTRAINT "slot_category_fk" FOREIGN KEY ("fk_category_id") REFERENCES "hr"."schedule_category" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "hr"."slot" ADD CONSTRAINT "slot_schedule_fk" FOREIGN KEY ("fk_schedule_id") REFERENCES "hr"."schedule" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "event" ADD CONSTRAINT "event_device_fk" FOREIGN KEY ("fk_device_id") REFERENCES "device" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "event" ADD CONSTRAINT "event_employee_fk" FOREIGN KEY ("fk_employee_id") REFERENCES "hr"."employee" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "event" ADD CONSTRAINT "event_event_type_fk" FOREIGN KEY ("fk_event_type_id") REFERENCES "event_type" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "event_type" ADD CONSTRAINT "event_type_company_fk" FOREIGN KEY ("fk_company_id") REFERENCES "hr"."company" ("id") ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "event_type" ADD CONSTRAINT "event_type_parent_fk" FOREIGN KEY ("event_parent_id") REFERENCES "event_type" ("id") ON DELETE SET NULL DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "hr"."branch" ADD CONSTRAINT "branch_company_fk" FOREIGN KEY ("fk_company_id") REFERENCES "hr"."company" ("id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "hr"."branch" ADD CONSTRAINT "branch_user_fk" FOREIGN KEY ("fk_admin_user_id") REFERENCES "auth"."user" ("id") DEFERRABLE INITIALLY IMMEDIATE;