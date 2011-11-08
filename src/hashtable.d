module hashtable;

enum HASH_ENV      = 0x00000001;
enum HASH_COOKIE   = 0x00000002;
enum HASH_FORM     = 0x00000004;
enum HASH_ARG      = 0x00000008;

enum HASH_ALL      = 0x0000001F;

enum HASH_BUILTIN  = 0x40000000;
enum HASH_READONLY = 0x80000000;
