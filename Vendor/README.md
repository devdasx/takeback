# Fingerprint dependencies

Unmodified source files, pinned for reproducible offline builds:

- bitcoin-core/secp256k1 v0.8.0, commit `6e2c8bc4ecdc6e71dbe7a368f360d8d453ce435d`.
  https://github.com/bitcoin-core/secp256k1/tree/v0.8.0
  Only root headers, public headers, and the three library translation units are vendored.
  The pinned extrakeys and schnorrsig modules are enabled for BIP86 cancellation signing. Upstream defaults select field/scalar implementations and tables.
- Bitcoin Core v29.0: RIPEMD-160 plus its common/endian/byteswap headers.
  https://github.com/bitcoin/bitcoin/tree/v29.0/src/crypto

Both MIT licenses are included. SHA256SUMS records the imported source files.
Apple CommonCrypto provides PBKDF2-HMAC-SHA512, HMAC-SHA512 and SHA256.
