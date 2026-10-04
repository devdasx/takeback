#include "CancellationCrypto.h"
extern "C" {
#include "SecureMemory.h"
}
#include <CommonCrypto/CommonCrypto.h>
#include <Security/SecRandom.h>
#include <secp256k1.h>
#include <secp256k1_extrakeys.h>
#include <secp256k1_schnorrsig.h>
#include <cstring>
namespace {
struct State {
    uint8_t node[64]{}, message[37]{}, digest[64]{}, random[32]{}, extra[32]{};
    secp256k1_keypair pair{};
    secp256k1_context *ctx = secp256k1_context_create(SECP256K1_CONTEXT_NONE);
    ~State() { if(ctx) secp256k1_context_destroy(ctx); takeback_secure_zero(this, sizeof(*this)); }
    bool derive(const uint8_t root[64], const uint32_t *path, size_t count) {
        if (!ctx || count > 7 || SecRandomCopyBytes(kSecRandomDefault,32,random) != errSecSuccess || !secp256k1_context_randomize(ctx,random)) return false;
        memcpy(node,root,64);
        for(size_t i=0;i<count;i++) {
            if(path[i]&0x80000000) { message[0]=0; memcpy(message+1,node,32); }
            else { secp256k1_pubkey pub; size_t n=33; if(!secp256k1_ec_pubkey_create(ctx,&pub,node) || !secp256k1_ec_pubkey_serialize(ctx,message,&n,&pub,SECP256K1_EC_COMPRESSED)) return false; }
            for(int b=0;b<4;b++) message[33+b]=uint8_t(path[i]>>(24-8*b));
            CCHmac(kCCHmacAlgSHA512,node+32,32,message,37,digest);
            if(!secp256k1_ec_seckey_tweak_add(ctx,node,digest)) return false;
            memcpy(node+32,digest+32,32);
        }
        return secp256k1_ec_seckey_verify(ctx,node);
    }
};
}
int takeback_public(const uint8_t root[64], const uint32_t *path, size_t count, int compressed, uint8_t out[65], size_t *size) {
    *size=0; State s; if(!s.derive(root,path,count)) return 0;
    secp256k1_pubkey pub; if(!secp256k1_ec_pubkey_create(s.ctx,&pub,s.node)) return 0;
    *size=compressed?33:65; return secp256k1_ec_pubkey_serialize(s.ctx,out,size,&pub,compressed?SECP256K1_EC_COMPRESSED:SECP256K1_EC_UNCOMPRESSED);
}
int takeback_sign(const uint8_t root[64], const uint32_t *path, size_t count, int taproot, const uint8_t digest[32], uint8_t out[72], size_t *size) {
    *size=0; State s; if(!s.derive(root,path,count)) return 0;
    if(taproot) {
        if(!secp256k1_keypair_create(s.ctx,&s.pair,s.node)) return 0;
        secp256k1_xonly_pubkey pub; uint8_t input[96],tweak[32];
        if(!secp256k1_keypair_xonly_pub(s.ctx,&pub,nullptr,&s.pair) || !secp256k1_xonly_pubkey_serialize(s.ctx,input+64,&pub)) return 0;
        CC_SHA256("TapTweak",8,input); memcpy(input+32,input,32); CC_SHA256(input,96,tweak);
        if(!secp256k1_keypair_xonly_tweak_add(s.ctx,&s.pair,tweak) || !secp256k1_schnorrsig_sign32(s.ctx,out,digest,&s.pair,s.random)) return 0;
        *size=64; return 1;
    }
    // Low-R and low-S DER, with fixed 70-byte encoding: the preview and signed vsize agree exactly.
    for(uint32_t counter=0;counter<1024;counter++) {
        for(int b=0;b<4;b++) s.extra[b]=uint8_t(counter>>(8*b));
        secp256k1_ecdsa_signature sig;
        if(!secp256k1_ecdsa_sign(s.ctx,&sig,digest,s.node,nullptr,counter?s.extra:nullptr)) return 0;
        *size=72; if(!secp256k1_ecdsa_signature_serialize_der(s.ctx,out,size,&sig)) return 0;
        if(*size==70 && out[3]==32 && out[37]==32) return 1;
    }
    *size=0; return 0;
}
int takeback_schnorr_verify_message(const uint8_t pub[32], const uint8_t *message, size_t message_count, const uint8_t signature[64]) {
    secp256k1_xonly_pubkey key;
    return secp256k1_xonly_pubkey_parse(secp256k1_context_static,&key,pub) && secp256k1_schnorrsig_verify(secp256k1_context_static,signature,message,message_count,&key);
}
int takeback_verify(const uint8_t *pub, size_t pubsize, const uint8_t digest[32], const uint8_t *sig, size_t size, int schnorr) {
    if(schnorr) {
        secp256k1_xonly_pubkey key;
        return pubsize==32 && size==64 && takeback_schnorr_verify_message(pub,digest,32,sig);
    }
    secp256k1_pubkey key; secp256k1_ecdsa_signature signature;
    return secp256k1_ec_pubkey_parse(secp256k1_context_static,&key,pub,pubsize) && secp256k1_ecdsa_signature_parse_der(secp256k1_context_static,&signature,sig,size) && secp256k1_ecdsa_verify(secp256k1_context_static,&signature,digest,&key);
}
#include <crypto/ripemd160.h>
extern "C" void takeback_hash160(const uint8_t *data, size_t size, uint8_t out[20]) {
    uint8_t hash[32]; CC_SHA256(data,(CC_LONG)size,hash); CRIPEMD160().Write(hash,32).Finalize(out);
}
