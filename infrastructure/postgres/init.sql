-- =============================================================================
-- KORA — university-social-platform
-- init.sql  |  Scripts iniciales de DB
-- =============================================================================

-- Extensiones útiles
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";      -- búsqueda por similitud de texto

-- =============================================================================
-- Tabla de auditoría global (creada aquí para garantizar existencia antes
-- de que Django haga migrate; Django la adoptará con inspectdb si hace falta)
-- =============================================================================
CREATE TABLE IF NOT EXISTS audit_logs (
    id           BIGSERIAL    PRIMARY KEY,
    timestamp    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    user_id      BIGINT,
    action       VARCHAR(80)  NOT NULL,
    context_json JSONB        NOT NULL DEFAULT '{}',
    ip_address   INET
);

CREATE INDEX IF NOT EXISTS idx_audit_action_ts  ON audit_logs (action, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_user_ts    ON audit_logs (user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_context    ON audit_logs USING GIN (context_json);

-- =============================================================================
-- Índices adicionales de rendimiento (las tablas las crea Django migrate)
-- Se aplican después del primer migrate via script externo si se prefiere,
-- pero aquí se dejan como referencia.
-- =============================================================================

-- Texto libre con pg_trgm para búsquedas de usuarios
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_nombre_trgm
--     ON users USING GIN (nombre gin_trgm_ops);
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_carrera_trgm
--     ON users USING GIN (carrera gin_trgm_ops);

COMMENT ON TABLE audit_logs IS
    'Tabla de auditoría inmutable 360° — Capa de Observabilidad Global';
