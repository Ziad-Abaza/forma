# Operational Runbook: Backup & Disaster Recovery

**Version:** 1.0.0  
**Target Platform:** PostgreSQL 16+ on Docker / Managed Cloud Database  
**Compliance Reference:** Forma Product Architecture Blueprint §22, §31, §32

---

## 1. Backup Strategy Overview

Forma maintains a 3-tier backup strategy to ensure zero data loss (RPO < 5 minutes) and rapid recovery (RTO < 1 hour):

1. **Continuous Write-Ahead Log (WAL) Archiving:** Streaming physical replication and WAL archiving to encrypted offsite object storage (S3 / GCS).
2. **Daily Logical Database Dumps:** Scheduled `pg_dump` with schema, data, and RLS policies preserved.
3. **Monthly Disaster Recovery Verification Drill:** Automated spin-up of staging replica to verify dump integrity and policy persistence.

---

## 2. Logical Backup Procedure (`pg_dump`)

### Manual Backup
Execute a full, consistent logical backup including Row-Level Security policies and system roles:

```bash
# Set timestamp variable
BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Execute pg_dump from container or host
docker exec -t forma-postgres-prod pg_dump \
  -U postgres \
  --format=custom \
  --compress=9 \
  --create \
  --clean \
  --if-exists \
  forma_prod > "/var/backups/forma/forma_prod_${BACKUP_TIMESTAMP}.dump"
```

### Automated Nightly Cron
Configured on host backup agent:

```cron
0 2 * * * /usr/local/bin/forma-backup.sh >> /var/log/forma-backup.log 2>&1
```

---

## 3. Full Database Restore Procedure

### Step 1: Pre-Restore Safety Check
1. Ensure traffic is stopped or backend is placed in maintenance mode to avoid split-brain writes:
   ```bash
   docker compose -f docker-compose.prod.yml stop backend
   ```
2. Verify target PostgreSQL server is accessible and running.

### Step 2: Restore from Custom Dump
Execute `pg_restore` using superuser privileges to ensure RLS policies and application role grants are re-applied:

```bash
docker exec -i forma-postgres-prod pg_restore \
  -U postgres \
  --clean \
  --if-exists \
  --exit-on-error \
  --dbname=forma_prod < "/var/backups/forma/forma_prod_TARGET_TIMESTAMP.dump"
```

### Step 3: Run Database Migrations to Ensure Schema Parity
```bash
docker compose -f docker-compose.prod.yml run --rm backend npm run migrate
```

---

## 4. Post-Restore Verification Checklist

After restoring, verify the following critical health gates before re-enabling public traffic:

1. **Verify Database Readiness Endpoint:**
   ```bash
   curl http://localhost:3000/health/ready
   # Expected: {"status":"ready","database":"connected",...}
   ```

2. **Verify Row-Level Security (RLS) on all 24 Tables:**
   Execute query to ensure zero tables have lost RLS enforcement:
   ```sql
   SELECT relname, relrowsecurity, relforcerowsecurity 
   FROM pg_class 
   WHERE relnamespace = 'public'::regnamespace 
     AND relkind = 'r' 
     AND (relrowsecurity = false OR relforcerowsecurity = false);
   -- Expected: 0 rows returned
   ```

3. **Verify App Role Grants:**
   Verify `forma_app` has appropriate limited permissions without table owner privileges:
   ```sql
   SELECT grantee, table_name, privilege_type 
   FROM information_schema.role_table_grants 
   WHERE grantee = 'forma_app';
   ```

4. **Verify Append-Only Immutability:**
   Verify `observations` and `provenance_records` table integrity and sequence alignment.

5. **Restart Backend Service:**
   ```bash
   docker compose -f docker-compose.prod.yml start backend
   ```
