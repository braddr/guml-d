#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "global.h"

Data		**stack;
HashNode	*hash_table[HASH_WIDTH];
unsigned int	stack_depth, stack_allocated, hash_depths[HASH_WIDTH], hash_allocated[HASH_WIDTH], dupes, readonly;

void init_hash_table(void)
{
	dupes = 0;
    readonly = 0;
	stack_depth = 0;
	stack_allocated = 0;
	stack = NULL;
	memset(hash_depths, 0, sizeof(unsigned int) * HASH_WIDTH);
	memset(hash_allocated, 0, sizeof(unsigned int) * HASH_WIDTH);
	memset(hash_table, 0, sizeof(HashNode*) * HASH_WIDTH);
}

void push_stack(Data *data)
{
	if (stack_depth == stack_allocated)
	{
		stack_allocated += STACK_INCREMENT;
		stack = realloc(stack, sizeof(Data*) * stack_allocated);
		if (!stack)
		{
			printf("Content-type: text/plain\n\nFatal error, unable to grow stack, bailing!!!\n");
			exit(5);
		}
	}
	stack[stack_depth++] = data;
}

Data *pop_stack(void)
{
	if (stack_depth)
		return stack[--stack_depth];
	else
		return NULL;
}

void shrink_stack(void)
{
	if (stack_allocated != 0)
	{
		stack_allocated = ((stack_depth & STACK_MASK) + 1) * STACK_INCREMENT;
		stack = realloc(stack, sizeof(Data*) * stack_allocated);
	}
}

#ifdef DEBUG_STACK
void stack_info(void)
{
	printf("stack depth: %d\nstack allocated: %d\n", stack_depth, stack_allocated);
}
#endif

#ifdef DEBUG_HASH
void hash_info(void)
{
	int i, j, k, min, max;

	printf("hash_size: %dx%d\ndupes: %d\ndepths used:\n", HASH_WIDTH, HASH_DEPTH, dupes);

	for (i=0, j=0, k=0, min=999999, max=0; i<HASH_WIDTH; i++)
		if (hash_depths[i])
		{
			if (hash_depths[i] < min)
				min = hash_depths[i];
			if (hash_depths[i] > max)
				max = hash_depths[i];
			printf("\t%d = %d\n", i, hash_depths[i]);
			k += hash_depths[i];
			j++;
		}
	printf("buckets with data: %d\n", j);
    printf("total entries: %d\n", k);
	printf("min entries: %d\n", min);
	printf("max entries: %d\n", max);

	printf("buckets at each depth:\n"); 
	for (;max;max--)
	{
		for (i=0, j=0; i<HASH_WIDTH; i++)
			if (hash_depths[i] == max)
				j++;
		printf("\t%d = %d\n", max, j);
	}
}
#endif

INLINE void calc_hash_increment(unsigned long *hash_value, char c)
{
	*hash_value = (*hash_value << 4) + c;
}

unsigned long calc_hash(char *str)
{
	unsigned long hashval = 0/*, g*/;
	int len;

	len = strlen(str);

	for (; len; len--, str++)
		hashval = (hashval << 4) + *str;

	return hashval;
}

HashNode *find_hash_node(char *key, unsigned long hash)
{
	int bucket = hash % HASH_WIDTH;
	unsigned int i = 0;
	HashNode *tmp = hash_table[bucket];

	while (tmp && i < hash_depths[bucket] && strcmp(tmp[i].key, key) != 0)
		i++;

	if (i < hash_depths[bucket])
		return &(tmp[i]);
	else
		return NULL;
}

Data *find_hash_data(char *key, unsigned long hash)
{
	HashNode *tmp = find_hash_node(key, hash);

	if (tmp)
		return tmp->data;
	else
		return NULL;
}

int insert_hash(char *key, Data *data, unsigned long hash, unsigned long flags)
{
	HashNode *tmp_node;
	unsigned int bucket;

	if ((tmp_node = find_hash_node(key, hash)))
	{
        if (tmp_node->flags & HASH_READONLY)
        {
            readonly++;
            return 1;
        }
		free(key);
		free(tmp_node->data->data);
		free(tmp_node->data);
		dupes++;
	}
	else
	{
		bucket = hash % HASH_WIDTH;
		if (hash_depths[bucket] == hash_allocated[bucket])
		{
			hash_allocated[bucket] += HASH_DEPTH;
			hash_table[bucket] = (HashNode*)realloc(hash_table[bucket], hash_allocated[bucket]*sizeof(HashNode));
			if (!hash_table[bucket])
			{
				printf("Content-type: text/plain\n\nError growing hash table, bailing!\n");
				exit(6);
			}
		}
		tmp_node = &(hash_table[bucket][hash_depths[bucket]]);
		tmp_node->key = key;
		tmp_node->hash = hash;
		(hash_depths[bucket])++;
	}
	tmp_node->data = data;
	tmp_node->flags = flags;
    return 0;
}

void delete_hash(char *key, unsigned long hash)
{
	int bucket = hash % HASH_WIDTH;
	unsigned int i = 0;
	HashNode *tmp = hash_table[bucket];

	while (tmp && i < hash_depths[bucket] && strcmp(tmp[i].key, key) != 0)
		i++;

	if (i < hash_depths[bucket] && !(hash_table[bucket][i].flags & HASH_READONLY))
	{
		free(hash_table[bucket][i].data->data);
		free(hash_table[bucket][i].data);
		free(hash_table[bucket][i].key);
		hash_depths[bucket]--;
		memcpy(&(hash_table[bucket][i]), &(hash_table[bucket][hash_depths[bucket]]), sizeof(HashNode));
	}
}

// Warning, this code assumes that all the builtin's are first in the hash buckets
void clean_hash(unsigned long flags)
{
	unsigned int i, j, num_builtin;

	for (i=0; i<HASH_WIDTH; i++)
	{
        num_builtin = 0;
		for (j=0; j<hash_depths[i]; j++)
		{
            if (hash_table[i][j].flags & HASH_BUILTIN)
                num_builtin++;
            else
            {
			    free(hash_table[i][j].data->data);
			    free(hash_table[i][j].data);
			    free(hash_table[i][j].key);
		    }
		}
        if (num_builtin)
            hash_depths[i] = num_builtin;
        else
        {
		    free(hash_table[i]);
		    hash_table[i]     = NULL;
		    hash_depths[i]    = 0;
		    hash_allocated[i] = 0;
	    }
	}
}
