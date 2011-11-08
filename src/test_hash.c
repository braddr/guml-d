#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "global.h"

char *random_string(int len)
{
    static char tmp[1025];
    int i;

    for (i = 0; i < len; i++)
        tmp[i] = (random() % 26) + 'a';
    tmp[len] = 0;

    return tmp;
}

Data *create_string(char *str, int no_dup)
{
    Data *tmp = malloc(sizeof(Data));

    tmp->data = no_dup ? str : strdup(str);
    tmp->length = strlen(str) + 1;
    return tmp;
}

int main (int argc, char *argv[])
{
    char *tmp_str;
    Data *tmp_data, *tmp_data2;
    int i;

    init_hash_table();

    for (i = 0; i < 10000; i++)
    {
        tmp_str = random_string((random() % 64) + 5);
        tmp_data = create_string(tmp_str, 0);
        tmp_str = strdup(random_string((random() % 16) + 5));

        push_stack(create_string(tmp_str, 0));
        insert_hash(tmp_str, tmp_data, calc_hash(tmp_str), 0);
    }

#ifdef DEBUG_HASH
    hash_info();
#endif

    printf("\n\n\n");

    while ((tmp_data = pop_stack()))
    {
        printf("popped: %s\n", tmp_data->data);
        tmp_data2 = find_hash_data(tmp_data->data, calc_hash(tmp_data->data));
        if (tmp_data2)
            printf(" value: %s\n", tmp_data2->data);
        else
            printf(" value: unknown\n");
        free(tmp_data->data);
        free(tmp_data);
    }

    return 0;
}
