module email;

import hash_table;
import string_utils;

import core.stdc.config;
import core.stdc.stdio;
import core.stdc.string;
import core.sys.posix.stdio;

/* unset a variable */
char *guml_email (Data *out_string, const ref Data[] args)
{
    FILE *fp;
    char cmdstr[1000];

    if (args.length < 2 || args.length > 3)
        return cast(char*)"\\email requires either 2 or 3 parameters";

    Data* fwd = find_hash_data("FILE_WRITE_DIR", calc_hash("FILE_WRITE_DIR"));
    if (!fwd)
        return cast(char*)"\\email -- FILE_WRITE_DIR not configured";

    if (args.length == 3 && strlen (args[2].data) > 0)
        sprintf (cmdstr.ptr, "/usr/lib/sendmail -f \\\"%s\\\" %s >> %s/email.log", args[2].data, args[0].data, fwd.data);
    else
        sprintf (cmdstr.ptr, "/usr/lib/sendmail %s >> %s/email.log", args[0].data, fwd.data);

    fp = popen (cmdstr.ptr, "w");
    if (fp)
    {
        fprintf (fp, "%s\n", args[1].data);
        pclose (fp);
        add_string(out_string, cast(char*)"true", 4);
    }

    return null;
}

char *guml_sendmail (Data *out_string, const ref Data[] args)
{
    FILE *fp;
    string cmdstr =  "/usr/lib/sendmail -t";

    if (args.length > 2)
        return cast(char*)"\\sendmail requires exactly one parameter, the text of the message";

    fp = popen (cmdstr.ptr, "w");
    if (fp)
    {
        fprintf (fp, "%s\n", args[0].data);
        pclose (fp);
        add_string(out_string, cast(char*)"true", 4);
    }

    return null;
}

/+
char *guml_shell (Data *out_string, char *args[], int args.length)
{
    FILE *fp;
    char buf[1024];

    if (args.length != 1)
        return "\\shell requires only 1 parameter";
 
    if ((fp = popen(args[0].data, "r")) != null)
    {
        while (fgets(buf, 1000, fp) != null)
            add_string(out_string, buf);
 
        pclose(fp);
    }
    return null;
}
+/

