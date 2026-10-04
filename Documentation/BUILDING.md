# Building Takeback

The app uses Swift 6, SwiftUI, UIKit, C, and C++. Its deployment target is iOS 17.0 for iPhone and iPad. Use Xcode 26.6 or newer. The publication checks use the exact toolchains listed in [Validation](VALIDATION.md).

## Open the project

```sh
git clone https://github.com/devdasx/takeback.git
cd takeback
open Takeback.xcodeproj
```

Select the **Takeback** scheme. Choose an installed iOS simulator for local development. Running on a physical device requires your Apple development signing setup; set your own team and unique bundle identifier in Xcode. The repository does not include signing credentials.

Vendored crypto sources, fonts, the BIP39 wordlist, and the server-list snapshot are included. Building the app does not download Swift packages. Xcode and its SDKs must already be installed.

## Command-line build

```sh
xcodebuild -project Takeback.xcodeproj -scheme Takeback \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

An unsigned build proves compilation; it does not produce an installable App Store release. To choose a non-default Xcode, set `DEVELOPER_DIR` to that installation's `Contents/Developer` directory for the command.

## Regenerate with XcodeGen

[`project.yml`](../project.yml) is the project definition. The generated `.xcodeproj` is committed so opening the app does not require XcodeGen.

```sh
brew install xcodegen
xcodegen generate
```

Regenerate after adding files or changing build settings and include both the specification and generated project in your change. XcodeGen may overwrite local signing edits; keep credentials outside version control.

## Configuration

| Setting | Location | Purpose |
| --- | --- | --- |
| Bundle identifier | `project.yml` | `app.takeback.ios`; change for your own distribution |
| Source URL | `TAKEBACK_SOURCE_URL` in `project.yml` | Public repository links in the app |
| Version / build | `project.yml` | `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` |
| Mempool API / Electrum endpoints | In-app Settings | Runtime network preferences |
| Initial account count / address depth | In-app search settings | Numeric defaults; keys are never persisted |

The current source does not bundle approved Terms text. The Terms row stays disabled until the owner supplies that resource. Do not substitute invented legal terms.

## Troubleshooting

- **SDK or simulator unavailable:** install the needed platform in Xcode Settings and use a destination shown by `xcodebuild -showdestinations`.
- **Signing failure:** use `CODE_SIGNING_ALLOWED=NO` for compilation, or configure your own team for a device build.
- **Missing source after an edit:** regenerate the project from `project.yml`.
- **Server unavailable:** inspect connection results in Settings. Public server availability and policy can change.
- **Regtest TLS file missing:** run `sh Regtest/generate-test-certificate.sh` before starting the local mock or Docker stack.

See [Testing](TESTING.md) before running integration tests. Test keys are public fixtures and must never hold real funds.
