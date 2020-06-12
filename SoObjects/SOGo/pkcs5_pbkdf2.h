#ifndef PKCS5_PBKDF2_H
#define PKCS5_PBKDF2_H

#include <stddef.h>
#include <stdint.h>

#define PBKDF2_KEY_SIZE_SHA1 (20)
#define PBKDF2_SALT_LEN (16)
#define PBKDF2_DEFAULT_ROUNDS (5000)

int
pkcs5_pbkdf2(const char *pass, size_t pass_len, const uint8_t *salt,
    size_t salt_len, uint8_t *key, size_t key_len, unsigned int rounds);

#endif /* ! PKCS5_PBKDF2_H */