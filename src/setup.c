/* six.c */
/* main entry point for site */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "global.h"

extern char **guml_env;

#ifdef FASTCGI
extern FCGX_Stream *fcgi_in;
extern FCGX_ParamArray fcgi_envp;
#endif

#ifdef BRADDR_TESTING
void read_startup_config_file(void)
{
    Data output;
    FILE *g;
    char *ptr;

    if ((ptr = GETENV("GUML_CFGFILE")))
        if ((g = fopen(ptr, "r")))
        {
            guml_file(&output, g);
            fclose(g);
        }
}

void read_per_page_hit_config_file(void)
{
    Data results, *ptr;
    char *buf;

    results.data = NULL;
    results.length = 0;

    ptr = find_hash_data("SERVERNAME", calc_hash("SERVERNAME"));
    buf = malloc(strlen(ptr->data)+10);
    sprintf (buf, "/headers/%s", ptr->data);
    guml_file_include(&results, &buf, 1);
    free(buf);
}
#endif

void setup_commandline (int argc, char *argv[])
{
    printf("command line usage disabled\n");
    exit(1);
#if 0
    int i;
    char n[8], filename[256];

    filename[0] = 0;
    if (argc > 1)
    {
        strncpy (filename, argv[1], 255);
        filename[255] = 0;
    }
    insert_hash(strdup("FILENAME"), create_string(filename, 0), calc_hash("FILENAME"), HASH_ENV);
    insert_hash(strdup("BASE_DIR"), create_string(GUMLROOT, 0), calc_hash("BASE_DIR"), HASH_ENV);

    if (argc > 2)
    {
        for (i = 2; i < argc; i++)
        {
            sprintf (n, "ARG_%d", i - 1);
            insert_hash(strdup(n), create_string(argv[i], 0), calc_hash(n), HASH_ARG);
        }
    }
#endif
}

void setup_args ()
{
#if defined(ARG_HANDLE_USE_ONLY_GET_FORMAT)
    char *env_ptr, *str, *p, *q;

    env_ptr = GETENV ("QUERY_STRING");
    if (env_ptr)
    {
        insert_hash(strdup("QUERY_STRING"), create_string(env_ptr, 0), calc_hash("QUERY_STRING"), HASH_ENV);
        str = strdup (env_ptr);
        p = strtok (str, "&");
        while (p)
        { 
            q = strchr (p, '=');
            if (q)
            { 
                *q = 0;
                q++;
                insert_hash(strdup(http_decode(p)), create_string(http_decode(q), 0), calc_hash(p), HASH_FORM);
            }
            p = strtok (NULL, "&");
        }
        free(str);
    }
#elif defined(ARG_HANDLE_BOTH_FORMATS)
    char *env_ptr, *str, *str2, *p, *q, n[8];
    int i;

    env_ptr = GETENV ("QUERY_STRING");
    if (env_ptr)
    {
        insert_hash(strdup("QUERY_STRING"), create_string(env_ptr, 0), calc_hash("QUERY_STRING"), HASH_ENV);
        str2 = strdup(env_ptr);
        str = http_decode (strdup (env_ptr));
        p = strtok (str, " ");
        i = 1;
        while (p && i < 10000)
        {
            sprintf (n, "ARG_%d", i);
            insert_hash(strdup(n), create_string(p, 0), calc_hash(n), HASH_ARG);
            p = strtok (NULL, " ");
            i++;
        }
        free (str);

        p = strtok (str2, "&");
        while (p)
        {
            q = strchr (p, '=');
            if (q)
            {
                *q = 0;
                q++; 
                insert_hash(strdup(http_decode(p)), create_string(http_decode(q), 0), calc_hash(p), HASH_FORM);
            }
            p = strtok (NULL, "&");
        }
        free(str2);
    }
#else
    char *env_ptr, *str, *p, n[8];
    int i;

    env_ptr = GETENV ("QUERY_STRING");
    if (env_ptr)
    {
        insert_hash(strdup("QUERY_STRING"), create_string(env_ptr, 0), calc_hash("QUERY_STRING"), HASH_ENV);
        str = http_decode (strdup (env_ptr));
        p = strtok (str, " ");
        i = 1;
        while (p && i < 10000)
        {
            sprintf (n, "ARG_%d", i);
            insert_hash(strdup(n), create_string(p, 0), calc_hash(n), HASH_ARG);
            p = strtok (NULL, " ");
            i++;
        }
        free (str);
    }
#endif
}

void setup_form_args (void)
{
    char *data, *p, *q;
    int cl;

    data = GETENV ("CONTENT_LENGTH");
    if (data)
    {
        cl = atoi (data);
        if (cl)
        {
            data = malloc ((cl + 1) * sizeof (char));

#ifdef FASTCGI
            FCGX_GetStr (data, cl, fcgi_in);
#else
            fread (data, 1, cl, stdin);
#endif
            data[cl]=0;

            // keep an unmodified copy
            insert_hash(strdup("HTTP_BODY"), create_string(data, 0), calc_hash("HTTP_BODY"), HASH_FORM);

            p = strtok (data, "&");
            while (p)
            {
                q = strchr (p, '=');
                if (q)
                {
                    *q = 0;
                    q++;
                    insert_hash(strdup(p), create_string(http_decode(q), 0), calc_hash(p), HASH_FORM);
                }
                p = strtok (NULL, "&");
            }
            free (data);
        }
    }
}

void setup_cookie_args (void)
{
    char *env_str, *str, *p;
    int i;

    env_str = GETENV("HTTP_COOKIE");
    if (env_str)
    {
        str = strdup (env_str);
        p = strtok (str, ";");
        i = 1;
        while (p)
        {
            char *q;

            if ((q = strchr (p, '=')) != NULL)
            {
                *q = 0;
                q++;
                insert_hash(strdup(p), create_string(q, 0), calc_hash(p), HASH_COOKIE);
            }
            p = strtok (NULL, ";");
            if (p)
                p++;
            i++;
        }
        free (str);
    }
}

/*
 * BASE_DIR == path to root of document tree, used for all file lookups, should end in a /
 * FILENAME == append to BASE_DIR to load document to parse
 * PATH     == FILENAME - the actual filename, ie the part between BASE_DIR and the final file to load
 */
void setup_extract_parts(char *pi, char *pt)
{
    char *pi_ptr, *pt_ptr, *pi_last_slash, *pt_last_slash;
    Data *data;

    /* examples:
     * PATH_INFO=/inventory/index.ghtml
     * PATH_TRANSLATED=/home/www-data/www.puremagic.org/root/inventory/index.ghtml
     *
     * PATH_INFO=/~braddr/movies/index.ghtml
     * PATH_TRANSLATED=/home/braddr/public_html/movies/index.ghtml
     *
     * SCRIPT_NAME=/index.ghtml
     * SCRIPT_FILENAME=/home/www-data/www.guml.org/root/index.ghtml
     */

    /* point to end of strings */
    pi_ptr = pi+strlen(pi)-1;
    pt_ptr = pt+strlen(pt)-1;

    /* work backwards to find filename from pi */
    while (pi < pi_ptr && *pi_ptr != '/')
	pi_ptr--;
    pi_last_slash = pi_ptr;

    /* work backwards to find filename from pt */
    while (pt < pt_ptr && *pt_ptr != '/')
	pt_ptr--;
    pt_last_slash = pt_ptr;

    /* work backwards while the two strings are the same */
    while (pi < pi_ptr && pt < pt_ptr && *pt_ptr == *pi_ptr)
    {
	pi_ptr--;
	pt_ptr--;
    }
    if (*pi_ptr != '/')
	pi_ptr++;
    if (*pt_ptr != '/')
	pt_ptr++;

    /* BASE_DIR will be the data between pt and pt_ptr, inclusive */
    data = (Data*)malloc(sizeof(Data));
    data->data = NULL;
    data->length = 0;
    add_string_size(data, pt, pt_ptr-pt+1);
    insert_hash(strdup("BASE_DIR"), data, calc_hash("BASE_DIR"), HASH_ENV);

    /* want to end of string, so no need to make our own temp string */
    insert_hash(strdup("FILENAME"), create_string(pt_ptr, 0), calc_hash("FILENAME"), HASH_ENV);

    /* PATH will be the data between pt_ptr and pt_last_lash, inclusive */
    data = (Data*)malloc(sizeof(Data));
    data->data = NULL;
    data->length = 0;
    add_string_size(data, pt_ptr, pt_last_slash-pt_ptr+1);
    insert_hash(strdup("PATH"), data, calc_hash("PATH"), HASH_ENV);
}

#if 0
    used to be used between making sure that PATH_INFO and PATH_TRANSLATED both exist

    char filename[256];
    if (!GETENV("REDIRECT_STATUS") && !GETENV("HTTP_REDIRECT_STATUS"))
    {   /* not a redirect, setup from local.h */
        insert_hash(strdup("BASE_DIR"), create_string(GUMLROOT, 0), calc_hash("BASE_DIR"), HASH_ENV);
        insert_hash(strdup("FILENAME"), create_string(pi, 0), calc_hash("FILENAME"), HASH_ENV);

        strcpy (filename, pi);
        if (strrchr (filename, '/') != NULL)
            *strrchr (filename, '/') = 0;
        insert_hash(strdup("PATH"), create_string(filename, 0), calc_hash("PATH"), HASH_ENV);
	return;
    }
#endif

void setup_path_and_filename ()
{
    char *pi, *pt;

    pi = GETENV ("PATH_INFO");
    pt = GETENV ("PATH_TRANSLATED");

    if (pi && pt)
    {
        setup_extract_parts(pi, pt);
        return;
    }

    pi = GETENV ("SCRIPT_NAME");
    pt = GETENV ("SCRIPT_FILENAME");

    if (pi && pt)
    {
        setup_extract_parts(pi, pt);
        return;
    }

    /* unknown method of getting path from environment */
    return;
#if 0
    insert_hash(strdup("BASE_DIR"), create_string(GUMLROOT, 0), calc_hash("BASE_DIR"), HASH_ENV);
    insert_hash(strdup("FILENAME"), create_string("/file-not-found", 0), calc_hash("FILENAME"), HASH_ENV);
    insert_hash(strdup("PATH"), create_string("/", 0), calc_hash("PATH"), HASH_ENV);
#endif
}

void setup_environment (int argc, char *argv[])
{
    char servername[256], *tmp;
    int iscomm;
#if defined(DEBUG_ENV)
    FILE *fp;
#endif

#if defined(DEBUG_ENV)
    if ((fp = fopen("/tmp/guml-environ", "a")) != NULL)
    {
        for (int i=0; guml_env[i]; i++)
            fprintf(fp, "%s\n", guml_env[i]); 
        fclose(fp);
    }
#endif

    /* find out if we're off the "command line" */
    tmp = GETENV ("REQUEST_METHOD");
    if (tmp)
        insert_hash(strdup("REQUEST_METHOD"), create_string(tmp, 0), calc_hash("REQUEST_METHOD"), HASH_ENV);

    iscomm = (tmp == NULL);
    if (iscomm)
        insert_hash(strdup("USER"), create_string("manual", 0), calc_hash("USER"), HASH_ENV);
    else
    {
        tmp = GETENV ("REMOTE_USER");
        if (tmp)
            insert_hash(strdup("USER"), create_string(tmp, 0), calc_hash("USER"), HASH_ENV);
    }

    servername[0] = 0;
    if (iscomm)
        strcpy (servername, "localhost");
    else
    {
        tmp = GETENV ("SERVER_NAME");
        if (tmp)
        {
            strncpy (servername, tmp, 240);
            servername[240] = 0;
            insert_hash(strdup("SERVERDOMAIN"), create_string(servername, 0), calc_hash("SERVERDOMAIN"), HASH_ENV);
        }
        tmp = GETENV ("SERVER_PORT");
        if (tmp)
            if (atoi (tmp) != 80 && atoi (tmp) != 443)
            {
                strcat (servername, ":");
                strcat (servername, tmp);
            }
    }
    insert_hash(strdup("SERVERNAME"), create_string(servername, 0), calc_hash("SERVERNAME"), HASH_ENV);

    if (iscomm)
	setup_commandline(argc, argv);
    else
    {
        setup_args ();
        setup_path_and_filename ();
    }
    setup_form_args ();
    setup_cookie_args ();

    tmp = GETENV ("SCRIPT_NAME");
    if (tmp)
        insert_hash(strdup("SCRIPT_NAME"), create_string(tmp, 0), calc_hash("SCRIPT_NAME"), HASH_ENV);

    tmp = GETENV ("HTTP_REFERER");
    if (tmp)
        insert_hash(strdup("HTTP_REFERER"), create_string(tmp, 0), calc_hash("HTTP_REFERER"), HASH_ENV);

    tmp = GETENV ("HTTP_USER_AGENT");
    if (tmp)
        insert_hash(strdup("HTTP_USER_AGENT"), create_string(tmp, 0), calc_hash("HTTP_USER_AGENT"), HASH_ENV);

    tmp = GETENV ("REMOTE_HOST");
    if (tmp)
        insert_hash(strdup("REMOTE_HOST"), create_string(tmp, 0), calc_hash("REMOTE_HOST"), HASH_ENV);
    else
        insert_hash(strdup("REMOTE_HOST"), create_string("unknown", 0), calc_hash("REMOTE_HOST"), HASH_ENV);

    tmp = GETENV("REMOTE_ADDR");
    if (tmp)
        insert_hash(strdup("REMOTE_ADDR"), create_string(tmp, 0), calc_hash("REMOTE_ADDR"), HASH_ENV);
    else
        insert_hash(strdup("REMOTE_ADDR"), create_string("unknown", 0), calc_hash("REMOTE_ADDR"), HASH_ENV);
}

/* end */
