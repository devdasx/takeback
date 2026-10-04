#include "SecureMemory.h"

void takeback_secure_zero(void *memory, size_t count) {
    /* Volatile stores are observable side effects and cannot be optimized away. */
    volatile unsigned char *cursor = (volatile unsigned char *)memory;
    while (count--) { *cursor++ = 0; }
}
