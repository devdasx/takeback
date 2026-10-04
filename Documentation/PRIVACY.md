# Privacy and data flow

This document describes the checked-in implementation. It is not a promise about a modified fork, third-party server, operating system, or hosted build.

## Data on the device

Takeback has no app account system and includes no analytics or advertising SDK. Imported keys and passphrases live in the ephemeral session rather than files, UserDefaults, Keychain, or an app database. The application does not intentionally log them or send them to a service.

App-owned secret buffers are zeroed, and registered native editors are cleared during session cleanup. UIKit, Swift strings, camera/photo APIs, and the operating system can hold copies the app cannot reliably overwrite. A force-quit is not a guaranteed cleanup callback. The app-switcher privacy cover also does not prevent someone photographing the screen.

Network preferences, fee preferences, Electrum certificate pins, and numeric account/depth defaults can persist. Per-session keys, passphrases, and custom path selections are not saved as wallet history. Selecting a photo imports it for scanning; Takeback does not delete the original image from Photos. Pasting does not promise to erase the original clipboard or its source.

## Data sent over the network

| Recipient | Data / purpose |
| --- | --- |
| Electrum servers | Script hashes for history and UTXO lookup; transaction IDs, public transaction data, fee/status requests, and signed transaction broadcasts on fallback |
| Configured mempool-compatible API | Fee estimates, transaction status queries, and signed transaction broadcasts |
| mempool.space price endpoint | Optional USD price request |
| Explorer / GitHub | A normal browser request when the user opens the corresponding link |

Script hashes are not anonymity: servers can associate queries, infer public addresses, and observe connection metadata such as IP addresses. A signed transaction contains public Bitcoin data, not the private key, but its disclosure is still meaningful financial information.

## Your server and Tor

Settings accepts custom endpoints and certain onion addresses. The app does **not** include a Tor client or configure a SOCKS proxy. An onion address requires an appropriate external network setup; entering one alone does not create anonymity or connectivity.

Self-signed Electrum endpoints use first-use certificate pinning. First use is a trust decision; a stored pin can detect later changes but cannot authenticate an endpoint before that first connection.

## Reports and support

Do not submit private keys, recovery phrases, passphrases, clipboard contents, Photos exports, or unredacted logs in issues or pull requests. A public transaction ID or address can reveal financial activity; share only what is necessary and what you are comfortable making public. See [Security](../SECURITY.md) for vulnerability reports.
