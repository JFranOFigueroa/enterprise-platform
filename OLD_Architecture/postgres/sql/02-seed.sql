-- Enterprise Platform - Legacy Seed Data (Reference)
INSERT INTO hr.companies (id, name, rfc)
VALUES ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Demo Company', 'XAXX010101000')
ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.users (id, username, email, password_hash)
VALUES ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'admin', 'admin@demo.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy')
ON CONFLICT (username) DO NOTHING;
