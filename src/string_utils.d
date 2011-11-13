module string_utils;

import core.vararg;
import core.stdc.config;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.posix.sys.time;
import core.sys.posix.unistd;

struct Data
{
    char  *data   = null;
    size_t length = 0;    // includes trailing null
}

enum LOGFILE = "/tmp/guml_logfile";

void writelog(const char *msg, ...)
{
    timeval tp;
    char str[1024];
    static int mypid = -1;
    FILE   *fp;
    va_list ap;

    if (mypid == -1)
        mypid = getpid();
 
    fp = fopen(LOGFILE, "a");
    if (fp != null)
    {
        gettimeofday(&tp, null);
        sprintf(str.ptr, "%05d - %ld.%06ld", mypid, tp.tv_sec, tp.tv_usec);
        fprintf(fp, "%s - ", str.ptr);
        version(X86)
            va_start(ap, msg);
        else version(X86_64)
            va_start(ap, __va_argsave);
        vfprintf(fp, msg, ap);
        va_end(ap);
        fprintf(fp, "\n");
        fclose(fp);
    }
}

Data* create_string(string s)
{
    return create_string(s.ptr);
}

Data *create_string(const char *str)
{
    Data *tmp = cast(Data*)calloc(1, Data.sizeof);
    add_string(tmp, str);
    return tmp;
}

char *strip_space(char *buffer)
{
    char *p;
    char *q;

    p = buffer;
    q = buffer + strlen(buffer) - 1;
    while (*p && *p == ' ')
        p++;
    while (q > p && *q == ' ')
        q--;
    q++;
    *q = 0;

    memmove(buffer, p, (q - p) + 1);

    return buffer;
}

char *rtrim(char *buffer)
{
    char *p;

    p = buffer + strlen(buffer) - 1;
    while (p > buffer && *p == ' ')
        p--;
    p++;
    *p = 0;

    return buffer;
}

/* Make sure that str has enough space to append atleast 'add' characters */
enum SPACE_MASK = ((cast(c_ulong)-1) ^ 0xFFF);

void check_space(Data *str, size_t add)
{
    if (!(str.length))
        add++;
    if (str.length+add > ((str.length + 4095) & SPACE_MASK))
    {
        size_t newlen = (str.length + add + 4095) & SPACE_MASK;
        assert(newlen > str.length+add);

        str.data = cast(char*)realloc(str.data, newlen);
        if (!(str.length))
        {
            str.data[0] = 0;
            str.length++;
        }
    }
}

/* add c to the end of str */
void add_char(Data *str, char c)
{
    check_space(str, 1);
    str.data[str.length - 1] = c;
    str.data[str.length++] = 0;
}

/* add s2 to the end of s1 */
void add_string(Data *s1, const char *s2)
{
    size_t s2_len = strlen(s2);

    if (!s2_len)
        return;
    check_space(s1, s2_len);
    strncpy(s1.data + s1.length - 1, s2, s2_len + 1);
    s1.length += s2_len;
}

/* add s2 to the end of s1 */
void add_string(Data *s1, const char *s2, c_ulong s2_len)
{
    if (!s2_len)
        return;
    check_space(s1, s2_len);
    strncpy(s1.data + s1.length - 1, s2, s2_len);
    s1.length += s2_len;
    s1.data[s1.length-1] = 0;
}

void add_string(Data *s1, Data *s2)
{
    add_string(s1, *s2);
}

void add_string(Data *s1, const ref Data s2)
{
    if (!s2.length)
        return;
    check_space(s1, s2.length);
    strncpy(s1.data + s1.length - 1, s2.data, s2.length);
    s1.length += s2.length - 1;  /* don't account for 2 nulls */
}

int split_string(char *str, char split, char **w1, char **w2)
{
    char *tmp;

    tmp = strchr(str, split);
    if (tmp)
    {
        *tmp = 0;
        *w1 = str;
        *w2 = tmp+1;
        return 1;
    }
    else
        return 0;
}

