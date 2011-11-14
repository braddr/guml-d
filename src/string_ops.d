module string_ops;

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

char *guml_index (Data *out_string, const ref Data[] args)
{
    if (args.length != 2)
        return cast(char*)"\\strindex requires 2 parameters";

    char *comres = strstr (args[0].asCharStar, args[1].asCharStar);
    if (comres != null)
    {
        char retc[32];
        sprintf (retc.ptr, "%ld", (comres - args[0].asCharStar) / char.sizeof);
        add_string (out_string, retc.ptr);
    }
    return null;
}

/* returns substring of length arg[2] starting at arg[1] */
char *guml_substr (Data *out_string, const ref Data[] args)
{
    if (args.length != 2 && args.length != 3)
        return cast(char*)"\\strsubstr requires 2-3 parameters";

    uint start_index = atoi (args[1].asCharStar);

    if (start_index > args[0].length)
        return null;

    size_t len;
    if (args.length == 2)
        len = strlen(args[0].asCharStar);
    else
    {
        len = atoi (args[2].asCharStar);
        if (len < 0)
            return null;
    }

    if (len > args[0].length - start_index)
        len = args[0].length - start_index;

    add_string (out_string, &(args[0].asCharStar[start_index]), len);

    return null;
}

/* compute length of a string */
char *guml_length (Data *out_string, const ref Data[] args)
{
    if (args.length != 1)
        return cast(char*)"\\strlen requires only 1 parameter";

    char s[128];
    sprintf (s.ptr, "%zd", args[0].length);
    add_string (out_string, s.ptr);

    return null;
}

char *guml_upper_string (Data *out_string, const ref Data[] args)
{
    if (args.length != 1)
        return cast(char*)"\\strupper requires only 1 parameter";

    foreach (c; args[0].asString)
        add_char (out_string, cast(char)toupper(c));

    return null;
}

char *guml_lower_string (Data *out_string, const ref Data[] args)
{
    if (args.length != 1)
        return cast(char*)"\\strlower requires only 1 parameter";

    foreach(c; args[0].asString())
        add_char (out_string, cast(char)tolower(c));

    return null;
}

char *guml_strip (Data *out_string, const ref Data[] args)
{
    if (args.length < 2 || args.length > 3)
        return cast(char*)"\\strstrip requires 2 or 3 parameters";

    int flag = 0;

    if (args.length == 3)
        flag = atoi(args[2].asCharStar);

    foreach(c; args[0].asString)
        if (flag)
        {
            if (strchr(args[1].asCharStar, c) != null)
                add_char(out_string, c);
        }
        else
        {
            if (strchr(args[1].asCharStar, c) == null)
                add_char (out_string, c);
        }

    return null;
}

/* return a date, two optional arguments: */
/* args[0]: date format string, default like "February 19, 1997" */
/* args[1]: time to convert. (as in "854523817"..)  defaults to current time */
char *guml_date (Data *out_string, const ref Data[] args)
{
    if (args.length > 2)
        return cast(char*)"\\date requires between 0 and 2 parameters";

    const(char) *fmtstr;
    if (args.length < 1 || args[0].asCharStar[0] == '\0')
        fmtstr = cast(char*)("%B %d, %Y");
    else
        fmtstr = args[0].asCharStar;

    time_t ttime;
    if (args.length < 2 || args[1].asCharStar[0] == '\0')
        ttime = time (null);
    else
        ttime = atol (args[1].asCharStar);
    tm* tmtime = localtime (&ttime);

    char buffer[100];
    strftime (buffer.ptr, buffer.sizeof, fmtstr, tmtime);
    add_string (out_string, buffer.ptr);

    return null;
}

/* return the unix time, # of seconds since Jan 1st, 1970 0:00 GMT */
/* OR, give it a date format string, a date (in said format), and we'll */
/* return to you /that/ unix time..  pretty swell, eh? */
char *guml_time (Data *out_string, const ref Data[] args)
{
    if (args.length != 0 && args.length != 2)
        return cast(char*)"\\time requires 0 or 2 parameters";

    time_t ttime;
    if (args.length < 2 || args[0].asCharStar[0] == '\0')
        ttime = time (null);
    else
    {
        tm tms;
        strptime (args[1].asCharStar, args[0].asCharStar, &tms);
        ttime = mktime (&tms);
    }

    char buffer[64];
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

char *guml_soundex(Data *out_string, const ref Data[] args)
{
    if (args.length < 0 || args.length > 2)
        return cast(char*)"\\soundex requires either 1 or 2 parameters";

    int num_chars;
    if (args.length == 2)
    {
        num_chars = atoi(args[1].asCharStar);
        if (num_chars <= 0)
            num_chars = 4;
    }
    else
        num_chars = 4;

    char last_char;
    for (size_t i = 0; i < args[0].length && num_chars; i++)
    {
        char c = args[0].asCharStar[i];
        if (!isascii(c) || !isalpha(c))
            continue;
        c = cast(char)toupper(c);
        if (c == 'S' && (!isalpha(args[0].asCharStar[i+1])))
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

char *guml_strtok(Data *out_string, const ref Data[] args)
{
    static char *my_tok = null;

    if (args.length != 2)
        return cast(char*)"\\strtok requires 2 parameters";

    char *tmp;
    if (args[0])
    {
        if (my_tok)
            free(my_tok);
        my_tok = strdup(args[0].asCharStar);
        tmp = strtok(my_tok, args[1].asCharStar);
    }
    else
        tmp = strtok(null, args[1].asCharStar);
    if (tmp)
        add_string(out_string, tmp);
    else
    {
        free(my_tok);
        my_tok = null;
    }
    return null;
}

char *guml_strcmp(Data *out_string, const ref Data[] args)
{
    if (args.length != 2)
        return cast(char*)"\\strcmp requires 2 arguments!";

    int rc = strcmp(args[0].asCharStar, args[1].asCharStar);
    if (rc > 0)
        add_char(out_string, '1');
    else if (rc == 0)
        add_char(out_string, '0');
    else
        add_string(out_string, "-1", 2);

    return null;
}

/* modifies args[0], so never call with a constant string */
char *guml_httpdecode(Data *out_string, const ref Data[] args)
{
    if (args.length != 1)
        return cast(char*)"\\httpdecode requires only 1 parameter";

    char* t = strdup(args[0].asCharStar);

    add_string(out_string, http_decode(t));
    free(t);
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

char *guml_httpencode(Data *out_string, const ref Data[] args)
{
    if (args.length != 1)
        return cast(char*)"\\httpencode requires only 1 parameter";

    foreach (c; args[0].asString)
    {
        if (c == ' ')
            add_char(out_string, '+');
        else if ((c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z'))
            add_char(out_string, c);
        else
            add_string(out_string, tohex(c));
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

char *guml_sqlquote(Data *out_string, const ref Data[] args)
{
    if (args.length != 1)
        return cast(char*)"\\sqlquote requires only 1 parameter";
 
    foreach (c; args[0].asString)
    {
        if (c == QUOTE_CHAR)
            add_string(out_string, QUOTED_STR, 2);
        else
            add_char(out_string, c);
    }
 
    return null;
}

