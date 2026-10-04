# Architecture

Takeback separates ephemeral secret ownership, public discovery, replacement planning, signing, and network submission. The UI routes through a typed `NavigationStack` and uses native sheets and toolbars.

## Source map

| Directory | Responsibility |
| --- | --- |
| `Takeback/App` | App lifecycle, configuration, navigation root |
| `Takeback/Features/EnterKey` | Format detection, validation, input state |
| `Takeback/Features/Passphrase` | Exact passphrase draft and fingerprint work |
| `Takeback/Features/Scanner` | Camera/photo capture and multipart decoding |
| `Takeback/Features/SearchPaths` | Path syntax, selection, preview, search defaults |
| `Takeback/Features/Finding` | Discovery state and transaction ownership metadata |
| `Takeback/Electrum` | Connections, server probing, batch methods, gap scanning |
| `Takeback/Features/Payments` | Eligibility and pending-payment explanations |
| `Takeback/Features/Cancel` | Shared Cancel/Speed up review, fee policy, replacement signing and validation |
| `Takeback/Features/Result` | Broadcast lifecycle, errors, confirmation status |
| `Takeback/Features/Settings` | Network preferences, fee defaults, About and notices |
| `Takeback/Security` | Zeroable memory, derivation/signing bridges, privacy and authentication |
| `Takeback/Services` | HTTP/Electrum adapters, fees, broadcast and txid verification |
| `Takeback/Components`, `DesignSystem`, `Layout` | Native controls, typography, color, adaptive layout |
| `Vendor` | Pinned C/C++ dependencies and checksums |

## Secret session

`SecretSession` owns the key and BIP39 passphrase in `SecureBytes`. Editing views register cleanup callbacks. Passphrase sheets work on a separate draft; dismissing without Done discards it. Passphrase whitespace is significant and is never trimmed.

Private derivation is used to produce public scan plans and short-lived signing work. Search tasks receive public address/script data. Cancellation generations and task cancellation prevent stale workers from applying results after a wipe.

Successful broadcast calls `completedCancellation()` for either action. Returning to Welcome clears the session. A background deadline of 60 seconds and the system background-task expiration handler also clear it. Retryable errors may retain material until the user retries, changes key, exits, or the session expires.

## Discovery

`PublicScanPlan` describes the applicable standard or custom paths. Defaults use one account, all applicable types, and 20 initial addresses on each receive/change branch. `GapScanner` queries the union of script hashes, preserving a mapping to the selected paths. It extends used tails in groups of 20, capped at 1,000 indices per branch, and fetches UTXOs in batches.

`ElectrumClient` matches replies by JSON-RPC ID, handles per-item failures, and adapts batch sizes to server behavior. The server pool checks batching support; membership in the bundled Muun-derived list alone does not prove availability or capacity. The list is a pinned snapshot, not a live directory.

## Replacement and broadcast

The review model prepares a plan from original inputs, verified funding data, owned destinations, original fee, and linked descendants. Cancel returns the remainder to an owned destination. Speed up keeps recipient scripts and deducts the increase from change, or from the supported single-recipient amount when no change exists. Dust change may be absorbed into the fee.

After device-owner authentication, signing work creates the transaction using the appropriate ECDSA or Schnorr path. `ReplacementCheck` validates the signed result against the plan before transmission. The configured mempool-compatible API handles action fees, broadcast, and status with Electrum fallback. The locally calculated transaction ID must match a successful server response; an already-known response is handled separately.

Confirmation is public status and can continue after keys are wiped. Network acceptance is not final settlement: competing transactions and miner policy remain outside the app's control.

## Navigation and test boundaries

The root owns typed routes. Native back actions and edge swipes update the same route state. Broadcast blocks leaving the in-progress operation; after secrets are wiped, result back-navigation avoids restoring a stale signing review.

`PreviewContent` includes synthetic Debug fixtures. Live surveys, loopback transport adversaries, and regtest tests are opt-in. See [Testing](TESTING.md) and [Security](../SECURITY.md).
