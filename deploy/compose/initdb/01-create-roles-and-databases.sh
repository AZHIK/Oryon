#!/bin/sh
# Create one owner role, one runtime role, and one database per service.
#
# Runs only on first initialisation of an empty PostgreSQL data directory.
# Passwords are read from Docker secrets, never from environment variables.
set -eu

read_secret() {
    secret_path="/run/secrets/$1"
    if [ ! -s "$secret_path" ]; then
        echo "Missing or empty secret: $secret_path" >&2
        exit 1
    fi
    cat "$secret_path"
}

psql_admin() {
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres "$@"
}

create_role() {
    role="$1"
    password="$2"
    psql_admin -v role="$role" -v password="$password" <<'SQL'
CREATE ROLE :"role"
    LOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    INHERIT
    PASSWORD :'password';
SQL
}

create_database() {
    database="$1"
    owner="$2"
    app="$3"

    psql_admin -v database="$database" -v owner="$owner" <<'SQL'
CREATE DATABASE :"database" OWNER :"owner" ENCODING 'UTF8';
SQL

    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$database" \
        -v database="$database" -v owner="$owner" -v app="$app" <<'SQL'
REVOKE ALL ON DATABASE :"database" FROM PUBLIC;
GRANT CONNECT ON DATABASE :"database" TO :"app";

REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO :"app";

-- Every table/sequence the owner creates later is usable by the runtime role.
ALTER DEFAULT PRIVILEGES FOR ROLE :"owner" IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :"app";
ALTER DEFAULT PRIVILEGES FOR ROLE :"owner" IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO :"app";
SQL
}

create_role identity_owner "$(read_secret identity_owner_db_password)"
create_role identity_app "$(read_secret identity_app_db_password)"
create_role inventory_owner "$(read_secret inventory_owner_db_password)"
create_role inventory_app "$(read_secret inventory_app_db_password)"
create_role pos_owner "$(read_secret pos_owner_db_password)"
create_role pos_app "$(read_secret pos_app_db_password)"

create_database oryonfoods_auth identity_owner identity_app
create_database oryonfoods_inventory inventory_owner inventory_app
create_database oryonfoods_pos pos_owner pos_app

echo "Oryon Foods databases, owner roles, and runtime roles created."
