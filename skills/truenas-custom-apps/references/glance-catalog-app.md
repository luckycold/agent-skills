# Glance (community catalog + host paths, not ixVolume)

_Moved verbatim from `SKILL.md` on 2026-10-08 during the size refactor; the skill keeps a short summary that links here._

- Prefer **official catalog** (`train: community`, `catalog_app: glance`) when Luke wants upstream Glance with TrueNAS lifecycle — not a hand-registered custom app.
- Storage: set `storage.config.type` to `host_path` → `/mnt/Apps/Applications/glance/config` (maps to `/app/config`). Add `additional_storage` host_path → `/mnt/Apps/Applications/glance/assets` at `/app/assets` to match [docker-compose-template](https://github.com/glanceapp/docker-compose-template) (`config/glance.yml`, `config/home.yml`, `assets/user.css`).
- Seed those files from upstream **before** `midclt call app.create` (job returns immediately; poll `core.get_jobs` until SUCCESS). `run_as` **568:568**; `chown -R 568:568` on the host tree first.
- CLI install shape: `app.create` with `custom_app: false`, `version: "1.0.3"`, and `values` matching `questions.yaml` (see catalog `trains/community/glance/1.0.3/questions.yaml`).
- Default web port in catalog: **30426** (published). Verify: `curl http://${NAS_IP}:30426/` → 200; `app.query` volumes should show both host paths, `custom_app: false`.
