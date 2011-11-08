/* file_ops.c */
/* guml file handling primitives */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>

#include "global.h"

#ifdef FASTCGI
    extern FCGX_Stream *fcgi_out;
#endif

char *guml_file_delete (Data *out_string, char *args[], int nargs)
{
    char *tmp, buffer[1024];

    if (nargs != 1)
        return "\\filedelete requires only 1 parameter";

    if (strstr (args[0], "../") != NULL)
        return "\\filedelete -- illegal filename, may not contain ..'s";

    tmp = find_hash_data ("USER", calc_hash("USER"))->data;
    if (!tmp)
        return "\\filedelete -- not authenticated";

    sprintf (buffer, "%s%s", FILE_WRITE_DIR, args[0]);
    writelog ("guml_file_delete() called: %s", buffer);
    unlink (buffer);
    return NULL;
}

char *guml_file_write (Data *out_string, char *args[], int nargs)
{
    FILE *fp;
    char buffer[1024], *tmp;

    if (nargs != 2)
        return "\\filewrite requires 2 parameters";

    if (strstr (args[0], "../") != NULL)
        return "\\filewrite -- illegal filename, may not contain ..'s";

    tmp = find_hash_data ("USER", calc_hash("USER"))->data;
    if (!tmp)
        return "\\filewrite -- not authenticated";

    sprintf (buffer, "%s%s", FILE_WRITE_DIR, args[0]);
    writelog ("guml_file_write() called: %s", buffer);
    if ((fp = fopen (buffer, "w")) == NULL)
        return "\\filewrite -- unable to write file";

    fprintf (fp, "%s", args[1]);
    fclose (fp);

    return NULL;
}

char *guml_file_read (Data *out_string, char *args[], int nargs)
{
    Data file_text = {NULL, 0}, *base_dir;
    FILE *fp;
    char buffer[1024];

    if (nargs != 1)
        return "\\fileread requires only 1 parameter";

    if (strstr (args[0], "../") != NULL)
        return "\\fileread -- illegal filename, may not contain ..'s";

    base_dir = find_hash_data("BASE_DIR", calc_hash("BASE_DIR"));
    if (!base_dir)
        return "\\include -- no BASE_DIR set";
    if (!base_dir->data)
        return "\\include -- BASE_DIR contains nothing";
 
    sprintf (buffer, "%s%s", base_dir->data, (args[0][0] == '/') ? args[0] + 1 : args[0]);
    writelog ("guml_file_read() called: %s", buffer);

    if ((fp = fopen (buffer, "r")) == NULL)
        return NULL;

    while (fgets (buffer, sizeof (buffer), fp) != NULL)
        add_string (&file_text, buffer);

    fclose (fp);
    add_string_data (out_string, &file_text);

    return NULL;
}

char *guml_file_exists (Data *out_string, char *args[], int nargs)
{
    FILE *fp;
    char buffer[1024];
    Data *base_dir;

    if (nargs != 1)
        return "\\fileexists requires only 1 parameter";

    if (strstr (args[0], "../") != NULL)
        return "\\fileexists -- illegal filename, may not contain ..'s";

    base_dir = find_hash_data("BASE_DIR", calc_hash("BASE_DIR"));
    if (!base_dir)
        return "\\include -- no BASE_DIR set";
    if (!base_dir->data)
        return "\\include -- BASE_DIR contains nothing";
 
    sprintf (buffer, "%s%s", base_dir->data, (args[0][0] == '/') ? args[0] + 1 : args[0]);
    writelog ("guml_file_exists() called: %s", buffer);

    if ((fp = fopen (buffer, "r")) != NULL)
    {
        fclose (fp);
        add_string_size (out_string, "true", 4);
    }
    return NULL;
}

char *guml_file_status (Data *out_string, char *args[], int nargs)
{
    char buffer[1024];
    struct stat statstr;
    Data *base_dir;

    if (nargs != 2)
        return "\\filestatus requires 2 parameters";

    if (strstr (args[0], "../") != NULL)
        return "\\filestatus -- illegal filename, may not contain ..'s";

    base_dir = find_hash_data("BASE_DIR", calc_hash("BASE_DIR"));
    if (!base_dir)
        return "\\include -- no BASE_DIR set";
    if (!base_dir->data)
        return "\\include -- BASE_DIR contains nothing";
 
    sprintf (buffer, "%s%s", base_dir->data, (args[0][0] == '/') ? args[0] + 1 : args[0]);
    writelog ("guml_file_status() called: %s", buffer);

    if (stat (buffer, &statstr) == -1)
        return strerror (errno);

    if (strcmp (args[1], "size") == 0)
    {
        sprintf (buffer, "%li", (long) (statstr.st_size));
        return strdup (buffer);
    }
    if (strcmp (args[1], "atime") == 0)
    {
        sprintf (buffer, "%li", (long) (statstr.st_atime));
        return strdup (buffer);
    }
    if (strcmp (args[1], "mtime") == 0)
    {
        sprintf (buffer, "%li", (long) (statstr.st_mtime));
        return strdup (buffer);
    }
    if (strcmp (args[1], "ctime") == 0)
    {
        sprintf (buffer, "%li", (long) (statstr.st_ctime));
        return strdup (buffer);
    }
    return NULL;
}

void guml_file (Data *out_string, FILE * f)
{
    Data intext = {NULL, 0};
    char buffer[1025], *holdtext;
    int i;

    while (!feof (f))
    {
        i = fread (buffer, 1, sizeof (buffer) - 1, f);
        buffer[i] = 0;
        add_string (&intext, buffer);
    }

    fclose (f);

    if (!intext.data)
        return;

    holdtext = intext.data;
    guml_backend (out_string, &holdtext, NULL, 0);
    free (intext.data);

    return;
}

/* load in another file */
char *guml_file_include (Data *out_string, char *args[], int nargs)
{
    struct stat mystat;
    FILE *g;
    char myfile[1024], filenotfound[1024];
    Data *base_dir;
    static char errstr[1024];
 
    if (nargs != 1 && nargs != -1)
        return "\\include requires only one argument";

    if (strstr (args[0], "../") != NULL)
    {
        FPUTS("Content-type: text/plain\n\nIllegal file name encountered!\n");
        exit (4);
    }

    base_dir = find_hash_data("BASE_DIR", calc_hash("BASE_DIR"));
    if (!base_dir)
        return "\\include -- no BASE_DIR set";
    if (!base_dir->data)
        return "\\include -- BASE_DIR contains nothing";
 
    sprintf (myfile, "%s%s", base_dir->data, (args[0][0] == '/') ? args[0] + 1 : args[0]);
    if (stat(myfile, &mystat))
    {
#if !defined(GUMLHEADERROOT) || !defined(GUMLHEADERDIR)
        goto file_error;
#else
        /* If the file is not found in guml root, see if the string specifies *
         * that it is in an alternative header directory (GUMLHEADERDIR) and  *
         * look in the alternative header root (GUMLHEADERROOT).  This means  *
         * that even header files in the header root must specify the "full   *
         * path" when including other headers by using the header directory.  */
        if (strstr (args[0], GUMLHEADERDIR) != NULL)
        {
           sprintf (myfile, "%s%s", GUMLHEADERROOT, 
              (args[0][0] == '/') ? args[0] + strlen(GUMLHEADERDIR) + 2 : 
                                    args[0] + strlen(GUMLHEADERDIR) + 1
           );
           if (stat(myfile, &mystat))
              goto file_error;
        }
        else
            goto file_error;       
#endif
    }
    if (mystat.st_mode & S_IFDIR)
    {
        if (myfile[strlen(myfile)-1] != '/')
            strcat(myfile, "/main.html");
        else
            strcat(myfile, "main.html");
        if (stat(myfile, &mystat))
            goto file_error;
    }
    if (mystat.st_mode & S_IFREG)
        if ((g = fopen(myfile, "r")))
        {
            guml_file (out_string, g);
            return NULL;
        }
 
file_error:
    sprintf (filenotfound, "%sfile-not-found", base_dir->data);
    if ((g = fopen (filenotfound, "r")) == NULL)
    { 
        sprintf(errstr, "\\include -- file not found (%s)", myfile);
        return errstr;
    }
    else
    {
        guml_file (out_string, g);
        return NULL;
    }
}

