#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "global.h"

$include sqlstype;
$include locator;
$include sqltypes;

$struct loc_list_t
{
    loc_t ptr;
    int   freeit;
    struct loc_list_t *next;
};

struct loc_list_t *locs = NULL, *locs_last = NULL;

$int num_cols, num_rows = 0;
int  sql_initted = 0, sql_exec_started = 0;
extern int free_err_res;
char *sql_query;

void sql_free_descriptors()
{
    struct loc_list_t *tmp, *prev;

    tmp = locs;
    while(tmp)
    {
        prev = tmp;
        tmp = tmp->next;
        if (prev->freeit)
            free(prev->ptr.loc_buffer);
        free(prev);
    }
    locs = NULL;
}

void sql_free_exec()
{
    sql_free_descriptors();

    EXEC SQL close guml_curs;                   /* close cursor */
    EXEC SQL free guml_id;                      /* free resources for statement */
    EXEC SQL free guml_curs;                    /* free resources for cursor */
    EXEC SQL deallocate descriptor 'guml_desc'; /* free system descriptor area */

    if (sql_query)
        free(sql_query);

    sql_exec_started = 0;
    num_rows = 0;
}

char *reporterror(char *functioncall, char *sqlexec, long sqlcode)
{
    Data informix_error = { NULL, 0 };
    char tmp[1024];
    int j;
    $int exception_count, messlen, i;
    $char overflow[2], class_id[255], subclass_id[255], message[255], sqlstate_code[6];

    if (sqlcode < 0)
    {
        sprintf(tmp, "In function: %s, call: %s\n", functioncall, sqlexec);
        add_string(&informix_error, tmp);
        if (sql_query)
        {
            add_string_size (&informix_error, "SQL Statement:\n", 15);
            add_string(&informix_error, sql_query);
            add_char(&informix_error, '\n');
        }
        sprintf(tmp, "SQLSTATE: %s\nSQLCODE: %ld\n", SQLSTATE, SQLCODE);
        add_string(&informix_error, tmp);

        EXEC SQL get diagnostics :exception_count = NUMBER, :overflow = MORE;
        if (SQLCODE != 0)
        {
            sprintf(tmp, "Error getting exception info: %ld\n", SQLCODE);
            add_string(&informix_error, tmp);
        }
        else
        {
            sprintf(tmp, "EXCEPTIONS:  Number=%d\tMore? %s\n", exception_count, overflow);
            add_string(&informix_error, tmp);

            for (i = 1; i <= exception_count; i++)
            {
                EXEC SQL get diagnostics exception :i :sqlstate_code = RETURNED_SQLSTATE,
                    :class_id = CLASS_ORIGIN, :subclass_id = SUBCLASS_ORIGIN,
                    :message = MESSAGE_TEXT, :messlen = MESSAGE_LENGTH;
                if (SQLCODE != 0)
                    sprintf(tmp, "Error getting exception info: %ld\n", SQLCODE);
                else
                {
                    message[messlen-1] = '\0';
                    j = byleng(class_id, stleng(class_id));
                    class_id[j] = '\0';
                    j = byleng(subclass_id, stleng(subclass_id));
                    subclass_id[j] = '\0';

                    sprintf(tmp, "- - - - - - - - - - - - - - - - - - - -\n"
                                 "EXCEPTION %d: SQLSTATE=%s\n"
                                 "MESSAGE TEXT: %s\n"
                                 "CLASS ORIGIN: %s\n"
                                 "SUBCLASS ORIGIN: %s\n",
                            i, sqlstate_code, message, class_id, subclass_id);
                }
                add_string(&informix_error, tmp);
            }
        }

        add_string_size (&informix_error, "----------------------------------------------------------\n", 59);
    }
    return informix_error.data;
}

#ifdef NEED_SQL_ENVIRONMENT
char *sql_init_environ()
{
    writelog("Initializing Informix environment...");
    putenv("INFORMIXDIR=" DB_ROOT);
    putenv("INFORMIXSERVER=" DB_HOST);

    return NULL;
}
#endif

char *sql_init()
{
#ifdef DB_DB
    $char db_name[128];
#endif
#ifdef DB_USER
    $char db_user[128], db_password[128];
#endif
    char *tmp;

    if (sql_initted)
        return "SQL Environment already initialized.. should never happen";

#if defined(NEED_SQL_ENVIRONMENT)
    sql_init_environ ();
#endif

#ifdef DB_DB
    strcpy(db_name, DB_DB);
#ifdef DB_USER
    strcpy(db_user, DB_USER);
    strcpy(db_password, DB_PASSWORD);
    EXEC SQL connect to :db_name user :db_user using :db_password;
#else
    EXEC SQL connect to :db_name;
#endif
#endif
    if ((tmp = reporterror("sql_init", "connect", SQLCODE)) != NULL)
    {
        free_err_res = 2;
        return tmp;
    }

    sql_initted = 1;
    return NULL;
}

char *sql_cleanup()
{
#ifndef DB_DB
    char *tmp;

    EXEC SQL close database;
    if ((tmp = reporterror("sql_init", "connect", SQLCODE)) != NULL)
    {
        free_err_res = 2;
        return tmp;
    }
#endif
    return NULL;
}

char *sql_shutdown()
{
    char *tmp;

    if (!sql_initted)
        return NULL;

    if (sql_exec_started)
        sql_free_exec();

    EXEC SQL disconnect all;
    if ((tmp = reporterror("sql_shutdown", "disconnect", SQLCODE)) != NULL)
    {
        free_err_res = 2;
        return tmp;
    }

    return NULL;
}

struct loc_list_t *get_new_descriptor(int freeit)
{
    struct loc_list_t *tmp;

    tmp = malloc(sizeof(struct loc_list_t));
    memset(&tmp->ptr, 0, sizeof(tmp->ptr));
    tmp->ptr.loc_loctype = LOCMEMORY;
    tmp->ptr.loc_bufsize = -1;
    tmp->ptr.loc_oflags = 0;
    tmp->ptr.loc_mflags = 0;
    tmp->freeit = freeit;
    tmp->next = NULL;
    if (!locs)
        locs = tmp;
    else
        locs_last->next = tmp;
    locs_last = tmp;
    return tmp;
}

char *guml_sqlexec(Data *out_string, char *args[], int nargs)
{
    $char  *tmp, name[40];
    $int    i;
    $short  type;
    $struct loc_list_t *temp_desc;
#if defined(DEBUG_SQL)
    Data *debug_sql;
#endif

    if (nargs < 1)
        return "\\sqlexec requires atleast 1 parameter";
 
    if (!sql_initted)
        if ((tmp = sql_init()) != NULL)
        {
            free_err_res = 2;
            return tmp;
        }

    if (sql_exec_started)
        sql_free_exec();

    sql_exec_started = 1;

#if defined(DEBUG_SQL)
    debug_sql = find_hash_data("DEBUG_SQL", calc_hash("DEBUG_SQL"));
    if (debug_sql && debug_sql->data)
    {
        writelog("sqlexec:");
        for (i = 0; i < nargs; i++)
            writelog("    %s\n", args[i]); 
    }
#endif

    /* prepare statement id */
    tmp = args[0];
    sql_query = strdup(tmp);
    EXEC SQL prepare guml_id from :tmp;
    if ((tmp = reporterror("guml_sqlexec", "prepare sql statement", SQLCODE)) != NULL)
    {
        free_err_res = 2;
        return tmp;
    }

    /* allocate descriptor area */
    EXEC SQL allocate descriptor 'guml_desc';
    if ((tmp = reporterror("guml_sqlexec", "allocate descriptor", SQLCODE)) != NULL)
    {
        free_err_res = 2;
        return tmp;
    }

    /* Ask the database server to describe the statement */
    EXEC SQL describe guml_id using sql descriptor 'guml_desc';
    if ((tmp = reporterror("guml_sqlexec", "describe descriptor", SQLCODE)) != NULL)
    {
        free_err_res = 2;
        return tmp;
    }

    if (SQLCODE != 0 && SQLCODE != SQ_SELECT && SQLCODE != SQ_EXECPROC)
    {
        if (nargs > 1)
        {
            /* Determine the number of columns in the select list */
            EXEC SQL get descriptor 'guml_desc' :num_cols = COUNT;
            if ((tmp = reporterror("guml_sqlexec", "nonselect get column count", SQLCODE)) != NULL)
            {
                free_err_res = 2;
                return tmp;
            }

            if (!num_cols)
            {
                EXEC SQL deallocate descriptor 'guml_desc';
                i = nargs-1;
                EXEC SQL allocate descriptor 'guml_desc' with max :i;
            }
            for(i = 1; i < nargs; i++)
            {
                temp_desc = get_new_descriptor(0);
                temp_desc->ptr.loc_buffer = args[i];
                temp_desc->ptr.loc_bufsize = strlen(args[i]) + 1;
                temp_desc->ptr.loc_size = temp_desc->ptr.loc_bufsize;
                type = CLOCATORTYPE;
                EXEC SQL set descriptor 'guml_desc' VALUE :i TYPE = :type, DATA = :temp_desc->ptr;
                if ((tmp = reporterror("guml_sqlexec", "nonselect set column data", SQLCODE)) != NULL)
                {
                    free_err_res = 2;
                    return tmp;
                }
            }

            EXEC SQL execute guml_id using sql descriptor 'guml_desc';
            if ((tmp = reporterror("guml_sqlexec", "execute non-select with desc", SQLCODE)) != NULL)
            {
                free_err_res = 2;
                return tmp;
            }
        }
        else
        {
            EXEC SQL execute guml_id;
            if ((tmp = reporterror("guml_sqlexec", "execute non-select without desc", SQLCODE)) != NULL)
            {
                free_err_res = 2;
                return tmp;
            }
        }

        EXEC SQL get diagnostics :num_rows = ROW_COUNT;
        if ((tmp = reporterror("guml_sqlexec", "row_count non-select", SQLCODE)) != NULL)
        {
            free_err_res = 2;
            return tmp;
        }
        sprintf(name, "%d", num_rows);
        insert_hash(strdup("SQL_ROW_COUNT"), create_string(name, 0), calc_hash("SQL_ROW_COUNT"), 0);
        sprintf(name, "%ld", sqlca.sqlerrd[5]);
        insert_hash(strdup("SQL_ROW_ID"), create_string(name, 0), calc_hash("SQL_ROW_ID"), 0);

        sql_free_descriptors();

        EXEC SQL free guml_id;
        if ((tmp = reporterror("guml_sqlexec", "free non-select", SQLCODE)) != NULL)
        {
            free_err_res = 2;
            return tmp;
        }
        /* free system descriptor area */
        EXEC SQL deallocate descriptor 'guml_desc';
        if ((tmp = reporterror("guml_sqlexec", "free descriptor in non-select", SQLCODE)) != NULL)
        {
            free_err_res = 2;
            return tmp;
        }
        sql_exec_started = 0;
        return NULL;
    }

    /* declare cursor */
    EXEC SQL declare guml_curs cursor for guml_id;
    if ((tmp = reporterror("guml_sqlexec", "declare cursor", SQLCODE)) != NULL)
    {
        free_err_res = 2;
        return tmp;
    }

    /* Determine the number of columns in the select list */
    EXEC SQL get descriptor 'guml_desc' :num_cols = COUNT;
    if ((tmp = reporterror("guml_sqlexec", "get column count", SQLCODE)) != NULL)
    {
        free_err_res = 2;
        return tmp;
    }

    /* open cursor; process select statement */
    EXEC SQL open guml_curs;
    if ((tmp = reporterror("guml_sqlexec", "open cursor", SQLCODE)) != NULL)
    {
        free_err_res = 2;
        return tmp;
    }

    for(i = 1; i <= num_cols; i++)
    {
        EXEC SQL get descriptor 'guml_desc' VALUE :i :type = TYPE, :name = NAME;
        if (type == SQLTEXT || type == SQLBYTES)
        {
            temp_desc = get_new_descriptor(0);
            EXEC SQL set descriptor 'guml_desc' VALUE :i DATA = :temp_desc->ptr;
        }
    }

    return NULL;
}

char *guml_sqlrow(Data *out_string, char *args[], int nargs)
{
    $short    type, ind, char_len, short_data;
    $int      i, int_data;
    $long     date_data;
    $interval intvl_data;
    $char     name[40], *char_data, decimal_buf[128];
    $decimal  dec_data;
    $datetime dt_data;
    int       x;
    char      buffer[1024];
    $struct loc_list_t *tmp;

    if (!sql_exec_started)
        return "\\sqlrow -- no \\sqlexec pending";

    EXEC SQL fetch guml_curs using sql descriptor 'guml_desc';
    if (SQLCODE == 100)
    {
        sprintf(buffer, "%d", num_rows);
        insert_hash(strdup("SQL_ROW_COUNT"), create_string(buffer, 0), calc_hash("SQL_ROW_COUNT"), 0);
        sql_free_exec();
        return NULL;
    }
    sprintf(buffer, "%ld", sqlca.sqlerrd[5]);
    insert_hash(strdup("SQL_ROW_ID"), create_string(buffer, 0), calc_hash("SQL_ROW_ID"), 0);

    num_rows++;
    tmp = locs;
    for(i = 1; i <= num_cols && i <= nargs; i++)
    {
        EXEC SQL get descriptor 'guml_desc' VALUE :i :type = TYPE;
        switch(type)
        {
            case SQLSERIAL:
            case SQLINT:
                EXEC SQL get descriptor 'guml_desc' VALUE :i :name = NAME, :ind = INDICATOR, :int_data = DATA;
                if(ind == -1)
                    buffer[0] = 0;
                else
                    sprintf(buffer, "%d", int_data);
                insert_hash(strdup(args[i-1]), create_string(buffer, 0), calc_hash(args[i-1]), 0);
                break;
            case SQLSMINT:
                EXEC SQL get descriptor 'guml_desc' VALUE :i :name = NAME, :ind = INDICATOR, :short_data = DATA;
                if(ind == -1)
                    buffer[0] = 0;
                else
                    sprintf(buffer, "%d", short_data);
                insert_hash(strdup(args[i-1]), create_string(buffer, 0), calc_hash(args[i-1]), 0);
                break;
            case SQLDECIMAL:
                EXEC SQL get descriptor 'guml_desc' VALUE :i :name = NAME, :ind = INDICATOR, :decimal_buf = DATA;
                strip_space(decimal_buf);
                insert_hash(strdup(args[i-1]), create_string(decimal_buf, 0), calc_hash(args[i-1]), 0);
                break;
            case SQLMONEY:
                EXEC SQL get descriptor 'guml_desc' VALUE :i :name = NAME, :ind = INDICATOR, :dec_data = DATA;
                if(ind == -1)
                    buffer[0] = 0;
                else
                {
                    if(type == SQLDECIMAL)
                        rfmtdec(&dec_data, "###,###,###.##", buffer);
                    else
                        rfmtdec(&dec_data, "$$$,$$$,$$$.$$", buffer);
                }
                insert_hash(strdup(args[i-1]), create_string(buffer, 0), calc_hash(args[i-1]), 0);
                break;
            case SQLDATE:
                EXEC SQL get descriptor 'guml_desc' VALUE :i :name = NAME, :ind = INDICATOR, :date_data = DATA;
                if(ind == -1)
                    buffer[0] = 0;
                else
                    if((x = rfmtdate(date_data, "mmm. dd, yyyy", buffer)) < 0)
                        sprintf(buffer, "\\sqlrow - DATE - fmt error %d", x);
                insert_hash(strdup(args[i-1]), create_string(buffer, 0), calc_hash(args[i-1]), 0);
                break;
            case SQLDTIME:
                EXEC SQL get descriptor 'guml_desc' VALUE :i :name = NAME, :ind = INDICATOR, :dt_data = DATA;
                if(ind == -1)
                    buffer[0] = 0;
                else
                    if ((x = dttofmtasc(&dt_data, buffer, sizeof(buffer), 0)) < 0)
                        sprintf(buffer, "\\sqlrow - DTIME - fmt error %d", x);
                insert_hash(strdup(args[i-1]), create_string(buffer, 0), calc_hash(args[i-1]), 0);
                break;
            case SQLINTERVAL:
                EXEC SQL get descriptor 'guml_desc' VALUE :i :name = NAME, :ind = INDICATOR, :intvl_data = DATA;
                if(ind == -1)
                    buffer[0] = 0;
                else
                    if((x = intofmtasc(&intvl_data, buffer, sizeof(buffer), "%3d days, %2H hours, %2M minutes")) < 0)
                        sprintf(buffer, "\\sqlrow - INTRVL - fmt error %d", x);
                insert_hash(strdup(args[i-1]), create_string(buffer, 0), calc_hash(args[i-1]), 0);
                break;
            case SQLVCHAR:
            case SQLCHAR:
                EXEC SQL get descriptor 'guml_desc' VALUE :i :char_len = LENGTH, :name = NAME;
                char_data = (char *)malloc(char_len + 1);
                EXEC SQL get descriptor 'guml_desc' VALUE :i :char_data = DATA, :ind =  INDICATOR;
                if(ind == -1)
                    char_data[0] = 0;
                else
                    rtrim(char_data);
                insert_hash(strdup(args[i-1]), create_string(char_data, 1), calc_hash(args[i-1]), 0);
                break;
            case SQLTEXT:
            case SQLBYTES:
                EXEC SQL get descriptor 'guml_desc' VALUE :i :name = NAME, :ind = INDICATOR, :tmp->ptr = DATA;
                if(ind == -1)
                {
                    buffer[0] = 0;
                    insert_hash(strdup(args[i-1]), create_string(buffer, 0), calc_hash(args[i-1]), 0);
                    tmp = tmp->next;
                    break;
                }
                char_data = (char*)malloc(tmp->ptr.loc_size+1);
                memcpy(char_data, tmp->ptr.loc_buffer, tmp->ptr.loc_size);
                char_data[tmp->ptr.loc_size] = 0;
                insert_hash(strdup(args[i-1]), create_string(char_data, 1), calc_hash(args[i-1]), 0);
                tmp = tmp->next;
                break;
            default:
                sprintf(buffer, "Unexpected data type: %d", type);
                insert_hash(strdup(args[i-1]), create_string(buffer, 0), calc_hash(args[i-1]), 0);
        }
    }

    add_string_size (out_string, "true", 4);
    return NULL;
}
