module engine;

import commands;
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
    err_string.reset();
    modetrigger  = 0;
    depth        = 0;
    fatal_error  = 0;
    free_err_res = 0;
}

void dump_accumulate(Data* from, const(char)* to, ref size_t num)
{
    if (num)
    {
        add_string(from, to-num, num);
        num = 0;
    }
}

char* guml_parse_params (const(char) **ins, const ref Data[] params, ref Data[] args, int quoted)
{
    char* err = null;
    size_t accumulate = 0;

    const(char)* cur = *ins;

    while (*cur == '{' && !err)
    {
        args.length = args.length + 1;
        check_space(&args[args.length-1], 0);

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
                            dump_accumulate(&args[args.length-1], cur, accumulate);
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
                            dump_accumulate(&args[args.length-1], cur, accumulate);
                        break;
                    default:
                        notws = 1;
                        accumulate++;
                }
                prev = *cur;
                cur++;
            }
            cur--;
            dump_accumulate(&args[args.length-1], cur, accumulate);
        }
        else
        {
            guml_backend (&args[args.length-1], &cur, params);
            if (fatal_error)
                return null;
        }

        if (*cur != '}')
            return cast(char*)"Missing } in parameter parsing";

        cur++;
    }

    *ins = cur;
    return null;
}

// out_string == results of parse
// ins == pointer to char* being parsed
// params == arguments 
extern(C) void guml_backend (Data *out_string, const(char) **ins, const ref Data[] params)
{
    size_t accumulate = 0;
    int quit = 0, notws = 1, line = 1;
    wsw wsmode = wsw.cmode;

    depth++;
    if (depth >= MAXDEPTH)
    {
        printf ("Content-type: text/plain\n\nMAXIMUM DEPTH REACHED: PROBABLY AN INFINITE LOOP!  BAILING!!!\n");
        exit (3);
    }

    const(char)* cur = *ins;

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
                    char *t = strchr(cur, '\n');
                    cur = t ? t : &(cur[strlen(cur)-1]);
                }
                notws = 0;
                break;

            case '{':
                dump_accumulate(out_string, cur, accumulate);
                notws = 1;
                cur++;
                guml_backend (out_string, &cur, params);
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
                        int quoteargs = 0;
                        char* err;

                        if ((myfunction = find_hash_node(commandstr[0 .. i], hash_value)) != null)
                            if (myfunction.flags & HASH_BUILTIN)
                            {
                                mycmd = cast(command*)(myfunction.data);
                                if (command_wants_quoted(mycmd))
                                    quoteargs = 1;
                            }

                        Data[] args;
                        err = guml_parse_params (&cur, params, args, quoteargs);
                        if (err || fatal_error)
                        {
                            char[1024] tmp;

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
                                err = command_invoke(mycmd, out_string, args, params);

                                if (modetrigger != 0)
                                {
                                    wsmode = modetrigger == 1 ? wsw.cmode : wsw.tmode;
                                    modetrigger = 0;
                                }
                            }
                            else
                            {
                                Data *env_data = myfunction.data;

                                if (env_data && (env_data.asCharStar != null))
                                {
                                    char* str = strdup(env_data.asCharStar);
                                    const(char)* env_str = str;
                                    guml_backend (out_string, &env_str, args);
                                    free(str);
                                }
                            }
                        }
                        else
                        {
                            char[128] buffer;

                            if (!fatal_error)
                                fatal_error = 1;
                            sprintf (buffer.ptr, "Undefined macro \"%s\" invoked.\n", commandstr.ptr);
                            add_string (&err_string, buffer.ptr);
                        }

                        if (err || fatal_error)
                        {
                            char[1024] tmp;

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
                            add_string(&err_string, "   ... while processing '", 25);
                            add_string(&err_string, commandstr.ptr);
                            if (!strcmp(commandstr.ptr, "include"))
                            {
                                add_string(&err_string, "' of file '", 11);
                                add_string(&err_string, args[0]);
                            }
                            add_string(&err_string, "' at line ", 10);
                            sprintf(tmp.ptr, "%d", line);
                            add_string(&err_string, tmp.ptr);
                            add_string(&err_string, ".\n", 2);
                        }

                      cleanup_params:
                        foreach(ref arg; args)
                            arg.reset();
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
                            if (i >= 0 && i < params.length)
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
