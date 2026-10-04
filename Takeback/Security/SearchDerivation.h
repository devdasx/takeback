#ifndef TAKEBACK_SEARCH_DERIVATION_H
#define TAKEBACK_SEARCH_DERIVATION_H
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
int takeback_bip39_seed(const uint8_t *words, size_t word_count, const uint8_t *phrase, size_t phrase_count, uint8_t seed[64]);
int takeback_bip32_master(const uint8_t *seed, size_t count, uint8_t root[64]);
int takeback_bip32_node(const uint8_t root[64], const uint32_t *path, size_t path_count, uint8_t out[64]);
int takeback_search_master(const uint8_t *words, size_t word_count, const uint8_t *phrase, size_t phrase_count, uint8_t root[64]);
// root is scalar || chain code (64 bytes). A single key uses no path.
int takeback_search_script(const uint8_t root[64], const uint32_t *path, size_t path_count, int purpose, int compressed, uint8_t script[34], size_t *script_count);
int takeback_account_public(const uint8_t root[64], const uint32_t *path, size_t path_count, uint8_t account[65]);
// branch UINT32_MAX derives only index from a fixed-chain public node.
int takeback_public_script(const uint8_t account[65], uint32_t branch, uint32_t index, int purpose, uint8_t script[34], size_t *script_count);
#ifdef __cplusplus
}
#endif
#endif
