# 02 - Homolog Env

## Goal
Create a homolog environment that can be deployed and refreshed regularly without causing any change to production application traffic, production database state, or production secrets.

## Status
- Implemented.
- `homolog.30fev.com` is live.
- Homolog deploys through Kamal destination `homolog`.
- Homolog uses its own database container and database name.
- Production deploy flow remains separate.

## Non-negotiable safety rules
- Homolog must use a different app host/domain from production.
- Homolog must use a different database name from production.
- Homolog must use different app secrets and environment variables.
- Homolog must never run migrations against the production database.
- Homolog background jobs, emails, webhooks, and notifications must be disabled or redirected to safe endpoints.
- Production deploy commands must remain unchanged.

## Architecture
- Keep the current production app and database untouched.
- Add a second Kamal target/service for homolog.
- Reuse the same Postgres server only if homolog points to a separate database, user, and credentials.
- Use separate container names, volumes, env files, accessory names, and reverse-proxy hostnames.

## Current setup audit
- Current Kamal service is `financerb`.
- Current proxy host is `30fev.com`.
- Current app env in base config hardcodes `RAILS_ENV=production`.
- Current database accessory is named `db` and uses database `finance`.
- Current Postgres accessory persists to `data:/var/lib/postgresql/data`.
- Current pre-deploy hook runs `DbBackupJob.perform_now`.
- Current post-deploy hook installs cron entries for:
  - `scheduled:daily_backup`
  - `scheduled:due_payments`
- Current cron hook filters containers by `financerb-web`.

## Why the current setup cannot be reused as-is
- Reusing service name `financerb` would collide with production containers.
- Reusing proxy host `30fev.com` would route homolog traffic into production paths.
- Reusing accessory name `db` and volume `data` would risk sharing the production database container and disk.
- Reusing the current hooks would make homolog install the same cron/backups logic unless explicitly separated.
- Reusing `RAILS_ENV=production` would make homolog behave like prod in logging, mailers, and safety assumptions.

## Execution plan
1. Audit current Kamal setup.
2. Create homolog app config.
3. Create homolog database.
4. Harden homolog side effects.
5. Add refresh workflow.
6. Add guardrails.
7. Test deploy end to end.

## What was implemented
- Added [config/deploy.homolog.yml](/home/lovelace/personal/Ruby/finance.rb/config/deploy.homolog.yml)
  - `proxy.host: homolog.30fev.com`
  - `RAILS_ENV: homolog`
  - `POSTGRES_DATABASE: finance_homolog`
  - `POSTGRES_HOST: financerb-homolog-db`
  - accessory renamed to `db_homolog`
- Added [.kamal/secrets.homolog](/home/lovelace/personal/Ruby/finance.rb/.kamal/secrets.homolog)
  - uses variables from `.env.homolog`
- Added [config/environments/homolog.rb](/home/lovelace/personal/Ruby/finance.rb/config/environments/homolog.rb)
  - disables real mail delivery
  - adds homolog log tagging
- Added homolog DB config to [config/database.yml](/home/lovelace/personal/Ruby/finance.rb/config/database.yml)
- Added homolog sections to:
  - [config/cable.yml](/home/lovelace/personal/Ruby/finance.rb/config/cable.yml)
  - [config/cache.yml](/home/lovelace/personal/Ruby/finance.rb/config/cache.yml)
- Added [bin/kamal-homolog](/home/lovelace/personal/Ruby/finance.rb/bin/kamal-homolog)
  - always sources `.env.homolog`
  - always appends `-d homolog`
- Added [bin/homolog-refresh](/home/lovelace/personal/Ruby/finance.rb/bin/homolog-refresh)
  - one-way sync from prod DB container to homolog DB container
  - guarded by `--force`
  - aborts if source and target names collide
- Updated [app/views/layouts/application.rb](/home/lovelace/personal/Ruby/finance.rb/app/views/layouts/application.rb)
  - homolog uses a different background/theme color
- Updated deploy hooks:
  - [.kamal/hooks/pre-deploy](/home/lovelace/personal/Ruby/finance.rb/.kamal/hooks/pre-deploy)
    - skips production backup hook for homolog
  - [.kamal/hooks/post-deploy](/home/lovelace/personal/Ruby/finance.rb/.kamal/hooks/post-deploy)
    - installs homolog refresh cron on the VPS host
    - keeps production cron install path separate

## What changed from the original idea
- Homolog was implemented as a Kamal destination override, not a fully separate base deploy file.
- Homolog secrets were aligned to the actual `.env.homolog` variable names instead of introducing `HOMOLOG_*` names.
- Cron installation is done directly on the VPS via `scp` + `ssh`, not through a nonexistent `cron` accessory.
- The DB refresh job runs at the host level and targets both DB containers directly.

## Daily refresh design
- Dump production DB.
- Restore into homolog DB.
- Never replicate in the opposite direction.
- Run refresh through a dedicated script, not manual shell history.
- Fail fast if target DB name matches production.
- Run refresh from production -> homolog only.
- Prefer a dedicated script with explicit guards for:
  - source database name
  - target database name
  - target host
  - target service

## Current runbook
1. Deploy homolog DB accessory
   - `bin/kamal-homolog accessory boot db_homolog`
2. Deploy homolog app
   - `bin/kamal-homolog setup`
   - or `bin/kamal-homolog deploy`
3. Manual refresh
   - `./bin/homolog-refresh --force`
4. Verify refresh cron on VPS
   - `ssh root@187.77.32.15 'cat /etc/cron.d/financerb-homolog-refresh'`
5. Check homolog refresh log
   - `ssh root@187.77.32.15 'tail -n 100 /var/log/financerb-homolog-refresh.log'`

## Proposed repo-level implementation
1. Keep `config/deploy.yml` as the production source of truth.
2. Add a second Kamal config dedicated to homolog, for example:
   - `config/deploy.homolog.yml`
3. In homolog config, change at minimum:
   - `service`
   - `proxy.host`
   - `env.clear.RAILS_ENV`
   - `env.clear.POSTGRES_DATABASE`
   - `env.clear.POSTGRES_HOST`
   - `accessories.db_homolog` name
   - `accessories.db_homolog.directories`
4. Split secrets so homolog does not reuse production app secrets by accident.
5. Split hooks or gate them by environment.
   - Production keeps current backup/cron hooks.
   - Homolog either disables them or uses homolog-specific jobs only.
6. Add a standalone refresh script outside deploy hooks.
   - `bin/homolog-refresh` or similar.
   - Script must abort if target matches prod values.

## Minimal homolog config checklist
- host: `homolog.30fev.com` or another isolated subdomain
- service: `financerb-homolog`
- postgres database: `finance_homolog`
- postgres accessory: `db_homolog`
- postgres host/container: `financerb-homolog-db`
- postgres volume: `data_homolog`
- rails env: `homolog` or `staging`
- separate `RAILS_MASTER_KEY`
- separate `SECRET_KEY_BASE`
- separate `POSTGRES_PASSWORD`

## Risks to avoid
- Sharing `DATABASE_URL` between prod and homolog.
- Reusing production credentials.
- Running `db:migrate` with the wrong env.
- Sending real user-facing emails from homolog.
- Letting homolog jobs mutate third-party systems.

## Problems found along the way
- `db_homolog` needed explicit accessory fields because the destination override replaced the base block.
- `.kamal/secrets.homolog` initially pointed to wrong variable names.
- `homolog` needed explicit Rails config in:
  - `database.yml`
  - `cable.yml`
  - `cache.yml`
- The post-deploy hook initially assumed a `cron` accessory that does not exist in this repo.
- Kamal host selection in hooks needed `--hosts`, not `-H`.
- Remote heredoc writing through `kamal server exec` was too fragile and could hang deploys.

## Deliverables
- homolog Kamal config
- homolog secrets/env files
- homolog DB bootstrap steps
- daily refresh script
- deployment and rollback checklist

## Success criteria
- Production deploy flow remains identical.
- Homolog can be deployed independently.
- Homolog data can be refreshed daily from production.
- No homolog operation can write into production DB.
