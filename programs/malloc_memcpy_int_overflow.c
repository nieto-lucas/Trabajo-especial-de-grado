#include <stdlib.h>
#include <string.h>

void sum_noteq(size_t len, char *src) { /*DETECTA*/
    char *dst = malloc(len + 8);
    memcpy(dst, src, len + 7);
}

void sub_noteq(size_t len, char *src) { /*DETECTA*/
    char *dst = malloc(len - 8);
    memcpy(dst, src, len - 7);
}

void mul_noteq(size_t len, char *src) { /*DETECTA*/
    char *dst = malloc(len * 8);
    memcpy(dst, src, len * 7);
}

void div_noteq(size_t len, char *src) { /*DETECTA*/
    char *dst = malloc(len / 8);
    memcpy(dst, src, len / 7);
}

void const_case(size_t len, char *src) { /*NO DETECTA*/
    char *dst = malloc(some_size);
    memcpy(dst, src, some_size);
}

void sum_eq(size_t len, char *src) { /*NO DETECTA*/
    char *dst = malloc(len + 8);
    memcpy(dst, src, len + 8);
}

void sub_eq(size_t len, char *src) { /*NO DETECTA*/
    char *dst = malloc(len - 8);
    memcpy(dst, src, len - 8);
}

void mul_eq(size_t len, char *src) { /*NO DETECTA*/
    char *dst = malloc(len * 8);
    memcpy(dst, src, len * 8);
}

void div_eq(size_t len, char *src) { /*NO DETECTA*/
    char *dst = malloc(len / 8);
    memcpy(dst, src, len / 8);
}
