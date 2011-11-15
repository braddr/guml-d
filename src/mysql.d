module mysql;

import hash_table;
import setup;
import string_utils;

import core.stdc.config;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.time;

struct MYSQL { ubyte[1272] junk; } // sizeof on 64 bit linux from the c header
struct MYSQL_RES;
alias char** MYSQL_ROW;

enum mysql_option
{
    MYSQL_OPT_CONNECT_TIMEOUT, MYSQL_OPT_COMPRESS, MYSQL_OPT_NAMED_PIPE,
    MYSQL_INIT_COMMAND, MYSQL_READ_DEFAULT_FILE, MYSQL_READ_DEFAULT_GROUP,
    MYSQL_SET_CHARSET_DIR, MYSQL_SET_CHARSET_NAME, MYSQL_OPT_LOCAL_INFILE,
    MYSQL_OPT_PROTOCOL, MYSQL_SHARED_MEMORY_BASE_NAME, MYSQL_OPT_READ_TIMEOUT,
    MYSQL_OPT_WRITE_TIMEOUT, MYSQL_OPT_USE_RESULT,
    MYSQL_OPT_USE_REMOTE_CONNECTION, MYSQL_OPT_USE_EMBEDDED_CONNECTION,
    MYSQL_OPT_GUESS_CONNECTION, MYSQL_SET_CLIENT_IP, MYSQL_SECURE_AUTH,
    MYSQL_REPORT_DATA_TRUNCATION, MYSQL_OPT_RECONNECT,
    MYSQL_OPT_SSL_VERIFY_SERVER_CERT
};

enum CLIENT_REMEMBER_OPTIONS = 1UL << 31;

extern(C)
{
    extern MYSQL* mysql_init(MYSQL *mysql);
    extern int mysql_options(MYSQL *mysql, mysql_option option, const void *arg);
    extern MYSQL* mysql_real_connect(MYSQL *mysql, const char *host, const char *user, const char *passwd, const char *db, uint port, const char *unix_socket, c_ulong clientflag);
    extern void mysql_close(MYSQL *sock);
    extern void mysql_server_end();

    extern const(char)* mysql_error(MYSQL *mysql);

    extern int mysql_query(MYSQL *mysql, const char *q);
    extern MYSQL_ROW mysql_fetch_row(MYSQL_RES *result);
    extern MYSQL_RES* mysql_store_result(MYSQL *mysql);
    extern void	mysql_free_result(MYSQL_RES *result);

    extern c_ulong mysql_escape_string(char *to, const char *from, c_ulong from_length);
    extern uint mysql_field_count(MYSQL *mysql);
    extern uint mysql_num_fields(MYSQL_RES *res);
}

MYSQL*[string] sitedbs;

char *sql_cmd = null;
MYSQL_RES *res = null;

private char *text_time ()
{
    time_t tt = time (null);
    char *foo = ctime (&tt);

    foo[24] = '\0';

    return foo;
}

private char *exiterr ()
{
    static char err_msg[1024];

    FILE *fp = fopen ("/tmp/sqldaemon.log", "a");
    MYSQL* m = lookupdb();

    sprintf (err_msg.ptr, "%s - cmd:\t%s\n%s - error:\t%s\n",
            text_time (), sql_cmd ? sql_cmd : "<none>",
            text_time (), m ? mysql_error (m) : "<unknown>");
    if (fp)
    {
        fprintf (fp, "%s", err_msg.ptr);
        fclose (fp);
    }
    return err_msg.ptr;
}

private MYSQL* lookupdb()
{
    Data* sn = find_hash_data("SERVERNAME", calc_hash("SERVERNAME"));
    MYSQL** m = sn.asString in sitedbs;

    return m != null ? *m : null;
}

private void storedb(MYSQL* m)
{
    Data* sn = find_hash_data("SERVERNAME", calc_hash("SERVERNAME"));
    sitedbs[sn.asString.idup] = m;
}

char *sql_init ()
{
    MYSQL* m = lookupdb();
    assert(!m);

    Data* db_host     = find_hash_data("DB_HOST",     calc_hash("DB_HOST"));
    Data* db_userid   = find_hash_data("DB_USERID",   calc_hash("DB_USERID"));
    Data* db_password = find_hash_data("DB_PASSWORD", calc_hash("DB_PASSWORD"));
    Data* db_db       = find_hash_data("DB_DB",       calc_hash("DB_DB"));

    if (!db_host || !db_userid || !db_password || !db_db)
        return null;

    writelog("connecting to mysql server: %s:%s", db_host.asCharStar, db_db.asCharStar);
    m = mysql_init(null);
    storedb(m);

    ubyte opt = 1;
    if (mysql_options(m, mysql_option.MYSQL_OPT_RECONNECT, &opt) != 0)
        return exiterr();

    if (!mysql_real_connect (m, db_host.asCharStar, db_userid.asCharStar, db_password.asCharStar, db_db.asCharStar, 3306, null, CLIENT_REMEMBER_OPTIONS))
        return exiterr();

    return null;
}

char *sql_cleanup_after_page()
{
    if (res)
    {
        mysql_free_result(res);
        res = null;
    }

    if (sql_cmd)
    {
        free(sql_cmd);
        sql_cmd = null;
    }

    return null;
}

void sql_reset_connection()
{
    MYSQL* m = lookupdb();

    if (m)
    {
        mysql_close(m);
        storedb(null);
    }
    sql_init();
}

char *sql_shutdown ()
{
    foreach(k, v; sitedbs)
    {
        writelog("closing sql connection for %.*s", k.length, k.ptr);
        if (v)
            mysql_close(v);
    }
    mysql_server_end();

    return null;
}

char *guml_sqlexec (Data *out_string, const ref Data[] args)
{
    if (args.length != 1)
        return cast(char*)"\\sqlexec requries only 1 parameter";

    MYSQL* m = lookupdb();
    if (!m)
    {
        char *rc = sql_init();
        if (rc)
            return rc;
        m = lookupdb();
    }

    if (res)
    {
        mysql_free_result (res);
        res = null;
    }

    if (sql_cmd)
        free (sql_cmd);

    sql_cmd = strdup(args[0].asCharStar);
    size_t len = strlen(sql_cmd);

    while (sql_cmd[len-1] == '\n')
    {
        sql_cmd[len-1] = '\0';
        len--;
    }

    if (mysql_query (m, sql_cmd))
        return exiterr ();

    res = mysql_store_result(m);
    if (!res && mysql_field_count(m))
        return exiterr ();

    return null;
}

char *guml_sqlrow (Data *out_string, const ref Data[] args)
{
    // if no query in progress
    if (!res) return null;

    MYSQL* m = lookupdb();

    // if not connected
    if (!m) return null;

    MYSQL_ROW row = mysql_fetch_row (res);
    if (!row) return null;

    for (int i = 0; i < mysql_num_fields(res) && i < args.length; i++)
        if (row[i])
            insert_hash(create_string(args[i]), create_string(row[i]), calc_hash(args[i]), 0);
        else
            insert_hash(create_string(args[i]), create_string(""), calc_hash(args[i]), 0);

    add_string(out_string, cast(char*)"true", 4);
    return null;
}

/* quote a string; that is, replace double quotes
   with backslashed double-quotes */
char *guml_sqlquote(Data *out_string, const ref Data[] args)
{
    if (args.length != 1)
        return cast(char*)"\\sqlquote requires only 1 parameter";

    char* outstr = cast(char*)malloc(args[0].length * 2 + 1 );

    size_t len = mysql_escape_string(outstr, args[0].asCharStar, args[0].length);
    add_string(out_string, outstr, len);
    free(outstr);

    return null;
}
