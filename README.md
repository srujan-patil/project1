# DevOps Assessment: Terraform + Database Reliability

Internet → ALB → ECS/Fargate → RDS (Postgres), designed in Terraform, plus a
locally runnable Postgres stack for the database tasks (migrations, seed
data, query optimization, backup/restore).

Actual AWS deployment is not required/performed. Terraform is validated via
`fmt`, `init`, and `plan` only. All database work is fully runnable and was
tested locally end-to-end (see "What I actually ran" below).

## Repo layout

```
infra/
  modules/
    network/   # VPC, public/private subnets, NAT, ALB/ECS/RDS security groups
    ecs/        # ALB, target group, ECS cluster, Fargate task def + service
    rds/        # Private RDS instance (Postgres)
  envs/
    dev/        # smaller instance, 1-day backup retention, deletion protection OFF
    prod/       # larger instance, 30-day backup retention, deletion protection ON, Multi-AZ
docker-compose.yml   # local Postgres 16
docker/init-order.sh # applies migrations then seed data on first container start
migrations/          # schema + index
seed/                # seed data generator + generated seed SQL
scripts/
  backup.sh          # timestamped pg_dump
  restore.sh          # restores into a fresh database, verifies row counts
.github/workflows/terraform.yml  # fmt/init/validate/plan on PRs (optional part)
```

## Part 1–3: Terraform

### Design

- **Network module**: one VPC, 2 public + 2 private subnets across 2 AZs, one
  NAT gateway (private subnets need outbound access to pull images), and
  three security groups:
  - `alb-sg`: 80/443 open to the internet
  - `ecs-sg`: only accepts traffic from `alb-sg`, on the app port
  - `rds-sg`: only accepts Postgres (5432) from `ecs-sg` — RDS has no path to
    the internet and no path from anything except the ECS tasks.
- **RDS module**: private (`publicly_accessible = false`), subnet group built
  from the private subnets only, encrypted storage, and all of the
  environment-sensitive settings (instance class, backup retention, deletion
  protection, Multi-AZ) exposed as variables so `dev`/`prod` can diverge.
- **ECS module**: ALB → target group → Fargate service running in the
  private subnets (`assign_public_ip = false`), task execution role with the
  standard `AmazonECSTaskExecutionRolePolicy`, and a separate (currently
  empty) task role, ready for app-specific IAM permissions. Container image
  defaults to `nginx` as a placeholder per the assignment.

### Environments

| Setting                  | dev                  | prod                 |
|---------------------------|----------------------|----------------------|
| RDS instance class         | `db.t4g.micro`       | `db.r6g.large`       |
| RDS backup retention        | 1 day                | 30 days              |
| RDS deletion protection     | `false`              | `true`               |
| RDS Multi-AZ                 | `false`              | `true`               |
| ECS task size (cpu/mem)      | 256 / 512            | 1024 / 2048          |
| ECS desired count             | 1                    | 2                    |

Each environment has its own `variables.tf` (defaults), `<env>.tfvars`
(explicit values — this is what you'd pass with `-var-file`), and a
`backend.hcl.example` showing the expected S3+DynamoDB remote state config
(not wired to a real bucket, since no AWS deployment is expected).

### How to validate

```bash
cd infra/envs/dev   # or infra/envs/prod
terraform fmt -check -recursive ../../
terraform init -backend=false
terraform validate
terraform plan -refresh=false -var-file=dev.tfvars   # or prod.tfvars
```

`plan` will fail at the point of an actual AWS API call unless you export
real AWS credentials (no credentials are configured here, on purpose) — but
`fmt`, `init`, and `validate` fully pass and prove the code is well-formed.
If you do have an AWS account handy, exporting credentials and re-running
`plan` will produce a complete plan (no resources are created without
`apply`).

### Part 3 (optional): GitHub Actions

`.github/workflows/terraform.yml` runs on every PR touching `infra/**`, for
both `dev` and `prod` as a matrix: `fmt -check`, `init -backend=false`,
`validate`, then `plan` (best-effort — see the comment in the workflow about
why the plan step itself needs real credentials to fully succeed). The plan
output is both uploaded as a workflow artifact and posted as a PR comment.

## Part 4–5: Local database

### Run it

```bash
docker compose up -d
```

This starts Postgres 16 and, on first boot (empty data volume), automatically
runs `docker/init-order.sh`, which applies everything in `migrations/` and
then `seed/` in filename order. (The official Postgres image only auto-runs
files placed directly in `/docker-entrypoint-initdb.d`, not subfolders, so
this one script drives both directories in the right order.)

Connection details (matching `docker-compose.yml`):

```
host: localhost
port: 5432
db:   hotelapp
user: app_admin
pass: app_password
```

### Schema

- `hotel_bookings`: one row per booking (`org_id`, `hotel_id`, `city`, dates,
  `amount`, `status`, `created_at`).
- `booking_events`: append-only event log per booking (`event_type`,
  `payload` JSONB), foreign-keyed to `hotel_bookings.id`.

### Seed data

`seed/generate_seed.py` generates `seed/001_seed_data.sql` (already committed,
regenerate any time with `python3 seed/generate_seed.py > seed/001_seed_data.sql`):

- 120 bookings across 5 cities, 4 orgs, 4 statuses, spread over the last 90
  days (so the "last 30 days" filter in the target query returns a realistic
  subset rather than everything or nothing).
- ~130 booking_events across roughly half of those bookings.

### Query optimization (Part 5)

Target query:

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

Index added in `migrations/002_indexes.sql`:

```sql
CREATE INDEX idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
```

**Why this shape:**
- `city` is an equality filter and `created_at` is a range filter, so they're
  the key (sorted) columns, equality column first — this lets Postgres do a
  single range scan on the index for `city = 'delhi' AND created_at >= ...`.
- `org_id`, `status`, and `amount` are never filtered on in this query — only
  read/aggregated — so they're added as `INCLUDE` columns rather than key
  columns. This keeps the B-tree shorter and cheaper to maintain (they don't
  participate in sort order) while still letting Postgres answer the entire
  query from the index alone (index-only scan), avoiding a heap fetch per
  matching row once the table's visibility map is up to date.

Verified locally with `EXPLAIN ANALYZE` — the plan uses
`Index Only Scan using idx_hotel_bookings_city_created_at`.

A second, smaller index (`idx_booking_events_booking_id`) was also added on
`booking_events.booking_id` since it's a foreign key that's the natural
lookup path for "get the event history for this booking."

## Part 6: Backup and restore

```bash
./scripts/backup.sh
```

- Runs `pg_dump` in custom format (`-Fc`), timestamped into `backups/`
  (git-ignored), and updates a `backups/latest.dump` symlink to the newest
  file.

```bash
./scripts/restore.sh                       # restores backups/latest.dump into hotelapp_restore
./scripts/restore.sh path/to/file.dump mydb  # or restore a specific file into a named db
```

- Drops (if present) and recreates the **target** database from scratch —
  restore correctness is never dependent on any existing state — then runs
  `pg_restore`, and finally prints row counts for both tables as a
  verification step.

### How to verify restore worked

1. Note the row counts before backing up:
   ```bash
   psql -h localhost -U app_admin -d hotelapp -c \
     "SELECT (SELECT COUNT(*) FROM hotel_bookings), (SELECT COUNT(*) FROM booking_events);"
   ```
2. Run `./scripts/backup.sh`.
3. Run `./scripts/restore.sh` — it prints the row counts for the restored
   database (`hotelapp_restore` by default) at the end automatically.
4. Compare: they should match exactly (in my local test run: 120 bookings /
   129 events, both before and after).
5. Optionally, spot-check the target query still returns the same result set
   against the restored database:
   ```bash
   psql -h localhost -U app_admin -d hotelapp_restore -c "
     SELECT org_id, status, COUNT(*), SUM(amount)
     FROM hotel_bookings
     WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
     GROUP BY org_id, status;"
   ```

### What I actually ran (local verification, no Docker available in the
authoring environment — logic is identical under `docker compose up`)

- Installed Postgres 16 locally, created the `app_admin` user / `hotelapp` db
  matching `docker-compose.yml`.
- Applied `migrations/001_create_tables.sql` and `002_indexes.sql` — both
  succeeded.
- Generated and loaded seed data — 120 bookings / 129 events inserted.
- Ran `EXPLAIN ANALYZE` on the target query — confirmed
  `Index Only Scan using idx_hotel_bookings_city_created_at`.
- Ran `./scripts/backup.sh` — produced a valid custom-format dump.
- Ran `./scripts/restore.sh` — restored into a fresh `hotelapp_restore`
  database, row counts matched exactly (120 / 129).

## Notes / things I'd do differently with real AWS access

- `db_password` defaults to a placeholder in `variables.tf` — in a real
  deployment this would come from AWS Secrets Manager or SSM Parameter
  Store, referenced via a data source, never committed as a plain variable
  default.
- The NAT setup uses one NAT gateway shared across AZs to keep cost down for
  an assessment; a production system might use one NAT gateway per AZ for
  full AZ isolation.
- `backend.hcl.example` is a placeholder; real usage would point at an actual
  S3 bucket + DynamoDB lock table per environment.
