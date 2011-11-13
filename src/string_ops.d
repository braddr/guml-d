module string_ops;

import data;
import string_utils;
import www;

import core.stdc.config;
import core.stdc.ctype;
import core.stdc.stdlib;
import core.stdc.stdio;
import core.stdc.string;
import core.stdc.time;

extern(C)
{
    extern char *strptime(const char *s, const char *format, tm *tm);
}

char *guml_index (Data *out_string, char** args, int nargs)
{
    char *comres;
    char retc[32];

    if (nargs != 2)
        return cast(char*)"\\strindex requires 2 parameters";

    comres = strstr (args[0], args[1]);
    if (comres != null)
    {
        sprintf (retc.ptr, "%ld", (comres - args[0]) / char.sizeof);
        add_string (out_string, retc.ptr);
    }
    return null;
}

/* returns substring of length arg[2] starting at arg[1] */
char *guml_substr (Data *out_string, char** args, int nargs)
{
    uint start_index;
    size_t len;

    if (nargs != 3)
        return cast(char*)"\\strsubstr requires 3 parameters";

    start_index = atoi (args[1]);

    if (start_index > strlen (args[0]))
        return null;

    len = atoi (args[2]);
    if (len < 0)
        return null;

    if (len > strlen (args[0]) - start_index)
        len = strlen (args[0]) - start_index;

    args[0][start_index + len] = 0;
    add_string (out_string, &(args[0][start_index]));

    return null;
}

/* compute length of a string */
char *guml_length (Data *out_string, char** args, int nargs)
{
    char s[128];

    if (nargs != 1)
        return cast(char*)"\\strlen requires only 1 parameter";

    sprintf (s.ptr, "%zd", strlen (args[0]));
    add_string (out_string, s.ptr);

    return null;
}

char *guml_upper_string (Data *out_string, char** args, int nargs)
{
    if (nargs != 1)
        return cast(char*)"\\strupper requires only 1 parameter";

    for (size_t i = 0; i < strlen (args[0]); i++)
        add_char (out_string, cast(char)toupper (args[0][i]));

    return null;
}

char *guml_lower_string (Data *out_string, char** args, int nargs)
{
    if (nargs != 1)
        return cast(char*)"\\strlower requires only 1 parameter";

    for (size_t i = 0; i < strlen (args[0]); i++)
        add_char (out_string, cast(char)tolower (args[0][i]));

    return null;
}

char *guml_strip (Data *out_string, char** args, int nargs)
{
    int flag = 0;

    if (nargs < 2 || nargs > 3)
        return cast(char*)"\\strstrip requires 2 or 3 parameters";

    if (nargs == 3)
        flag = atoi(args[2]);

    for (size_t i = 0; i < strlen (args[0]); i++)
        if (flag)
        {
            if (strchr(args[1], args[0][i]) != null)
                add_char(out_string, args[0][i]);
        }
        else
        {
            if (strchr (args[1], args[0][i]) == null)
                add_char (out_string, args[0][i]);
        }

    return null;
}

/* return a date, two optional arguments: */
/* args[0]: date format string, default like "February 19, 1997" */
/* args[1]: time to convert. (as in "854523817"..)  defaults to current time */
char *guml_date (Data *out_string, char** args, int nargs)
{
    char buffer[100];
    char *fmtstr;
    time_t ttime;
    tm *tmtime;

    if (nargs > 2)
        return cast(char*)"\\date requires between 0 and 2 parameters";

    if (nargs < 1 || *args[0] == '\0')
        fmtstr = cast(char*)("%B %d, %Y");
    else
        fmtstr = args[0];

    if (nargs < 2 || *args[1] == '\0')
        ttime = time (null);
    else
        ttime = atol (args[1]);
    tmtime = localtime (&ttime);

    strftime (buffer.ptr, buffer.sizeof, fmtstr, tmtime);
    add_string (out_string, buffer.ptr);

    return null;
}

/* return the unix time, # of seconds since Jan 1st, 1970 0:00 GMT */
/* OR, give it a date format string, a date (in said format), and we'll */
/* return to you /that/ unix time..  pretty swell, eh? */
char *guml_time (Data *out_string, char** args, int nargs)
{
    tm tms;
    char buffer[64];
    time_t ttime;

    if (nargs != 0 && nargs != 2)
        return cast(char*)"\\time requires 0 or 2 parameters";

    if (nargs < 2 || *args[0] == '\0')
        ttime = time (null);
    else
    {
        strptime (args[1], args[0], &tms);
        ttime = mktime (&tms);
    }

    sprintf (buffer.ptr, "%li", cast(long) ttime);
    add_string (out_string, buffer.ptr);

    return null;
}

static char soundex_lookup[] =
[
    '0',    /* A */
    '1',    /* B */
    '2',    /* C */
    '3',    /* D */
    '0',    /* E */
    '1',    /* F */
    '2',    /* G */
    '0',    /* H */
    '0',    /* I */
    '2',    /* J */
    '2',    /* K */
    '4',    /* L */
    '5',    /* M */
    '5',    /* N */
    '0',    /* O */
    '1',    /* P */
    '0',    /* Q */
    '6',    /* R */
    '2',    /* S */
    '3',    /* T */
    '0',    /* U */
    '1',    /* V */
    '0',    /* W */
    '2',    /* X */
    '0',    /* Y */
    '2',    /* Z */
];

bool isascii(char c)
{
    return c >= 0 && c <= 127;
}

char *guml_soundex(Data *out_string, char** args, int nargs)
{
    int num_chars;
    char c, last_char;

    if (nargs < 0 || nargs > 2)
        return cast(char*)"\\soundex requires either 1 or 2 parameters";

    if (nargs == 2)
    {
        num_chars = atoi(args[1]);
        if (num_chars <= 0)
            num_chars = 4;
    }
    else
        num_chars = 4;

    for (size_t i=0; i<strlen(args[0]) && num_chars; i++)
    {
        c = args[0][i];
        if (!isascii(c) || !isalpha(c))
            continue;
        c = cast(char)toupper(c);
        if (c == 'S' && (!isalpha(args[0][i+1])))
            continue;
        if (i == 0)
        {
            add_char(out_string, c);
            last_char = c;
            num_chars--;
        }
        else
        {
            c = soundex_lookup[c-'A'];
            if (c != '0' && c != last_char)
            {
                last_char = c;
                add_char(out_string, c);
                num_chars--;
            }
        }
    }
    while (num_chars)
    {
        add_char(out_string, '0');
        num_chars--;
    }
    return null;
}

char *guml_strtok(Data *out_string, char** args, int nargs)
{
    static char *my_tok = null;
    char *tmp;

    if (nargs != 2)
        return cast(char*)"\\strtok requires 2 parameters";

    if (strlen(args[0]) != 0)
    {
        if (my_tok)
            free(my_tok);
        my_tok = strdup(args[0]);
        tmp = strtok(my_tok, args[1]);
    }
    else
        tmp = strtok(null, args[1]);
    if (tmp)
        add_string(out_string, tmp);
    else
    {
        free(my_tok);
        my_tok = null;
    }
    return null;
}

char *guml_strcmp(Data *out_string, char** args, int nargs)
{
    int rc;

    if (nargs != 2)
        return cast(char*)"\\strcmp requires 2 arguments!";

    if ((rc = strcmp(args[0], args[1])) > 0)
        add_char(out_string, '1');
    else if (rc == 0)
        add_char(out_string, '0');
    else
        add_string_size(out_string, "-1", 2);

    return null;
}

/* modifies args[0], so never call with a constant string */
char *guml_httpdecode(Data *out_string, char** args, int nargs)
{
    if (nargs != 1)
        return cast(char*)"\\httpdecode requires only 1 parameter";

    add_string(out_string, http_decode(args[0]));
    return null;
}

string tohex(int c)
{
    static string dec_2_hex[] =
    [
       "%00", "%01", "%02", "%03", "%04", "%05", "%06", "%07", "%08", "%09",
       "%0a", "%0b", "%0c", "%0d", "%0e",
       null, null, null, null, null,
       null, null, null, null, null,
       null, null, null, null, null,
       null, null, null,
       "%21", "%22", "%23", "%24", "%25", "%26", "%27", "%28", "%29", "%2a", "%2b",
       "%2c", "%2d", "%2e", "%2f", "%30", "%31", "%32", "%33", "%34", "%35", "%36",
       "%37", "%38", "%39", "%3a", "%3b", "%3c", "%3d", "%3e", "%3f", "%40", "%41",
       "%42", "%43", "%44", "%45", "%46", "%47", "%48", "%49", "%4a", "%4b", "%4c",
       "%4d", "%4e", "%4f", "%50", "%51", "%52", "%53", "%54", "%55", "%56", "%57",
       "%58", "%59", "%5a", "%5b", "%5c", "%5d", "%5e", "%5f", "%60", "%61", "%62",
       "%63", "%64", "%65", "%66", "%67", "%68", "%69", "%6a", "%6b", "%6c", "%6d",
       "%6e", "%6f", "%70", "%71", "%72", "%73", "%74", "%75", "%76", "%77", "%78",
       "%79", "%7a", "%7b", "%7c", "%7d", "%7e", null
    ];
    return dec_2_hex[c];
}

char *guml_httpencode(Data *out_string, char** args, int nargs)
{
    int i;

    if (nargs != 1)
        return cast(char*)"\\httpencode requires only 1 parameter";

    for (i=0; i<strlen(args[0]); i++) {
        if (args[0][i] == ' ')
            add_char(out_string, '+');
        else if ((args[0][i] >= '0' && args[0][i] <= '9') ||
                (args[0][i] >= 'A' && args[0][i] <= 'Z') ||
                (args[0][i] >= 'a' && args[0][i] <= 'z'))
            add_char(out_string, args[0][i]);
        else
            add_string_size(out_string, tohex(args[0][i]).ptr, 3);
    }
    return null;
}

/* quote a string; that is, replace double quotes
   with backslashed double-quotes */
 
version (USE_ORACLE)
{
    enum QUOTE_CHAR = '\'';
    enum QUOTED_STR = "''";
}
else
{
    enum QUOTE_CHAR = '"';
    enum QUOTED_STR = "\"\"";
}

char *guml_sqlquote(Data *out_string, char** args, int nargs)
{
    if (nargs != 1)
        return cast(char*)"\\sqlquote requires only 1 parameter";
 
    for (size_t i=0; i<strlen(args[0]); i++)
    {
        if (args[0][i] == QUOTE_CHAR)
            add_string_size(out_string, QUOTED_STR, 2);
        else
            add_char(out_string, args[0][i]);
    }
 
    return null;
}

