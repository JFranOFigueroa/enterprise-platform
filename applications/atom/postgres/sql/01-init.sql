-- ==============================================================================
-- Script de Inicialización de Base de Datos PostgreSQL
-- Generado a partir de esquema DBML
-- ==============================================================================

-- 1. Creación de Esquemas
CREATE SCHEMA IF NOT EXISTS administration;
CREATE SCHEMA IF NOT EXISTS warehouse;

-- ==============================================================================
-- 2. Creación de Tablas: Esquema "administration"
-- ==============================================================================

CREATE TABLE administration.permissions (
    id_permission serial NOT NULL,
    name character varying(100) NOT NULL,
    description character varying(200) NOT NULL,
    fk_parent_id integer,
    type smallint NOT NULL,
    hierarchical_order smallint NOT NULL,
    CONSTRAINT pk_permissions PRIMARY KEY (id_permission)
);

CREATE TABLE administration.roles (
    id_role serial NOT NULL,
    name character varying(100) NOT NULL,
    description character varying(200) NOT NULL,
    CONSTRAINT pk_roles PRIMARY KEY (id_role)
);

CREATE TABLE administration.roles_permissions (
    fk_role_id integer NOT NULL,
    fk_permission_id integer NOT NULL,
    CONSTRAINT roles_permissions_pkey PRIMARY KEY (fk_role_id, fk_permission_id)
);

CREATE TABLE administration.suppliers (
    id_supplier serial NOT NULL,
    tax_id character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    commercial_name character varying(200) NOT NULL,
    CONSTRAINT pk_suppliers PRIMARY KEY (id_supplier)
);

CREATE TABLE administration.users (
    id_user serial NOT NULL,
    email text NOT NULL,
    password character varying(100) NOT NULL,
    name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    fk_role_id integer NOT NULL,
    available boolean NOT NULL DEFAULT true,
    status smallint,
    CONSTRAINT pk_users PRIMARY KEY (id_user)
);

-- ==============================================================================
-- 3. Creación de Tablas: Esquema "warehouse"
-- ==============================================================================

CREATE TABLE warehouse.input_orders (
    id_input_order serial NOT NULL,
    invoice character varying(100) NOT NULL,
    create_date timestamp NOT NULL,
    status smallint NOT NULL,
    available boolean NOT NULL DEFAULT true,
    observations text NOT NULL,
    fk_supplier_id integer NOT NULL,
    CONSTRAINT pk_input_orders PRIMARY KEY (id_input_order)
);

CREATE TABLE warehouse.movements (
    id_movement serial NOT NULL,
    movement_type smallint NOT NULL,
    movement_type_reference smallint NOT NULL,
    movement_date timestamp NOT NULL,
    movement_reference_id integer NOT NULL,
    unit_price double precision NOT NULL,
    batch character varying(50) NOT NULL,
    expiration date NOT NULL,
    quantity integer NOT NULL,
    available boolean NOT NULL DEFAULT true,
    fk_product_id integer NOT NULL,
    fk_user_id integer NOT NULL,
    CONSTRAINT pk_movements PRIMARY KEY (id_movement)
);

CREATE TABLE warehouse.output_orders (
    id_output_order serial NOT NULL,
    create_date timestamp NOT NULL,
    status smallint NOT NULL,
    available boolean NOT NULL DEFAULT true,
    observations text NOT NULL,
    CONSTRAINT pk_output_orders PRIMARY KEY (id_output_order)
);

CREATE TABLE warehouse.products (
    id_product serial NOT NULL,
    product_ean character varying(100) NOT NULL,
    name text NOT NULL,
    short_description character varying(1000) NOT NULL,
    long_description text NOT NULL,
    CONSTRAINT pk_products PRIMARY KEY (id_product)
);

-- ==============================================================================
-- 4. Definición de Llaves Foráneas (Relaciones)
-- ==============================================================================

ALTER TABLE administration.roles_permissions
ADD CONSTRAINT fk_roles_permissions_permission
FOREIGN KEY (fk_permission_id) REFERENCES administration.permissions (id_permission);

ALTER TABLE administration.roles_permissions
ADD CONSTRAINT fk_roles_permissions_role
FOREIGN KEY (fk_role_id) REFERENCES administration.roles (id_role);

ALTER TABLE administration.users
ADD CONSTRAINT fk_users_role
FOREIGN KEY (fk_role_id) REFERENCES administration.roles (id_role);

ALTER TABLE warehouse.input_orders
ADD CONSTRAINT fk_input_orders_supplier
FOREIGN KEY (fk_supplier_id) REFERENCES administration.suppliers (id_supplier);

ALTER TABLE warehouse.movements
ADD CONSTRAINT fk_movements_product
FOREIGN KEY (fk_product_id) REFERENCES warehouse.products (id_product) ON DELETE CASCADE;

ALTER TABLE warehouse.movements
ADD CONSTRAINT fk_movements_user
FOREIGN KEY (fk_user_id) REFERENCES administration.users (id_user);

-- ==============================================================================
-- 5. Datos Iniciales
-- ==============================================================================

INSERT INTO administration.roles (name, description) VALUES ('Administrador', 'Administrador');
INSERT INTO administration.roles (name, description) VALUES ('Encargado de Inventario', 'Encargado de Inventario');
INSERT INTO administration.roles (name, description) VALUES ('Vendedor', 'Vendedor');

INSERT INTO administration.permissions (name, description, fk_parent_id, type, hierarchical_order) VALUES ('Acceso General', 'Acceso General', null, 1, 1);

INSERT INTO administration.roles_permissions (fk_role_id, fk_permission_id) VALUES (1, 1);
INSERT INTO administration.roles_permissions (fk_role_id, fk_permission_id) VALUES (2, 1);

INSERT INTO administration.suppliers (tax_id, name, commercial_name) VALUES ('SICC0000000000', 'SICC', 'SICC');

INSERT INTO administration.users (email, password, name, last_name, fk_role_id, available, status) VALUES ('administracion@sicc.com', 'bop15J/V15Iawsevynx/LA==:MbN6M9yYS10FdV6uVoX+h+dWaDrNIyqyocNjAb8bmwY=', 'Administración', 'SICC', 1, true, 1);
