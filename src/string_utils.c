#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>
#include <stdarg.h>

#include "global.h"

/* get time as text string */
void writelog(char *msg, ...)
{
    struct timeval tp;
    char str[1024];
    static int mypid = -1;
    FILE   *fp;
    va_list ap;

    if (mypid == -1)
        mypid = getpid();
 
    if ((fp = fopen(LOGFILE, "a")) != NULL)
    {
        gettimeofday(&tp, NULL);
        sprintf(str, "%05d - %ld.%06ld", mypid, tp.tv_sec, tp.tv_usec);
        fprintf(fp, "%s - ", str);
        va_start(ap, msg);
        vfprintf(fp, msg, ap);
        va_end(ap);
        fprintf(fp, "\n");
        fclose(fp);
    }
}


Data *create_string(char *str, int no_dup)
{
    Data *tmp = malloc(sizeof(Data));

    tmp->data = no_dup ? str : strdup(str);
    tmp->length = strlen(str)+1;
    return tmp;
}

char *strip_space (char *buffer)
{
    char *p, *q;

    p = buffer;
    q = buffer + strlen (buffer) - 1;
    while (*p && *p == ' ')
        p++;
    while (q > p && *q == ' ')
        q--;
    q++;
    *q = 0;

    memmove (buffer, p, (q - p) + 1);

    return buffer;
}

char *rtrim (char *buffer)
{
    char *p;

    p = buffer + strlen (buffer) - 1;
    while (p > buffer && *p == ' ')
        p--;
    p++;
    *p = 0;

    return buffer;
}

/* Make sure that str has enough space to append atleast 'add' characters */
#define SPACE_MASK (((unsigned long)-1) ^ 0xFFF)

void check_space (Data *str, int add)
{
    if (!(str->length))
        add++;
    if (str->length+add > ((str->length + 4095) & SPACE_MASK))
    {
        str->data = realloc (str->data, (str->length + add + 4095) & SPACE_MASK);
        if (!(str->length))
        {
            str->data[0] = 0;
            str->length++;
        }
    }
}

/* add c to the end of str */
void add_char (Data *str, char c)
{
    check_space (str, 1);
    str->data[str->length - 1] = c;
    str->data[str->length++] = 0;
}

/* add s2 to the end of s1 */
void add_string (Data *s1, char *s2)
{
    int s2_len = strlen(s2);

    if (!s2_len)
        return;
    check_space (s1, s2_len);
    strncpy (s1->data + s1->length - 1, s2, s2_len + 1);
    s1->length += s2_len;
}

/* add s2 to the end of s1 */
void add_string_size (Data *s1, char *s2, unsigned long s2_len)
{
    if (!s2_len)
        return;
    check_space (s1, s2_len);
    strncpy (s1->data + s1->length - 1, s2, s2_len);
    s1->length += s2_len;
    s1->data[s1->length-1] = 0;
}

void add_string_data (Data *s1, Data *s2)
{
    if (!s2->length)
        return;
    check_space (s1, s2->length);
    strncpy (s1->data + s1->length - 1, s2->data, s2->length);
    s1->length += s2->length - 1;  /* don't account for 2 nulls */
}

int split_string(char *str, char split, char **w1, char **w2)
{
    char *tmp;

    if ((tmp = strchr(str, split)))
    {
        *tmp = 0;
        *w1 = str;
        *w2 = tmp+1;
        return 1;
    }
    else
        return 0;
}

