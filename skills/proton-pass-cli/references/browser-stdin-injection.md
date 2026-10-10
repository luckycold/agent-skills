# Native secret injection into an authorized browser

Use only the existing authorized CLI scope. Browser owner login does not
implicitly authorize a full-owner CLI bootstrap or wider agent-token scope.
Check current `pass-cli run --help`; version 2.4.1 accepts secret references in
inherited environment variables or an env file, not a `--env` argument.

```bash
PROTON_PASS_AGENT_REASON='Authorized browser sign in' \
BROWSER_PASSWORD='pass://<share-id>/<item-id>/password' \
  pass-cli run -- <maintained-browser-client>
```

For secure batching, the launched application may read the resolved environment
variable and send it to the browser client's stdin. Keep masking enabled, capture
responses privately, and print only success booleans. Some clients echo batch
arguments even on failure. Never put resolved passwords or codes in argv.

`pass://<share-id>/<item-id>/totp` resolves to the current six-digit code, not the
TOTP seed URI. Use the fresh resolved code promptly. On Proton's six separate
OTP inputs, clearing or filling each box individually can fire Backspace/focus
handlers and overwrite neighboring boxes. Focus the first input and type the
whole code continuously. If clearing is needed, use the page's actual keyboard
behavior, then refocus the first box. Verify entry without logging digits.

A submitted authentication form is not proof of success. Wait for the intended
signed-in app, check account/vault metadata, and inspect browser crashes or OOM
reports if the page stays blank. Avoid retrying credentials against a crashed
renderer. Reidentify the exact tab before each credential operation.

When an item view fails during remote audit transmission, preserve the error and
use the supported scoped `run` interface for a specifically needed field only if
it succeeds with the same authorization and a truthful reason. Do not disable
audit logging or widen permissions. A successful email/username read does not
establish that notes, passkeys or the full item were examined. Missing optional
fields are different from failed reads. Duplicate titles require item-ID-based
references; never resolve duplicates by taking the last title match.

Serialize audited `item view` calls on a host. Concurrent views can time out in
remote audit transmission even while the same scoped session works. After a
verified serialized read succeeds, retry failed items one at a time with their
original share/item IDs. Preserve unresolved errors and distinguish full-item
coverage from field-only recovery.
