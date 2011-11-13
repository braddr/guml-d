module bestguml;

import commands;
import dir_ops;
import engine;
import file_ops;
import hash_table;
import mysql;
import setup;
import string_utils;

import core.stdc.config;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.time;

extern(C)
{
    extern __gshared Data err_string;
    extern __gshared const char** environ;

    __gshared char** guml_env;

    __gshared int shutdownguml = 0;

    extern void mysql_server_end();

    version (FASTCGI)
    {
        struct FCGX_Stream;
        alias char** FCGX_ParamArray;
        FCGX_Stream* fcgi_in, fcgi_out, fcgi_err;
        FCGX_ParamArray fcgi_envp;

        extern int FCGX_Accept(FCGX_Stream **instr, FCGX_Stream **outstr, FCGX_Stream **err, FCGX_ParamArray *envp);
        extern void FCGX_Finish();
        extern int FCGX_PutS(const char *str, FCGX_Stream *stream);
    }
}

void FPUTS(const char* x)
{
    version (FASTCGI)
        FCGX_PutS(x, fcgi_out);
    else
        fputs(x, stdout);
}

void processRequest(string[] args)
{
    Data results;

    setup_environment (args);
    init_engine();
    read_startup_config_file();

    {
        char* err = sql_init();
        if (err)
        {
            writelog("Error, unable to initialize the db: %s", err);
            exit(10);
        }
    }

    fatal_error = 0;

    Data* filename = find_hash_data ("FILENAME", calc_hash("FILENAME"));
    Data* err = find_hash_data("BASE_DIR", calc_hash("BASE_DIR"));  /* overloading usage of err */

    version (LOG_ONLY_ERRORS) {}
    else
        writelog("Parsing file: %s%s", err, filename.data[0] == '/' ? filename.data+1 : filename.data);

    if (strstr (filename.data, "..") != null)
    {
        FPUTS("Content-type: text/plain\n\nIllegal file name encountered!\n");
        exit (2);
    }

    Data[] funcargs = [ *filename ];
    char *errstr = guml_file_include (&results, funcargs);

    Data* error_data = find_hash_data ("ERROR", calc_hash("ERROR"));
    if (error_data && error_data.data)
    {
        writelog("ERROR defined");
        if (strstr(error_data.data, "Content-type:") == null)
        {
            if (strstr(error_data.data, "Location:") != null)
                FPUTS("Content-type: text/html\n");
            else
                FPUTS("Content-type: text/html\n\n");
        }

        FPUTS(error_data.data);

        delete_hash("ERROR", calc_hash("ERROR"));
    }
    else
    {
        if ((errstr || fatal_error) && fatal_error != 2)
        {
            writelog("fatal_error = %d", fatal_error);
            if (errstr)
                add_string(&err_string, errstr);

            if (results.data)
            {
                insert_hash(strdup("ERROR_results"), create_string(results.data), calc_hash("ERROR_results"), 0);
                free(results.data);
                results.data  = null;
                results.length = 0;
            }
            if (err_string.data)
            {
                writelog("traceback: %s", err_string.data);
                insert_hash(strdup("ERROR_traceback"), create_string(err_string.data), calc_hash("ERROR_traceback"), 0);
                free(err_string.data);
                err_string.data = null;
                err_string.length = 0;
            }
            fatal_error = 0;
            filename = create_string("/handle-error");
            funcargs = [ *filename ];
            errstr = guml_file_include (&results, funcargs);
            free(filename.data);
            free(filename);
            filename = null;
            if (errstr)
            {
                char *oops = strdup("Content-type: text/plain\n\n\\get{ERROR_traceback}\n\nResults so far:\n\n\\get{ERROR_results}");
                Data[] params;
                guml_backend (&results, &oops, params);
                free(oops);
                oops = null;

                if (err_string.data)
                {
                    FPUTS("Content-type: text/plain\n\nFatal error parsing /handle-error\n");
                    FPUTS(err_string.data);
                    FPUTS(errstr);
                    FPUTS("\n\nBase-Dir: ");
                    error_data = find_hash_data("BASE_DIR", calc_hash("BASE_DIR"));
                    if (error_data && error_data.data)
                        FPUTS(error_data.data);
                }
                else
                    FPUTS(results.data);
            }
            else
            {
                if (err_string.data)
                {
                    FPUTS("Content-type: text/plain\n\nFatal error parsing /handle-error\n");
                    FPUTS(err_string.data);
                }
                else if (results.data)
                    FPUTS(results.data);
                else
                    FPUTS("Content-type: text/plain\n\nFatal error, unable to find /handle-error\n");
            }
        }
        else
        {
            if (results.data)
            {
                if (strstr(results.data, "Content-type:") == null)
                {
                    if (strstr(results.data, "Location:") != null)
                        FPUTS("Content-type: text/html\n");
                    else
                        FPUTS("Content-type: text/html\n\n");
                }
                FPUTS(results.data);
            }
        }
    }

    version (FASTCGI)
        FCGX_Finish();

    if (err_string.data)
    {
        free(err_string.data);
        err_string.data = null;
        err_string.length = 0;
    }

    if (results.data)
    {
        free (results.data);
        results.data  = null;
        results.length = 0;
    }

    version (LOG_ONLY_ERRORS) {}
    else
        writelog ("Done parsing.");

    sql_shutdown();
}

int main (string[] args)
{
    guml_env = cast(char**)environ;

    srand(cast(uint)time(null));
    init_hash_table();
    init_commands();

    version (FASTCGI)
    {
        while(!shutdownguml && FCGX_Accept(&fcgi_in, &fcgi_out, &fcgi_err, &fcgi_envp) >= 0)
        {
            guml_env = fcgi_envp;

            processRequest(args);

            version (USE_FILE_HANDLE_OPS)
            {
                if (clean_filehandles())
                    writelog ("Failed to close a file handle.");
            }

            guml_close_dir_internal();
            clean_hash(HASH_ALL);
        }
    }
    else
    {
        processRequest(args);

        guml_close_dir_internal();
        clean_hash(HASH_ALL);
    }

    mysql_server_end();
    clean_hash(HASH_BUILTIN);

    return 0;
}

/* end */
