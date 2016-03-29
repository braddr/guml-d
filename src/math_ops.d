module math_ops;

import string_utils;

import core.stdc.config;
import core.stdc.ctype;
import core.stdc.math;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.posix.stdlib;

extern(C)
{
    extern int strcasecmp(const char *s1, const char *s2);
}

char *guml_parse_money (Data *out_string, const ref Data[] args)
{
    if (args.length != 1)
        return cast(char*)"\\money requires only one parameter";

    char[1024] buffer;
    size_t pos = 0;
    foreach(c; args[0].asString)
    {
        switch (c)
        {
            case '0':
            case '1':
            case '2':
            case '3':
            case '4':
            case '5':
            case '6':
            case '7':
            case '8':
            case '9':
            case '.':
                buffer[pos + 1] = 0;
                buffer[pos] = c;
                ++pos;
                goto case;
            case ',':
            case '$':
                break;
            default:
                return null;
        }
    }

    add_string (out_string, buffer.ptr);
    return null;
}

/* pick a random number from 0 to arg[0]-1 */
char *guml_rand (Data *out_string, const ref Data[] args)
{
    if (args.length != 1)
        return cast(char*)"\\rand requires only one argument";

    int max = atoi (args[0].asCharStar);

    if (max == 0)
        return cast(char*)"\\rand called with a string or a 0";

    char[15] res;
    sprintf (res.ptr, "%ld", cast(long) random () % max);

    add_string (out_string, res.ptr);
    return null;
}

/* do general math operation */
char *guml_op (Data *out_string, const ref Data[] args)
{
    if (args.length < 2 || args.length > 3)
        return cast(char*)"\\op requires 2 or 3 parameters";

    int b;

    if (strchr ("+-*%|&^</>=", args[1].asCharStar[0]) != null)
    {
        if (args.length != 3)
            return cast(char*)"\\op with +, -, *, /, %, |, &, ^, <, >, <=. >=, or = requires 3 parameters";
        else
            b = atoi (args[2].asCharStar);
    }
    else
    {
        if (args.length < 2)
            return cast(char*)"\\op with V or ~ requires 2 parameters";
    }

    int a = atoi (args[0].asCharStar);
    int c = 0;
    const char* op = args[1].asCharStar;
    int isrel = 0;

    switch (*op)
    {
        case 'v':
        case 'V':
            isrel = 1;
            c = args[0].length != 0;
            foreach (ch; args[0].asString)
                if (!(isdigit(ch) || ch == '-'))
                {
                    c = 0;
                    break;
                }
            break;
        case '+':
            c = a + b;
            break;
        case '-':
            c = a - b;
            break;
        case '*':
            c = a * b;
            break;
        case '/':
            if (b == 0)
                return cast(char*)"\\op divide by 0 error";
            c = a / b;
            break;
        case '%':              /* modulus is WRONG in c! */
            if (b == 0)
                return cast(char*)"\\op divide by 0 error";
            c = a % b;
            if (c < 0)
                c += b;
            break;
        case '~':
            c = ~a;
            break;
        case '|':
            c = a | b;
            break;
        case '&':
            c = a & b;
            break;
        case '^':
            c = a ^ b;
            break;
        default:
            isrel = 1;
            switch (*op)
            {
                case '<':
                    if (*(op + 1) == '=')
                        c = a <= b;
                    else
                        c = a < b;
                    break;
                case '>':
                    if (*(op + 1) == '=')
                        c = a >= b;
                    else
                        c = a > b;
                    break;
                case '=':
                    c = a == b;
                    break;
                default:
                    return cast(char*)"\\op -- unknown math operation.";
            }
    }

    if (isrel)
    {
        if (c)
            add_string(out_string, "true", 4);
    }
    else
    {
        char[32] res;
        sprintf (res.ptr, "%d", c);
        add_string (out_string, res.ptr);
    }
    return null;
}

/* do general fp math operation */
char *guml_fop (Data *out_string, const ref Data[] args)
{
    static char[1024] res;
    double a, b, c;
    int d = 0, isrel = 0;
    char[10] fmt;

/*
   if (args.length < 2 || args.length > 5)
   return "\\op requires between 2 and 5 parameters";

   if (strchr("+-*</>=", args[1].data[0]) != null)
   {
   if (args.length != 3 && args.length != 4)
   return "\\fop with +, -, *, **, /, <, >, <=. >=, or = requires 3 or 4 parameters";
   else
   }
   else
   {
   if (args.length != 2 && args.length != 3)
   return "\\fop with c, f, r, or V requires 2 or 3 parameters";
   }
 */
    c = 0;
    a = atof (args[0].asCharStar);
    if (args.length >= 3)
        b = atof (args[2].asCharStar);
    else
        b = 0;

    if (args.length == 4)
        sprintf (fmt.ptr, "%%.%df", atoi (args[3].asCharStar));
    else if (args.length == 5)
        sprintf (fmt.ptr, "%%%d.%df", atoi (args[3].asCharStar), atoi (args[4].asCharStar));
    else
    {
        char* ptr = strchr (args[0].asCharStar, '.');
        size_t len = args[0].length;
        if (ptr) len -= (ptr - args[0].asCharStar) + 1;
        sprintf (fmt.ptr, "%%.%zdf", len);
    }
    const char* op = args[1].asCharStar;

    switch (*op)
    {
        case '+':
            c = a + b;
            break;
        case '-':
            c = a - b;
            break;
        case '*':
            if (*(op + 1) == '*')
                c = pow (a, b);
            else
                c = a * b;
            break;
        case '/':
            if (b == 0)
                return cast(char*)"\\fop divide by 0 error";
            c = a / b;
            break;
        case 'c':
        case 'C':
            c = ceil (a);
            break;
        case 'f':
        case 'F':
            c = floor (a);
            break;
        case 'l':
        case 'L':
            if (strcasecmp(op, "log") == 0)
                c = log(a);
            else if (strcasecmp(op, "log10") == 0)
                c = log10(a);
            else
                return cast(char*)"\\fop -- invalid operator";
            break;
        case 'r':
        case 'R':
            c = rint (a);
            break;
        case 'v':
        case 'V':
            isrel = 1;
            d = args[0].length != 0;
            foreach (ch; args[0].asString)
                if (!(isdigit(ch) || ch == '-' || ch == '.'))
                {
                    d = 0;
                    break;
                }
            break;
        default:
            isrel = 1;
            switch (*op)
            {
                case '<':
                    if (*(op + 1) == '=')
                        d = a <= b;
                    else
                        d = a < b;
                    break;
                case '>':
                    if (*(op + 1) == '=')
                        d = a >= b;
                    else
                        d = a > b;
                    break;
                case '=':
                    d = a == b;
                    break;
                default:
                    return cast(char*)"\\fop -- invalid math operation.";
            }
    }

    if (isrel)
    {
        if (d)
            add_string(out_string, "true", 4);
    }
    else
    {
        sprintf (res.ptr, fmt.ptr, c);
        add_string (out_string, res.ptr);
    }
    return null;
}
