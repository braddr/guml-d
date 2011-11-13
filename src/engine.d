module engine;

import commands;
import data;
import hash_table;
import string_utils;

import core.stdc.config;
import core.stdc.string;
import core.stdc.stdio;
import core.stdc.stdlib;

extern(C)
{
    __gshared Data err_string;
    __gshared int modetrigger;
}

enum wsw
{
    cmode, smode, tmode
}

enum MAXDEPTH = 100;

int depth;
__gshared int fatal_error;
int free_err_res;

void init_engine()
{
    err_string.data = null;
    err_string.length = 0;
    modetrigger  = 0;
    depth        = 0;
    fatal_error  = 0;
    free_err_res = 0;
}

void dump_accumulate(Data* from, char* to, ref size_t num)
{
    if (num)
    {
        add_string_size(from, to-num, num);
        num = 0;
    }
}

char* guml_parse_params (char **ins, char **params, int numparams, char ***args, int *nargs, int quoted)
{
    char* cur, err = null;
    size_t accumulate = 0;

    cur = *ins;

    *nargs = 0;

    while (*cur == '{' && !err)
    {
        Data t;

        t.data = null;
        t.length = 0;
        *args = cast(char**) realloc (*args, (char*).sizeof * ((*nargs) + 1));

        cur++;
        if (quoted)
        {
            char prev;
            int nesting = 0, notws = 1;

            prev = 0;
            while (*cur && nesting >= 0)
            {
                switch (*cur)
                {
                    case '{':
                        nesting++;
                        accumulate++;
                        break;
                    case '}':
                        nesting--;
                        if (nesting >= 0)
                            accumulate++;
                        break;
                    case '#':
                        if (prev != '\\')
                        {
                            char *tmp;

                            notws = 0;
                            dump_accumulate(&t, cur, accumulate);
                            tmp = strchr(cur, '\n');
                            cur = tmp ? tmp : &(cur[strlen(cur)-1]);
                        }
                        else
                            accumulate++;
                        break;
                    case '\n':
                        notws = 0;
                        accumulate++;
                        break;
                    case '\f':
                    case '\r':
                    case '\t':
                    case '\v':
                    case ' ':
                        if (notws)
                            accumulate++;
                        else
                            dump_accumulate(&t, cur, accumulate);
                        break;
                    default:
                        notws = 1;
                        accumulate++;
                }
                prev = *cur;
                cur++;
            }
            cur--;
            dump_accumulate(&t, cur, accumulate);
            (*args)[*nargs] = t.data;
        }
        else
        {
            guml_backend (&t, &cur, params, numparams);
            (*args)[*nargs] = t.data;
            if (fatal_error)
                return null;
        }

        if ((*args)[*nargs] == null)
        {
            (*args)[*nargs] = cast(char*) malloc (1);
            (*args)[*nargs][0] = 0;
        }

        (*nargs)++;

        if (*cur != '}')
            return cast(char*)"Missing } in parameter parsing";

        cur++;
    }

    *ins = cur;
    return null;
}

extern(C) void guml_backend (Data *out_string, char **ins, char **params, int numparams)
{
    size_t accumulate = 0;
    int quit = 0, notws = 1, line = 1;
    char *cur;
    wsw wsmode = wsw.cmode;

    depth++;
    if (depth >= MAXDEPTH)
    {
        printf ("Content-type: text/plain\n\nMAXIMUM DEPTH REACHED: PROBABLY AN INFINITE LOOP!  BAILING!!!\n");
        exit (3);
    }

    cur = *ins;

    while (*cur && !quit && !fatal_error)
    {
        switch (*cur)
        {
            case '\n':
                line++;
                notws = 0;
                if (wsmode == wsw.tmode)
                    accumulate++;
                else
                    dump_accumulate(out_string, cur, accumulate);
                break;

            case ' ':
            case '\f':
            case '\r':
            case '\t':
            case '\v':
                if (notws && (wsmode == wsw.tmode))
                    accumulate++;
                else
                    dump_accumulate(out_string, cur, accumulate);
                break;

            case '#':
                dump_accumulate(out_string, cur, accumulate);
                {
                    char *t;

                    t = strchr(cur, '\n');
                    cur = t ? t : &(cur[strlen(cur)-1]);
                }
                notws = 0;
                break;

            case '{':
                dump_accumulate(out_string, cur, accumulate);
                notws = 1;
                cur++;
                guml_backend (out_string, &cur, params, numparams);
                if (fatal_error)
                    return;
                break;

            case '}':
                dump_accumulate(out_string, cur, accumulate);
                quit = 1;
                notws = 1;
                break;

            case '\\':
                dump_accumulate(out_string, cur, accumulate);
                {
                    char[100] commandstr;
                    c_ulong hash_value = 0;
                    int i;

                    notws = 1;
                    i = 0;
                    cur++;
                    while (*cur && ((*cur >= 'A' && *cur <= 'Z') || (*cur >= 'a' && *cur <= 'z') || *cur == '_') && i < 99)
                    {
                        commandstr[i] = *cur;
                        calc_hash_increment(&hash_value, *cur);
                        i++;
                        cur++;
                    }
                    commandstr[i] = 0;

                    if (commandstr[0])
                    {
                        command *mycmd = null;
                        HashNode *myfunction;
                        int quoteargs = 0, nargs = 0;
                        char** args = null;
                        char* err;

                        if ((myfunction = find_hash_node(commandstr.ptr, hash_value)) != null)
                            if (myfunction.flags & HASH_BUILTIN)
                            {
                                mycmd = cast(command*)(myfunction.data);
                                if (command_wants_quoted(mycmd))
                                    quoteargs = 1;
                            }

                        err = guml_parse_params (&cur, params, numparams, &args, &nargs, quoteargs);
                        if (err || fatal_error)
                        {
                            char tmp[1024];

                            if (!fatal_error)
                                fatal_error = 1;
                            if (err)
                            {
                                add_string(&err_string, err);
                                add_char(&err_string, '\n');
                            }
                            sprintf(tmp.ptr, "   ... while parsing parameters for '%s' at line %d.\n", commandstr.ptr, line);
                            add_string(&err_string, tmp.ptr);
                            goto cleanup_params;
                        }

                        if (myfunction)
                        {
                            if (myfunction.flags & HASH_BUILTIN)
                            {
                                err = command_invoke(mycmd, out_string, args, nargs, params, numparams);

                                if (modetrigger != 0)
                                {
                                    wsmode = modetrigger == 1 ? wsw.cmode : wsw.tmode;
                                    modetrigger = 0;
                                }
                            }
                            else
                            {
                                Data *env_data;
                                char* env_str, str;

                                env_data = myfunction.data;
                                if (env_data && ((env_str = env_data.data) != null))
                                {
                                    str = strdup(env_str);
                                    env_str = str;
                                    guml_backend (out_string, &str, args, nargs);
                                    free(env_str);
                                }
                            }
                        }
                        else
                        {
                            char buffer[128];

                            if (!fatal_error)
                                fatal_error = 1;
                            sprintf (buffer.ptr, "Undefined macro \"%s\" invoked.\n", commandstr);
                            add_string (&err_string, buffer.ptr);
                        }

                        if (err || fatal_error)
                        {
                            char tmp[1024];

                            if (!fatal_error)
                                fatal_error = 1;
                            if (err)
                            {
                                switch(free_err_res)
                                {
                                    case 0:
                                        add_string (&err_string, err);
                                        break;
                                    case 1:
                                        add_string (&err_string, *(cast(char**)err));
                                        free(*(cast(char**)err));
                                        *(cast(char**)err) = null;
                                        free_err_res = 0;
                                        break;
                                    case 2:
                                        add_string (&err_string, err);
                                        free(err);
                                        free_err_res = 0;
                                        break;
                                    default:
                                        add_string(&err_string, "CRITICAL ERROR -- missing free_err_res case #3");
                                        free_err_res = 0;
                                }
                                add_char (&err_string, '\n');
                            }
                            add_string_size(&err_string, "   ... while processing '", 25);
                            add_string(&err_string, commandstr.ptr);
                            if (!strcmp(commandstr.ptr, "include"))
                            {
                                add_string_size(&err_string, "' of file '", 11);
                                add_string(&err_string, args[0]);
                            }
                            add_string_size(&err_string, "' at line ", 10);
                            sprintf(tmp.ptr, "%d", line);
                            add_string(&err_string, tmp.ptr);
                            add_string_size(&err_string, ".\n", 2);
                        }

                      cleanup_params:
                        for (i = 0; i < nargs; i++)
                            free (args[i]);
                        free (args);
                        cur--;
                    }
                    else
                    {
                        while (*cur && *cur >= '0' && *cur <= '9' && i < 99)
                        {
                            commandstr[i] = *cur;
                            i++;
                            cur++;
                        }
                        commandstr[i] = 0;
                        if (commandstr[0])
                        {
                            cur--;
                            i = atoi (commandstr.ptr) - 1;
                            if (i >= 0 && i < numparams)
                                add_string (out_string, params[i]);
                        }
                        else
                        {
                            wsmode = wsw.tmode;
                            accumulate++;
                        }
                    }
                }
                break;

            default:
                wsmode = wsw.tmode;
                notws = 1;
                accumulate++;
        }
        if (!quit && !fatal_error)
            cur++;
    }
    dump_accumulate(out_string, cur, accumulate);

    *ins = cur;

    depth--;

    return;
}

/* end */
