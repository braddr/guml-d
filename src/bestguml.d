module bestguml;

import commands;
import data;
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
    Data results = {null, 0};

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

    char* filename = find_hash_data ("FILENAME", calc_hash("FILENAME")).data;
    char* err = find_hash_data("BASE_DIR", calc_hash("BASE_DIR")).data;  /* overloading usage of err */

    version (LOG_ONLY_ERRORS) {}
    else
        writelog("Parsing file: %s%s", err, filename[0] == '/' ? filename+1 : filename);

    if (strstr (filename, "..") != null)
    {
        FPUTS("Content-type: text/plain\n\nIllegal file name encountered!\n".ptr);
        exit (2);
    }

    err = guml_file_include (&results, &filename, -1);

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
        if ((err || fatal_error) && fatal_error != 2)
        {
            writelog("fatal_error = %d", fatal_error);
            if (err)
                add_string(&err_string, err);

            if (results.data)
            {
                insert_hash(strdup("ERROR_results"), create_string(results.data, 1), calc_hash("ERROR_results"), 0);
                results.data  = null;
                results.length = 0;
            }
            if (err_string.data)
            {
                writelog("traceback: %s", err_string.data);
                insert_hash(strdup("ERROR_traceback"), create_string(err_string.data, 1), calc_hash("ERROR_traceback"), 0);
                err_string.data = null;
                err_string.length = 0;
            }
            fatal_error = 0;
            filename = strdup("/handle-error");
            err = guml_file_include (&results, &filename, -1);
            free(filename);
            filename = null;
            if (err)
            {
                char *oops = strdup("Content-type: text/plain\n\n\\get{ERROR_traceback}\n\nResults so far:\n\n\\get{ERROR_results}");
                guml_backend (&results, &oops, null, 0);
                free(oops);
                oops = null;

                if (err_string.data)
                {
                    FPUTS("Content-type: text/plain\n\nFatal error parsing /handle-error\n");
                    FPUTS(err_string.data);
                    FPUTS(err);
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

        // The three cleanup routines above aren't called since the process
        // is just going to exit anyway.
    }

    return 0;
}

/* end */
