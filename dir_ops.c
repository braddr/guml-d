/* dir_ops.c */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "global.h"

DIR *mydir = NULL;

int guml_close_dir_internal ()
{
    int rc = 0;

    if (mydir)
    {
        rc = closedir(mydir);
        mydir = NULL;
    }

    return rc;
}
    
char *guml_close_dir (Data *out_string, char *args[], int nargs)
{
    if (nargs != 0)
        return "\\closedir requires no parameters";

    guml_close_dir_internal();
    return NULL;
}       

char *guml_open_dir (Data *out_string, char *args[], int nargs)
{
    if (nargs != 1)
        return "\\opendir requires only one parameter";

    guml_close_dir_internal();
    mydir = opendir(args[0]);
    if (!mydir)
        return NULL;

    add_string_size (out_string, "true", 4);
    return NULL;
}

char *guml_read_dir (Data *out_string, char *args[], int nargs)
{
    struct dirent *mydirent;

    if (!mydir)
        return "mydir in \\readdir is null -- make sure to check the return value of \\opendir";

    mydirent = readdir(mydir);
    if (!mydirent)
    {
        guml_close_dir_internal();
        return NULL;
    }

    add_string (out_string, mydirent->d_name);
    return NULL;
}

char *guml_isdir (Data *out_string, char *args[], int nargs)
{
    struct stat buf;

    if(nargs != 1)
      return "\\isdir requires one parameter, the file name!";

    stat(args[0],&buf);

/* returns error if there's a permission error.  oh well..
    if(stat(args[0],&buf))
      return "stat call returned error in \\isdir!";
*/

    if(S_ISDIR(buf.st_mode))
      add_string_size (out_string, "true", 4);

    return NULL;
}

