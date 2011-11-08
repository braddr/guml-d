#ifndef __SQL_H
#define __SQL_H

typedef struct blobstuff_s_
{
    char *pointer;
    long buffsize;
} blobstuff_s;

extern int sql_init_environ();
extern char *sql_shutdown();

#ifdef USE_INFORMIX
extern int blobopen(char *name, blobstuff_s *blob);
#endif

#endif __SQL_H
