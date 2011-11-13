module prims;

import data;
import engine;
import hash_table;
import string_utils;
import www;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

extern(C)
{
    extern __gshared int shutdownguml;
}

/* stops guml in a fastcgi environment */
char *guml_shutdownguml(Data *out_string, char** args, int nargs)
{
    Data *tmp;

    if (nargs != 0)
        return cast(char*)"\\shutdownguml requires no parameters";

    tmp = find_hash_data("USER", calc_hash("USER"));
    if (!tmp)
        return cast(char*)"\\shutdownguml must be called by a privlidged user";

    if (!tmp.data)
        return cast(char*)"\\shutdownguml must be called by a privlidged user";

    shutdownguml = 1;
    return cast(char*)"\\shutdownguml -- shutting down";
}

/* unset a variable */
char *guml_unset (Data *out_string, char** args, int nargs)
{
    if (nargs != 1)
        return cast(char*)"\\unset requires only 1 parameter";

    delete_hash(args[0], calc_hash(args[0]));

    return null;
}

/* quote any html */
/* wrapper for quote_html */
char *guml_htmlquote (Data *out_string, char** args, int nargs)
{
    char *tmp;

    if (nargs != 1)
        return cast(char*)"\\htmlquote requires only 1 parameter";

    tmp = quote_html(args[0]);
    add_string (out_string, tmp);
    free(tmp);
    return null;
}

/* show (unexpanded) a variable */
char *guml_get (Data *out_string, char** args, int nargs)
{
    Data *tmp_data;

    if (nargs != 1)
        return cast(char*)"\\get requires only 1 parameter";

    tmp_data = find_hash_data(args[0], calc_hash(args[0]));

    if (!tmp_data)
        return null;

    add_string_data (out_string, tmp_data);

    return null;
}

/* set, returns nothing */
char *guml_set (Data *out_string, char** args, int nargs)
{
    if (nargs != 2)
        return cast(char*)"\\set requires 2 parameters";

    if (insert_hash(strdup(args[0]), create_string(args[1], 0), calc_hash(args[0]), 0))
        return cast(char*)"\\set of a read only parameter is illegal";

    return null;
}

/* quote something */
/* really does nothing since work is done in guml */
char *guml_quote (Data *out_string, char** args, int nargs)
{
    if (nargs != 1)
        return cast(char*)"\\quote requires only 1 parameter";

    add_string (out_string, args[0]);

    return null;
}

/* switch to cmode */
char *guml_cmode (Data *out_string, char** args, int nargs)
{
    if (nargs != 0)
        return cast(char*)"\\cmode requires no parameters";

    modetrigger = 1;

    return null;
}

/* switch to tmode */
char *guml_tmode (Data *out_string, char** args, int nargs)
{
    if (nargs != 0)
        return cast(char*)"\\tmode requires no parameters";

    modetrigger = 2;

    return null;
}

/* returns "true" if defined, otherwise "" */
char *guml_isset (Data *out_string, char** args, int nargs)
{
    if (nargs != 1)
        return cast(char*)"\\isset requires only 1 parameter";

    if (find_hash_node(args[0], calc_hash(args[0])))
        add_string_size (out_string, "true", 4);

    return null;
}

/* test for equality */
char *guml_eq (Data *out_string, char** args, int nargs)
{
    if (nargs != 2)
        return cast(char*)"\\eq requires 2 parameters";

    if (strcmp (args[0], args[1]) == 0)
        add_string_size (out_string, "true", 4);

    return null;
}

/* branches to second if first is true, else third if exists */
char *guml_if (Data *out_string, char** args, int nargs, char **params, int nparams)
{
    Data res = {null, 0};
    char *arg;
    int truth = 1;

    if (nargs != 2 && nargs != 3)
        return cast(char*)"\\if requires either 2 or 3 parameters";

    arg = args[0];
    guml_backend (&res, &arg, params, nparams);

    if (fatal_error)
        return null;

    if (res.data == null)
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

    return null;
}

char *guml_exit (Data *out_string, char** args, int nargs)
{
    if (nargs != 0)
        return cast(char*)"\\exit requires no parameters";

    fatal_error = 2;
    return cast(char*)"\\exiting";
}

char *guml_while (Data *out_string, char** args, int nargs, char **params, int nparams)
{
    Data res = {null, 0};
    char *arg;
    int truth = 1, loop_count = 0;

    if (nargs != 2)
        return cast(char*)"\\while expects 2 parameters";

    do
    {
        loop_count++;
        if (loop_count > 5000)
            return cast(char*)"\\while -- exceeded max loop count (5000)";

        arg = args[0];
        guml_backend (&res, &arg, params, nparams);
        if (fatal_error)
            return null;
        if (res.data == null)
            truth = 0;
        else
        {
            if (res.data[0] == '\0')
                truth = 0;
            free (res.data);
            res.data = null;
            res.length = 0;
        }
        if (truth)
        {
            arg = args[1];

            guml_backend (out_string, &arg, params, nparams);
            if (fatal_error)
                return null;
        }
    }
    while (truth && !fatal_error);

    return null;
}

char *guml_paramcount (Data *out_string, char** arg, int nargs, char **params, int nparams)
{
    char temp[1024];

    if (nargs != 0)
        return cast(char*)"\\paramcount expects no parameters";

    sprintf(temp.ptr, "%d", nparams);
    add_string(out_string, temp.ptr);

    return null;
}

char *guml_param (Data *out_string, char** arg, int nargs, char **params, int nparams)
{
    int num;

    if (nargs != 1)
        return cast(char*)"\\param expects only 1 parameters";

    num = atoi(arg[0]) - 1;
    if (num  < 0 || num >= nparams)
        return null;

    add_string(out_string, params[num]);

    return null;
}
