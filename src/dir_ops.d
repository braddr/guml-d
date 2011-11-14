module dir_ops;

import string_utils;

import core.stdc.config;
import core.sys.posix.dirent;
import core.sys.posix.sys.stat;

DIR *mydir = null;

int guml_close_dir_internal ()
{
    int rc = 0;

    if (mydir)
    {
        rc = closedir(mydir);
        mydir = null;
    }

    return rc;
}
    
char *guml_close_dir (Data *out_string, const ref Data[] args)
{
    if (args.length != 0)
        return cast(char*)"\\closedir requires no parameters";

    guml_close_dir_internal();
    return null;
}       

char *guml_open_dir (Data *out_string, const ref Data[] args)
{
    if (args.length != 1)
        return cast(char*)"\\opendir requires only one parameter";

    guml_close_dir_internal();
    mydir = opendir(args[0].asCharStar);
    if (!mydir)
        return null;

    add_string(out_string, "true", 4);
    return null;
}

char *guml_read_dir (Data *out_string, const ref Data[] args)
{
    dirent *mydirent;

    if (!mydir)
        return cast(char*)"mydir in \\readdir is null -- make sure to check the return value of \\opendir";

    mydirent = readdir(mydir);
    if (!mydirent)
    {
        guml_close_dir_internal();
        return null;
    }

    add_string (out_string, mydirent.d_name.ptr);
    return null;
}

char *guml_isdir (Data *out_string, const ref Data[] args)
{
    stat_t buf;

    if (args.length != 1)
      return cast(char*)"\\isdir requires one parameter, the file name!";

    stat(args[0].asCharStar, &buf);

/* returns error if there's a permission error.  oh well..
    if(stat(args[0],&buf))
      return "stat call returned error in \\isdir!";
*/

    if (S_ISDIR(buf.st_mode))
      add_string(out_string, "true", 4);

    return null;
}

