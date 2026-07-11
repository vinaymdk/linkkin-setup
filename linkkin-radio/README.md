# LinkKin Radio — streaming infrastructure

Radio streaming (Icecast, nginx, HLS) is configured alongside `linkkin-backend`.
This folder holds **standardized ops scripts** for the radio server — not a separate app repo.

## Scripts

| Command | Description |
|---------|-------------|
| `./setup.sh` | First-time: check deps, copy `.env`, verify backend radio config |
| `./doctor.sh` | Verify Icecast, nginx, ffmpeg, ports |
| `./run.sh` | Show listen URLs and service status |
| `./update.sh` | Refresh backend radio docs, optional `git pull` |
| `./clean.sh` | Clear local temp files |
| `./server-setup.sh` | **Production**: full radio stack install (requires `sudo`) |

Backend installer: `../linkkin-backend/scripts/radio.setup.install.sh`

Workspace (all repos): run `../linkkin-setup.sh` from the parent folder.
