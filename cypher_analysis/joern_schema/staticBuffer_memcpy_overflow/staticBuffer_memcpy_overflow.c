#include <string.h>
#include <stdlib.h>

void bad_memcpy_overwrite() { /*DETECTA*/
    char buffer[32];
    char source[256];
    memcpy(buffer, source, 256);
}

void bad_memcpy_overead() { /*DETECTA*/
    char buffer[256];
    char source[32];
    memcpy(buffer, source, 256);
}

void bad_memcpy_both() { /*DETECTA*/
    char buffer[32];
    char source[32];
    memcpy(buffer, source, 256);
}

void bad_memcpy_overwrite2() { /*DETECTA*/
    char buffer[32];
    char source[256];
    char *ptr = buffer;
    memcpy(ptr, source, 256);
}

void bad_memcpy_overead2() { /*DETECTA*/
    char buffer[256];
    char source[32];
    char *ptr = source;
    memcpy(buffer, ptr, 256);
}

void good_memcpy() { /*NO DETECTA*/
    char buffer[256];
    char source[100];
    memcpy(buffer, source, 100);
}

void good_strncpy() { /*NO DETECTA*/
    char buffer[64];
    strncpy(buffer, "Hello World", 64);
}

void bad_strncpy() { /*DETECTA*/
    char buffer[64];
    strncpy(buffer, "Hello World", 128);
}

void copy_first_100B(char *dest, const char *src) {
    memcpy(dest, src, 100);
}

void bad_ipa_overwrite() { /*DETECTA*/
    char buffer[32];
    char source[256];
    copy_first_100B(buffer, source);
}

void bad_ipa_overead() { /*DETECTA*/
    char buffer[256];
    char source[32];
    copy_first_100B(buffer, source);
}

void good_ipa() { /*NO DETECTA*/
    char buffer[256];
    const char *data = "Hello";
    copy_first_100B(buffer, data);
}
