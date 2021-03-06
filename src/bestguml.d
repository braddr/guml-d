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
    setup_environment (args);
    init_engine();

    if (read_startup_config_file())
    {
        // config file was re-read.. so flush anything that might have cached state
        sql_reset_connection(); // will re-connect next time a query happens
    }

    fatal_error = 0;

    Data* filename = find_hash_data ("FILENAME", calc_hash("FILENAME"));
    Data* err = find_hash_data("BASE_DIR", calc_hash("BASE_DIR"));  /* overloading usage of err */

    version (LOG_ONLY_ERRORS) {}
    else
        writelog("Parsing file: %s%s", err.asCharStar, filename.asCharStar[0] == '/' ? filename.asCharStar+1 : filename.asCharStar);

    if (strstr(filename.asCharStar, "..") != null)
    {
        FPUTS("Content-type: text/plain\n\nIllegal file name encountered!\n");
        exit (2);
    }

    Data[] funcargs = [ *filename ];
    Data results;
    char *errstr = guml_file_include (&results, funcargs);

    Data* error_data = find_hash_data ("ERROR", calc_hash("ERROR"));
    if (error_data && *error_data)
    {
        writelog("ERROR defined");
        if (strstr(error_data.asCharStar, "Content-type:") == null)
        {
            if (strstr(error_data.asCharStar, "Location:") != null)
                FPUTS("Content-type: text/html\n");
            else
                FPUTS("Content-type: text/html\n\n");
        }

        FPUTS(error_data.asCharStar);

        delete_hash("ERROR", calc_hash("ERROR"));
    }
    else
    {
        if ((errstr || fatal_error) && fatal_error != 2)
        {
            writelog("fatal_error = %d", fatal_error);
            if (errstr)
                add_string(&err_string, errstr);

            if (results)
            {
                insert_hash(create_string("ERROR_results"), create_string(results), calc_hash("ERROR_results"), 0);
                results.reset();
            }
            if (err_string)
            {
                writelog("traceback: %s", err_string.asCharStar);
                insert_hash(create_string("ERROR_traceback"), create_string(err_string), calc_hash("ERROR_traceback"), 0);
                err_string.reset();
            }
            fatal_error = 0;
            filename = create_string("/handle-error");
            funcargs = [ *filename ];
            errstr = guml_file_include (&results, funcargs);
            filename.reset();
            free(filename);
            filename = null;
            if (errstr)
            {
                const(char)* oops = "Content-type: text/plain\n\n\\get{ERROR_traceback}\n\nResults so far:\n\n\\get{ERROR_results}";
                Data[] params;
                guml_backend (&results, &oops, params);

                if (err_string)
                {
                    FPUTS("Content-type: text/plain\n\nFatal error parsing /handle-error\n");
                    FPUTS(err_string.asCharStar);
                    FPUTS(errstr);
                    FPUTS("\n\nBase-Dir: ");
                    error_data = find_hash_data("BASE_DIR", calc_hash("BASE_DIR"));
                    if (error_data && *error_data)
                        FPUTS(error_data.asCharStar);
                }
                else
                    FPUTS(results.asCharStar);
            }
            else
            {
                if (err_string)
                {
                    FPUTS("Content-type: text/plain\n\nFatal error parsing /handle-error\n");
                    FPUTS(err_string.asCharStar);
                }
                else if (results)
                    FPUTS(results.asCharStar);
                else
                    FPUTS("Content-type: text/plain\n\nFatal error, unable to find /handle-error\n");
            }
        }
        else
        {
            if (results)
            {
                if (strstr(results.asCharStar, "Content-type:") == null)
                {
                    if (strstr(results.asCharStar, "Location:") != null)
                        FPUTS("Content-type: text/html\n");
                    else
                        FPUTS("Content-type: text/html\n\n");
                }
                FPUTS(results.asCharStar);
            }
        }
    }

    version (FASTCGI)
        FCGX_Finish();

    err_string.reset();
    results.reset();

    version (LOG_ONLY_ERRORS) {}
    else
        writelog ("Done parsing.");

    sql_cleanup_after_page();
}

int main (string[] args)
{
    guml_env = cast(char**)environ;

    init_hash_table();
    init_commands();

    version (FASTCGI)
    {
        writelog ("start fcgi loop");
        while(!shutdownguml && FCGX_Accept(&fcgi_in, &fcgi_out, &fcgi_err, &fcgi_envp) >= 0)
        {
            guml_env = fcgi_envp;

            try
            {
                processRequest(args);
            }
            catch (Exception e)
            {
                writelog ("Caught exception: %s", e.toString);
            }

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

    writelog("shutting down");
    sql_shutdown();
    clean_hash(HASH_BUILTIN);

    return 0;
}

/* end */
