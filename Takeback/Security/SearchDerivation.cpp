#include "SearchDerivation.h"
extern "C" {
#include "SecureMemory.h"
}
#include <CommonCrypto/CommonCrypto.h>
#include <Security/SecRandom.h>
#include <secp256k1.h>
#include <crypto/ripemd160.h>
#include <cstring>
#include <cstdlib>
namespace {
struct Scratch {
    uint8_t node[64]{}, message[37]{}, digest[64]{}, random[32]{};
    ~Scratch() { takeback_secure_zero(this, sizeof(*this)); }
};
struct Context {
    secp256k1_context *p = secp256k1_context_create(SECP256K1_CONTEXT_NONE);
    ~Context() { if (p) secp256k1_context_destroy(p); }
};
void hash160(const uint8_t *data, size_t size, uint8_t out[20]) {
    uint8_t sha[32]; CC_SHA256(data, (CC_LONG)size, sha);
    CRIPEMD160().Write(sha, 32).Finalize(out);
}
}
int takeback_bip39_seed(const uint8_t *words, size_t word_count, const uint8_t *phrase, size_t phrase_count, uint8_t seed[64]) {
    memset(seed, 0, 64);
    if (!words || !word_count || phrase_count > SIZE_MAX - 8) return 0;
    auto salt = static_cast<uint8_t *>(malloc(phrase_count + 8));
    if (!salt) return 0;
    memcpy(salt, "mnemonic", 8);
    if (phrase_count) memcpy(salt + 8, phrase, phrase_count);
    Scratch s;
    int status = CCKeyDerivationPBKDF(kCCPBKDF2, (const char *)words, word_count, salt, phrase_count + 8,
                                     kCCPRFHmacAlgSHA512, 2048, s.digest, 64);
    takeback_secure_zero(salt, phrase_count + 8); free(salt);
    if (status != kCCSuccess) return 0;
    memcpy(seed, s.digest, 64); return 1;
}
int takeback_bip32_master(const uint8_t *seed, size_t count, uint8_t root[64]) {
    CCHmac(kCCHmacAlgSHA512, "Bitcoin seed", 12, seed, count, root);
    if (!secp256k1_ec_seckey_verify(secp256k1_context_static, root)) { takeback_secure_zero(root,64); return 0; }
    return 1;
}
int takeback_search_master(const uint8_t *words, size_t word_count, const uint8_t *phrase, size_t phrase_count, uint8_t root[64]) {
    Scratch s;
    if (!takeback_bip39_seed(words,word_count,phrase,phrase_count,s.digest)) return 0;
    return takeback_bip32_master(s.digest,64,root);
}
int takeback_bip32_node(const uint8_t root[64], const uint32_t *path, size_t path_count, uint8_t out[64]) {
    if (path_count > 255) return 0;
    Scratch s; memcpy(s.node, root, 64);
    Context ctx;
    if (!ctx.p || SecRandomCopyBytes(kSecRandomDefault, 32, s.random) != errSecSuccess || !secp256k1_context_randomize(ctx.p, s.random)) return 0;
    secp256k1_pubkey pub;
    uint8_t encoded[65]; size_t length;
    for (size_t i = 0; i < path_count; ++i) {
        if (path[i] & 0x80000000) { s.message[0] = 0; memcpy(s.message + 1, s.node, 32); }
        else {
            if (!secp256k1_ec_pubkey_create(ctx.p, &pub, s.node)) return 0;
            length = 33;
            if (!secp256k1_ec_pubkey_serialize(ctx.p, s.message, &length, &pub, SECP256K1_EC_COMPRESSED)) return 0;
        }
        for (int b = 0; b < 4; ++b) s.message[33+b] = uint8_t(path[i] >> (24 - 8*b));
        CCHmac(kCCHmacAlgSHA512, s.node + 32, 32, s.message, 37, s.digest);
        // Invalid BIP32 children fail the search rather than silently changing the requested index.
        if (!secp256k1_ec_seckey_tweak_add(ctx.p, s.node, s.digest)) return 0;
        memcpy(s.node + 32, s.digest + 32, 32);
    }
    memcpy(out, s.node, 64); return 1;
}
int takeback_search_script(const uint8_t root[64], const uint32_t *path, size_t path_count, int purpose, int compressed, uint8_t script[34], size_t *script_count) {
    *script_count = 0;
    if (path_count > 7) return 0;
    Scratch s; Context ctx; secp256k1_pubkey pub;
    uint8_t encoded[65]; size_t length;
    if (!takeback_bip32_node(root,path,path_count,s.node)) return 0;
    if (!secp256k1_ec_pubkey_create(ctx.p, &pub, s.node)) return 0;
    length = compressed ? 33 : 65;
    if (!secp256k1_ec_pubkey_serialize(ctx.p, encoded, &length, &pub, compressed ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED)) return 0;
    uint8_t hash[20];
    if (purpose == 86) {
        // BIP340 lift_x: normalize to the even-Y internal public key, then TapTweak.
        if (encoded[0] == 3 && !secp256k1_ec_pubkey_negate(ctx.p, &pub)) return 0;
        uint8_t tag[32], input[96], tweak[32];
        CC_SHA256("TapTweak", 8, tag);
        memcpy(input, tag, 32); memcpy(input + 32, tag, 32); memcpy(input + 64, encoded + 1, 32);
        CC_SHA256(input, 96, tweak);
        if (!secp256k1_ec_pubkey_tweak_add(ctx.p, &pub, tweak)) return 0;
        length = 33;
        if (!secp256k1_ec_pubkey_serialize(ctx.p, encoded, &length, &pub, SECP256K1_EC_COMPRESSED)) return 0;
        script[0] = 0x51; script[1] = 32; memcpy(script + 2, encoded + 1, 32); *script_count = 34;
    } else {
        hash160(encoded, length, hash);
        if (purpose == 84) { script[0] = 0; script[1] = 20; memcpy(script + 2, hash, 20); *script_count = 22; }
        else if (purpose == 49) {
            uint8_t redeem[22]{0,20}; memcpy(redeem + 2, hash, 20); hash160(redeem, 22, hash);
            script[0] = 0xa9; script[1] = 20; memcpy(script + 2, hash, 20); script[22] = 0x87; *script_count = 23;
        } else if (purpose == 44) {
            script[0] = 0x76; script[1] = 0xa9; script[2] = 20; memcpy(script + 3, hash, 20);
            script[23] = 0x88; script[24] = 0xac; *script_count = 25;
        } else return 0;
    }
    return 1;
}

int takeback_account_public(const uint8_t root[64], const uint32_t *path, size_t path_count, uint8_t account[65]) {
    if (path_count > 6) return 0;
    Scratch s; Context ctx; secp256k1_pubkey pub; size_t length;
    if (!takeback_bip32_node(root,path,path_count,s.node)) return 0;
    if (!secp256k1_ec_pubkey_create(ctx.p, &pub, s.node)) return 0;
    length = 33;
    if (!secp256k1_ec_pubkey_serialize(ctx.p, account, &length, &pub, SECP256K1_EC_COMPRESSED)) return 0;
    memcpy(account + 33, s.node + 32, 32);
    return 1;
}
int takeback_public_script(const uint8_t account[65], uint32_t branch, uint32_t index, int purpose, uint8_t script[34], size_t *script_count) {
    if ((branch > 1 && branch != UINT32_MAX) || index >= 0x80000000) return 0;
    Context ctx; secp256k1_pubkey pub; size_t length = 33;
    if (!secp256k1_ec_pubkey_parse(ctx.p, &pub, account, 33)) return 0;
    uint8_t chain[32], message[37], digest[64], encoded[65];
    memcpy(chain, account + 33, 32);
    uint32_t path[2]{branch, index};
    for (size_t step = branch == UINT32_MAX ? 1 : 0; step < 2; ++step) {
        uint32_t child = path[step];
        length = 33;
        if (!secp256k1_ec_pubkey_serialize(ctx.p, message, &length, &pub, SECP256K1_EC_COMPRESSED)) return 0;
        for (int b = 0; b < 4; ++b) message[33+b] = uint8_t(child >> (24 - 8*b));
        CCHmac(kCCHmacAlgSHA512, chain, 32, message, 37, digest);
        if (!secp256k1_ec_pubkey_tweak_add(ctx.p, &pub, digest)) return 0;
        memcpy(chain, digest + 32, 32);
    }
    length = 33;
    if (!secp256k1_ec_pubkey_serialize(ctx.p, encoded, &length, &pub, SECP256K1_EC_COMPRESSED)) return 0;
    uint8_t hash[20];
    if (purpose == 86) {
        // BIP340 lift_x: normalize to the even-Y internal public key, then TapTweak.
        if (encoded[0] == 3 && !secp256k1_ec_pubkey_negate(ctx.p, &pub)) return 0;
        uint8_t tag[32], input[96], tweak[32];
        CC_SHA256("TapTweak", 8, tag);
        memcpy(input, tag, 32); memcpy(input + 32, tag, 32); memcpy(input + 64, encoded + 1, 32);
        CC_SHA256(input, 96, tweak);
        if (!secp256k1_ec_pubkey_tweak_add(ctx.p, &pub, tweak)) return 0;
        length = 33;
        if (!secp256k1_ec_pubkey_serialize(ctx.p, encoded, &length, &pub, SECP256K1_EC_COMPRESSED)) return 0;
        script[0] = 0x51; script[1] = 32; memcpy(script + 2, encoded + 1, 32); *script_count = 34;
    } else {
        hash160(encoded, length, hash);
        if (purpose == 84) { script[0] = 0; script[1] = 20; memcpy(script + 2, hash, 20); *script_count = 22; }
        else if (purpose == 49) {
            uint8_t redeem[22]{0,20}; memcpy(redeem + 2, hash, 20); hash160(redeem, 22, hash);
            script[0] = 0xa9; script[1] = 20; memcpy(script + 2, hash, 20); script[22] = 0x87; *script_count = 23;
        } else if (purpose == 44) {
            script[0] = 0x76; script[1] = 0xa9; script[2] = 20; memcpy(script + 3, hash, 20);
            script[23] = 0x88; script[24] = 0xac; *script_count = 25;
        } else return 0;
    }
    return 1;
}
