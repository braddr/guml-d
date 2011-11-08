/* www.c */
/* Library of general WWW utilities. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "global.h"

/* Convert a single hex digit to its value 0-15,
   either lower or upper case.  No error checking. */

int hd2n (char c)
{
    return (c <= '9') ? c - '0' : 10 + (c - 'A') % 32;
}

/* Decode http string by resolving +'s and %'s. */

char *http_decode (char *s)
{
    char *t, *v;

    t = v = s;
    while (*v)
    {
        switch (*v)
        {
            case '+':
                *t = ' ';
                break;
            case '%':
                *t = (hd2n (*(v + 1)) << 4) + hd2n (*(v + 2));
                v += 2;
                break;
            default:
                if (t != v)
                    *t = *v;
        }
        v++;
        t++;
    }
    *t = '\0';

    return s;
}

/* quote all <, >, and & in text... generates malloc... should be free'd */

char *quote_html (char *s)
{
    int i;
    char *t, *qq, *q;

    /* first, count offending chars */
    for (i = 0, t = s; *t; t++)
    {
        switch (*t)
        {
            case '<':
            case '>':
                i += 3;
                break;
            case '&':
                i += 4;
                break;
            case '"':
                i += 5;
                break;
        }
    }

    /* the malloc of death */
    qq = q = malloc ((sizeof (*q)) * (strlen (s) + i + 1));

    /* copy s on over to q */
    for (t = s; *t; t++)
    {
        switch (*t)
        {
            case '<':
                strncpy (q, "&lt;", 4);
                q += 4;
                break;
            case '>':
                strncpy (q, "&gt;", 4);
                q += 4;
                break;
            case '&':
                strncpy (q, "&amp;", 5);
                q += 5;
                break;
            case '"':
                strncpy (q, "&quot;", 6);
                q += 6;
                break;
            default:
                *q++ = *t;
        }
    }

    *q = '\0';

    return qq;
}
