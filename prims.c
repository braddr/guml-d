/* prims.c */
/* guml language primitives */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <ctype.h>

#include "global.h"

extern int fatal_error, shutdownguml;

/* stops guml in a fastcgi environment */
char *guml_shutdownguml(Data *out_string, char *args[], int nargs)
{
    Data *tmp;

    if (nargs != 0)
        return "\\shutdownguml requires no parameters";

    tmp = find_hash_data("USER", calc_hash("USER"));
    if (!tmp)
        return "\\shutdownguml must be called by a privlidged user";

    if (!tmp->data)
        return "\\shutdownguml must be called by a privlidged user";

    shutdownguml = 1;
    return "\\shutdownguml -- shutting down";
}

/* unset a variable */
char *guml_unset (Data *out_string, char *args[], int nargs)
{
    if (nargs != 1)
        return "\\unset requires only 1 parameter";

    delete_hash(args[0], calc_hash(args[0]));

    return NULL;
}

/* quote any html */
/* wrapper for quote_html */
char *guml_htmlquote (Data *out_string, char *args[], int nargs)
{
    char *tmp;

    if (nargs != 1)
        return "\\htmlquote requires only 1 parameter";

    tmp = quote_html(args[0]);
    add_string (out_string, tmp);
    free(tmp);
    return NULL;
}

/* show (unexpanded) a variable */
char *guml_get (Data *out_string, char *args[], int nargs)
{
    Data *tmp_data;

    if (nargs != 1)
        return "\\get requires only 1 parameter";

    tmp_data = find_hash_data(args[0], calc_hash(args[0]));

    if (!tmp_data)
        return NULL;

    add_string_data (out_string, tmp_data);

    return NULL;
}

/* set, returns nothing */
char *guml_set (Data *out_string, char *args[], int nargs)
{
    if (nargs != 2)
        return "\\set requires 2 parameters";

    if (insert_hash(strdup(args[0]), create_string(args[1], 0), calc_hash(args[0]), 0))
        return "\\set of a read only parameter is illegal";

    return NULL;
}

/* quote something */
/* really does nothing since work is done in guml */
char *guml_quote (Data *out_string, char *args[], int nargs)
{
    if (nargs != 1)
        return "\\quote requires only 1 parameter";

    add_string (out_string, args[0]);

    return NULL;
}

/* switch to cmode */
char *guml_cmode (Data *out_string, char *args[], int nargs)
{
    extern int modetrigger;

    if (nargs != 0)
        return "\\cmode requires no parameters";

    modetrigger = 1;

    return NULL;
}

/* switch to tmode */
char *guml_tmode (Data *out_string, char *args[], int nargs)
{
    extern int modetrigger;

    if (nargs != 0)
        return "\\tmode requires no parameters";

    modetrigger = 2;

    return NULL;
}

/* returns "true" if defined, otherwise "" */
char *guml_isset (Data *out_string, char *args[], int nargs)
{
    if (nargs != 1)
        return "\\isset requires only 1 parameter";

    if (find_hash_node(args[0], calc_hash(args[0])))
        add_string_size (out_string, "true", 4);

    return NULL;
}

/* test for equality */
char *guml_eq (Data *out_string, char *args[], int nargs)
{
    if (nargs != 2)
        return "\\eq requires 2 parameters";

    if (strcmp (args[0], args[1]) == 0)
        add_string_size (out_string, "true", 4);

    return NULL;
}

/* branches to second if first is true, else third if exists */
char *guml_if (Data *out_string, char *args[], int nargs, char *params[], int nparams)
{
    Data res = {NULL, 0};
    char *arg;
    int truth = 1;

    if (nargs != 2 && nargs != 3)
        return "\\if requires either 2 or 3 parameters";

    arg = args[0];
    guml_backend (&res, &arg, params, nparams);

    if (fatal_error)
        return NULL;

    if (res.data == NULL)
        truth = 0;
    else
    {
        if (res.data[0] == '\0')
            truth = 0;
        free (res.data); // Clearing unnecessary, nothing uses res below
    }
    if (truth)
    {
        arg = args[1];
        guml_backend (out_string, &arg, params, nparams);
    }
    else
    {
        if (nargs == 3)
        {
            arg = args[2];
            guml_backend (out_string, &arg, params, nparams);
        }
    }

    return NULL;
}

char *guml_exit (Data *out_string, char *args[], int nargs)
{
    if (nargs != 0)
        return "\\exit requires no parameters";

    fatal_error = 2;
    return "\\exiting";
}

char *guml_while (Data *out_string, char *args[], int nargs, char *params[], int nparams)
{
    Data res = {NULL, 0};
    char *arg;
    int truth = 1, loop_count = 0;

    if (nargs != 2)
        return "\\while expects 2 parameters";

    do
    {
        loop_count++;
        if (loop_count > 5000)
            return "\\while -- exceeded max loop count (5000)";

        arg = args[0];
        guml_backend (&res, &arg, params, nparams);
        if (fatal_error)
            return NULL;
        if (res.data == NULL)
            truth = 0;
        else
        {
            if (res.data[0] == '\0')
                truth = 0;
            free (res.data);
            res.data = NULL;
            res.length = 0;
        }
        if (truth)
        {
            arg = args[1];

            guml_backend (out_string, &arg, params, nparams);
            if (fatal_error)
                return NULL;
        }
    }
    while (truth && !fatal_error);

    return NULL;
}

char *guml_paramcount (Data *out_string, char *arg[], int nargs, char *params[], int nparams)
{
    char temp[1024];

    if (nargs != 0)
        return "\\paramcount expects no parameters";

    sprintf(temp, "%d", nparams);
    add_string(out_string, temp);

    return NULL;
}

char *guml_param (Data *out_string, char *arg[], int nargs, char *params[], int nparams)
{
    int num;

    if (nargs != 1)
        return "\\param expects only 1 parameters";

    num = atoi(arg[0]) - 1;
    if (num  < 0 || num >= nparams)
        return NULL;

    add_string(out_string, params[num]);

    return NULL;
}
