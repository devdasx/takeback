# Security policy

Takeback handles Bitcoin signing material. Treat a locally built copy and its dependencies as software that needs review before use with funds. This repository does not claim an independent security audit or guaranteed recovery.

## Reporting a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/devdasx/takeback/security/advisories/new), enabled for this repository. Include the affected commit, impact, reproduction steps, and a minimal example using disposable public test keys. Never include a real recovery phrase, passphrase, private key, or signing credential.

If the private reporting button is unavailable, open a public issue containing only a request for a private contact route—do not include exploit details or sensitive data. There is no published security email or guaranteed response deadline.

Public issues are appropriate for ordinary non-sensitive bugs. Do not test against another person's wallet, server, or funds without permission.

## Review scope

The active development branch is the review target. No separate long-term support branch or binary security-update channel is promised. Report the exact commit and Xcode/iOS versions so the maintainer can reproduce the issue.

High-priority areas include:

- Secret persistence, logging, unintended network disclosure, or failed session cleanup.
- Incorrect derivation, ownership classification, destination selection, or passphrase handling.
- Fee arithmetic, dust handling, descendant policy, and recipient/output preservation.
- Signing/self-check disagreement, unsafe retry behavior, or a transaction-ID mismatch being accepted.
- Malformed QR payload handling, response framing, TLS/pinning behavior, and unbounded resource use.

## Memory and network boundaries

App-owned secret buffers use explicit zeroing. Native text editing and system frameworks may make copies that cannot be proven erased. Sessions clear after successful broadcast, on return to Welcome, and on timeout/expiration in the background. Retryable failures may retain the current session. Force-termination does not guarantee a lifecycle callback.

Electrum queries and broadcasts reveal public transaction activity to servers. TLS protects transport but does not make server-provided data trustworthy or hide query relationships. First-use certificate pinning cannot establish trust before the first connection. There is no bundled Tor client.

## Development fixtures

Private-key strings in tests and Debug fixtures are published vectors or disposable synthetic keys, not production credentials. **Never send real funds to them.** Regtest's RPC credential is a public local-test value, and host ports are bound to loopback. Test TLS private keys are generated locally and excluded from Git.

This document is a reporting policy and threat-boundary description, not a certification. See [Privacy](Documentation/PRIVACY.md) and [Testing](Documentation/TESTING.md).
