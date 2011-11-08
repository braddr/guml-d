#ifndef __NEW_ENV_H
#define __NEW_ENV_H

#define STACK_INCREMENT 16
#define STACK_MASK     (unsigned long)(-STACK_INCREMENT)
#define HASH_WIDTH      509
#define HASH_DEPTH      16
#define HASH_MASK      (unsigned long)(-HASH_DEPTH)

typedef struct data_struct
{
    char *data;
    unsigned long length;
} Data;

typedef struct hash_struct
{
    Data *data;
    char *key;
    unsigned long hash;
    unsigned long flags;
} HashNode;

extern unsigned long calc_hash(char *str);
extern void init_engine(void);
extern void push_stack(Data *data);
extern Data *pop_stack(void);
extern void shrink_stack(void);
extern HashNode *find_hash_node(char *key, unsigned long hash);
extern Data *find_hash_data(char *key, unsigned long hash);
extern void insert_hash(char *key, Data *data, unsigned long hash, unsigned long flags);
extern void delete_hash(char *key, unsigned long hash);
extern void clean_hash(unsigned long flags);

#ifdef DEBUG_STACK
extern void stack_info(void);
#endif
#ifdef DEBUG_HASH
extern void hash_info(void);
#endif

#endif
