-- liquibase formatted sql

-- changeset jurgen-garrido:v0002-2026-05-15-db-seed-init

-- rollback DELETE FROM device WHERE name IN ('Aplicación Web', 'Aplicación Móvil');
-- rollback DELETE FROM auth.role_permission;
-- rollback DELETE FROM auth.permission WHERE name IN ('COMPANY_CREATE', 'COMPANY_READ', 'COMPANY_UPDATE', 'EMPLOYEE_WRITE', 'EVENT_READ', 'EVENT_WRITE');
-- rollback DELETE FROM auth.role WHERE name IN ('ADMIN', 'EMPLOYEE', 'HARDWARE_TERMINAL');

-- 1. Insertar Roles Base
INSERT INTO auth.role (id, name, description, status)
VALUES
    (public.uuid_v7(), 'ADMIN', 'Administrador principal de la empresa. Acceso total.', true),
    (public.uuid_v7(), 'EMPLOYEE', 'Empleado regular. Acceso a checador web y dashboard personal.', true),
    (public.uuid_v7(), 'HARDWARE_TERMINAL', 'Rol técnico exclusivo para los checadores físicos (Raspberry Pi).', true);

-- 2. Insertar Permisos Iniciales (Opcional para el registro, pero vital para el futuro)
INSERT INTO auth.permission (id, name, description, status)
VALUES
    (public.uuid_v7(), 'COMPANY_CREATE', 'Permite registrar una nueva empresa', true),
    (public.uuid_v7(), 'COMPANY_READ', 'Permite ver los datos de la empresa', true),
    (public.uuid_v7(), 'COMPANY_UPDATE', 'Permite editar los datos de la empresa', true),
    (public.uuid_v7(), 'EMPLOYEE_WRITE', 'Permite registrar, editar o dar de baja empleados', true),
    (public.uuid_v7(), 'EVENT_READ', 'Permite ver el historial de checadas', true),
    (public.uuid_v7(), 'EVENT_WRITE', 'Permite registrar una nueva checada', true);

-- 3. Vincular los permisos al rol ADMIN
-- Este bloque asigna todos los permisos recién creados al rol 'ADMIN'
INSERT INTO auth.role_permission (fk_role_id, fk_permission_id, status)
SELECT r.id, p.id, true
FROM auth.role r
         CROSS JOIN auth.permission p
WHERE r.name = 'ADMIN';

-- 4. Vincular permisos básicos al rol EMPLOYEE
INSERT INTO auth.role_permission (fk_role_id, fk_permission_id, status)
SELECT r.id, p.id, true
FROM auth.role r
         JOIN auth.permission p ON p.name IN ('COMPANY_READ', 'EVENT_READ', 'EVENT_WRITE')
WHERE r.name = 'EMPLOYEE';

-- 5. Insertar dispositivo (Aplicación Web)
INSERT INTO device (id, name, description, ip_address, mac_address) VALUES
(public.uuid_v7(), 'Aplicación Web', 'Aplicación Web', NULL, NULL),
(public.uuid_v7(),'Aplicación Móvil', 'Aplicación Móvil', NULL, NULL);

