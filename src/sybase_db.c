/* sql.c -- contains routines for connecting to SyBase */

#ifdef USE_SYBASE

#include <stdlib.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sybfront.h>
#include <sybdb.h>
#include <syberror.h>
#include <syblogin.h>

#include "global.h"

DBPROCESS *dbproc;

#ifdef LOG_ONLY_ERRORS
char *error_msg = NULL;
#endif

int sql_initted = 0;

/* prototype */
char *dberrstr (int);

#ifdef NEED_SQL_ENVIRONMENT
char *sql_init_environ (void)
{
    putenv ("LD_LIBRARY_PATH=" DB_ROOT "/lib");
    putenv ("SYBASE=" DB_ROOT);
    putenv ("DSQUERY=" DB_HOST);
    putenv ("DSLISTEN=" DB_HOST);
    return NULL;
}
#endif

/* handle errors */
int err_handler (DBPROCESS * dbp, int sev, int errno, int oserr, char *dberrstr, char *oserrstr)
{
#ifdef LOG_ONLY_ERRORS
    if (error_msg)
        writelog ("Script: %s\n", error_msg);
#endif

    writelog ("SQL ERROR %d: `%s'.\n", errno, dberrstr);

    return 0;
}

int msg_handler (DBPROCESS * dbp, DBINT msgno, int msgstate, int severity, char *msgtext, char *dummy1, char *dummy2, int dummy3)
{
    if (msgno != 5701 && msgno != 5702 && msgno != 5703)
    {
        printf ("A sql error occurred, please check the log file!<br>\n");

#ifdef LOG_ONLY_ERRORS
        if (error_msg)
            writelog ("Script: %s\n", error_msg);
#endif

        writelog ("SQL MESSAGE %d: `%s'.\n", (int) msgno, msgtext);
    }

    return 0;
}

/* start up SQL server */
char *sql_init ()
{
    LOGINREC *login;

    /* set up error and message handlers */
    dberrhandle (err_handler);
    dbmsghandle (msg_handler);

    login = dblogin ();

    if (login == NULL)
    {
        printf ("Content-type: text/plain\n\nLogin returned NULL.\n");
        exit (1);
    }

    DBSETLUSER (login, DB_USERID);
    DBSETLPWD (login, DB_PASSWORD);

    dbproc = dbopen (login, DB_HOST);

    if (dbproc == NULL)
    {
        /* couldn't open the database, all is lost */
        printf ("Content-type: text/plain\n\nDatabase returned NULL.\n");
        exit (1);
    }

    if (dbuse (dbproc, DB_DB) == FAIL)
    {
        dbexit ();
        printf ("Content-type: text/plain\n\nCannot open database tables.\n");
        exit (1);
    }

    sql_initted = 1;

    return NULL;
}

/* bring down SQL server */
char *sql_shutdown ()
{

    if (!sql_initted)
        return NULL;

    dbclose (dbproc);

    dbexit ();

    return NULL;
}

/* these provide the loaded values with a home */
DBCHAR **results = NULL;
int numcols = 0;

#define max(a,b) (a>b?a:b)

/* guml interface for SQL */
char *guml_sqlexec (Data *out_string, char *args[], int nargs)
{
    RETCODE ret_code;
    int i;

    if (!sql_initted)
        sql_init ();

    if (numcols != 0)
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
    }

    dbcmd (dbproc, args[0]);

#ifdef LOG_ONLY_ERRORS
    error_msg = malloc (strlen (args[0]) + 1);
    strcpy (error_msg, args[0]);
#else
    writelog ("%s\n", args[0]);
#endif

    if (dbsqlexec (dbproc) == FAIL)
        return "SQL EXEC error";

    if ((ret_code = dbresults (dbproc)) == NO_MORE_RESULTS)
        return NULL;

    numcols = dbnumcols (dbproc);

    results = (char **) malloc (sizeof (char *) * numcols);

    /* malloc, clear, and bind these babies */
    for (i = 0; i < numcols; i++)
    {
        results[i] = malloc (sizeof (char) * max (64, dbcollen(dbproc, i+1)));

        results[i][0] = '\0';
        dbbind (dbproc, i + 1, STRINGBIND, (DBINT) 0, results[i]);
    }

    return NULL;
}

/* get a row of returned data */
char *guml_sqlrow (Data *out_string, char *args[], int nargs)
{
    int i;

    if (!sql_initted)
        return "Sorry, bonehead, try executing a script first!";

    if (dbnextrow (dbproc) == NO_MORE_ROWS)
    {
        /* it's over! */
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
        insert_hash(strdup(args[i]), create_string(rtrim(results[i]), 0), calc_hash(args[i]), 0);

    add_string_size (out_string, "true", 4);
    return NULL;
}

#endif

