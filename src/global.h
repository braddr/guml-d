/* global.h */
/* contains all relevant global settings */

#ifdef FASTCGI
#include "fcgiapp.h"
#define FPUTS(x)   FCGX_PutS(x, fcgi_out)
#define GETENV(x)  FCGX_GetParam(x, fcgi_envp)
#else
#define FPUTS(x)   fputs(x, stdout)
#define GETENV(x)  getenv(x)
#endif

#include "local.h"

#if defined(__SUNPRO_C) || defined(__SUNPRO_CC)
#define INLINE
#define srandom srand
#define random  rand
#else
#define INLINE inline
#endif

#ifdef NEED_RANDOM
extern int srandom(unsigned seed);
extern int random(void);
#endif

#define CMD_ARGS        0x00000001
#define CMD_PARAMS      0x00000002
#define CMD_QUOTED      0x00000004

#define STACK_INCREMENT 16
#define STACK_MASK      (unsigned long)(-STACK_INCREMENT)
#define HASH_WIDTH      509
#define HASH_DEPTH      16
#define HASH_MASK       (unsigned long)(-HASH_DEPTH)

#define HASH_ENV        0x00000001
#define HASH_COOKIE     0x00000002
#define HASH_FORM       0x00000004
#define HASH_ARG        0x00000008
#define HASH_ALL        0x0000001F

#define HASH_BUILTIN    0x40000000
#define HASH_READONLY   0x80000000

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

typedef char *commfunc_args(Data *out_string, char *args[], int nargs);
typedef char *commfunc_args_params(Data *out_string, char *args[], int nargs, char *params[], int nparams);

struct command {
  char *thecomm;
  union
  {
    commfunc_args        *c_arg;
    commfunc_args_params *c_arg_param;
  } cmd;
  int  cmd_flags;
};

#ifdef __cplusplus
extern "C" {
#endif

/* hash_table.h */
extern void calc_hash_increment(unsigned long *hash_value, char c);
extern void init_hash_table(void);
extern void push_stack(Data *data);
extern Data *pop_stack(void);
extern void shrink_stack(void);
extern Data *find_hash_data(char *key, unsigned long hash);
extern int  insert_hash(char *key, Data *data, unsigned long hash, unsigned long flags);
extern void delete_hash(char *key, unsigned long hash);
extern void clean_hash(unsigned long flags);
extern HashNode *find_hash_node(char *key, unsigned long hash);
extern unsigned long calc_hash(char *str);

#ifdef DEBUG_STACK
extern void stack_info(void);
#endif
#ifdef DEBUG_HASH       
extern void hash_info(void);
#endif

/* setup.c */
extern void setup_environment (int argc, char *argv[]);
#ifdef BRADDR_TESTING
extern void read_startup_config_file(void);
extern void read_per_page_hit_config_file(void);
#endif

/* string_utils.c */
extern void writelog(char *msg, ...);
extern Data *create_string(char *str, int no_dup);
extern char *strip_space (char *buffer);
extern char *rtrim (char *buffer);
extern void add_string_size(Data *s1, char *s2, unsigned long s2_len);
extern void add_string_data(Data *s1, Data *s2);
extern void add_string(Data *s1, char *s2);
extern void add_char(Data *s1, char c);
extern int  split_string(char *str, char split, char **w1, char **w2);

/* commands.c */
extern void init_commands(void);

/* engine.c */
extern void guml_backend(Data *out_string, char **ins, char *params[], int numparams);
extern void init_engine(void);
 
/* guml primitives from prims.c */
commfunc_args guml_shutdownguml;
commfunc_args guml_unset;
commfunc_args guml_htmlquote;
commfunc_args guml_get;
commfunc_args guml_set;
commfunc_args guml_quote;
commfunc_args guml_cmode;
commfunc_args guml_tmode;
commfunc_args guml_isset;
commfunc_args guml_eq;
commfunc_args guml_exit;
commfunc_args_params guml_if;
commfunc_args_params guml_while;
commfunc_args_params guml_param;
commfunc_args_params guml_paramcount;
 
/* string ops from string_ops.c */
commfunc_args guml_strtok;
commfunc_args guml_index;
commfunc_args guml_substr;
commfunc_args guml_strcmp;
commfunc_args guml_length;
commfunc_args guml_lower_string;
commfunc_args guml_soundex;
commfunc_args guml_upper_string;
commfunc_args guml_strip;
commfunc_args guml_date;
commfunc_args guml_time;
commfunc_args guml_httpencode;
commfunc_args guml_httpdecode;
commfunc_args guml_sqlquote;
 
/* file ops from file_ops.c */
commfunc_args guml_file_delete;
commfunc_args guml_file_write;
commfunc_args guml_file_read;
commfunc_args guml_file_exists;
commfunc_args guml_file_status;
commfunc_args guml_file_include;
extern void guml_file(Data *, FILE *);
 
/* additional filehandle operations from filehandle_ops.c */
commfunc_args guml_filehandle_output;
commfunc_args guml_filehandle_append;
commfunc_args guml_filehandle_writeline;
commfunc_args guml_filehandle_open;
commfunc_args guml_filehandle_close;
commfunc_args guml_filehandle_readline;
commfunc_args guml_filehandle_isopen;
int clean_filehandles(void);
 
/* math ops from math_ops.c */
commfunc_args guml_parse_money;
commfunc_args guml_rand;
commfunc_args guml_op;
commfunc_args guml_fop;
 
/* from calculator.c */
commfunc_args guml_calculator;

/* from email.c */
commfunc_args guml_email;
commfunc_args guml_sendmail;
commfunc_args guml_shell;

/* sql engine public routines */ 
#if defined(USE_SYBASE) || defined(USE_ORACLE) || defined(USE_KUBL) || defined(USE_INFORMIX) || defined (USE_MYSQL) || defined(USE_MSSQL)
#ifdef NEED_SQL_ENVIRONMENT
extern char *sql_init_environ(void);
#endif
extern char *sql_init(void);
extern char *sql_cleanup(void);
extern char *sql_shutdown(void);
commfunc_args guml_sqlexec;
commfunc_args guml_sqlrow;
#endif

#if defined(USE_ORACLE)
commfunc_args guml_plsqlcall;
#endif

/* site_specific_ops.c */
#ifdef SITE_MOLSON
commfunc_args molson_encode_password;
#endif

/* www.h */
extern char *http_decode(char *);
extern char *quote_html(char *);

/* tuxedo.h */
commfunc_args guml_tuxedo;
commfunc_args guml_tuxedo_results;

/* dir_ops.h */
commfunc_args guml_open_dir;
commfunc_args guml_read_dir;
commfunc_args guml_isdir;
commfunc_args guml_close_dir;
extern int guml_close_dir_internal();

/* env_ops.h */
commfunc_args guml_environ;

#ifdef __cplusplus
}
#endif

