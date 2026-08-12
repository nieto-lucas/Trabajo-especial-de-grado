// Ejemplos de strncpy-no-null-term https://queries.joern.io/
// Autor: @fabsx00

#include <stdlib.h>
#include <string.h>

// If src points to a string that is at least `asize` long,
// then `ptr` will not be null-terminated after the `strncpy`
// call.
int bad() {
    char *ptr = malloc(asize);
    strncpy(ptr, src, asize);
}

// Null-termination is ensured if we can only copy
// less than `asize + 1` into the buffer
int good() {
    char *ptr = malloc(asize + 1);
    strncpy(ptr, src, asize);
}

// Null-termination is also ensured if it is performed
// explicitly
int alsogood() {
    char *ptr = malloc(asize);
    strncpy(ptr, src, asize);
    ptr[asize - 1] = '\0';
}