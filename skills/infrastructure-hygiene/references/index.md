# infrastructure-hygiene reference index (detailed descriptions)

_Moved verbatim from `SKILL.md` on 2026-10-08 during the size refactor; the skill keeps a short summary that links here._

- `references/hermes-container-weekly-maintenance.md` — concrete execution log + recipes from cron runs on the HAOS Hermes container (inspection commands, npm prefix update, **kagi-cli glibc pin**, Kagi MCP wrapper+HOME + auth sync, summarize MCP vs subscriber CLI, smoke tests, caches, hermes-update/gateway approval behavior, git dirty handling, no-sudo observation, final report template). **2026-07-05 follow-up execution:** Luke-directed fix of cron report items (jobs.json paths, linuxbrew tmp reclaim, update+cherry-pick, MCP adapter, add-on gateway restart). **2026-07-05 cron run:** 0.14.1 glibc break → pin 0.11.0; `hermes mcp add` for config.yaml. **2026-06-21:** native typed schemas; `file_safety.py` conflict fix.
- `references/kagi-mcp-schema-probe.py` — Tirith-safe schema probe script (no shell pipes); exit 1 if the five required tools lack typed properties.
- See `references/hermes-harness-boundary.md` for the specific incident that established the Hermes harness rule.
- See `references/proxmox-readonly-recon.md` for read-only Proxmox reconnaissance without persisting live topology.
- See `references/proxmox-cluster-ceph.md` for generic cluster join, major-version upgrade, Ceph retirement, local-ZFS replication, HAOS placement, and PBS recovery patterns.
- `references/agent-clis-lan-hosts.md` — Cursor/Grok/Codex/Pass on Proxmox, TrueNAS, PBS, and Hermes; `common`+`personal` Stow; vendored Stow when `apt` is disabled.
- `references/truenas-backrest-restic-path-health.md` — Backrest/restic: empty `_backrest-view` ix-app-mounts stub; Immich Media mount failure (top-level `additional_storage` ignored; use `storage.additional_storage`); host-eval secrets + `docker exec restic` (no python3 in image); midclt app.update Extra inputs pitfall; plan gaps (odysseus, HA); FUTO restore drill; NFSv4 ACL for uid 568.
- `references/truenas-apps-pool-space-reclaim.md` — Apps pool near full: Docker image prune first; karakeep/plex-stage leftovers; legacy Immich `app_mounts` destroy only after live mounts verified; snapshot holdback.
- `references/netbird-bmc-work-pc-dual-homed.md` — generic diagnosis for NetBird routed-network instability when Wi‑Fi and Ethernet are both active.
- `references/hermes-cron-creation.md` — correct `hermes cron create` usage, flags, deliver=local pattern, skill attachment, self-contained prompts, and the generic-cronjob-tool pitfall (for hygiene/monitoring/maintenance jobs). Cross-references the himalaya email-scan example.
- `references/rpi-otbr-docker-appliance.md` — standalone Raspberry Pi OTBR Docker appliance for Home Assistant (host-network REST on 8081, Trixie docker-cli split, ghcr IPv4 pull pitfall). Resolve host/IP from private context.
