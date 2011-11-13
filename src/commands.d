module commands;

import hash_table;
import string_utils;

// command implementations
import calculator;
import dir_ops;
import email;
import env_ops;
import file_ops;
import math_ops;
import prims;
import string_ops;

import mysql;

import core.stdc.string;

alias char* function(Data* out_string, const ref Data[] args) commfunc_args;
alias char* function(Data* out_string, const ref Data[] args, const ref Data[] params) commfunc_args_params;

enum CMD_PARAMS = 0x00000001;
enum CMD_QUOTED = 0x00000002;

struct command
{
    string name;
    int    flags;
    union
    {
        commfunc_args         c_arg;
        commfunc_args_params  c_arg_param;
    }
}

command commlist[] =
[
    { name: "calc",         flags: 0, c_arg: &guml_calculator   },
    { name: "cmode",        flags: 0, c_arg: &guml_cmode        },
    { name: "date",         flags: 0, c_arg: &guml_date         },
    { name: "dirclose",     flags: 0, c_arg: &guml_close_dir    },
    { name: "diropen",      flags: 0, c_arg: &guml_open_dir     },
    { name: "dirread",      flags: 0, c_arg: &guml_read_dir     },
    { name: "email",        flags: 0, c_arg: &guml_email       },
    { name: "environ",      flags: 0, c_arg: &guml_environ     },
    { name: "eq",           flags: 0, c_arg: &guml_eq           },
    { name: "exit",         flags: 0, c_arg: &guml_exit         },
    { name: "filedelete",   flags: 0, c_arg: &guml_file_delete  },
    { name: "fileexists",   flags: 0, c_arg: &guml_file_exists  },
    { name: "fileread",     flags: 0, c_arg: &guml_file_read    },
    { name: "filestatus",   flags: 0, c_arg: &guml_file_status  },
    { name: "filewrite",    flags: 0, c_arg: &guml_file_write   },
    { name: "fop",          flags: 0, c_arg: &guml_fop          },
    { name: "get",          flags: 0, c_arg: &guml_get          },
    { name: "htmlquote",    flags: 0, c_arg: &guml_htmlquote    },
    { name: "httpdecode",   flags: 0, c_arg: &guml_httpdecode   },
    { name: "httpencode",   flags: 0, c_arg: &guml_httpencode   },
    { name: "include",      flags: 0, c_arg: &guml_file_include },
    { name: "isdir",        flags: 0, c_arg: &guml_isdir        },
    { name: "isset",        flags: 0, c_arg: &guml_isset        },
    { name: "money",        flags: 0, c_arg: &guml_parse_money  },
    { name: "op",           flags: 0, c_arg: &guml_op           },
    { name: "rand",         flags: 0, c_arg: &guml_rand         },
    { name: "sendmail",     flags: 0, c_arg: &guml_sendmail    },
    { name: "set",          flags: 0, c_arg: &guml_set          },
//    { name: "shell",        flags: 0, c_arg: &guml_shell       },
    { name: "shutdownguml", flags: 0, c_arg: &guml_shutdownguml },
    { name: "sqlexec",      flags: 0, c_arg: &guml_sqlexec      },
    { name: "sqlquote",     flags: 0, c_arg: &guml_sqlquote     },
    { name: "sqlrow",       flags: 0, c_arg: &guml_sqlrow       },
    { name: "strcmp",       flags: 0, c_arg: &guml_strcmp       },
    { name: "strindex",     flags: 0, c_arg: &guml_index        },
    { name: "strip",        flags: 0, c_arg: &guml_strip        },
    { name: "strlength",    flags: 0, c_arg: &guml_length       },
    { name: "strlower",     flags: 0, c_arg: &guml_lower_string },
    { name: "strsoundex",   flags: 0, c_arg: &guml_soundex      },
    { name: "strtok",       flags: 0, c_arg: &guml_strtok       },
    { name: "strupper",     flags: 0, c_arg: &guml_upper_string },
    { name: "substr",       flags: 0, c_arg: &guml_substr       },
    { name: "time",         flags: 0, c_arg: &guml_time         },
    { name: "tmode",        flags: 0, c_arg: &guml_tmode        },
    { name: "unset",        flags: 0, c_arg: &guml_unset        },

    { name: "quote",        flags: CMD_QUOTED,              c_arg:       &guml_quote      },
    { name: "if",           flags: CMD_QUOTED | CMD_PARAMS, c_arg_param: &guml_if         },
    { name: "param",        flags:              CMD_PARAMS, c_arg_param: &guml_param      },
    { name: "paramcount",   flags:              CMD_PARAMS, c_arg_param: &guml_paramcount },
    { name: "while",        flags: CMD_QUOTED | CMD_PARAMS, c_arg_param: &guml_while      },
];

/+
version (USE_FILE_HANDLE_OPS)
{
    command("append",       {guml_filehandle_append},        0 },
    command("close",        {guml_filehandle_close},        0 },
    command("isopen",       {guml_filehandle_isopen},        0 },
    command("open",         {guml_filehandle_open},                0 },
    command("output",       {guml_filehandle_output},        0 },
    command("readline",     {guml_filehandle_readline},        0 },
    command("writeline",    {guml_filehandle_writeline},        0 },
}
version (USE_ORACLE)
{
    command("plsqlcall",    {guml_plsqlcall},                0 },
}
version (TUXEDO)
{
    command("tuxedo",       {guml_tuxedo},                        0 },
    command("tuxedoresults",{guml_tuxedo_results},                0 },
}
+/

void init_commands()
{
    foreach (ref c; commlist)
        insert_hash(strdup(c.name.ptr),
                    cast(Data*)(&c),
                    calc_hash(c.name.ptr),
                    HASH_BUILTIN | HASH_READONLY);
}

char* command_invoke(command* c, Data* out_string, const ref Data[] args, const ref Data[] params)
{
    if (c.flags & CMD_PARAMS)
        return (*c.c_arg_param)(out_string, args, params);
    else
        return (*c.c_arg)(out_string, args);
}

int command_wants_quoted(command* c)
{
    return c.flags & CMD_QUOTED;
}
