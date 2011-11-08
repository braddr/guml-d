#include <stdlib.h>
#include <stdio.h>
#ifdef NEED_CRYPT
#include <crypt.h>
#endif
#include <time.h>

#include "global.h"

#ifdef SITE_MOLSON
#define PERIOD 86400  /* change once a day */

char *molson_encode_password (Data *out_string, char *args[], int nargs)
{
    char salts[65]="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./";  /* acceptable salts */
    char salt[3];
    unsigned long tt;
    int doffs;

    if (nargs < 1 || nargs > 2)
        return "\\encodepassword requires 1 or 2 parameters";

    if (nargs == 2)
    {
        doffs = atoi(args[1]);
        tt = (long)time(NULL);
        tt /= PERIOD;
        tt += doffs;
        tt &= 0xfff;
    }
    else
        tt = 0x654;  /* ??? some fixed random number.. */

    salt[2] = 0;
    salt[1] = salts[tt & 0x3f];
    salt[0] = salts[tt >> 6];

    add_string(out_string, crypt(args[0], salt));

    return NULL;
}
#endif

