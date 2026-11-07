# Security

RoundScreen is a local-only macOS app. It does not contain networking code,
telemetry, analytics, or a remote update mechanism.

## Permissions

RoundScreen asks for Accessibility permission only for:

- keeping the pointer outside the four corner cutouts;
- proxying the macOS hot-corner actions configured in Dock preferences.

The app does not request Screen Recording permission.

## Reporting

Please report security issues privately through GitHub Security Advisories:

<https://github.com/gnawlrak/RoundScreen/security/advisories/new>

Do not include passwords, tokens, or other secrets in a public issue.
