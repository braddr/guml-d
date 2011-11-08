/* stub.c */
/* launches six.c with env set right */
/* by Galen Huntington */

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

#include "local.h"

void error_out (int var)
{
    printf ("Content-type: text/plain\n\n");
    printf ("error setting var %d\n", var);
    exit (1);
}

int main (int dummy1, char **argv)
{
#ifdef USE_SYBASE
    if (putenv ("LD_LIBRARY_PATH=" DB_ROOT "/lib:/usr/lib"))
        error_out (1);
    if (putenv ("SYBASE=" DB_ROOT))
        error_out (2);
    if (putenv ("DSQUERY=" DB_HOST))
        error_out (3);
    if (putenv ("DSLISTEN=" DB_HOST))
        error_out (4);
#endif
#ifdef USE_ORACLE
    putenv ("LD_LIBRARY_PATH=" DB_ROOT "/lib");
#endif
#ifdef USE_INFORMIX
    putenv ("LD_LIBRARY_PATH=" DB_ROOT "/lib:" DB_ROOT "/lib/esql");
#endif
    execv (EXECGUML, argv);

    return 1;
}
