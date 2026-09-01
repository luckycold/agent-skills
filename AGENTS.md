# Repository guidance

- Keep each portable skill under `skills/<skill-name>/` with a valid `SKILL.md` entrypoint.
- Preserve `author: Luke` on Luke-authored skills.
- Put detailed procedures in directly linked `references/` files and deterministic helpers in `scripts/`.
- Never commit credentials, tokens, private keys, session material, private hostnames, or rendered private context.
- Use descriptive placeholders when exact private infrastructure values are required at runtime.
- Validate every changed skill with the Agent Skills validator before committing.
- Do not commit or push changes unless Luke explicitly asks.
