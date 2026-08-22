#include <string.h>
#include <stdlib.h>

void bad_memcpy() { /*DETECTA*/
    char buffer[32];
    char source[256];
    memcpy(buffer, source, 256);
}

void good_memcpy() { /*NO DETECTA*/
    char buffer[256];
    char source[100];
    memcpy(buffer, source, 100);
}

void good_strncpy() { /*NO DETECTA*/
    char buffer[64];
    const char *source = "Hello World";
    strncpy(buffer, source, 64);
}

void bad_strncpy() { /*DETECTA*/
    char buffer[64];
    const char *source = "Hello World";
    strncpy(buffer, source, 128);
}

void copy_first_100B(char *dest, const char *src) {
    memcpy(dest, src, 100);
}

void bad_ipa() { /*DETECTA*/
    char buffer[32];
    const char *data = "X";
    copy_first_100B(buffer, data);
}

void good_ipa() { /*NO DETECTA*/
    char buffer[256];
    const char *data = "Hello";
    copy_first_100B(buffer, data);
}
