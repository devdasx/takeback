# Third-party notices

Upstream licenses remain in force for the material listed below. Keep the accompanying license texts when redistributing source or binaries. This index does not replace those texts.

| Component | Included material / provenance | License |
| --- | --- | --- |
| [libsecp256k1](https://github.com/bitcoin-core/secp256k1) | v0.8.0; commit `6e2c8bc4ecdc6e71dbe7a368f360d8d453ce435d`; ECDSA, extrakeys, Schnorr | [MIT](Vendor/secp256k1/COPYING) |
| [Bitcoin Core](https://github.com/bitcoin/bitcoin/tree/v29.0) | v29.0 RIPEMD-160 and supporting headers | [MIT](Vendor/bitcoin-core/COPYING) |
| [Muun recovery](https://github.com/muun/recovery) | Electrum server-list snapshot at `a33c463793c025937693a7dc5a67d5e16d076c3e` | [MIT](Takeback/Resources/MuunRecoveryLicense.txt) |
| [Blockchain Commons URKit](https://github.com/BlockchainCommons/URKit) | Reference portions: PRNG, alias sampler, Bytewords; revision `ebba59b2e1538cb368d98147dd58c452e6d1dc47` | [BSD-2-Clause-Patent](Takeback/Resources/ScannerNotices.txt) |
| [Coinkite BBQr](https://github.com/coinkite/BBQr) | Multipart QR format reference | [Public-domain notice](Takeback/Resources/ScannerNotices.txt) |
| [Geist by Vercel](https://github.com/vercel/geist-font) | Unmodified static fonts; revision `10dc7658f13c38a474cde201bb09a4617267545b` | [SIL Open Font License 1.1](Takeback/Resources/Fonts/OFL.txt) |
| [BIP39](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki) | Standard English mnemonic wordlist | [MIT notice](Takeback/Resources/BIP39License.txt), [provenance](Takeback/Resources/BIP39/NOTICE.txt) |

`Vendor/SHA256SUMS` records imported cryptographic source files. Run `shasum -a 256 -c Vendor/SHA256SUMS` from the repository root to check them. Apple system frameworks supply CommonCrypto, CryptoKit, LocalAuthentication, camera/photo support, and system UI; they are not vendored here. zlib is linked from the platform.

The application also bundles notices for display in **Settings → About → Open-source licenses**. Public test vectors are identified in the fixture source and generator scripts. They are test material and must never be used with funds.
