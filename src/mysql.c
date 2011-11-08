#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <mysql/mysql.h>

#include "global.h"

int sql_initted = 0;
char *sql_cmd = NULL;
MYSQL mysql;
MYSQL_RES *res = NULL;

char *text_time ()
{
    time_t tt = time (NULL);
    char *foo = ctime (&tt);

    foo[24] = '\0';

    return foo;
}

char *exiterr ()
{
    static char err_msg[1024];
    FILE *fp;

    fp = fopen ("/tmp/sqldaemon.log", "a");

    sprintf (err_msg, "%s - cmd:\t%s\n%s - error:\t%s\n", text_time (), sql_cmd ? sql_cmd : "<none>", text_time (), mysql_error (&mysql));
    if (fp)
    {
        fprintf (fp, "%s", err_msg);
        fclose (fp);
    }
    return err_msg;
}

char *sql_init ()
{
    if (!mysql_real_connect (&mysql, DB_HOST, DB_USERID, DB_PASSWORD, DB_DB, 3306, NULL, 0))
        return exiterr ();
#if 0
    else if (mysql_select_db (&mysql, DB_DB) < 0)
    {
        mysql_close (&mysql);
        return exiterr ();
    }
#endif

    sql_initted = 1;

    return NULL;
}

/* bring down SQL server */
char *sql_shutdown ()
{
    if (!sql_initted)
        return NULL;

    if (res)
    {
        mysql_free_result (res);
        res = NULL;
    }

    mysql_close (&mysql);

    if (sql_cmd)
    {
        free (sql_cmd);
        sql_cmd = NULL;
    }
    return NULL;
}

char *dbtype_str (int t)
{
    static char buff[20];

    switch (t)
    {
/*    case SYBVOID:        return "Void";
   case SYBBINARY:      return "Binary";
   case SYBBIT:         return "Bit";
   case SYBCHAR:        return "Char";
   case SYBDATETIME4:   return "Datetime4";
   case SYBDATETIME:    return "Datetime";
   case SYBDATETIMN:    return "Datetime16";
   case SYBDECIMAL:     return "Decimal";
   case SYBFLT8:        return "Float8";
   case SYBFLTN:        return "Float16";
   case SYBREAL:        return "Real";
   case SYBIMAGE:       return "Image";
   case SYBINT1:        return "Integer1";
   case SYBINT2:        return "Integer2";
   case SYBINT4:        return "Integer4";
   case SYBINTN:        return "Integer16";
   case SYBLONGBINARY:  return "LongBinary";
   case SYBLONGCHAR:    return "LongChar";
   case SYBMONEY4:      return "Money4";
   case SYBMONEY:       return "Money";
   case SYBMONEYN:      return "Money16";
   case SYBNUMERIC:     return "Numeric";
   case SYBTEXT:        return "Text";
   case SYBVARBINARY:   return "VarBinary";
   case SYBVARCHAR:     return "VarChar";
   case SYBSENSITIVITY: return "Sensitivity";
   case SYBBOUNDARY:    return "Boundary"; */
        default:
            sprintf (buff, "Unknown: %d", t);
            return buff;
    }
}

char *guml_sqlexec (Data *out_string, char *args[], int nargs)
{
    char *initres;

    if (nargs != 1)
        return "\\sqlexec requries only 1 parameter";

    if (!sql_initted)
        if ((initres = sql_init()) != NULL)
            return initres;

    if (res)
    {
        mysql_free_result (res);
        res = NULL;
    }

    if (sql_cmd)
        free (sql_cmd);

    while (args[0][strlen(args[0])-1] == '\n')
        args[0][strlen(args[0])-1] = '\0';

    sql_cmd = strdup (args[0]);

    if (mysql_query (&mysql, sql_cmd))
        return exiterr ();

    if (!(res = mysql_store_result(&mysql)) && mysql_field_count(&mysql))
        return exiterr ();

    /*if (!(res = mysql_store_result (&mysql)))
        return exiterr ();*/

    return NULL;
}

char *guml_sqlrow (Data *out_string, char *args[], int nargs)
{
    MYSQL_ROW row;
    int i;

    if (!res)
        return NULL;

    row = mysql_fetch_row (res);
    if (!row)
        return NULL;

    for (i = 0; i < mysql_num_fields(res) && i < nargs; i++)
        if (row[i])
            insert_hash(strdup(args[i]), create_string(row[i], 0), calc_hash(args[i]), 0);
        else
            insert_hash(strdup(args[i]), create_string("", 0), calc_hash(args[i]), 0);

    add_string_size (out_string, "true", 4);
    return NULL;
}
