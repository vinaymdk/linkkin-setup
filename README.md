# linkkin-setup

Workspace operations for LinkKin — scripts, config, and radio infrastructure that live **outside** the individual app repositories.

## Layout (sibling repos)

Clone `linkkin-setup` next to the other LinkKin repositories:

```
your-workspace/
├── linkkin-setup/      ← this repo (you are here)
├── linkkin-backend/
├── linkkin-web/
├── linkkin-admin/
├── linkkin-support/
├── linkkin-mobile/
└── db-dump/            ← optional shared backups
```

`linkkin-radio/` is **inside** this repository (streaming ops scripts).

## Quick start

```bash
cd linkkin-setup
./bootstrap.sh          # clone missing repos + setup + doctor
./linkkin-run.sh        # start dev stack
./health.sh
```

## What's in this repo

| Path | Purpose |
|------|---------|
| `workspace.yml` | Ports, URLs, repo paths |
| `bootstrap.sh`, `linkkin-*.sh` | Workspace orchestration |
| `preflight.sh`, `release.sh`, `rollback.sh` | Deploy / release |
| `health.sh`, `status.sh`, `incident-report.sh` | Diagnostics |
| `linkkin-radio/` | Icecast / nginx radio server scripts |
| `docs/reference.commands.md` | Ops command notes |
| `scripts/ci-pipeline.sh` | CI entry point (Local == CI) |

## Per-app scripts

Each app repo (`linkkin-backend`, `linkkin-web`, …) still has its own `setup.sh`, `doctor.sh`, `run.sh`, etc. This repo **orchestrates** them across the workspace.

## Config

Edit [`workspace.yml`](workspace.yml) to change ports or repo paths. Default assumes sibling layout (`../linkkin-backend`).

## Push / clone

```bash
git clone git@github.com:vinaymdk/linkkin-setup.git
cd linkkin-setup
./bootstrap.sh
```

See [README workspace scripts](#) section in the full docs below — every script supports `--help`.

## Full script reference

### Core

| Command | Description |
|---------|-------------|
| `./bootstrap.sh` | Clone repos + setup + doctor |
| `./linkkin-setup.sh` | First-time setup all repos |
| `./linkkin-update.sh` | git pull + update per repo |
| `./linkkin-doctor.sh` | Environment check all repos |
| `./linkkin-run.sh` | Start backend, web, admin, support |
| `./fix-permissions.sh` | chmod scripts; `.env` → 600 |

### Operations

| Command | Description |
|---------|-------------|
| `./preflight.sh` | Pre-deploy validation |
| `./release.sh 1.2.0` | Version bump, tag, changelog |
| `./rollback.sh v1.1.0` | Rollback to tag |
| `./incident-report.sh INC-1024` | Incident snapshot folder |
| `./status.sh` | Expected vs actual services |

### Diagnostics

| Command | Description |
|---------|-------------|
| `./health.sh` | Live service health |
| `./report.sh` | Generate report.md |
| `./backup-verify.sh` | Verify DB backups |
| `./dependency-check.sh` | Lock file integrity |
| `./secret-check.sh` | Scan for committed secrets |

Every script: `--help` · Exit codes: `0` ok · `1` fail · `2` blocked · `64` usage
