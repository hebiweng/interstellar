-- Prevent untrusted roles from creating objects in the default public schema.
-- M1 migrations will create owned application schemas and grant explicit roles.

REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO PUBLIC;
