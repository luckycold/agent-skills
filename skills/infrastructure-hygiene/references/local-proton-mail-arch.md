# Local Proton Mail access on Arch

Use for mail-dependent tasks after an agent-host migration. Prefer local ownership over persistent SSH tunnels or old-host password commands.

## Supported packages and service

```bash
sudo pacman -S --needed himalaya protonmail-bridge-core pass
himalaya --version
protonmail-bridge-core --help
systemctl --user cat protonmail-bridge.service
```

The core package ships `protonmail-bridge.service`; use that unit rather than writing a custom daemon wrapper. Complete account sign-in with the Bridge CLI before enabling it. Initialize the local GPG-backed `pass` store before the first sign-in so noninteractive service startup does not depend on unlocking a desktop keyring. Keep the store directory at `0700` and its encrypted credential files at `0600`.

Bridge's Linux helper identifier for `pass` is **`pass-app`**, not `pass`. Its `keychain.json` records the selected helper. Verify the installed-version upstream helper definitions before changing it. Never switch an existing populated vault to another helper casually: its vault key belongs to the original helper and may become unavailable.

Use credentials from the scoped secret manager without echoing or saving the Proton password or TOTP. Bridge generates a separate local mailbox password. Store that generated password encrypted in `pass`, and let the mail client's native password-command configuration retrieve it.

```bash
systemctl --user enable --now protonmail-bridge.service
systemctl --user is-enabled protonmail-bridge.service
systemctl --user is-active protonmail-bridge.service
ss -ltnp 'sport = :1143 or sport = :1025'
```

Require loopback-only listeners. Check user lingering if the service must survive logout. Do not add a second supervisor or service definition.

## CLI readiness and certificate export

The account can report `currently locked` immediately after startup while loading. Retry the non-destructive `info` query after loading; do not assume this means the account password failed.

Bridge's readline redraws the `>>>` prefix for each typed character. When automating one-time setup, matching a bare `>>>` can consume command echoes instead of a ready prompt. The observed empty ready prompt matched `r'>>> {1,2}\x08'`. Keep prompt-specific automation temporary, never log its credential buffers, and remove it after setup.

`cert export` asks for a **directory**, not a certificate filename, and exports both `cert.pem` and `key.pem`. A mail client needs only the public certificate. Remove its redundant exported private-key copy after configuring trust. Match Bridge's reported STARTTLS mode; do not disable certificate verification.

## Himalaya version 2 configuration

Read the installed-version sample, for example `https://raw.githubusercontent.com/pimalaya/himalaya/v2.1.0/config.sample.toml`. Version 1's `backend.*`, `folder.aliases`, `folder list`, and `--output json` examples are not interchangeable with version 2.

```toml
[accounts.proton]
default = true
email = "<mailbox-address>"
imap.server = "imap://127.0.0.1:1143"
imap.starttls = true
imap.tls.cert = "<absolute-public-certificate-path>"
imap.sasl.plain.username = "<bridge-generated-username>"
imap.sasl.plain.password.command = ["/usr/bin/pass", "show", "<local-encrypted-entry>"]
mailbox.alias.inbox = "Inbox"
mailbox.alias.sent = "Sent"
mailbox.alias.drafts = "Drafts"
mailbox.alias.trash = "Trash"
```

Use IMAP-only configuration for read/draft tasks; do not add sending credentials merely because Bridge also exposes SMTP. Verify actual mailbox names using `himalaya --json mailbox list`.

```bash
himalaya --json mailbox list
himalaya --json envelope search -m 'All Mail' -s 100 '(from example or subject example) order by date desc'
himalaya message read -m 'All Mail' '<message-id>'
```

Version 2 reads leave the Seen flag untouched unless `--seen` is explicitly requested. Its search parser rejects whitespace immediately inside parentheses. Fetch MIME with `--raw` when parsing evidence; remove styles, tracking links, reset links, and quoted duplicates before returning excerpts.

## Explicitly authorized sending

Add SMTP only when sending is authorized. Reading and saving a draft do not exercise outgoing mail. Reuse Bridge's existing local username, encrypted password command, and public trust certificate:

```toml
[accounts.proton.smtp]
server = "smtp://127.0.0.1:1025"
starttls = true
[accounts.proton.smtp.tls]
provider = "rustls"
cert = "<absolute-public-certificate-path>"
[accounts.proton.smtp.sasl.plain]
username = "<bridge-generated-username>"
[accounts.proton.smtp.sasl.plain.password]
command = ["/usr/bin/pass", "show", "<local-encrypted-entry>"]
```

Run `himalaya --json account check -b smtp` before submission. This verifies handshake and authentication without sending a test email. Preserve IMAP settings and require STARTTLS with certificate verification.

**Himalaya 2.1.0 saves before sending when `message send --save` is used.** Its upstream `shared/message/handler.rs` calls `add_message` before `send_message`, so a Sent copy can exist even when outgoing configuration is missing and nothing was submitted. Prefer `himalaya --json message send` without `--save` for Proton Bridge, then verify the automatically generated Sent message using its exact RFC Message-ID. A successful SMTP result plus a read-back provider Sent record is the completion gate; Sent presence alone is not. Never blindly retry an ambiguous submission. A definite no-backend error can be retried after repair once the pre-send imported copy has been identified and removed.

Compare the read-back recipient, reply-thread headers, body, and attachment contents. Match attachments by filename, not MIME order: Proton may reorder them. Do not claim recipient delivery merely because SMTP accepted the message.

Re-list mailbox-relative IDs before mutations and match the RFC Message-ID. Preserve live user edits: fetch the current draft, merge only the approved changes, and recheck before sending. Remove the source draft only after sent verification and only if its body has not been edited further.

When investigating migrated receipts, read both the MIME body and provenance headers. `X-Pm-Origin: import` identifies an imported copy, not its original provider; preserved `Received` and `X-Original-To` headers establish the recorded delivery route. Activation confirmations are not itemized receipts unless amounts and transaction details are actually present.

## Completion gates

- Restart the shipped service, then repeat an authenticated mailbox read with certificate verification enabled.
- Confirm generated credentials are locally encrypted and no active configuration references the former host.
- Remove temporary login scripts and unused exported TLS private keys; keep only package-managed binaries, the shipped service, and native application configuration.
- Initial Bridge synchronization can be lengthy. Track synchronization completion before claiming that older receipts, welcome messages, or account history are absent; a successful inbox read does not prove full historical synchronization.
- Password-manager entry creation time is not the service account creation time. Saved TOTP does not prove SMS was never enabled. Label unavailable recovery facts instead of inventing answers.
