-- ---------------------------------------------------------------------------
-- Row-Level Security policies for tenant isolation.
--
-- Every tenant-scoped table carries a `tenant_id` column. The app sets
-- SESSION_CONTEXT('tenant_id') on every connection via a middleware that
-- reads the authenticated user's tenant claim from Entra ID. RLS then
-- filters rows automatically — a compromised tenant can only ever see
-- its own data, even if a query omits a WHERE clause.
-- ---------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS rls;
GO

-- Predicate: accept rows whose tenant_id matches the session context.
CREATE OR ALTER FUNCTION rls.fn_tenant_isolation(@tenant_id UNIQUEIDENTIFIER)
    RETURNS TABLE
    WITH SCHEMABINDING
AS
    RETURN SELECT 1 AS fn_result
    WHERE
        CAST(SESSION_CONTEXT(N'tenant_id') AS UNIQUEIDENTIFIER) = @tenant_id
        OR CAST(SESSION_CONTEXT(N'is_superadmin') AS BIT) = 1;
GO

-- Apply the predicate as a SECURITY POLICY to every tenant-scoped table.
CREATE OR ALTER SECURITY POLICY rls.tenant_isolation_policy
    ADD FILTER PREDICATE rls.fn_tenant_isolation(tenant_id) ON dbo.sessions,
    ADD FILTER PREDICATE rls.fn_tenant_isolation(tenant_id) ON dbo.athletes,
    ADD FILTER PREDICATE rls.fn_tenant_isolation(tenant_id) ON dbo.teams,
    ADD FILTER PREDICATE rls.fn_tenant_isolation(tenant_id) ON dbo.practices,
    ADD FILTER PREDICATE rls.fn_tenant_isolation(tenant_id) ON dbo.videos,
    ADD BLOCK PREDICATE  rls.fn_tenant_isolation(tenant_id) ON dbo.sessions   AFTER INSERT,
    ADD BLOCK PREDICATE  rls.fn_tenant_isolation(tenant_id) ON dbo.athletes   AFTER INSERT,
    ADD BLOCK PREDICATE  rls.fn_tenant_isolation(tenant_id) ON dbo.teams      AFTER INSERT,
    ADD BLOCK PREDICATE  rls.fn_tenant_isolation(tenant_id) ON dbo.practices  AFTER INSERT,
    ADD BLOCK PREDICATE  rls.fn_tenant_isolation(tenant_id) ON dbo.videos     AFTER INSERT
    WITH (STATE = ON, SCHEMABINDING = ON);
GO
