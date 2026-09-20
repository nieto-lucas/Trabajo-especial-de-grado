// Ejemplos free-returned-value https://queries.joern.io/
// Autor: @maltek

#include <stdlib.h>

void bad(a_struct_type *a_struct) {
    void *x = NULL;
    a_struct->foo = x;
    free(x);
}

void good1(a_struct_type *a_struct) {
    void *x = NULL, *y = NULL;
    a_struct->foo = x;
    free(y);
}

void good2(a_struct_type *a_struct) {
    void *x = NULL;
    free(a_struct->foo);
    a_struct->foo = x;
}

void falseGood(a_struct_type *a_struct) {
    void *x = NULL;
    a_struct->foo = x;
    free(a_struct->foo);
}