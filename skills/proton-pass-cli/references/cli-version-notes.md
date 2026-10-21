# Proton Pass CLI version notes

Linked from the proton-pass-cli skill. Check `--help` per subcommand on the installed version before side-effecting commands.

## CLI v2.5.0 login notes

- v2.5.0 (box, 2026-10-20) signs in through the web login only; there is no password prompt flow.
- The account has an extra (second) password. Commands that need it read `PROTON_PASS_EXTRA_PASSWORD`.
  After `source ~/.config/proton-pass-cli/env`, set it from the env var `PROTON_PASS_LOGIN_EXTRA`
  (`export PROTON_PASS_EXTRA_PASSWORD="$PROTON_PASS_LOGIN_EXTRA"`). Never print either value.
- Read an API Credential field straight into a 0600 file (`--field "API Key" > file`), then use
  it through a credential helper that reads the file. Never put it in argv or the output.

## CLI v2.1.0 syntax notes

- `pass-cli item list` takes the vault as a positional argument in the observed 2.1.0 CLI:
  ```bash
  proton-pass-agent item list "<vault>" --output json
  ```
- Do not use `--vault-name` with `item list` on this version; it errors with `unexpected argument '--vault-name'`. Other subcommands may still use `--vault-name`, so check `--help` per subcommand.
- A global `item list --output json` can fail if no default vault is set. Prefer explicit positional vault names for deterministic automation.
- When locating credentials, use `item list "<Vault>" --filter-type login --output json` before resolving `/username` or `/password`. Recursive searches across every item type can mistake email aliases for login records because alias titles often look like account usernames; aliases correctly fail with `Field 'username' not found`.
- When scanning item metadata for candidate SSH/host credentials, summarize only title/type/state; redact vault/share/item IDs and never print secret fields.
- If `--output json` from `pass-cli item list` contains literal control characters and `json.loads` fails, use Hermes `execute_code`'s `json_parse()` helper instead of printing or hand-cleaning the JSON. Continue to redact IDs and secret fields in any summary.
