module prims;

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
char *guml_shutdownguml(Data *out_string, const ref Data[] args)
{
    Data *tmp;

    if (args.length != 0)
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
char *guml_unset (Data *out_string, const ref Data[] args)
{
    if (args.length != 1)
        return cast(char*)"\\unset requires only 1 parameter";

    delete_hash(args[0].data, calc_hash(args[0].data));

    return null;
}

/* quote any html */
/* wrapper for quote_html */
char *guml_htmlquote (Data *out_string, const ref Data[] args)
{
    if (args.length != 1)
        return cast(char*)"\\htmlquote requires only 1 parameter";

    char* tmp = quote_html(args[0].data);
    add_string (out_string, tmp);
    free(tmp);
    return null;
}

/* show (unexpanded) a variable */
char *guml_get (Data *out_string, const ref Data[] args)
{
    Data *tmp_data;

    if (args.length != 1)
        return cast(char*)"\\get requires only 1 parameter";

    tmp_data = find_hash_data(args[0].data, calc_hash(args[0].data));

    if (!tmp_data)
        return null;

    add_string(out_string, tmp_data);

    return null;
}

/* set, returns nothing */
char *guml_set (Data *out_string, const ref Data[] args)
{
    if (args.length != 2)
        return cast(char*)"\\set requires 2 parameters";

    if (insert_hash(strdup(args[0].data), create_string(args[1].data), calc_hash(args[0].data), 0))
        return cast(char*)"\\set of a read only parameter is illegal";

    return null;
}

/* quote something */
/* really does nothing since work is done in guml */
char *guml_quote (Data *out_string, const ref Data[] args)
{
    if (args.length != 1)
        return cast(char*)"\\quote requires only 1 parameter";

    add_string (out_string, args[0]);

    return null;
}

/* switch to cmode */
char *guml_cmode (Data *out_string, const ref Data[] args)
{
    if (args.length != 0)
        return cast(char*)"\\cmode requires no parameters";

    modetrigger = 1;

    return null;
}

/* switch to tmode */
char *guml_tmode (Data *out_string, const ref Data[] args)
{
    if (args.length != 0)
        return cast(char*)"\\tmode requires no parameters";

    modetrigger = 2;

    return null;
}

/* returns "true" if defined, otherwise "" */
char *guml_isset (Data *out_string, const ref Data[] args)
{
    if (args.length != 1)
        return cast(char*)"\\isset requires only 1 parameter";

    if (find_hash_node(args[0].data, calc_hash(args[0].data)))
        add_string(out_string, "true", 4);

    return null;
}

/* test for equality */
char *guml_eq (Data *out_string, const ref Data[] args)
{
    if (args.length != 2)
        return cast(char*)"\\eq requires 2 parameters";

    if (strcmp (args[0].data, args[1].data) == 0)
        add_string(out_string, "true", 4);

    return null;
}

/* branches to second if first is true, else third if exists */
char *guml_if (Data *out_string, const ref Data[] args, const ref Data[] params)
{
    Data res = {null, 0};
    int truth = 1;

    if (args.length != 2 && args.length != 3)
        return cast(char*)"\\if requires either 2 or 3 parameters";

    const(char)* arg = args[0].data;
    guml_backend (&res, &arg, params);

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
        arg = args[1].data;
        guml_backend (out_string, &arg, params);
    }
    else
    {
        if (args.length == 3)
        {
            arg = args[2].data;
            guml_backend (out_string, &arg, params);
        }
    }

    return null;
}

char *guml_exit (Data *out_string, const ref Data[] args)
{
    if (args.length != 0)
        return cast(char*)"\\exit requires no parameters";

    fatal_error = 2;
    return cast(char*)"\\exiting";
}

char *guml_while (Data *out_string, const ref Data[] args, const ref Data[] params)
{
    int truth = 1, loop_count = 0;

    if (args.length != 2)
        return cast(char*)"\\while expects 2 parameters";

    do
    {
        loop_count++;
        if (loop_count > 5000)
            return cast(char*)"\\while -- exceeded max loop count (5000)";

        const(char)* arg = args[0].data;
        Data res;
        guml_backend (&res, &arg, params);
        if (fatal_error)
            return null;
        if (res.data == null)
            truth = 0;
        else
        {
            if (res.data[0] == '\0')
                truth = 0;
            free (res.data);
        }
        if (truth)
        {
            arg = args[1].data;

            guml_backend (out_string, &arg, params);
            if (fatal_error)
                return null;
        }
    }
    while (truth && !fatal_error);

    return null;
}

char *guml_paramcount (Data *out_string, const ref Data[] args, const ref Data[] params)
{
    char temp[1024];

    if (args.length != 0)
        return cast(char*)"\\paramcount expects no parameters";

    sprintf(temp.ptr, "%d", params.length);
    add_string(out_string, temp.ptr);

    return null;
}

char *guml_param (Data *out_string, const ref Data[] args, const ref Data[] params)
{
    int num;

    if (args.length != 1)
        return cast(char*)"\\param expects only 1 parameters";

    num = atoi(args[0].data) - 1;
    if (num  < 0 || num >= params.length)
        return null;

    add_string(out_string, params[num]);

    return null;
}
