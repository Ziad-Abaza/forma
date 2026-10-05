DROP POLICY IF EXISTS audit_logs_isolation ON audit_logs;
DROP POLICY IF EXISTS audit_logs_read_isolation ON audit_logs;
DROP POLICY IF EXISTS audit_logs_insert_policy ON audit_logs;

-- Read policy: Strictly user-isolated or system
CREATE POLICY audit_logs_read_isolation ON audit_logs
FOR SELECT USING (
    user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
);

-- Insert policy: Append-only audit record creation permitted for authenticated application
CREATE POLICY audit_logs_insert_policy ON audit_logs
FOR INSERT WITH CHECK (true);
