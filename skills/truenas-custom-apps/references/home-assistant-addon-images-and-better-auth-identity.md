# Reusing Home Assistant Add-on Images on TrueNAS and Migrating Better Auth Identity

Use this pattern when an upstream project publishes a supported Home Assistant add-on image but no generic production image, and Luke wants a fully managed TrueNAS app rather than a manual Home Assistant installation.

## Applicability

- Upstream add-on image is public and architecture-specific (for example `*-amd64:<version>`).
- The image launcher reads `/data/options.json` and may bundle PostgreSQL.
- The application uses Better Auth with email/password login.
- Luke explicitly asks to align the application's local login with an existing Authelia/LLDAP identity.

Do not assume credential reuse is desirable. Reusing the Authelia password increases credential coupling; only do it after explicit direction. Prefer OIDC/LDAP integration when the application natively supports it.

## TrueNAS deployment pattern

1. Pin an immutable upstream version tag; verify the manifest for the NAS architecture before installation.
2. Create `/mnt/Apps/Applications/<app>/data` and seed the add-on's expected `/data/options.json` with only non-secret defaults when the launcher can generate persistent secrets itself.
3. Register with `midclt call -j app.create` using `custom_app: true` and `custom_compose_config_string`; mount the host data directory to `/data` and publish only the required LAN port.
4. If bundled PostgreSQL initialization fails with `initdb: could not access directory "/data/postgres": Permission denied`, inspect the entire path, not only `/data/postgres`. The launcher may chown the child correctly while the internal `postgres` user still cannot traverse a root-owned `0770` `/data`. When appropriate, make the bind root traversable (`chmod 755 .../data`) while keeping secret files `0600` and PostgreSQL itself `0700`.
5. Stop/start through TrueNAS middleware, then require all of:
   - app state `RUNNING`;
   - container health `healthy`;
   - application health HTTP 200;
   - database health HTTP 200;
   - successful authenticated login;
   - persistence after another managed stop/start.

## Resolving an Authelia identity without exposing secrets

1. Use the scoped Proton Pass agent with a short audit reason.
2. Locate the login item from metadata, then fetch only field-specific values (`username`, `password`). Never dump the full item or print the password.
3. If the Pass username is a short LDAP user ID rather than an email, resolve the identity from LLDAP's authoritative data source. On the observed LLDAP v0.6.x SQLite layout, the read-only database is `/data/users.db`, backed on TrueNAS by `/mnt/Apps/Applications/lldap/data/users.db`; table `users` includes `user_id`, `email`, and `display_name`.
4. Query by exact/case-insensitive `user_id`. Do not infer the email from the username or domain.
5. Keep any temporary field files root-only (`0600`) and remove them immediately after verification.

## Better Auth credential migration

Observed with Better Auth 1.6.x:

- `POST /api/auth/change-password` is the supported password-change path. It requires an authenticated recent session and body fields `currentPassword`, `newPassword`, and optional `revokeOtherSessions`.
- `POST /api/auth/update-user` can change `name` but deliberately rejects `email` (`EMAIL_CAN_NOT_BE_UPDATED`) unless the application enables a separate email-change flow.

Safe sequence:

1. Create a root-only `pg_dump -Fc` backup of the auth tables (`user`, `account`, `session`) under the app's persistent backup directory.
2. Sign in using the current local credentials.
3. Change the password through Better Auth with `revokeOtherSessions: true` so Better Auth performs its own validation and hashing. Never generate or write a password hash manually.
4. If the application has no supported email-change endpoint, update only the local Better Auth `user.email`, `user.name`, verification state as appropriate, and timestamp in one database transaction. Do not alter the user ID or credential account linkage.
5. Delete remaining sessions after the direct identity update so stale cookies cannot continue presenting the old email/name.
6. Verify:
   - the new email + requested password authenticate;
   - session identity returns the expected email and display name;
   - old credentials are rejected;
   - application data tied to immutable user ID remains present;
   - login still succeeds after a TrueNAS-managed stop/start.

## Connecting a manual-IMAP application to Proton Bridge

Use the Bridge-generated relay credential—not the Proton account password and not the Authelia password. Retrieve it at runtime through the audited Proton Pass wrapper/field, keep it in process memory, and send it only in the application's authenticated credential-creation request.

1. Inspect the application's actual manual-IMAP input parser and persistence path before submitting credentials. Typical fields are email/display name, IMAP host/port/security mode, IMAP username, app password, and Inbox/Sent/Drafts folder names. Do not assume the UI exposes SMTP fields: some applications infer SMTP from the IMAP host and default to port 587 + STARTTLS.
2. Prove the Bridge endpoint from the intended consumer path. A working client on another host does not prove a TrueNAS app container can reach the same NAS-local bind address. Prefer the routable TLS hostname already used by a known-good client, verify DNS and certificate authorization from the consumer container, and match protocol mode exactly (implicit TLS on 993 versus STARTTLS on another port).
3. Run a bounded authenticated mailbox probe before storing credentials. Open ports and TLS handshakes alone do not establish a usable mailbox.
4. Submit the credential through the application's authenticated API/UI. Expect some email automation apps to synchronize their current labels by creating provider folders as part of account creation; this is a real mailbox side effect and should be reported.
5. Correlate account-status results by immutable account ID. Some status endpoints return only `{id, status, statusMessage}` rather than provider/email metadata, so matching again by email will falsely report failure even though the account is connected.
6. Verify all of:
   - account list shows exactly one intended manual-IMAP account;
   - connection status is `connected`;
   - a read-only provider query succeeds with no skipped account;
   - SMTP authentication succeeds with a transport `verify()`/EHLO+STARTTLS+AUTH check that sends no message;
   - the app survives a managed stop/start and can decrypt/use the stored credential afterward.
7. Keep polling/classification disabled until the user explicitly wants automation and any required AI provider is configured. Connecting credentials is not permission to begin moving or classifying live mail.

Security details:
- Prefer an application that encrypts the stored relay credential with a persistent application key. Inspect the storage implementation when uncertain; never print the encrypted blob or compare it by exposing plaintext.
- Pipe secrets over stdin or keep them in process memory. Do not place relay credentials in compose YAML, options JSON, shell argv, logs, skills, memory, or summaries.
- SMTP `verify()` is the preferred non-destructive send-path test; do not send a test message unless the user asks or approves a recipient.

## Security and rollback

- Never put the Authelia password in compose, options JSON, shell argv, logs, memory, or the final summary.
- A field-specific Pass read may be held only in process memory or a short-lived `0600` file.
- Preserve the pre-change auth dump until the new login and restart-persistence checks pass.
- If the password change succeeds but the email transaction fails, recovery is the old email with the new password; do not blindly restore the full database.
- Report the resulting login email/display name, but refer to the password as “the Authelia password stored in Proton Pass.”

## Pitfall summary (formerly in SKILL.md)

_Moved verbatim from `SKILL.md` on 2026-10-08 during the size refactor; the skill keeps a short summary that links here._

- **Reusing a Home Assistant add-on image as a TrueNAS custom app:** A prebuilt add-on image can be the cleanest upstream artifact when it includes its own database and launcher. Mount `/mnt/Apps/Applications/<name>/data` to `/data`, seed the add-on's expected `/data/options.json`, and preserve that directory. Ensure the bind root is traversable by internal service users (`chmod 755 .../data` when appropriate): a root-owned `0770` bind root can let the launcher `chown /data/postgres` yet still make `initdb` fail with `Permission denied` because the container's `postgres` user cannot traverse `/data`. After correcting permissions, stop/start through `midclt`, require both app `RUNNING` and container health `healthy`, then verify database health, authenticated login, and persistence across another managed stop/start.
