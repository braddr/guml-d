/* filehandle_ops.c */
/* ..see dave about this one */

/* support for reading files line by line, via four simple functions:      */
/* \open, \readline, \close, and \isopen.  note that filehandle is closed  */
/* once fgets in \readline returns a NULL- thus one should read lines from */
/* a file \while{\quote{\isopen{\filehandle}}}.. */

/* NEW! - \output{filename} and \writeline{\filehandle}{line} commands */
/* as a temporary standin for a database.. */

/* also, \append{filename} opens filehandle for appending data to  */
/* existing file */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "global.h"

typedef struct filehandlestruct *filehandle;

struct filehandlestruct
{
    char *filename;
    FILE *fileptr;
    filehandle nextfile;
};

/* memo to myself: it has to be a linked list!  you can't pluck items
   from the middle of a stack!  */

filehandle filestack = NULL;

char *fileopener (Data *out_string, char **args, int nargs, char *opentype)
{
    static int handlenum = 0;
    filehandle fh;
    FILE *fp;
    char name[1024];

    if (nargs != 1)
        return "\\open requires only 1 parameter";

    if ((fh = malloc (sizeof (struct filehandlestruct))) == NULL)
        return "\\open -- Couldn't allocate memory for filehandle!";

    sprintf (name, "%s/%s", FILE_WRITE_DIR, args[0]);

    if ((fp = fopen (name, opentype)) == NULL)
    {
        free (fh);
        return NULL;
    }

    sprintf (name, "_out:%i", handlenum);
    fh->filename = strdup (name);
    handlenum++;

    fh->fileptr = fp;
    fh->nextfile = filestack;
    filestack = fh;

    add_string(out_string, fh->filename);
    return NULL;
}

char *guml_filehandle_output (Data *out_string, char **args, int nargs)
{
    return fileopener (out_string, args, nargs, "w");
}

char *guml_filehandle_append (Data *out_string, char **args, int nargs)
{
    return fileopener (out_string, args, nargs, "a");
}

char *guml_filehandle_open (Data *out_string, char **args, int nargs)
{
    return fileopener (out_string, args, nargs, "r");
}

char *guml_filehandle_isopen (Data *out_string, char **args, int nargs)
{
    filehandle ptr = filestack;

    if (nargs != 1)
        return "\\isopen requires only one parameter";

    while (ptr)
    {
        if (strcmp (args[0], ptr->filename) == 0)
        {
            add_string_size(out_string, "true", 4);
            break;
        }
        ptr = ptr->nextfile;
    }
    return NULL;
}

int clean_filehandles(void)
{
    int num_closed = 0;
    filehandle ptr = filestack, tmp;

    while (ptr)
    {
        tmp = ptr;
        ptr = ptr->nextfile;
        fclose(tmp->fileptr);
        free(tmp->filename);
        free(tmp);
        num_closed++;
    }
    filestack = NULL;
    return num_closed;
}

char *guml_filehandle_close (Data *out_string, char **args, int nargs)
{
    filehandle ptr = filestack, prev;

    if (nargs != 1)
        return "\\close requires only one parameter";

    while (ptr)
    {
        if (strcmp (args[0], ptr->filename) == 0)
        {
            if (ptr == filestack)
               filestack = filestack->nextfile;
            else
               prev->nextfile = ptr->nextfile;

            fclose(ptr->fileptr);
            free (ptr->filename);
            free (ptr);
            break;
        }
        prev = ptr;
        ptr = ptr->nextfile;
    }
    return NULL;
}

char *guml_filehandle_writeline (Data *out_string, char **args, int nargs)
{
    filehandle ptr = filestack;

    if (nargs != 2)
        return "\\writeline requires two parameters";

    while (ptr)
    {
        if (strcmp (args[0], ptr->filename) == 0)
        {
            fputs (args[1], ptr->fileptr);
            break;
        }
        ptr = ptr->nextfile;
    }
    return NULL;
}

char *guml_filehandle_readline (Data *out_string, char **args, int nargs)
{
    filehandle ptr = filestack;
    char buffer[1024];
    int tmp;

    if (nargs != 1)
        return "\\readline requires one parameter";

    while (ptr)
    {
        if (strcmp (args[0], ptr->filename) == 0)
        {
            if (fgets (buffer, 1024, ptr->fileptr) == NULL)
                (void) guml_filehandle_close (out_string, args, nargs);
            break;
        }
        ptr = ptr->nextfile;
    }
    if ((tmp = strlen (buffer)) > 0 && buffer[tmp - 1] == '\n')
        buffer[tmp - 1] = '\0';
    add_string(out_string, buffer);
    return NULL;
}
