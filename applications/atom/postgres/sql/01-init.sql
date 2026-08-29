--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: administration; Type: SCHEMA; Schema: -; Owner: -
--
CREATE SCHEMA administration;

--
-- Name: warehouse; Type: SCHEMA; Schema: -; Owner: -
--
CREATE SCHEMA warehouse;

SET default_tablespace = '';
SET default_table_access_method = heap;

--
-- Name: clients; Type: TABLE; Schema: administration; Owner: -
--
CREATE TABLE administration.clients (
    id_client serial NOT NULL,
    tax_id character varying(20) NOT NULL,
    name character varying(150) NOT NULL,
    phone character varying(20),
    email character varying(150),
    latitude double precision,
    longitude double precision,
    reverse_location text,
    available boolean DEFAULT true NOT NULL,
    status smallint DEFAULT 1
);

--
-- Name: permissions; Type: TABLE; Schema: administration; Owner: -
--
CREATE TABLE administration.permissions (
    id_permission serial NOT NULL,
    name character varying(100) NOT NULL,
    description character varying(200) NOT NULL,
    fk_parent_id integer,
    type smallint NOT NULL,
    hierarchical_order smallint NOT NULL
);

--
-- Name: roles; Type: TABLE; Schema: administration; Owner: -
--
CREATE TABLE administration.roles (
    id_role serial NOT NULL,
    name character varying(100) NOT NULL,
    description character varying(200) NOT NULL
);

--
-- Name: roles_permissions; Type: TABLE; Schema: administration; Owner: -
--
CREATE TABLE administration.roles_permissions (
    fk_role_id integer NOT NULL,
    fk_permission_id integer NOT NULL
);

--
-- Name: suppliers; Type: TABLE; Schema: administration; Owner: -
--
CREATE TABLE administration.suppliers (
    id_supplier serial NOT NULL,
    tax_id character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    commercial_name character varying(200) NOT NULL,
    phone character varying(20),
    email character varying(150),
    latitude double precision,
    longitude double precision,
    reverse_location text,
    available boolean DEFAULT true NOT NULL,
    status smallint DEFAULT 1
);

--
-- Name: user_warehouses; Type: TABLE; Schema: administration; Owner: -
--
CREATE TABLE administration.user_warehouses (
    fk_user_id integer NOT NULL,
    fk_warehouse_id integer NOT NULL
);

--
-- Name: users; Type: TABLE; Schema: administration; Owner: -
--
CREATE TABLE administration.users (
    id_user serial NOT NULL,
    email text NOT NULL,
    password character varying(100) NOT NULL,
    name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    fk_role_id integer NOT NULL,
    available boolean DEFAULT true NOT NULL,
    status smallint
);

--
-- Name: warehouses; Type: TABLE; Schema: administration; Owner: -
--
CREATE TABLE administration.warehouses (
    id_warehouse serial NOT NULL,
    name character varying(150) NOT NULL,
    latitude double precision,
    longitude double precision,
    reverse_location text,
    available boolean DEFAULT true NOT NULL,
    status smallint DEFAULT 1
);

--
-- Name: system_config; Type: TABLE; Schema: public; Owner: -
--
CREATE TABLE public.system_config (
    id serial NOT NULL,
    config_key character varying(100) NOT NULL,
    config_value text NOT NULL,
    description text
);

--
-- Name: system_notifications; Type: TABLE; Schema: public; Owner: -
--
CREATE TABLE public.system_notifications (
    id serial NOT NULL,
    fk_user_id integer NOT NULL,
    title character varying(150) NOT NULL,
    message text NOT NULL,
    notification_type character varying(50) NOT NULL,
    reference_id integer,
    metadata text,
    is_read boolean DEFAULT false,
    create_date timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

--
-- Name: system_reports; Type: TABLE; Schema: public; Owner: -
--
CREATE TABLE public.system_reports (
    id serial NOT NULL,
    report_type character varying(50) NOT NULL,
    status character varying(20) NOT NULL,
    file_name character varying(255),
    file_data bytea,
    error_message text,
    fk_requested_by_id integer NOT NULL,
    create_date timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    completed_date timestamp with time zone
);

--
-- Name: input_orders; Type: TABLE; Schema: warehouse; Owner: -
--
CREATE TABLE warehouse.input_orders (
    id_input_order serial NOT NULL,
    invoice character varying(100),
    create_date timestamp without time zone NOT NULL,
    status smallint NOT NULL,
    available boolean DEFAULT true NOT NULL,
    observations text NOT NULL,
    fk_origin_supplier_id integer,
    input_type smallint DEFAULT 1 NOT NULL,
    fk_destination_warehouse_id integer NOT NULL,
    fk_origin_warehouse_id integer,
    fk_origin_client_id integer,
    origin_other character varying(255),
    fk_output_order_id integer,
    return_reason character varying(100)
);

--
-- Name: movements; Type: TABLE; Schema: warehouse; Owner: -
--
CREATE TABLE warehouse.movements (
    id_movement serial NOT NULL,
    movement_type smallint NOT NULL,
    movement_type_reference smallint NOT NULL,
    movement_date timestamp without time zone NOT NULL,
    movement_reference_id integer NOT NULL,
    unit_price double precision,
    purchase_cost double precision,
    batch character varying(50) NOT NULL,
    expiration date,
    quantity integer NOT NULL,
    available boolean DEFAULT true NOT NULL,
    fk_product_id integer NOT NULL,
    fk_user_id integer NOT NULL,
    fk_warehouse_id integer NOT NULL
);

--
-- Name: output_orders; Type: TABLE; Schema: warehouse; Owner: -
--
CREATE TABLE warehouse.output_orders (
    id_output_order serial NOT NULL,
    create_date timestamp without time zone NOT NULL,
    status smallint NOT NULL,
    available boolean DEFAULT true NOT NULL,
    observations text NOT NULL,
    output_type smallint DEFAULT 1 NOT NULL,
    fk_origin_warehouse_id integer,
    fk_destination_warehouse_id integer,
    fk_destination_client_id integer,
    fk_destination_supplier_id integer,
    destination_other character varying(255),
    fk_input_order_id integer,
    scrap_reason character varying(100)
);

--
-- Name: products; Type: TABLE; Schema: warehouse; Owner: -
--
CREATE TABLE warehouse.products (
    id_product serial NOT NULL,
    product_ean character varying(100) NOT NULL,
    name text NOT NULL,
    short_description character varying(1000) NOT NULL,
    long_description text NOT NULL,
    product_type character varying(50),
    serial_number character varying(100),
    brand character varying(100),
    model character varying(100),
    color character varying(50),
    sku character varying(100),
    internal_sku character varying(100)
);

--
-- Name: transfer_orders; Type: TABLE; Schema: warehouse; Owner: -
--
CREATE TABLE warehouse.transfer_orders (
    id_transfer_order serial NOT NULL,
    fk_origin_warehouse_id integer NOT NULL,
    fk_destination_warehouse_id integer NOT NULL,
    status smallint NOT NULL,
    create_date timestamp without time zone NOT NULL,
    receive_date timestamp without time zone,
    observations text NOT NULL,
    fk_user_id integer NOT NULL,
    available boolean DEFAULT true NOT NULL
);

--
-- Name: clients pk_clients; Type: CONSTRAINT; Schema: administration; Owner: -
--
ALTER TABLE ONLY administration.clients
    ADD CONSTRAINT pk_clients PRIMARY KEY (id_client);

--
-- Name: permissions pk_permissions; Type: CONSTRAINT; Schema: administration; Owner: -
--
ALTER TABLE ONLY administration.permissions
    ADD CONSTRAINT pk_permissions PRIMARY KEY (id_permission);

--
-- Name: roles pk_roles; Type: CONSTRAINT; Schema: administration; Owner: -
--
ALTER TABLE ONLY administration.roles
    ADD CONSTRAINT pk_roles PRIMARY KEY (id_role);

--
-- Name: suppliers pk_suppliers; Type: CONSTRAINT; Schema: administration; Owner: -
--
ALTER TABLE ONLY administration.suppliers
    ADD CONSTRAINT pk_suppliers PRIMARY KEY (id_supplier);

--
-- Name: users pk_users; Type: CONSTRAINT; Schema: administration; Owner: -
--
ALTER TABLE ONLY administration.users
    ADD CONSTRAINT pk_users PRIMARY KEY (id_user);

--
-- Name: warehouses pk_warehouses; Type: CONSTRAINT; Schema: administration; Owner: -
--
ALTER TABLE ONLY administration.warehouses
    ADD CONSTRAINT pk_warehouses PRIMARY KEY (id_warehouse);

--
-- Name: roles_permissions roles_permissions_pkey; Type: CONSTRAINT; Schema: administration; Owner: -
--
ALTER TABLE ONLY administration.roles_permissions
    ADD CONSTRAINT roles_permissions_pkey PRIMARY KEY (fk_role_id, fk_permission_id);

--
-- Name: user_warehouses user_warehouses_pkey; Type: CONSTRAINT; Schema: administration; Owner: -
--
ALTER TABLE ONLY administration.user_warehouses
    ADD CONSTRAINT user_warehouses_pkey PRIMARY KEY (fk_user_id, fk_warehouse_id);

--
-- Name: system_config system_config_config_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--
ALTER TABLE ONLY public.system_config
    ADD CONSTRAINT system_config_config_key_key UNIQUE (config_key);

--
-- Name: system_config system_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--
ALTER TABLE ONLY public.system_config
    ADD CONSTRAINT system_config_pkey PRIMARY KEY (id);

--
-- Name: system_notifications system_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--
ALTER TABLE ONLY public.system_notifications
    ADD CONSTRAINT system_notifications_pkey PRIMARY KEY (id);

--
-- Name: system_reports system_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--
ALTER TABLE ONLY public.system_reports
    ADD CONSTRAINT system_reports_pkey PRIMARY KEY (id);

--
-- Name: input_orders pk_input_orders; Type: CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.input_orders
    ADD CONSTRAINT pk_input_orders PRIMARY KEY (id_input_order);

--
-- Name: movements pk_movements; Type: CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.movements
    ADD CONSTRAINT pk_movements PRIMARY KEY (id_movement);

--
-- Name: output_orders pk_output_orders; Type: CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.output_orders
    ADD CONSTRAINT pk_output_orders PRIMARY KEY (id_output_order);

--
-- Name: products pk_products; Type: CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.products
    ADD CONSTRAINT pk_products PRIMARY KEY (id_product);

--
-- Name: transfer_orders transfer_orders_pkey; Type: CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.transfer_orders
    ADD CONSTRAINT transfer_orders_pkey PRIMARY KEY (id_transfer_order);

--
-- Name: roles_permissions fk_roles_permissions_permission; Type: FK CONSTRAINT; Schema: administration; Owner: -
--
ALTER TABLE ONLY administration.roles_permissions
    ADD CONSTRAINT fk_roles_permissions_permission FOREIGN KEY (fk_permission_id) REFERENCES administration.permissions(id_permission);

--
-- Name: roles_permissions fk_roles_permissions_role; Type: FK CONSTRAINT; Schema: administration; Owner: -
--
ALTER TABLE ONLY administration.roles_permissions
    ADD CONSTRAINT fk_roles_permissions_role FOREIGN KEY (fk_role_id) REFERENCES administration.roles(id_role);

--
-- Name: users fk_users_role; Type: FK CONSTRAINT; Schema: administration; Owner: -
--
ALTER TABLE ONLY administration.users
    ADD CONSTRAINT fk_users_role FOREIGN KEY (fk_role_id) REFERENCES administration.roles(id_role);

--
-- Name: user_warehouses fk_uw_user; Type: FK CONSTRAINT; Schema: administration; Owner: -
--
ALTER TABLE ONLY administration.user_warehouses
    ADD CONSTRAINT fk_uw_user FOREIGN KEY (fk_user_id) REFERENCES administration.users(id_user) ON DELETE CASCADE;

--
-- Name: user_warehouses fk_uw_warehouse; Type: FK CONSTRAINT; Schema: administration; Owner: -
--
ALTER TABLE ONLY administration.user_warehouses
    ADD CONSTRAINT fk_uw_warehouse FOREIGN KEY (fk_warehouse_id) REFERENCES administration.warehouses(id_warehouse) ON DELETE CASCADE;

--
-- Name: system_notifications fk_system_notifications_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--
ALTER TABLE ONLY public.system_notifications
    ADD CONSTRAINT fk_system_notifications_user FOREIGN KEY (fk_user_id) REFERENCES administration.users(id_user);

--
-- Name: system_reports fk_system_reports_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--
ALTER TABLE ONLY public.system_reports
    ADD CONSTRAINT fk_system_reports_user FOREIGN KEY (fk_requested_by_id) REFERENCES administration.users(id_user);

--
-- Name: input_orders fk_input_order_output_order; Type: FK CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.input_orders
    ADD CONSTRAINT fk_input_order_output_order FOREIGN KEY (fk_output_order_id) REFERENCES warehouse.output_orders(id_output_order);

--
-- Name: input_orders fk_input_orders_destination_warehouse; Type: FK CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.input_orders
    ADD CONSTRAINT fk_input_orders_destination_warehouse FOREIGN KEY (fk_destination_warehouse_id) REFERENCES administration.warehouses(id_warehouse);

--
-- Name: input_orders fk_input_orders_origin_client; Type: FK CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.input_orders
    ADD CONSTRAINT fk_input_orders_origin_client FOREIGN KEY (fk_origin_client_id) REFERENCES administration.clients(id_client);

--
-- Name: input_orders fk_input_orders_origin_supplier; Type: FK CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.input_orders
    ADD CONSTRAINT fk_input_orders_origin_supplier FOREIGN KEY (fk_origin_supplier_id) REFERENCES administration.suppliers(id_supplier);

--
-- Name: input_orders fk_input_orders_origin_warehouse; Type: FK CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.input_orders
    ADD CONSTRAINT fk_input_orders_origin_warehouse FOREIGN KEY (fk_origin_warehouse_id) REFERENCES administration.warehouses(id_warehouse);

--
-- Name: movements fk_movement_warehouse; Type: FK CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.movements
    ADD CONSTRAINT fk_movement_warehouse FOREIGN KEY (fk_warehouse_id) REFERENCES administration.warehouses(id_warehouse);

--
-- Name: movements fk_movements_product; Type: FK CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.movements
    ADD CONSTRAINT fk_movements_product FOREIGN KEY (fk_product_id) REFERENCES warehouse.products(id_product) ON DELETE CASCADE;

--
-- Name: movements fk_movements_user; Type: FK CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.movements
    ADD CONSTRAINT fk_movements_user FOREIGN KEY (fk_user_id) REFERENCES administration.users(id_user);

--
-- Name: output_orders fk_output_order_input_order; Type: FK CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.output_orders
    ADD CONSTRAINT fk_output_order_input_order FOREIGN KEY (fk_input_order_id) REFERENCES warehouse.input_orders(id_input_order);

--
-- Name: output_orders fk_output_orders_destination_client; Type: FK CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.output_orders
    ADD CONSTRAINT fk_output_orders_destination_client FOREIGN KEY (fk_destination_client_id) REFERENCES administration.clients(id_client);

--
-- Name: output_orders fk_output_orders_destination_supplier; Type: FK CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.output_orders
    ADD CONSTRAINT fk_output_orders_destination_supplier FOREIGN KEY (fk_destination_supplier_id) REFERENCES administration.suppliers(id_supplier);

--
-- Name: output_orders fk_output_orders_destination_warehouse; Type: FK CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.output_orders
    ADD CONSTRAINT fk_output_orders_destination_warehouse FOREIGN KEY (fk_destination_warehouse_id) REFERENCES administration.warehouses(id_warehouse);

--
-- Name: output_orders fk_output_orders_origin_warehouse; Type: FK CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.output_orders
    ADD CONSTRAINT fk_output_orders_origin_warehouse FOREIGN KEY (fk_origin_warehouse_id) REFERENCES administration.warehouses(id_warehouse);

--
-- Name: transfer_orders transfer_orders_fk_destination_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.transfer_orders
    ADD CONSTRAINT transfer_orders_fk_destination_warehouse_id_fkey FOREIGN KEY (fk_destination_warehouse_id) REFERENCES administration.warehouses(id_warehouse);

--
-- Name: transfer_orders transfer_orders_fk_origin_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.transfer_orders
    ADD CONSTRAINT transfer_orders_fk_origin_warehouse_id_fkey FOREIGN KEY (fk_origin_warehouse_id) REFERENCES administration.warehouses(id_warehouse);

--
-- Name: transfer_orders transfer_orders_fk_user_id_fkey; Type: FK CONSTRAINT; Schema: warehouse; Owner: -
--
ALTER TABLE ONLY warehouse.transfer_orders
    ADD CONSTRAINT transfer_orders_fk_user_id_fkey FOREIGN KEY (fk_user_id) REFERENCES administration.users(id_user);

--
-- Initial Data Inserts
--

-- 1. Asegurar la existencia de los roles básicos (id = 1 Administrador, 2 Encargado, 3 Vendedor)
INSERT INTO administration.roles (id_role, name, description)
VALUES
    (1, 'Administrador', 'Acceso total al sistema'),
    (2, 'Encargado de Inventario', 'Gestión de stock y catálogos'),
    (3, 'Vendedor', 'Acceso a módulo de ventas (POS) y catálogos lectura')
ON CONFLICT (id_role) DO NOTHING;

-- 2. Insertar Permisos Granulares
INSERT INTO administration.permissions (id_permission, name, description, type, hierarchical_order)
VALUES
    (1, 'VIEW_DASHBOARD_FINANCE', 'Ver métricas financieras en el Dashboard', 1, 1),
    (2, 'VIEW_DASHBOARD_STOCK', 'Ver métricas de inventario en el Dashboard', 1, 2),
    (3, 'ACCESS_POS', 'Acceso al Punto de Venta (POS)', 1, 3),
    (4, 'ACCESS_MOVEMENTS', 'Acceder al Kárdex y Movimientos', 1, 4),
    (5, 'ACCESS_SETTINGS', 'Acceso a la Configuración General', 1, 5),
    (6, 'READ_CATALOGS', 'Ver listado de productos, clientes, almacenes', 1, 6),
    (7, 'MANAGE_CATALOGS', 'Crear, editar, eliminar y cambiar estatus en catálogos', 1, 7),
    (8, 'MANAGE_USERS', 'Crear, editar y dar de baja usuarios', 1, 8)
ON CONFLICT (id_permission) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- 3. Asignar Permisos a Roles (Roles_Permissions)
-- Administrador (id_role = 1): Tiene TODO
INSERT INTO administration.roles_permissions (fk_role_id, fk_permission_id) VALUES
                                                                                (1, 1), (1, 2), (1, 3), (1, 4), (1, 5), (1, 6), (1, 7), (1, 8)
ON CONFLICT DO NOTHING;

-- Encargado de Inventario (id_role = 2): Stock, Movimientos, Catálogos (Lectura y Escritura)
INSERT INTO administration.roles_permissions (fk_role_id, fk_permission_id) VALUES
                                                                                (2, 2), (2, 4), (2, 6), (2, 7)
ON CONFLICT DO NOTHING;

-- Vendedor (id_role = 3): POS, Catálogos (Solo Lectura)
INSERT INTO administration.roles_permissions (fk_role_id, fk_permission_id) VALUES
                                                                                (3, 3), (3, 6)
ON CONFLICT DO NOTHING;

-- Inserción de configuraciones iniciales
INSERT INTO public.system_config (id, config_key, config_value, description) VALUES (1, 'INVENTORY_DISPATCH_STRATEGY', 'FIFO', 'Define el algoritmo de salida de inventario: FIFO o LIFO');
INSERT INTO public.system_config (id, config_key, config_value, description) VALUES (2, 'COMPANY_NAME', 'SICC S.A de C.V', 'Define el nombre de la empresa a aparecer en lso reportes generados');
INSERT INTO public.system_config (id, config_key, config_value, description) VALUES (3, 'SYSTEM_NAME', 'SICC POS', 'Define el nombre de la aplicacion en las vistas del sistema');
INSERT INTO public.system_config (id, config_key, config_value, description) VALUES (4, 'COMPANY_LOGO', 'data:image/png;base64,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', 'Define la imagen del logo en las vista del sistema');
INSERT INTO public.system_config (id, config_key, config_value, description) VALUES (5, 'VISUAL_THEME', '#348AA2', 'Define el color o tema visual de la aplicacion en las vistas del sistema');

-- Creación de usuario inicial
INSERT INTO administration.users (email, password, name, last_name, fk_role_id, available, status) VALUES ('administracion@sicc.com', 'bop15J/V15Iawsevynx/LA==:MbN6M9yYS10FdV6uVoX+h+dWaDrNIyqyocNjAb8bmwY=', 'Administración', 'SICC', 1, true, 1);