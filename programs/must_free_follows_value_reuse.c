// Ejemplos free-follows-value-reuse https://queries.joern.io/
// Autor: @maltek

#include <stdlib.h>

void *bad() { /*DETECTA*/
    void *x = NULL;
    if (cond)
        free(x);
    return x;
}

void *false_positive() { /*DETECTA*/
    void *x = NULL;
    free(x);
    if (cond)
        x = NULL;
    else
        x = NULL;
    return x;
}

void *false_negative() { /*NO DETECTA*/
    void *x = NULL;
    if (cond) {
        free(x);
        if (cond2)
            return x; // doesn't post-dominate the free call
        x = NULL;
    }
    return x;
}

void *good() { /*NO DETECTA*/
    void *x = NULL;
    if (cond)
        free(x);
    x = NULL;
    return x;
}
