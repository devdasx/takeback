# Contributing to Takeback

Thank you for helping improve a focused Bitcoin tool. Small, reviewable changes are easiest to validate.

## Before opening a change

1. Read [Building](Documentation/BUILDING.md), [Architecture](Documentation/ARCHITECTURE.md), and [Security](SECURITY.md).
2. Open an issue for a substantial feature or behavior change. For a vulnerability, use the security reporting route instead of a public issue.
3. Keep unrelated UI, dependency, and transaction changes separate. Preserve native navigation and safe-area behavior.
4. Use only public test vectors and disposable regtest keys. Never attach real key material, private server credentials, or signing assets.

## Development expectations

- Treat key lifetime and cleanup as part of every secret-handling change. Never add secret logging, persistence, analytics, or clipboard export.
- Keep satoshi calculations integral and fee conversions explicit. Cover dust, insufficient value, linked descendants, ownership, and transaction-ID mismatch where relevant.
- Validate both Cancel and Speed up when changing shared replacement code.
- Preserve upstream copyright notices and document dependency revisions. Do not modify vendored crypto casually.
- Regenerate `Takeback.xcodeproj` after changing `project.yml` or adding app/test files.
- Use native navigation, sheets, toolbars, and actual safe areas. Test a specific runtime uncertainty when necessary; do not report unperformed simulator or device checks as passed.

## Pull request checklist

Describe the concrete problem and changed behavior. Include the commands/checks actually run, their results, and any unverified behavior. For UI changes, include focused screenshots with synthetic data when useful. For transaction changes, include deterministic tests and relevant regtest evidence.

Before submitting:

```sh
sh Scripts/validate-key-vectors.sh
shasum -a 256 -c Vendor/SHA256SUMS
python3 Scripts/check-publication.py
```

Also compile the app and run tests appropriate to the change. See [Testing](Documentation/TESTING.md). The publication checker is a focused hygiene check, not a complete security audit.

## Review and community

Be respectful, explain tradeoffs, and keep discussions about the change. Do not post private financial data. A maintainer may request a smaller scope, additional evidence, or a separate design discussion before merging. No response-time guarantee is offered.
