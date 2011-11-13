module math_ops;

import data;
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

char *guml_parse_money (Data *out_string, char** args, int nargs)
{
    char buffer[1024];
    size_t i;

    if (nargs != 1)
        return cast(char*)"\\money requires only one parameter";

    i = 0;
    buffer[0] = 0;
    while (i < strlen (args[0]))
    {
        switch (args[0][i])
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
                buffer[strlen (buffer.ptr) + 1] = 0;
                buffer[strlen (buffer.ptr)] = args[0][i];
            case ',':
            case '$':
                break;
            default:
                return null;
        }
        i++;
    }
    add_string (out_string, buffer.ptr);
    return null;
}

/* pick a random number from 0 to arg[0]-1 */
char *guml_rand (Data *out_string, char** args, int nargs)
{
    char res[15];
    int max;

    if (nargs != 1)
        return cast(char*)"\\rand requires only one argument";

    max = atoi (args[0]);

    if (max == 0)
        return cast(char*)"\\rand called with a string or a 0";
    else
        sprintf (res.ptr, "%ld", cast(long) random () % atoi (args[0]));

    add_string (out_string, res.ptr);
    return null;
}

/* do general math operation */
char *guml_op (Data *out_string, char** args, int nargs)
{
    int a, b, c;
    char *op;
    int isrel = 0;
    char res[32];

    if (nargs < 2 || nargs > 3)
        return cast(char*)"\\op requires 2 or 3 parameters";

    if (strchr ("+-*%|&^</>=", args[1][0]) != null)
    {
        if (nargs != 3)
            return cast(char*)"\\op with +, -, *, /, %, |, &, ^, <, >, <=. >=, or = requires 3 parameters";
        else
            b = atoi (args[2]);
    }
    else
    {
        if (nargs < 2)
            return cast(char*)"\\op with V or ~ requires 2 parameters";
    }

    c = 0;
    a = atoi (args[0]);
    op = args[1];

    switch (*op)
    {
        case 'v':
        case 'V':
            isrel = 1;
            c = strlen (args[0]) != 0;
            for (size_t loop = 0; loop < strlen (args[0]) && c; loop++)
                if (!(isdigit (args[0][loop]) || args[0][loop] == '-'))
                    c = 0;
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
                    break;
            }
    }

    if (isrel)
    {
        if (c)
            add_string_size (out_string, "true", 4);
    }
    else
    {
        sprintf (res.ptr, "%d", c);
        add_string (out_string, res.ptr);
    }
    return null;
}

/* do general fp math operation */
char *guml_fop (Data *out_string, char** args, int nargs)
{
    static char res[1024];
    double a, b, c;
    int d = 0, isrel = 0;
    char *op;
    char fmt[10];

/*
   if (nargs < 2 || nargs > 5)
   return "\\op requires between 2 and 5 parameters";

   if (strchr("+-*</>=", args[1][0]) != null)
   {
   if (nargs != 3 && nargs != 4)
   return "\\fop with +, -, *, **, /, <, >, <=. >=, or = requires 3 or 4 parameters";
   else
   }
   else
   {
   if (nargs != 2 && nargs != 3)
   return "\\fop with c, f, r, or V requires 2 or 3 parameters";
   }
 */
    c = 0;
    a = atof (args[0]);
    if (nargs >= 3)
        b = atof (args[2]);
    else
        b = 0;

    if (nargs == 4)
        sprintf (fmt.ptr, "%%.%df", atoi (args[3]));
    else if (nargs == 5)
        sprintf (fmt.ptr, "%%%d.%df", atoi (args[3]), atoi (args[4]));
    else if (strchr (args[0], '.') != null)
        sprintf (fmt.ptr, "%%.%zdf", strlen (strchr (args[0], '.') + 1));
    else
        sprintf (fmt.ptr, "%%.%zdf", strlen (args[0]));
    op = args[1];

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
            d = strlen (args[0]) != 0;
            for (size_t loop = 0; loop < strlen (args[0]) && d; loop++)
                if (!(isdigit (args[0][loop]) || args[0][loop] == '-' || args[0][loop] == '.'))
                    d = 0;
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
                    break;
            }
    }

    if (isrel)
    {
        if (d)
            add_string_size (out_string, "true", 4);
    }
    else
    {
        sprintf (res.ptr, fmt.ptr, c);
        add_string (out_string, res.ptr);
    }
    return null;
}
