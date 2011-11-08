/* email.c */
/* guml interface to sendmail */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include "global.h"

/* unset a variable */
char *guml_email (Data *out_string, char *args[], int nargs)
{
    FILE *fp;
    char cmdstr[1000];

    if (nargs < 2 || nargs > 3)
        return "\\email requires either 2 or 3 parameters";

    if (nargs == 3 && strlen (args[2]) > 0)
        sprintf (cmdstr, "/usr/lib/sendmail -f \\\"%s\\\" %s >> %s/email.log", args[2], args[0], FILE_WRITE_DIR);
    else
        sprintf (cmdstr, "/usr/lib/sendmail %s >> %s/email.log", args[0], FILE_WRITE_DIR);

#ifdef WIN32
    if ((fp = _popen (cmdstr, "w")) != NULL)
#else
    if ((fp = popen (cmdstr, "w")) != NULL)
#endif
    {
        fprintf (fp, "%s\n", args[1]);
#ifdef WIN32
        _pclose (fp);
#else
        pclose (fp);
#endif
        add_string_size (out_string, "true", 4);
    }

    return NULL;
}

char *guml_sendmail (Data *out_string, char *args[], int nargs)
{
    FILE *fp;
    char cmdstr[] =  "/usr/lib/sendmail -t";

    if (nargs > 2)
        return "\\sendmail requires exactly one parameter, the text of the message";

#ifdef WIN32
    if ((fp = _popen (cmdstr, "w")) != NULL)
#else
    if ((fp = popen (cmdstr, "w")) != NULL)
#endif
    {
        fprintf (fp, "%s\n", args[0]);
#ifdef WIN32
        _pclose (fp);
#else
        pclose (fp);
#endif
        add_string_size (out_string, "true", 4);
    }

    return NULL;
}

char *guml_shell (Data *out_string, char *args[], int nargs)
{
    FILE *fp;
    char buf[1024];

    if (nargs != 1)
        return "\\shell requires only 1 parameter";
 
#ifdef WIN32
    if ((fp = _popen(args[0]), "r")) != NULL)
#else
    if ((fp = popen(args[0], "r")) != NULL)
#endif
    {
        while (fgets(buf, 1000, fp) != NULL)
            add_string(out_string, buf);
 
#ifdef WIN32
        _pclose(fp);
#else
        pclose(fp);
#endif
    }
    return NULL;
}

