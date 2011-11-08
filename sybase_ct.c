/* sql.c -- contains routines for connecting to SyBase */

#include <stdlib.h>
#include <time.h>
#include <string.h>
#include <stdio.h>

#include <ctpublic.h>

#include "global.h"
#include "sql.h"
#include "env.h"

extern int free_err_res;

typedef struct _ex_column_data
{
    CS_SMALLINT indicator;
    CS_CHAR     *value;
    CS_INT      valuelen;
} SQL_DATA;

CS_CONTEXT    *context    = NULL;
CS_CONNECTION *connection = NULL;
CS_RETCODE     retcode    = CS_SUCCEED;
CS_COMMAND    *cmd        = NULL;

int   sql_initted   = 0;
char *cb_messages   = NULL;
long  cb_msg_size   = 0;

#ifdef LOG_ONLY_ERRORS
char *error_msg = NULL;
#endif

char *sql_exec_cmd(char *cmd);

#ifdef NEED_SQL_ENVIRONMENT
int sql_init_environ (void)
{
    putenv ("LD_LIBRARY_PATH=" DB_ROOT "/lib");
    putenv ("SYBASE=" DB_ROOT);
    putenv ("DSQUERY=" DB_HOST);
    putenv ("DSLISTEN=" DB_HOST);
    return 0;
}
#endif

/* get time as text string */
char *text_time ()
{
    time_t tt = time (NULL);
    char *foo = ctime (&tt);

    foo[24] = '\0';

    return foo;
}

CS_RETCODE CS_PUBLIC sql_clientmsg_cb(CS_CONTEXT *context, CS_CONNECTION *connection, CS_CLIENTMSG *errmsg)
{
    char tmp[1024];

printf("In sql_clientmsg_cb\n");
    add_string(&cb_messages, &cb_msg_size, "Open Client Message:\n");
    sprintf(tmp, "Message number: LAYER = (%ld) ORIGIN = (%ld) ", CS_LAYER(errmsg->msgnumber), CS_ORIGIN(errmsg->msgnumber));
    add_string(&cb_messages, &cb_msg_size, tmp);
    sprintf(tmp, "SEVERITY = (%ld) NUMBER = (%ld)\n", CS_SEVERITY(errmsg->msgnumber), CS_NUMBER(errmsg->msgnumber));
    add_string(&cb_messages, &cb_msg_size, tmp);
    add_string(&cb_messages, &cb_msg_size, "Message String: ");
    add_string(&cb_messages, &cb_msg_size, errmsg->msgstring);
    add_char(&cb_messages, &cb_msg_size, '\n');
    if (errmsg->osstringlen > 0)
    {
        add_string(&cb_messages, &cb_msg_size, "Operating System Error: ");
        add_string(&cb_messages, &cb_msg_size, errmsg->osstring);
        add_char(&cb_messages, &cb_msg_size, '\n');
    }

    return CS_SUCCEED;
}

CS_RETCODE CS_PUBLIC sql_servermsg_cb(CS_CONTEXT *context, CS_CONNECTION *connection, CS_SERVERMSG *srvmsg)
{
    char tmp[1024];

printf("In sql_servermsg_cb\n");
    if (srvmsg->msgnumber == 5701 || srvmsg->msgnumber == 5703 || srvmsg->msgnumber == 5704)
        return CS_SUCCEED;

    add_string(&cb_messages, &cb_msg_size, "Server message:\n");
    sprintf(tmp, "Message number: %ld, Severity %ld, ", srvmsg->msgnumber, srvmsg->severity);
    add_string(&cb_messages, &cb_msg_size, tmp);
    sprintf(tmp, "State %ld, Line %ld\n", srvmsg->state, srvmsg->line);
    add_string(&cb_messages, &cb_msg_size, tmp);

    if (srvmsg->svrnlen > 0)
    {
        add_string(&cb_messages, &cb_msg_size, "Server '");
        add_string(&cb_messages, &cb_msg_size, srvmsg->svrname);
        add_string(&cb_messages, &cb_msg_size, "'\n");
    }

    if (srvmsg->proclen > 0)
    {
        add_string(&cb_messages, &cb_msg_size, " Procedure '");
        add_string(&cb_messages, &cb_msg_size, srvmsg->proc);
        add_string(&cb_messages, &cb_msg_size, "'\n");
    }

    add_string(&cb_messages, &cb_msg_size, "Message String: ");
    add_string(&cb_messages, &cb_msg_size, srvmsg->text);
    add_char(&cb_messages, &cb_msg_size, '\n');

    return CS_SUCCEED;
}

CS_RETCODE CS_PUBLIC sql_init_context(CS_CONTEXT **context)
{
    CS_RETCODE retcode;

    retcode = cs_ctx_alloc(CS_VERSION_100, context);
    if (retcode != CS_SUCCEED)
    {
        add_string(&cb_messages, &cb_msg_size, "sql_init_context: cs_ctx_alloc() failed");
        return retcode;
    }

    retcode = ct_init(*context, CS_VERSION_100);
    if (retcode != CS_SUCCEED)
    {
        cs_ctx_drop(*context);
        *context = NULL;
        add_string(&cb_messages, &cb_msg_size, "sql_init_context: ct_init() failed");
        return retcode;
    }

    retcode = ct_callback(*context, NULL, CS_SET, CS_CLIENTMSG_CB, (CS_VOID *)sql_clientmsg_cb);
    if (retcode != CS_SUCCEED)
        add_string(&cb_messages, &cb_msg_size, "sql_init_context: ct_callback(clientmsg) failed");

    if (retcode == CS_SUCCEED)
    {
        retcode = ct_callback(*context, NULL, CS_SET, CS_SERVERMSG_CB, (CS_VOID *)sql_servermsg_cb);
        if (retcode != CS_SUCCEED)
            add_string(&cb_messages, &cb_msg_size, "sql_init_context: ct_callback(servermsg) failed");
    }

    if (retcode != CS_SUCCEED)
    {
        ct_exit(*context, CS_FORCE_EXIT);
        cs_ctx_drop(*context);
        *context = NULL;
    }

    return retcode;
}

CS_RETCODE CS_PUBLIC sql_init_connect(CS_CONTEXT *context, CS_CONNECTION **connection)
{
    CS_INT     len;
    CS_RETCODE retcode;

    retcode = ct_con_alloc(context, connection);
    if (retcode != CS_SUCCEED)
    {
        add_string(&cb_messages, &cb_msg_size, "sql_init_connect: ct_con_alloc failed");
        return retcode;
    }

    if (retcode == CS_SUCCEED && DB_USERID != NULL)
    {
        if ((retcode = ct_con_props(*connection, CS_SET, CS_USERNAME, DB_USERID, CS_NULLTERM, NULL)) != CS_SUCCEED)
            add_string(&cb_messages, &cb_msg_size, "sql_init_connect: ct_con_props(username) failed");
    }

    if (retcode == CS_SUCCEED && DB_PASSWORD != NULL)
    {
        if ((retcode = ct_con_props(*connection, CS_SET, CS_PASSWORD, DB_PASSWORD, CS_NULLTERM, NULL)) != CS_SUCCEED)
            add_string(&cb_messages, &cb_msg_size, "sql_init_connect: ct_con_props(password) failed");
    }

    if (retcode == CS_SUCCEED && DB_APPNAME != NULL)
    {
        if ((retcode = ct_con_props(*connection, CS_SET, CS_APPNAME, DB_APPNAME, CS_NULLTERM, NULL)) != CS_SUCCEED)
            add_string(&cb_messages, &cb_msg_size, "sql_init_connect: ct_con_props(appname) failed");
    }

    if (retcode == CS_SUCCEED)
    {
        len = (DB_HOST == NULL) ? 0 : CS_NULLTERM;
        retcode = ct_connect(*connection, DB_HOST, len);
        if (retcode != CS_SUCCEED)
            add_string(&cb_messages, &cb_msg_size, "sql_init_connect: ct_connect failed");
    }

    if (retcode != CS_SUCCEED)
    {
        ct_con_drop(*connection);
        *connection = NULL;
    }

    return retcode;
}

CS_RETCODE sql_use_db(CS_CONNECTION *connection)
{
    CS_RETCODE result_type;
    CS_COMMAND *cmd=NULL;
    CS_CHAR     sqlbuf[6 + strlen(DB_DB)];

    if ((retcode = ct_cmd_alloc(connection, &cmd )) != CS_SUCCEED)
        return retcode;

    strcpy(sqlbuf, "use " DB_DB);

    if ((retcode = ct_command(cmd, CS_LANG_CMD, sqlbuf, CS_NULLTERM, CS_UNUSED)) != CS_SUCCEED)
    {
        ct_cmd_drop(cmd);
        return retcode;
    }

    if ((retcode = ct_send(cmd)) != CS_SUCCEED)
    {
        ct_cmd_drop( cmd );
        return retcode;
    }

    while (ct_results(cmd, &result_type) != CS_END_RESULTS);
    ct_cmd_drop(cmd);

    return retcode;
}

CS_RETCODE CS_PUBLIC sql_con_cleanup(CS_CONNECTION *connection, CS_RETCODE status)
{
    CS_RETCODE retcode;
    CS_INT     close_option;

    close_option = (status != CS_SUCCEED) ? CS_FORCE_CLOSE : CS_UNUSED;
    retcode = ct_close(connection, close_option);
    if (retcode != CS_SUCCEED)
    {
        add_string(&cb_messages, &cb_msg_size, "sql_con_cleanup: ct_close() failed");
        return retcode;
    }
    retcode = ct_con_drop(connection);
    if (retcode != CS_SUCCEED)
    {
        add_string(&cb_messages, &cb_msg_size, "sql_con_cleanup: ct_con_drop() failed");
        return retcode;
    }

    return retcode;
}

CS_RETCODE CS_PUBLIC sql_ctx_cleanup(CS_CONTEXT *context, CS_RETCODE status)
{
    CS_RETCODE retcode;
    CS_INT     exit_option;

    exit_option = (status != CS_SUCCEED) ? CS_FORCE_EXIT : CS_UNUSED;
    retcode = ct_exit(context, exit_option);
    if (retcode != CS_SUCCEED)
    {
        add_string(&cb_messages, &cb_msg_size, "sql_ctx_cleanup: ct_exit() failed");
        return retcode;
    }
    retcode = cs_ctx_drop(context);
    if (retcode != CS_SUCCEED)
    {
        add_string(&cb_messages, &cb_msg_size, "sql_ctx_cleanup: cs_ctx_drop() failed");
        return retcode;
    }
    return retcode;
}

char *sql_init ()
{
    retcode = sql_init_context(&context);
    if (retcode != CS_SUCCEED)
        return "sql_init: fatal error initializing sql context";

    retcode = sql_init_connect(context, &connection);
    if (retcode != CS_SUCCEED)
    {
        retcode = sql_ctx_cleanup(context, retcode);
        return "sql_init: fatal error connecting";
    }

    retcode = sql_use_db(connection);
    if (retcode  != CS_SUCCEED)
    {
        retcode = sql_con_cleanup(connection, retcode);
        retcode = sql_ctx_cleanup(context, retcode);
        return "sql_init: sql_use_db failed";
    }
 
    sql_initted = 1;

    return NULL;
}

/* bring down SQL server */
char *sql_shutdown ()
{
    if (!sql_initted)
        return 1;

    if (connection != NULL)
        retcode = sql_con_cleanup(connection, retcode);

    if (context != NULL)
        retcode = sql_ctx_cleanup(context, retcode);

    return NULL;
}

/* these provide the loaded values with a home */

SQL_DATA *results = NULL;
int numcols = 0;

#define max(a,b) (a>b?a:b)


char *sql_exec_cmd(char *cmd)
{
    return NULL;
}

/* guml interface for SQL */
char *guml_sqlexec (Data *out_string, char *args[], int nargs)
{
    char *err = NULL;
    int i;
    FILE *fp;

    if (nargs != 1)
        return "\\sqlexec requires only 1 parameter";

    if (!sql_initted)
    {
        err = sql_init();
        if (err)
            add_string(&cb_messages, &cb_msg_size, err);
        if (cb_messages)
        {
            free_err_res = 1;
            return (char *)&cb_messages;
        }
    }

    if (cmd)
    {
        ct_cmd_drop(cmd);
        cmd = NULL;
    }

    if (numcols != 0)
    {
        for (i = 0; i < numcols; i++)
            free (results[i].value);
        free (results);
        results = NULL;
        numcols = 0;
#ifdef LOG_ONLY_ERRORS
        if (error_msg)
        {
            free (error_msg);
            error_msg = NULL;
        }
#endif
    }

    if ((retcode = ct_command(cmd, CS_LANG_CMD, args[0], CS_NULLTERM, CS_UNUSED)) != CS_SUCCEED)
    {
        char tmp[1024];

        sprintf(tmp, "retcode: %d\n", retcode);
        add_string(&cb_messages, &cb_msg_size, tmp);
        ct_cmd_drop(cmd);
        sleep(1);
        if (cb_messages)
        {
            free_err_res = 1;
            return (char*)&cb_messages;
        }
        else
            return "\\sqlexec -- failed ct_command";
    }

    if ((retcode = ct_send(cmd)) != CS_SUCCEED)
    {
        ct_cmd_drop(cmd);
        if (cb_messages)
        {
            free_err_res = 1;
            return (char*)&cb_messages;
        }
        else
            return "\\sqlexec -- failed ct_send";
    }

#ifdef LOG_ONLY_ERRORS
    error_msg = strdup(args[0]);
#else
    if ((fp = fopen (LOGFILE, "a")) != NULL)
    {
        fprintf (fp, "%s\n", args[0]);
        fclose (fp);
    }
#endif

    return NULL;
}

/* get a row of returned data */
char *guml_sqlrow (Data *out_string, char *args[], int nargs)
{
    CS_RETCODE result_type;

    if (!sql_initted)
        return "\\sqlrow -- no sql command ever started";

    if (!cmd)
        return "\\sqlrow -- no sql command in progress";

    while (ct_results(cmd, &result_type) != CS_END_RESULTS)
        sleep(1);
    ct_cmd_drop(cmd);

/*
    int i;

    if (dbnextrow (dbproc) == NO_MORE_ROWS)
    {
        for (i = 0; i < numcols; i++)
            free (results[i]);
        free (results);
        results = NULL;
        numcols = 0;
#ifdef LOG_ONLY_ERRORS
        if (error_msg)
        {
            free (error_msg);
            error_msg = NULL;
        }
#endif
        return NULL;
    }

    for (i = 0; i < nargs && i < numcols; i++)
        setEnv (args[i], rtrim(results[i]));

    add_string_size (out_string, "true", 4);
*/
    if (cb_messages)
    {
        free_err_res = 1;
        return (char *)&cb_messages;
    }
    else
        return NULL;
}

/* quote a string, that is, get replace double quotes with backslashed double-quotes */
char *guml_sqlquote (Data *out_string, char *args[], int nargs)
{
    char *t, *u;

    if (nargs != 1)
        return "\\sqlquote requires only 1 parameter";

    t = strtok(args[0], "\"");
    while (t)
    {
        u = t;
        t = strtok(NULL, "\"");
        add_string(out_string, u);
        if (t)
            add_string_size (out_string, "\"\"", 2);
    }

    return NULL;
}

/* end */
