#ifndef TAKEBACK_MASTER_FINGERPRINT_H
#define TAKEBACK_MASTER_FINGERPRINT_H
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
// Inputs must already be NFKD UTF-8. Output is public, four bytes, big-endian display order.
int takeback_master_fingerprint(const uint8_t *mnemonic, size_t mnemonic_count,
                               const uint8_t *passphrase, size_t passphrase_count,
                               uint8_t output[4]);
#ifdef __cplusplus
}
#endif
#endif
