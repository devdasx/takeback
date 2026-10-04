#ifndef TAKEBACK_CANCELLATION_CRYPTO_H
#define TAKEBACK_CANCELLATION_CRYPTO_H
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
void takeback_hash160(const uint8_t *data, size_t size, uint8_t out[20]);
int takeback_sign(const uint8_t root[64], const uint32_t *path, size_t path_count, int taproot,
                  const uint8_t digest[32], uint8_t signature[72], size_t *signature_count);
int takeback_public(const uint8_t root[64], const uint32_t *path, size_t path_count, int compressed, uint8_t public_key[65], size_t *count);
int takeback_schnorr_verify_message(const uint8_t pub[32], const uint8_t *message, size_t message_count, const uint8_t signature[64]);
int takeback_verify(const uint8_t *public_key, size_t public_count, const uint8_t digest[32], const uint8_t *signature, size_t signature_count, int schnorr);
#ifdef __cplusplus
}
#endif
#endif
