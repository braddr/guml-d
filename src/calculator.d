module calculator;

import string_utils;

import core.stdc.ctype;
import core.stdc.math;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

/* calc.c - evaluates a numerical expression, e.g.:

 *       "calc '9+12/(5+1)**(8/4)'" returns "9.333333"
 *
 * the goal of this implementation is to avoid string copying and to have
 * the function stack do the work for us, i.e. recurse like hell.
 *
 * operators supported:
 *   order 0- bitwise operators: | & ^
 *   order 1- additive operators: + - (binary and unary!) % (REAL modulus!)
 *   order 2- multiplicative operators: * /
 *   order 3- exponentiation: **
 *
 * so here's how it's done:
 *  1. look for RIGHTMOST top-level (not contained in parentheses) 
 *      lowest-order operation.  (this is necessary for proper left-to-right 
 *      ordering- 5-2+3 is (5-2)+3, not 5-(2+3)..  if found, send left and
 *      right side to #1 and perform operation on returned values.  otherwise, 
 *      send whole string to next level of operation.
 *  2. if we can't find an operator in a string, assume it's a number and 
 *      attempt to parse as such (first checking for non-[0-9,'.'] characters
 *
 * bugs/other trouble:
 * mismatched parentheses are sometimes caught in skip_parens, 
 * sometimes in parse_num, sometimes not at all..  this should be 
 * probably be handled more cleanly.
 *
 * also, numbers are passed around as doubles, causing hell for 
 * integer-only operations like bitwise and modulus.  currently, the number 
 * is floored and compared against the original, with an error generated if 
 * the values don't match (i.e., is it an integer?).  not only does this 
 * cause unneccessary runtime errors and increased brittleness, but it 
 * may fail in cases where it shouldn't; for instance, (1/3)*3%2 may 
 * reduce to 0.9999999...%2, which throws an error.  i have no idea how 
 * to deal with this...
 *
 * finally, the reported precision is an arbitrary fixed number, with a 
 * default of 5 digits.  i'd like to make something more flexible, so 
 * that if the computed value is a pure integer, it is reported as such.  
 * similarly, i'd like to have facility for integer division (modulus 
 * doesn't make much sense without it, i suppose..), but it seems i'm all 
 * out of operator symbols..  oh well.
 *
 * make note that ^ is exclusive or, not exponentiation.  i'll get caught 
 * on this eventually, no doubt.
 *
 * possible future wackiness: functions like abs(), sin(), etc.??
 * mathematical constants like e, pi..??
 */

enum CALC_NUMLEVELS = 3;

int guml_calc_error = 0;

int isint (double d)
{
    return (floor (d) == d);
}

char *guml_calc_skip_parens (char *ptr, char *end)
{
    int level = 0, dir = (ptr > end) ? 0 : 1;

/* printf("skipping: "); */

    while (1)
    {
/* printf("%c ",*ptr); */
        switch (*ptr)
        {
            case '\0':
                return null;
            case '(':
                if (dir == 0)
                    level--;
                else
                    level++;
                break;
            case ')':
                if (dir == 0)
                    level++;
                else
                    level--;
                break;
            default:
                break;
        }
        if (level == 0 || ptr == end)
            break;
        if (dir == 0)
            ptr--;
        else
            ptr++;
    }

/* printf(" - ending on %c\n",*ptr); */

    if (level > 0)
    {
        guml_calc_error = 2;
        return null;
    }
    else
        return ptr;
}

double guml_calc_parsenum (char *expr)
{
    char *ptr;

/* printf("parsenum: %s\n",expr); */

    for (ptr = expr + strlen (expr) - 1; ptr >= expr; ptr--)
    {
        if (!isdigit (*ptr) && *ptr != '.' && *ptr != '-')
        {
            guml_calc_error = 3;
            return 0;
        }
    }

/* printf("it's %f!\n",atof(expr)); */
    return atof (expr);
}

/* generic parse loop.  hunt for target operator based on "level",
   break into left and right expressions, replace operator character with 
   a null, and recurse on them expressions.  if no operator found, try to 
   parse as a number. */

double guml_calc_parseexpr (char *expr, int level)
{
    char c;

    /* scan right to left, for associativity's sake */
    char *ptr = expr + strlen (expr);

    if (guml_calc_error)
        return 0;

    if (*expr == '\0')
    {
        guml_calc_error = 5;
        return 0;
    }

/* printf("parseexpr: %s level %i\n",expr,level); */

    /* strip any containing parentheses */
    while (*expr == '(' && *(ptr - 1) == ')')
    {
        if (guml_calc_skip_parens (expr, ptr) == null)
            return 0;
        *expr = '\0';           /* probably unnecessary, but cleaner.. */
        expr++;
        *(ptr - 1) = '\0';
        ptr--;
    }

    do
    {
        ptr--;
        c = *ptr;
        if (!isdigit (c) && c != '.')
        {
            if (c == ')')       /* don't go in there yet! */
                ptr = guml_calc_skip_parens (ptr, expr);
            else
            {
                switch (level)
                {
                    /* bitwise - should probably test for integers first! */
                    case 0:
                        if (c == '|' || c == '^' || c == '&')
                        {
                            double l, r;

                            *ptr = '\0';

                            l = guml_calc_parseexpr (expr, 0);
                            r = guml_calc_parseexpr (ptr + 1, 0);

                            if (!isint (l))
                            {
                                guml_calc_error = 1;
                                return 0;
                            }
                            if (!isint (r))
                            {
                                guml_calc_error = 1;
                                return 0;
                            }

                            switch (c)
                            {
                                case '|':
                                    return cast(int)floor(l) | cast(int)floor(r);
                                case '^':
                                    return cast(int)floor(l) ^ cast(int)floor(r);
                                case '&':
                                    return cast(int)floor(l) & cast(int)floor(r);
                                default:
                                    break;
                            }
                        }
                        break;

                    /* additive operations +, - (binary and unary), and %
                       note that % is *REAL* modulus, not stupid c version.. */
                    case 1:
                        if (c == '+')
                        {
                            *ptr = '\0';
                            return guml_calc_parseexpr (expr, 0) + guml_calc_parseexpr (ptr + 1, 0);
                        }

                        else if (c == '-')
                        {       /* it's the first character- take it! */
                            if (ptr == expr)
                            {   /* negate it if we've got a leading - */
                                *ptr = '\0';
                                return -guml_calc_parseexpr (ptr + 1, 0);
                            }
                            /* numbers and closing parens indicate a value to the left,
                               hence binary (subtraction).. */
                            else if (*(ptr - 1) == ')' || isdigit (*(ptr - 1)))
                            {
                                *ptr = '\0';
                                return guml_calc_parseexpr (expr, 0) - guml_calc_parseexpr (ptr + 1, 0);
                            }
                            /* else assume it's a unary negation and we'll pick it up later */
                        }

                        else if (c == '%')
                        {       /* can we do this with doubles??  nope.. */
                            double l = guml_calc_parseexpr (expr, 0), r = guml_calc_parseexpr (ptr + 1, 0);

                            if (!isint (l))
                            {
                                guml_calc_error = 1;
                                return 0;
                            }
                            if (!isint (r))
                            {
                                guml_calc_error = 1;
                                return 0;
                            }
                            return cast(long)floor(l) % cast(long)floor(r);
                        }
                        break;

                    /* multiplicative operations * and / */
                    case 2:
                        if (c == '*')
                        {
                            if (ptr != expr)
                            {
                                if (*(ptr - 1) != '*')
                                {
                                    *ptr = '\0';
                                    return guml_calc_parseexpr (expr, 0) * guml_calc_parseexpr (ptr + 1, 0);
                                }
                                else
                                    ptr--;  /* it's a '**' -- we'll pick it up next round.. */
                            }
                        }
                        else if (c == '/')
                        {
                            double leftval, rightval;

                            *ptr = '\0';
                            leftval = guml_calc_parseexpr (expr, 0);
                            if ((rightval = guml_calc_parseexpr (ptr + 1, 0)) != 0)
                                return leftval / rightval;
                            else
                            {
                                guml_calc_error = 4;
                                return 0;  /* NONONO! */
                            }
                        }
                        break;

                    /* exponentiation! ("**") */
                    case 3:
                        if (c == '*')
                        {
                            if (ptr != expr && *(ptr - 1) == '*')
                            {
                                *ptr = '\0';
                                *(ptr - 1) = '\0';
                                return pow (guml_calc_parseexpr (expr, 0), guml_calc_parseexpr (ptr + 1, 0));
                            }
                        }
                        break;

                    default:
                        assert(false);
                }
            }
        }

    }
    while (ptr != expr);

    /* if no operator found at this level, try to go up a level.
       if can't, try to make a number out of it.. */

    if (ptr == expr)
    {
        if (level < CALC_NUMLEVELS)
            return guml_calc_parseexpr (expr, level + 1);
        else
            return guml_calc_parsenum (expr);
    }
    else
        return 0;               /* should signal error! */
}

char *guml_calculator (Data *out_string, const ref Data[] args)
{
    char[1024] buf;
    char[16] formstr;

    if (args.length < 1 || args.length > 2)
        return cast(char*)"\\calc requires 1 or 2 parameters";

    if (args.length == 2)
    {
        foreach(c; args[1].asString)
            if (!isdigit(c))
                return cast(char*)"\\calc -- second argument must be a number!";

        sprintf (formstr.ptr, "%%0.%if".ptr, atoi (args[1].asCharStar));
    }
    else
        sprintf (formstr.ptr, "%%f".ptr);

    guml_calc_error = 0;

    char* s = strdup(args[0].asCharStar);
    sprintf (buf.ptr, formstr.ptr, guml_calc_parseexpr (s, 0));
    free(s);

    switch (guml_calc_error)
    {
        case 0:
            add_string (out_string, buf.ptr);
            return null;
        case 1:
            return cast(char*)"\\calc -- Non-integral values were used in integral context (bitwise or modulus)";
        case 2:
            return cast(char*)"\\calc -- Mismatched parentheses";
        case 3:
            return cast(char*)"\\calc -- Error parsing number";
        case 4:
            return cast(char*)"\\calc -- Division by zero";
        case 5:
            return cast(char*)"\\calc -- Missing operand";
        default:
            return cast(char*)"\\calc -- Undefined error";
    }
}

/+
void main(int argc, char *argv[])
{
    char *args[2] = { strdup(argv[1]), null };

    if(argc>1)
        printf("%s\n",guml_calculator(args,1));
    else
        printf("Usage: calc expression\n");
}
+/

