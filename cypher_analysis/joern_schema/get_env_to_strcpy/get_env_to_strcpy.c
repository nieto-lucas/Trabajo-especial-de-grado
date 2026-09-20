#include <stdlib.h>
#include <string.h>

static int cond;

void bad_base_case() { /*VULNERABLE*/
    char buf[64];
    strcpy(buf, getenv("PATH"));
}

void bad_var_case() { /*VULNERABLE*/
    char buf[64];
    char *val = getenv("USER");
    strcpy(buf, val);
}

char *get_home_env() {
    return getenv("HOME");
}

void bad_ipa_getenv() { /*VULNERABLE*/
    char buf[64];
    char *val = get_home_env();
    strcpy(buf, val);
}

char *get_home_wrapper() {
    return get_home_env();
}

void bad_ipa_getenv2() { /*VULNERABLE*/
    char buf[64];
    char *val = get_home_wrapper();
    strcpy(buf, val);
}

void ipa_strcpy() {
    char buf[64];
    char *val = getenv("LANG");
    bad_ipa_strcpy(val, buf);
}

void bad_ipa_strcpy(char *val, char *dst) { /*VULNERABLE*/
    strcpy(dst, val);
}

void ipa_strcpy_wrapper(char *val, char *dst) {
    bad_ipa_strcpy(val, dst);
}

void ipa_strcpy2() {
    char buf[64];
    char *val = getenv("PWD");
    ipa_strcpy_wrapper(val, buf);
}

void bad_strcpy_if_case() { /*VULNERABLE*/
    char buf[64];
    char *val = getenv("MANPATH");
    if (cond) {
        strcpy(buf, val);
    }
}

void bad_getenv_if_case() { /*VULNERABLE*/
    char buf[64];
    char *val = "foo";
    if (cond) {
        val = getenv("HOSTNAME");
    }
    strcpy(buf, val);
}

void good_not_source_case() { /*NO VULNERABLE*/
    char buf[64];
    char *literal = "foo";
    strcpy(buf, literal);
}

void good_not_sink_case() { /*NO VULNERABLE*/
    char *val = getenv("SHELL");
    if (val != NULL) {
        printf("%s\n", val);
    }
}