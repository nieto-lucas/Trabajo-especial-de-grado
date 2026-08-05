int f(int x) { /*ID*/
    return x;
}

int f1(int x) { /*ID*/
    int y = x;
    return y;
}

int f2(int x) { /*ID*/
    int y = x;
    int w = y;
    return w;
}

int f3(int x) { /*ID*/
    int y = x;
    x = x + 1;
    return y;
}

int f4(int x) { /*ID*/
    int y = x;
    x = x + 1;
    x = y;
    return x; 
}

int f5(int x) { /*ID*/
    int y = x;
    int w = y;
    x = x + 1;
    y = y + 1;
    x = w;
    return x;
}

int f6(int x) { /*ID*/
    if (cond) x = x;
    return x;
}

int f7(int x) { /*ID*/
    if (cond) x = x;
    else x = x;
    return x;
}

int f8(int x) {
    int y = 42;
    if (cond) y = x;
    else y = x;
    return y;
}

int s(int x) { /*NO ID*/
    return x + 1;
}

int s1(int x) { /*NO ID*/
    x = x + 1;
    return x;
}

int s2(int x) { /*NO ID*/
    int y = x + 1;
    return y;
}

int s3(int x) { /*NO ID*/
    int y = x;
    return y + 1;
}

int s4(int x) { /*NO ID*/
    if (cond) x = 42;
    return x;
}

int s5(int x) { /*NO ID*/
    int y = x;
    if (cond) y = 42;
    return y;
}

int s6(int x) { /*NO ID*/
    int y = x;
    if (cond) y = x + 1;
    return y;
}

int s7(int x) { /*NO ID*/
    int y = x;
    if (cond1) {
        if (cond2) y = 42;
    }
    return y;
}

int s8(int x) { /*NO ID*/
    return 42;
}

int s9(int x) { /*NO ID*/
    int y = 42;
    return y;
}

int s10(int x) { /*NO ID*/
    return f(x) + 1;
}

int s11(int x) { /*NO ID*/
    return s7(x);
}

int s12(int x) { /*NO ID*/
    return s10(x);
}

int s13(int x) { /*NO ID*/
    return f(x + 1);
}

int g(int x) { /*ID*/
    return f(x);
}

int g1(int x) { /*ID*/
    return f(f(x));
}

int g2(int x) { /*ID*/
    return f(f(f(x)));
}

int g3(int x) { /*ID*/
    int y = f(x);
    return y;
}

int g4(int x) { /*ID*/
    int y = x;
    if (cond) y = f(x);
    return y; 
}

int h(int x) { /*ID*/
    return g(x);
}

int i(int x) { /*ID*/
    return h(x);
}

int j(int x) { /*ID*/
    return i(x);
}
