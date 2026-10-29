# Auth (DRAFT): email and password

**Nothing here exists yet.** The app has no sign-in, and its UI says so.
Phone login is deferred until real phone verification is available.

Mobile apps use token-based auth, not browser cookie sessions.
Token model: short-lived access token (about 15 min) plus a refresh token
(about 30 days) that rotates on every use. The app keeps tokens in secure
storage (Keychain / Keystore), never in `shared_preferences`. The app never
stores the password.

## POST /v1/auth/register  (Public)
```json
{ "email": "abebe@example.com", "password": "correct horse battery", "name": "Abebe Kebede" }
```
`202`: `{ "message": "If this email can be used, a verification email was sent." }`
Same response whether or not the email already has an account, so it cannot
be used to discover accounts. Trade-off: slightly less friendly than a
`409 email_taken`.
Errors: `400 validation_failed` with fields, e.g.
`email: invalid_email`, `password: too_short | too_long | too_common`,
`name: too_short | too_long`. `429 rate_limited`.

## POST /v1/auth/email/verify  (Public)
`{ "token": "..." }`. `204`. Token is single-use and expires (about 24 h).
Errors: `400 invalid_or_expired_token`.

## POST /v1/auth/login  (Public)
```json
{ "email": "abebe@example.com", "password": "...", "deviceName": "Galaxy M15" }
```
`200`:
```json
{ "accessToken": "...", "expiresInSeconds": 900, "refreshToken": "...",
  "user": { "id": "usr_1", "email": "abebe@example.com", "name": "Abebe Kebede" } }
```
Errors:
- `401 invalid_credentials`: same message for wrong email or wrong password.
- `403 email_not_verified`.
- `429 rate_limited`: backoff or temporary lock after repeated failures,
  per account and per IP.

## POST /v1/auth/refresh  (Public)
`{ "refreshToken": "..." }` returns a new pair. Reusing an already-used
refresh token revokes that whole session (theft signal).

## POST /v1/auth/logout
Revokes the current session. `204`.

## POST /v1/auth/password/forgot  (Public)
`{ "email": "..." }`. Always `202`, whether or not the account exists.

## POST /v1/auth/password/reset  (Public)
`{ "token": "...", "newPassword": "..." }`. `204`. Token is single-use,
expires in about 30 minutes, and is stored hashed. Success revokes every
session for that user.
Errors: `400 invalid_or_expired_token`, `400 validation_failed`.

## POST /v1/auth/password/change
Auth required. `{ "currentPassword": "...", "newPassword": "..." }`. `204`.
`401 invalid_credentials` if the current password is wrong.

## Server must enforce
- Passwords: minimum 10 characters, maximum 128, reject common passwords.
  Store only a salted hash from a modern algorithm (argon2id or bcrypt) via
  a maintained library or the managed auth service. Never log or return it.
- Constant-time comparison, HTTPS only, rate limits on every endpoint above.
- Refresh and reset tokens stored hashed and revocable.
- Verification and reset emails need an email provider. Not chosen yet.
- Do not hand-roll crypto. A managed backend's built-in auth covers most of
  this; a custom API must implement all of it.