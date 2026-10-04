# Testing Takeback

Use public fixtures only. Tests are split into deterministic checks, UI checks, local protocol tests, and opt-in network/regtest tests. A skipped integration test is not a pass.

## Fast checks without a simulator

From the repository root with Xcode selected:

```sh
sh Scripts/validate-key-vectors.sh
shasum -a 256 -c Vendor/SHA256SUMS
python3 Scripts/check-publication.py
```

The standalone Swift checker exercises 68 key-detection vectors and checks owned input preservation and zeroing. It is not the full XCTest suite. The publication checker verifies repository hygiene and local documentation links; it is not a general secret scanner or a security audit.

Compile app and test targets without running a simulator:

```sh
xcodebuild build-for-testing -project Takeback.xcodeproj -scheme Takeback \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/Tests CODE_SIGNING_ALLOWED=NO
```

For a separate credential-pattern scan with Gitleaks installed, run `gitleaks git . --redact` after committing. `.gitleaks.toml` narrowly documents the reviewed public regtest credential, preference-key false positive, and official HD test-vector fixture. Do not add broad allowlists for new findings.

## Targeted XCTest

Choose an installed destination from `xcodebuild -showdestinations -project Takeback.xcodeproj -scheme Takeback` and substitute its ID:

```sh
xcodebuild test -project Takeback.xcodeproj -scheme Takeback \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_ID' \
  -derivedDataPath build/Tests -resultBundlePath build/UnitTests.xcresult \
  CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO \
  -only-testing:TakebackTests/KeyDetectionTests \
  -only-testing:TakebackTests/MasterVectorTests \
  -only-testing:TakebackTests/SpeedUpTests \
  -only-testing:TakebackTests/SearchPathsTests
```

Use a fresh result-bundle path for each run. Other focused suites cover passphrase cleanup, scanner decoding, Electrum ID matching/failover, fee policy, classification, settings, and result state. Select relevant classes rather than treating a compilation check as execution coverage.

## Native interaction checks

`TakebackUITests/NativeNavigationUITests.swift` covers native back/edge gestures, keyboard behavior, sheets, scanner return, finding cancellation, review/result routes, and navigation blocking during broadcast. Other UI suites cover the corresponding features and accessibility states.

Run a selected method with `-only-testing:TakebackUITests/NativeNavigationUITests/METHOD_NAME` on the affected simulator. UI fixtures use synthetic data. Do not run against a real imported wallet. Simulator tests do not validate physical camera, torch, haptics, Secure Enclave hardware, or every device size.

## Local Electrum protocol adversary

Generate a disposable self-signed certificate and start the loopback-only mock:

```sh
sh Regtest/generate-test-certificate.sh
python3 Scripts/electrum-mock.py
```

It listens on TLS ports 52102/52103 and TCP 52104. It deliberately shuffles responses, drops oversized requests, returns per-item errors, and holds a request for cancellation testing. No wallet or broadcast methods are exposed.

Set `TAKEBACK_MASTER_TRANSPORT=1` in the **Takeback scheme → Test → Arguments → Environment Variables**, then run `TakebackTests/MasterTransportTests`. Remove the opt-in afterward. The test validates framing, adaptive batch reduction, failover, cancellation, and certificate pin changes.

## Bitcoin Core + Fulcrum regtest

Requirements: Docker with Compose, OpenSSL, and curl. This starts a local Bitcoin Core 28.0 regtest node and a Fulcrum container. The Fulcrum Dockerfile currently uses the upstream `latest` tag; pin an image digest if you need repeatable infrastructure. Public Docker images must be downloaded on the first run.

```sh
sh Regtest/run-regtest.sh
```

Host ports are bound to `127.0.0.1`: RPC 52443 and Electrum TLS 52002. The public `unsend:regtest-only` RPC credential is deliberately retained for fixture compatibility and is not a production secret. The generated TLS key stays untracked. Docker volumes keep disposable regtest chain state between runs.

Set `TAKEBACK_MASTER_REGTEST=1` in the test scheme and run `TakebackTests/MasterRegtestTests`. The suite verifies the chain is regtest before writes. It creates and replaces transactions using public keys, exercises the four HD types, linked transactions, foreign inputs, insufficient funds, confirmation races, custom paths, and Speed up.

For the opt-in full UI integration, `Scripts/regtest-ui.py` additionally needs the Python `cryptography` package and runs the coordinator on loopback port 52110. Set `TAKEBACK_MASTER_UI=1` in the UI test environment and run `MasterRegtestUITests` only against that disposable stack.

Stop the stack without deleting its volumes:

```sh
docker compose -f Regtest/compose.yaml down
```

Earlier fixture helpers (`cancel-regtest.py` and `result-regtest.py`) use a separate `/tmp/Takeback-Cancel-Regtest` node and are not required by the main Docker suite. Read their module comments before use.

## Live read-only survey

`MasterLiveTests` requires `TAKEBACK_MASTER_LIVE=1`. It contacts public Electrum servers and exercises public history/UTXO lookups. Run it intentionally, not as an automatic PR check. Availability is time-dependent; a successful survey is not a mainnet broadcast test.

## Fixture generation

Fixtures are checked in. Regeneration is optional and should be reviewed separately. `generate_key_test_vectors.py` uses Python's standard library; fingerprint regeneration additionally uses `bip32`; custom-path regeneration uses `embit`. Use an isolated virtual environment, record dependency versions, and review resulting vectors before committing.

## CI scope

The GitHub workflow checks publication hygiene, vendored checksums, standalone key vectors, unsigned Release compilation, and compilation of test targets. It does not run UI, regtest, live-server, physical-device, or mainnet tests. See [Validation](VALIDATION.md) for actual publication results.
