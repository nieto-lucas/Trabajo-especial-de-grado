// Ejemplos de free-field-no-reassign https://queries.joern.io/
// Autor: @fabsx00

void free_field_reassigned(a_struct_type *a_struct) {
    free(a_struct->ptr);
    if (something) {
        return;
    }
    a_struct->ptr = foo;
}

void not_free_field_reassigned(a_struct_type *a_struct) {
    free(a_struct->ptr);
    if (something) {
        a_struct->ptr = NULL;
        return;
    }
    a_struct->ptr = foo;
}