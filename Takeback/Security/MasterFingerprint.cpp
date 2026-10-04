#include "MasterFingerprint.h"
extern "C" {
#include "SecureMemory.h"
}
#include <CommonCrypto/CommonKeyDerivation.h>
#include <CommonCrypto/CommonCryptoError.h>
#include <CommonCrypto/CommonHMAC.h>
#include <CommonCrypto/CommonDigest.h>
#include <Security/SecRandom.h>
#include <secp256k1.h>
#include <crypto/ripemd160.h>
#include <sys/mman.h>
#include <cstdlib>
#include <cstring>

namespace {
// All application-owned intermediate secret storage is cleared on every return path.
struct Scratch {
    unsigned char seed[64]{}, master[64]{}, random[32]{};
    ~Scratch() { takeback_secure_zero(this, sizeof(*this)); }
};
struct Salt {
    unsigned char *data;
    size_t size;
    explicit Salt(size_t n) : data(static_cast<unsigned char *>(malloc(n))), size(n) {
        if (data) (void)mlock(data, size);
    }
    ~Salt() { if (data) { takeback_secure_zero(data, size); munlock(data, size); free(data); } }
};
struct Context {
    secp256k1_context *value = secp256k1_context_create(SECP256K1_CONTEXT_NONE);
    ~Context() { if (value) secp256k1_context_destroy(value); }
};
}

int takeback_master_fingerprint(const uint8_t *mnemonic, size_t mnemonic_count,
                               const uint8_t *passphrase, size_t passphrase_count,
                               uint8_t output[4]) {
    memset(output, 0, 4);
    if (!mnemonic || mnemonic_count == 0 || passphrase_count > SIZE_MAX - 8) return 0;
    Scratch scratch;
    Salt salt(passphrase_count + 8);
    if (!salt.data) return 0;
    memcpy(salt.data, "mnemonic", 8);
    if (passphrase_count) memcpy(salt.data + 8, passphrase, passphrase_count);
    if (CCKeyDerivationPBKDF(kCCPBKDF2, reinterpret_cast<const char *>(mnemonic), mnemonic_count,
                            salt.data, salt.size, kCCPRFHmacAlgSHA512, 2048,
                            scratch.seed, sizeof(scratch.seed)) != kCCSuccess) return 0;
    CCHmac(kCCHmacAlgSHA512, "Bitcoin seed", 12, scratch.seed, sizeof(scratch.seed), scratch.master);
    Context context;
    if (!context.value || SecRandomCopyBytes(kSecRandomDefault, sizeof(scratch.random), scratch.random) != errSecSuccess) return 0;
    if (!secp256k1_context_randomize(context.value, scratch.random)) return 0;
    secp256k1_pubkey public_key;
    if (!secp256k1_ec_pubkey_create(context.value, &public_key, scratch.master)) return 0;
    unsigned char serialized[33], sha[32], hash[20];
    size_t length = sizeof(serialized);
    if (!secp256k1_ec_pubkey_serialize(context.value, serialized, &length, &public_key, SECP256K1_EC_COMPRESSED)) return 0;
    CC_SHA256(serialized, static_cast<CC_LONG>(length), sha);
    CRIPEMD160().Write(sha, sizeof(sha)).Finalize(hash);
    memcpy(output, hash, 4);
    return 1;
}
