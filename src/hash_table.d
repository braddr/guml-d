module hashtable;

import string_utils;

import core.stdc.config;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

enum HASH_ENV        = 0x00000001;
enum HASH_COOKIE     = 0x00000002;
enum HASH_FORM       = 0x00000004;
enum HASH_ARG        = 0x00000008;

enum HASH_ALL        = 0x0000001F;

enum HASH_BUILTIN    = 0x40000000;
enum HASH_READONLY   = 0x80000000;

enum STACK_INCREMENT = 16;
enum STACK_MASK      = cast(size_t)(-STACK_INCREMENT);
enum HASH_WIDTH      = 509;
enum HASH_DEPTH      = 16;
enum HASH_MASK       = cast(size_t)(-HASH_DEPTH);

struct HashNode
{
    Data *data;
    Data *key;
    c_ulong hash;
    c_ulong flags;
}

Data**                stack;
size_t                stack_depth, stack_allocated, dupes, readonly;
HashNode*[HASH_WIDTH] hash_table;
uint[HASH_WIDTH]      hash_depths, hash_allocated;

void init_hash_table()
{
    stack = null;
    stack_depth = 0;
    stack_allocated = 0;

    dupes = 0;
    readonly = 0;

    memset(hash_depths.ptr,    0, HASH_WIDTH * uint.sizeof);
    memset(hash_allocated.ptr, 0, HASH_WIDTH * uint.sizeof);
    memset(hash_table.ptr,     0, HASH_WIDTH * (HashNode*).sizeof);
}

void push_stack(Data *data)
{
    if (stack_depth == stack_allocated)
    {
        stack_allocated += STACK_INCREMENT;
        stack = cast(Data**)realloc(stack, (Data*).sizeof * stack_allocated);
        if (!stack)
        {
            printf("Content-type: text/plain\n\nFatal error, unable to grow stack, bailing!!!\n");
            exit(5);
        }
    }
    stack[stack_depth++] = data;
}

Data *pop_stack()
{
    if (stack_depth)
        return stack[--stack_depth];
    else
        return null;
}

void shrink_stack()
{
    if (stack_allocated != 0)
    {
        stack_allocated = ((stack_depth & STACK_MASK) + 1) * STACK_INCREMENT;
        stack = cast(Data**)realloc(stack, (Data*).sizeof * stack_allocated);
    }
}

version (DEBUG_STACK)
{
    void stack_info()
    {
        printf("stack depth: %d\nstack allocated: %d\n", stack_depth, stack_allocated);
    }
}

version (DEBUG_HASH)
{
    void hash_info(void)
    {
        int i, j, k, min, max;

        printf("hash_size: %dx%d\ndupes: %d\ndepths used:\n", HASH_WIDTH, HASH_DEPTH, dupes);

        for (i=0, j=0, k=0, min=999999, max=0; i<HASH_WIDTH; i++)
        {
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
}

void calc_hash_increment(size_t* hash_value, char c)
{
    *hash_value = (*hash_value << 4) + c;
}

size_t calc_hash(const ref Data str)
{
    return calc_hash(str.asString);
}

size_t calc_hash(const(char)[] str)
{
    size_t hashval = 0;

    foreach(c; str)
        hashval = (hashval << 4) + c;

    return hashval;
}

HashNode *find_hash_node(const ref Data key, size_t hash)
{
    return find_hash_node(key.asString, hash);
}

HashNode *find_hash_node(const(char)[] key, size_t hash)
{
    uint bucket = hash % HASH_WIDTH;
    size_t i = 0;
    HashNode *tmp = hash_table[bucket];

    while (tmp && i < hash_depths[bucket] && tmp[i].key.asString != key)
        i++;

    if (i < hash_depths[bucket])
        return &(tmp[i]);
    else
        return null;
}

Data *find_hash_data(const ref Data key, size_t hash)
{
    return find_hash_data(key.asString, hash);
}

Data *find_hash_data(const(char)[] key, size_t hash)
{
    HashNode *tmp = find_hash_node(key, hash);

    if (tmp)
        return tmp.data;
    else
        return null;
}

int insert_hash(Data *key, Data *data, size_t hash, c_ulong flags)
{
    HashNode *tmp_node = find_hash_node(key.asString, hash);
    if (tmp_node)
    {
        if (tmp_node.flags & HASH_READONLY)
        {
            readonly++;
            return 1;
        }
        key.reset();
        free(key);
        tmp_node.data.reset();
        free(tmp_node.data);
        dupes++;
    }
    else
    {
        uint bucket = hash % HASH_WIDTH;
        if (hash_depths[bucket] == hash_allocated[bucket])
        {
            hash_allocated[bucket] += HASH_DEPTH;
            hash_table[bucket] = cast(HashNode*)realloc(hash_table[bucket], hash_allocated[bucket]*(HashNode).sizeof);
            if (!hash_table[bucket])
            {
                printf("Content-type: text/plain\n\nError growing hash table, bailing!\n");
                exit(6);
            }
        }
        tmp_node = &(hash_table[bucket][hash_depths[bucket]]);
        tmp_node.key = key;
        tmp_node.hash = hash;
        ++(hash_depths[bucket]);
    }
    tmp_node.data = data;
    tmp_node.flags = flags;
    return 0;
}

void delete_hash(const ref Data key, size_t hash)
{
    delete_hash(key.asString, hash);
}

void delete_hash(string key, size_t hash)
{
    uint bucket = hash % HASH_WIDTH;
    size_t i = 0;
    HashNode *tmp = hash_table[bucket];

    while (tmp && i < hash_depths[bucket] && tmp[i].key.asString != key)
        i++;

    if (i < hash_depths[bucket] && !(hash_table[bucket][i].flags & HASH_READONLY))
    {
        hash_table[bucket][i].data.reset();
        free(hash_table[bucket][i].data);
        hash_table[bucket][i].key.reset();
        free(hash_table[bucket][i].key);
        hash_depths[bucket]--;
        memcpy(&(hash_table[bucket][i]), &(hash_table[bucket][hash_depths[bucket]]), HashNode.sizeof);
    }
}

// Warning, this code assumes that all the builtin's are first in the hash buckets
void clean_hash(c_ulong flags)
{
    for (size_t i=0; i<HASH_WIDTH; i++)
    {
        uint num_builtin = 0;
        for (size_t j=0; j<hash_depths[i]; j++)
        {
            if (hash_table[i][j].flags & HASH_BUILTIN)
            {
                if (flags & HASH_BUILTIN)
                {
                    hash_table[i][j].key.reset();
                    free(hash_table[i][j].key);
                }
                else
                    num_builtin++;
            }
            else
            {
                hash_table[i][j].data.reset();
                free(hash_table[i][j].data);
                hash_table[i][j].key.reset();
                free(hash_table[i][j].key);
            }
        }
        if (num_builtin)
            hash_depths[i] = num_builtin;
        else
        {
            free(hash_table[i]);
            hash_table[i]     = null;
            hash_depths[i]    = 0;
            hash_allocated[i] = 0;
        }
    }
}
