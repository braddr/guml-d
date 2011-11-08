/* six.c */
/* main entry point for site */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <time.h>
#ifndef WIN32
#  include <unistd.h>
#  include <sys/resource.h>
#endif
#include <sys/stat.h>
#include <sys/types.h>

#include "global.h"

extern Data err_string;
extern int fatal_error;
char **guml_env;

int shutdownguml = 0;

#ifdef FASTCGI
    FCGX_Stream *fcgi_in, *fcgi_out, *fcgi_err;
    FCGX_ParamArray fcgi_envp;
#endif

int main (int argc, char *argv[], char *envp[])
{
    Data results = {NULL, 0}, *error_data;
    char *err, *filename;

    guml_env = envp;

    srandom (time (NULL));
    init_hash_table();
    init_commands ();

#ifdef FASTCGI
#if defined(USE_SYBASE) || defined(USE_ORACLE) || defined(USE_KUBL) || defined(USE_INFORMIX) || defined(USE_MYSQL) || defined(USE_MSSQL)
    if ((err = sql_init()))
    {
        writelog("Error, unable to initialize the db: %s\n", err);
        exit(10);
    }
#endif

    while(!shutdownguml && FCGX_Accept(&fcgi_in, &fcgi_out, &fcgi_err, &fcgi_envp) >= 0)
    {
        guml_env = fcgi_envp;
#endif

        setup_environment (argc, argv);
        init_engine();
#ifdef BRADDR_TESTING
        read_startup_config_file();
        read_per_page_hit_config_file();
#endif
        fatal_error = 0;


        filename = find_hash_data ("FILENAME", calc_hash("FILENAME"))->data;
        err = find_hash_data("BASE_DIR", calc_hash("BASE_DIR"))->data;  /* overloading usage of err */

#ifndef LOG_ONLY_ERRORS
        writelog("Parsing file: %s%s", err, filename[0] == '/' ? filename+1 : filename);
#endif

        if (strstr (filename, "..") != NULL)
        {
            FPUTS("Content-type: text/plain\n\nIllegal file name encountered!\n");
            exit (2);
        }

        err = guml_file_include (&results, &filename, -1);

        error_data = find_hash_data ("ERROR", calc_hash("ERROR"));
        if (error_data && error_data->data)
        {
            writelog("ERROR defined");
            if (strstr(error_data->data, "Content-type:") == NULL)
            {
                if (strstr(error_data->data, "Location:") != NULL)
                    FPUTS("Content-type: text/html\n");
                else
                    FPUTS("Content-type: text/html\n\n");
            }

            FPUTS(error_data->data);

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
                    results.data  = NULL;
                    results.length = 0;
                }
                if (err_string.data)
                {
                    writelog("traceback: %s", err_string.data);
                    insert_hash(strdup("ERROR_traceback"), create_string(err_string.data, 1), calc_hash("ERROR_traceback"), 0);
                    err_string.data = NULL;
                    err_string.length = 0; 
                }
                fatal_error = 0;
                filename = "/handle-error";
                err = guml_file_include (&results, &filename, -1);
                if (err)
                {
                    char *oops = "Content-type: text/plain\n\n\\get{ERROR_traceback}\n\nResults so far:\n\n\\get{ERROR_results}";
                    guml_backend (&results, &oops, NULL, 0);

                    if (err_string.data)
                    {
                        FPUTS("Content-type: text/plain\n\nFatal error parsing /handle-error\n");
                        FPUTS(err_string.data);
                        FPUTS(err);
                        FPUTS("\n\nBase-Dir: ");
                        error_data = find_hash_data("BASE_DIR", calc_hash("BASE_DIR"));
                        if (error_data && error_data->data)
                            FPUTS(error_data->data);
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
                    if (strstr(results.data, "Content-type:") == NULL)
                    {
                        if (strstr(results.data, "Location:") != NULL)
                            FPUTS("Content-type: text/html\n");
                        else
                            FPUTS("Content-type: text/html\n\n");
                    }
                    FPUTS(results.data);
                }
            }
        }

#ifdef FASTCGI
        FCGX_Finish();
#endif

        if (err_string.data)
        {
            free(err_string.data);
            err_string.data = NULL;
            err_string.length = 0; 
        }
        if (results.data)
        {
            free (results.data);
            results.data  = NULL;
            results.length = 0;
        }

#ifndef LOG_ONLY_ERRORS
        writelog ("Done parsing.");
#endif

#ifdef FASTCGI
        if (clean_filehandles())
            writelog ("Failed to close a file handle.");

        guml_close_dir_internal();

        clean_hash(HASH_ALL);

        //    sql_cleanup();
    }
#endif

#if defined(USE_SYBASE) || defined(USE_ORACLE) || defined(USE_KUBL) || defined(USE_INFORMIX) || defined(USE_MYSQL) || defined(USE_MSSQL)
    sql_shutdown();
#endif

    return 0;
}

/* end */
