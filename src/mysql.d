module mysql;

import data;
import hash_table;
import setup;
import string_utils;

import core.stdc.config;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.time;

struct MYSQL
{
    ubyte junk[1272];
}

struct MYSQL_RES;
alias char** MYSQL_ROW;

extern(C)
{
    extern MYSQL* mysql_init(MYSQL *mysql);
    extern MYSQL* mysql_real_connect(MYSQL *mysql, const char *host, const char *user, const char *passwd, const char *db, uint port, const char *unix_socket, c_ulong clientflag);
    extern const(char)* mysql_error(MYSQL *mysql);
    extern void	mysql_free_result(MYSQL_RES *result);
    extern void mysql_close(MYSQL *sock);
    extern int mysql_query(MYSQL *mysql, const char *q);
    extern MYSQL_ROW mysql_fetch_row(MYSQL_RES *result);
    extern MYSQL_RES* mysql_store_result(MYSQL *mysql);
    extern uint mysql_field_count(MYSQL *mysql);
    extern uint mysql_num_fields(MYSQL_RES *res);
}

int sql_initted = 0;
char *sql_cmd = null;
MYSQL mysql;
MYSQL_RES *res = null;

char *text_time ()
{
    time_t tt = time (null);
    char *foo = ctime (&tt);

    foo[24] = '\0';

    return foo;
}

char *exiterr ()
{
    static char err_msg[1024];
    FILE *fp;

    fp = fopen ("/tmp/sqldaemon.log", "a");

    sprintf (err_msg.ptr, "%s - cmd:\t%s\n%s - error:\t%s\n", text_time (), sql_cmd ? sql_cmd : "<none>", text_time (), mysql_error (&mysql));
    if (fp)
    {
        fprintf (fp, "%s", err_msg.ptr);
        fclose (fp);
    }
    return err_msg.ptr;
}

char *sql_init ()
{
    Data* db_host     = find_hash_data("DB_HOST",     calc_hash("DB_HOST"));
    Data* db_userid   = find_hash_data("DB_USERID",   calc_hash("DB_USERID"));
    Data* db_password = find_hash_data("DB_PASSWORD", calc_hash("DB_PASSWORD"));
    Data* db_db       = find_hash_data("DB_DB",       calc_hash("DB_DB"));

    if (!db_host || !db_userid || !db_password || !db_db)
        return null;

    mysql_init(&mysql);

    if (!mysql_real_connect (&mysql, db_host.data, db_userid.data, db_password.data, db_db.data, 3306, null, 0))
        return exiterr ();

    sql_initted = 1;

    return null;
}

/* bring down SQL server */
char *sql_shutdown ()
{
    if (!sql_initted)
        return null;

    if (res)
    {
        mysql_free_result (res);
        res = null;
    }

    mysql_close (&mysql);

    if (sql_cmd)
    {
        free (sql_cmd);
        sql_cmd = null;
    }
    return null;
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
            sprintf (buff.ptr, "Unknown: %d", t);
            return buff.ptr;
    }
}

char *guml_sqlexec (Data *out_string, char** args, int nargs)
{
    char *initres;

    if (nargs != 1)
        return cast(char*)"\\sqlexec requries only 1 parameter";

    if (!sql_initted)
        if ((initres = sql_init()) != null)
            return initres;

    if (res)
    {
        mysql_free_result (res);
        res = null;
    }

    if (sql_cmd)
        free (sql_cmd);

    while (args[0][strlen(args[0])-1] == '\n')
        args[0][strlen(args[0])-1] = '\0';

    sql_cmd = strdup (args[0]);

    if (mysql_query (&mysql, sql_cmd))
        return exiterr ();

    res = mysql_store_result(&mysql);
    if (!res && mysql_field_count(&mysql))
        return exiterr ();

    /*if (!(res = mysql_store_result (&mysql)))
        return exiterr ();*/

    return null;
}

char *guml_sqlrow (Data *out_string, char** args, int nargs)
{
    MYSQL_ROW row;
    int i;

    if (!res)
        return null;

    row = mysql_fetch_row (res);
    if (!row)
        return null;

    for (i = 0; i < mysql_num_fields(res) && i < nargs; i++)
        if (row[i])
            insert_hash(strdup(args[i]), create_string(row[i]), calc_hash(args[i]), 0);
        else
            insert_hash(strdup(args[i]), create_string(""), calc_hash(args[i]), 0);

    add_string_size (out_string, cast(char*)"true", 4);
    return null;
}
