# Validation record

This page distinguishes source checks from runtime and network evidence. It is not an audit certificate or a promise that a mainnet replacement will confirm.

## Publication checks — 2026-10-04

Completed locally:

| Check | Result |
| --- | --- |
| Standalone key validator | 68 vectors, 0 failures; owned input preservation and zeroing checked |
| Vendored source checksums | All 88 listed files match |
| Publication hygiene and Markdown links | Passed for the staged source export |
| Gitleaks 8.30.1 | No findings after three reviewed, documented public-fixture / false-positive exceptions |
| Unsigned iOS Release build | Passed with Xcode 26.6 (17F113) |
| App and test-target compilation | Passed from a clean source export, Xcode 26.6, generic iOS Simulator; tests were compiled, not executed |
| Local TLS fixture setup | Fresh certificate generation and repeat-run preservation passed |

A Debug preview property wrapper needed an explicit `SwiftUI.State` qualification for Xcode 26.6 because the preview also defines a nested `State` enum. The change affects preview compilation only. Repository links now point to this public project.

No new simulator or physical-device session was opened for this documentation/publication task. GitHub Actions runs the documented build/source checks independently; consult its run for the published commit.

## Existing native navigation checks — 2026-10-04

The preceding native-navigation and toolbar work recorded **23 distinct targeted tests passing**: 10 unit tests and 13 UI tests, across 26 completed test/device pairs. The simulator targets were iPhone SE on iOS 18 and iPhone 17 Pro on iOS 27. The unsigned Release build also passed.

Those checks covered native back navigation, canceled and completed edge gestures, source-sheet/browser return, keyboard actions, passphrase cleanup, scanner return, finding cancellation/retry, payment review and fee sheets, result routes, and broadcast navigation blocking.

These counts aggregate completed individual checks across targeted runs, including interrupted runs. They are not a full-suite pass. Earlier failures were superseded only where the same check later completed successfully. Raw local logs and screenshots are excluded from the public repository because they contain workstation-specific metadata.

## Boundaries

- No physical-device test is claimed for this publication.
- The GitHub workflow compiles test targets but does not execute the complete XCTest/UI suite.
- Local test vectors and Debug fixture transactions have no relationship to user funds.
- Opt-in regtest and live-server suites are included; inclusion alone does not mean they ran on this commit.
- No mainnet broadcast, confirmation, independent security audit, App Store upload, or signed release is claimed.

Use [Testing](TESTING.md) to reproduce the checks appropriate to your change. Read the exact GitHub Actions run for a commit before describing its CI status.
