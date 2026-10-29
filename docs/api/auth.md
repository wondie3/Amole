# Auth (DRAFT)

Mobile apps need token-based auth, not browser cookie sessions.
Primary identifier: Ethiopian mobile number, verified by one-time code (OTP).
Which SMS provider delivers OTPs in Ethiopia is **undecided and must be tested**.

**Token model:** short-lived access token (about 15 min) plus a refresh token
(about 30 days) that rotates on every use. The app stores both in secure
storage (Keychain / Keystore), never in `shared_preferences`.

## POST /v1/auth/otp/request  (Public)
```json
{ "phone": "+251911223344" }
```
`202`: `{ "retryAfterSeconds": 60 }`. Always returns 202 for a valid format, so
it cannot be used to discover which numbers have accounts.
Errors: `400 validation_failed` (`phone: invalid_ethiopian_mobile`), `429`.

## POST /v1/auth/otp/verify  (Public)
```json
{ "phone": "+251911223344", "code": "123456", "deviceName": "Galaxy M15" }
```
`200`:
```json
{
  "accessToken": "...", "expiresInSeconds": 900, "refreshToken": "...",
  "user": { "id": "usr_1", "phone": "+251911223344", "name": null }
}
```
Errors: `400` (bad code format), `401 unauthenticated` (wrong or expired code),
`429` after repeated failures (lock the number for a period).

## POST /v1/auth/refresh  (Public)
Body `{ "refreshToken": "..." }` returns a new pair. Reusing an already-used
refresh token revokes that whole session (theft signal).

## POST /v1/auth/logout
Revokes the current session. `204`.

## Server must enforce
- OTP: 6 digits, single use, expires in about 5 minutes, hashed at rest,
  attempts and sends rate-limited per number and per device.
- Refresh tokens stored hashed and revocable. No passwords exist in this design.
- Use a maintained auth library or managed service. Do not hand-roll crypto.