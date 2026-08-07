#include <stdlib.h>
#include <string.h>

void base_case() { /*VULNERABLE*/
    char buf[64];
    strcpy(buf, getenv("PATH"));
}

void var_case() { /*VULNERABLE*/
    char buf[64];
    char *val = getenv("USER");
    strcpy(buf, val);
}

char *get_home_env() {
    return getenv("HOME");
}

void IPA_case() { /*VULNERABLE*/
    char buf[64];
    char *val = get_home_env();
    strcpy(buf, val);
}

void copy_value(char *val, char *dst) {
    strcpy(dst, val);
}

void IPA_case2() { /*VULNERABLE*/
    char buf[64];
    char *val = getenv("LANG");
    copy_value(val, buf);
}

char *get_home_env2() {
    return get_home_env();
}

void IPA_case3() { /*VULNERABLE*/
    char buf[64];
    char *val = get_home_env2();
    strcpy(buf, val);
}

void copy_value2(char *val, char *dst) {
    copy_value(val, dst);
}

void IPA_case4() { /*VULNERABLE*/
    char buf[64];
    char *val = getenv("PWD");
    copy_value2(val, buf);
}

void strcpyIf_case() { /*VULNERABLE*/
    char buf[64];
    char *val = getenv("MANPATH");
    if (cond) {
        strcpy(buf, val)
    }
}

void getenvIf_case() { /*VULNERABLE*/
    char buf[64];
    char *val = "foo";
    if (cond) {
        val = getenv("HOSTNAME");
    }
    strcpy(buf, val);
}

void not_source_case() { /*NO VULNERABLE*/
    char buf[64];
    char *literal = "foo";
    strcpy(buf, literal);
}

void not_sink_case() { /*NO VULNERABLE*/
    char *val = getenv("SHELL");
    if (val != NULL) {
        printf("%s\n", val);
    }
}
