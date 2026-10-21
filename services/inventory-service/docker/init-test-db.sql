-- Create the dedicated test database on fresh Postgres initialization.
-- The test suite runs real Alembic migrations against this database so it
-- is fully separate from the dev database (oryonfoods_inventory).
CREATE DATABASE oryonfoods_inventory_test;
