module file_ops;

import bestguml;
import data;
import engine;
import hash_table;
import string_utils;

import core.stdc.errno;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.posix.unistd;
import core.sys.posix.sys.stat;

char *guml_file_delete (Data *out_string, char** args, int nargs)
{
    char  buffer[1024];

    if (nargs != 1)
        return cast(char*)"\\filedelete requires only 1 parameter";

    if (strstr (args[0], "../") != null)
        return cast(char*)"\\filedelete -- illegal filename, may not contain ..'s";

    char *tmp = find_hash_data ("USER", calc_hash("USER")).data;
    if (!tmp)
        return cast(char*)"\\filedelete -- not authenticated";

    Data *fwd = find_hash_data ("FILE_WRITE_DIR", calc_hash("FILE_WRITE_DIR"));
    if (!fwd)
        return cast(char*)"\\filedelete -- FILE_WRITE_DIR not configured";

    sprintf (buffer.ptr, "%s/%s", fwd.data, args[0]);
    writelog ("guml_file_delete() called: %s", buffer.ptr);
    unlink (buffer.ptr);
    return null;
}

char *guml_file_write (Data *out_string, char** args, int nargs)
{
    FILE *fp;
    char  buffer[1024];

    if (nargs != 2)
        return cast(char*)"\\filewrite requires 2 parameters";

    if (strstr (args[0], "../") != null)
        return cast(char*)"\\filewrite -- illegal filename, may not contain ..'s";

    char* tmp = find_hash_data ("USER", calc_hash("USER")).data;
    if (!tmp)
        return cast(char*)"\\filewrite -- not authenticated";

    Data *fwd = find_hash_data ("FILE_WRITE_DIR", calc_hash("FILE_WRITE_DIR"));
    if (!fwd)
        return cast(char*)"\\filedelete -- FILE_WRITE_DIR not configured";

    sprintf (buffer.ptr, "%s/%s", fwd.data, args[0]);
    writelog ("guml_file_write() called: %s", buffer.ptr);
    if ((fp = fopen (buffer.ptr, "w")) == null)
        return cast(char*)"\\filewrite -- unable to write file";

    fprintf (fp, "%s", args[1]);
    fclose (fp);

    return null;
}

char *guml_file_read (Data *out_string, char** args, int nargs)
{
    Data file_text = {null, 0};
    Data* base_dir;
    FILE *fp;
    char buffer[1024];

    if (nargs != 1)
        return cast(char*)"\\fileread requires only 1 parameter";

    if (strstr (args[0], "../") != null)
        return cast(char*)"\\fileread -- illegal filename, may not contain ..'s";

    base_dir = find_hash_data("BASE_DIR", calc_hash("BASE_DIR"));
    if (!base_dir)
        return cast(char*)"\\fileread -- no BASE_DIR set";
    if (!base_dir.data)
        return cast(char*)"\\fileread -- BASE_DIR contains nothing";
 
    sprintf (buffer.ptr, "%s%s", base_dir.data, (args[0][0] == '/') ? args[0] + 1 : args[0]);
    writelog ("guml_file_read() called: %s", buffer.ptr);

    if ((fp = fopen (buffer.ptr, "r")) == null)
        return null;

    while (fgets (buffer.ptr, buffer.sizeof, fp) != null)
        add_string (&file_text, buffer.ptr);

    fclose (fp);
    add_string_data (out_string, &file_text);

    return null;
}

char *guml_file_exists (Data *out_string, char** args, int nargs)
{
    FILE *fp;
    char buffer[1024];
    Data *base_dir;

    if (nargs != 1)
        return cast(char*)"\\fileexists requires only 1 parameter";

    if (strstr (args[0], "../") != null)
        return cast(char*)"\\fileexists -- illegal filename, may not contain ..'s";

    base_dir = find_hash_data("BASE_DIR", calc_hash("BASE_DIR"));
    if (!base_dir)
        return cast(char*)"\\fileexists -- no BASE_DIR set";
    if (!base_dir.data)
        return cast(char*)"\\fileexists -- BASE_DIR contains nothing";
 
    sprintf (buffer.ptr, "%s%s", base_dir.data, (args[0][0] == '/') ? args[0] + 1 : args[0]);
    writelog ("guml_file_exists() called: %s", buffer.ptr);

    if ((fp = fopen (buffer.ptr, "r")) != null)
    {
        fclose (fp);
        add_string_size (out_string, "true", 4);
    }
    return null;
}

char *guml_file_status (Data *out_string, char** args, int nargs)
{
    char buffer[1024];
    stat_t statstr;
    Data *base_dir;

    if (nargs != 2)
        return cast(char*)"\\filestatus requires 2 parameters";

    if (strstr (args[0], "../") != null)
        return cast(char*)"\\filestatus -- illegal filename, may not contain ..'s";

    base_dir = find_hash_data("BASE_DIR", calc_hash("BASE_DIR"));
    if (!base_dir)
        return cast(char*)"\\filestatus -- no BASE_DIR set";
    if (!base_dir.data)
        return cast(char*)"\\filestatus -- BASE_DIR contains nothing";
 
    sprintf (buffer.ptr, "%s%s", base_dir.data, (args[0][0] == '/') ? args[0] + 1 : args[0]);
    writelog ("guml_file_status() called: %s", buffer.ptr);

    if (stat (buffer.ptr, &statstr) == -1)
        return strerror (errno);

    if (strcmp (args[1], "size") == 0)
    {
        sprintf (buffer.ptr, "%li", cast(long) (statstr.st_size));
        return strdup (buffer.ptr);
    }
    if (strcmp (args[1], "atime") == 0)
    {
        sprintf (buffer.ptr, "%li", cast(long) (statstr.st_atime));
        return strdup (buffer.ptr);
    }
    if (strcmp (args[1], "mtime") == 0)
    {
        sprintf (buffer.ptr, "%li", cast(long) (statstr.st_mtime));
        return strdup (buffer.ptr);
    }
    if (strcmp (args[1], "ctime") == 0)
    {
        sprintf (buffer.ptr, "%li", cast(long) (statstr.st_ctime));
        return strdup (buffer.ptr);
    }
    return null;
}

void guml_file (Data *out_string, FILE * f)
{
    Data intext = {null, 0};
    char buffer[1025];
    char *holdtext;

    while (!feof (f))
    {
        size_t i = fread (buffer.ptr, 1, buffer.sizeof - 1, f);
        buffer[i] = 0;
        add_string (&intext, buffer.ptr);
    }

    fclose (f);

    if (!intext.data)
        return;

    holdtext = intext.data;
    guml_backend (out_string, &holdtext, null, 0);
    free (intext.data);

    return;
}

/* load in another file */
char *guml_file_include (Data *out_string, char** args, int nargs)
{
    stat_t mystat;
    FILE *g;
    char myfile[1024];
    char filenotfound[1024];
    Data *base_dir;
    static char errstr[1024];
 
    if (nargs != 1 && nargs != -1)
        return cast(char*)"\\include requires only one argument";

    if (strstr (args[0], "../") != null)
    {
        FPUTS("Content-type: text/plain\n\nIllegal file name encountered!\n");
        exit (4);
    }

    base_dir = find_hash_data("BASE_DIR", calc_hash("BASE_DIR"));
    if (!base_dir)
        return cast(char*)"\\include -- no BASE_DIR set";
    if (!base_dir.data)
        return cast(char*)"\\include -- BASE_DIR contains nothing";
 
    sprintf (myfile.ptr, "%s%s", base_dir.data, (args[0][0] == '/') ? args[0] + 1 : args[0]);
    if (stat(myfile.ptr, &mystat))
    {
        goto file_error;
    }
    if (mystat.st_mode & S_IFDIR)
    {
        if (myfile[strlen(myfile.ptr)-1] != '/')
            strcat(myfile.ptr, "/main.html");
        else
            strcat(myfile.ptr, "main.html");
        if (stat(myfile.ptr, &mystat))
            goto file_error;
    }
    if (mystat.st_mode & S_IFREG)
    {
        g = fopen(myfile.ptr, "r");
        if (g)
        {
            guml_file (out_string, g);
            return null;
        }
    }
 
file_error:
    sprintf (filenotfound.ptr, "%sfile-not-found", base_dir.data);
    g = fopen (filenotfound.ptr, "r");
    if (g == null)
    { 
        sprintf(errstr.ptr, cast(char*)"\\include -- file not found (%s)", myfile.ptr);
        return errstr.ptr;
    }
    else
    {
        guml_file (out_string, g);
        return null;
    }
}
