/* env_ops.c */
/* guml interface to the environment variables */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "global.h"

extern char **guml_env;

/* unset a variable */
char *guml_environ (Data *out_string, char *args[], int nargs)
{
    static char guml_environ_initialized = 0;
    int i;
    char *eptr, *name, *value;

    if (nargs > 1)
        return "\\email requires either 0 or 1 parameters";

    if (!guml_environ_initialized)
    {
        for (i=0; guml_env[i]; i++)
        {
            eptr=strdup(guml_env[i]);
            if (split_string(eptr, '=', &name, &value))
                insert_hash(strdup(name), create_string(value, 0), calc_hash(name), HASH_ENV);
            else
                insert_hash(strdup(name), create_string("", 0), calc_hash(name), HASH_ENV);
            free(eptr);
        }
        guml_environ_initialized = 1;
    }

    for (i=0; guml_env[i]; i++)
    {
        eptr=strdup(guml_env[i]);
        if (split_string(eptr, '=', &name, &value))
        {
            add_string(out_string, name);
            add_char(out_string, ' ');
        }
        free(eptr);
    }

    return NULL;
}
