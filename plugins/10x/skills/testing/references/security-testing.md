# Security Testing

Author tests, not a duplicate reviewer OWASP Top 10:2025 detection/severity checklist; that reviewer walk is outside this plugin. Use actual project contracts; the HTTP outcomes below preserve the reference recipes.

## Authentication Tests

Reject invalid credentials, expired/tampered tokens with 401; cover missing auth. Exercise login brute-force/API-abuse rate limits (reference: six failed logins, next request returns 429 even with correct credentials).

## Authorization Tests

Cover IDOR and privilege escalation: another user's resources and admin routes accessed by regular users return 403. Exercise missing/invalid CSRF tokens.

## Input Validation Tests

Exercise SQL injection (reference hostile query returns 400), command injection, XSS (reference accepted post returns 201 but no `<script>` in title), and forbidden upload types (executable returns 400).

## Security Headers Test

Assert `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, HSTS present, and applicable CSP. Test PII exposure and information leaked through error messages.
