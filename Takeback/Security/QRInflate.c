#include "QRInflate.h"
#include "SecureMemory.h"
#include <zlib.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
// zlib's history window can contain decoded key bytes; zero its own allocations too.
static voidpf secure_alloc(voidpf opaque, uInt items, uInt size) {
    (void)opaque;
    if (size && items > (SIZE_MAX - sizeof(size_t)) / size) return NULL;
    size_t count = (size_t)items * size;
    size_t *block = calloc(1, sizeof(size_t) + count);
    if (!block) return NULL;
    *block = count; return block + 1;
}
static void secure_free(voidpf opaque, voidpf ptr) {
    (void)opaque;
    if (!ptr) return;
    size_t *block = (size_t *)ptr - 1;
    takeback_secure_zero(ptr, *block); takeback_secure_zero(block, sizeof(size_t)); free(block);
}
int takeback_qr_inflate(const uint8_t *source, size_t count, uint8_t *target, size_t capacity, size_t *written) {
    *written = 0;
    if (!source || !target || count > UINT32_MAX || capacity > UINT32_MAX) return 0;
    z_stream stream = {0}; stream.zalloc = secure_alloc; stream.zfree = secure_free;
    stream.next_in = (Bytef *)source; stream.avail_in = (uInt)count;
    stream.next_out = target; stream.avail_out = (uInt)capacity;
    if (inflateInit2(&stream, -10) != Z_OK) return 0;
    int status = inflate(&stream, Z_FINISH);
    int valid = status == Z_STREAM_END && stream.avail_in == 0;
    if (valid) *written = stream.total_out;
    inflateEnd(&stream); takeback_secure_zero(&stream, sizeof(stream));
    return valid;
}
