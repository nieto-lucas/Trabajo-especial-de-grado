// malloc-memcpy-int-overflow ejemplos de https://queries.joern.io/
// Autor: @fabsx00

int vulnerable(size_t len, char *src) {
    char *dst = malloc(len + 8);
    memcpy(dst, src, len + 7);
}

int non_vulnerable(size_t len, char *src) {
    char *dst = malloc(len + 8);
    memcpy(dst, src, len + 8);
}

int non_vulnerable2(size_t len, char *src) {
    char *dst = malloc(some_size);
    memcpy(dst, src, some_size);
}
