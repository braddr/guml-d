#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "global.h"

int num_commands = 0;
/* *INDENT-OFF* */
/* function list, sorted (roughly) by frequency of use */
struct command commlist[] =
{
#ifdef USE_FILE_HANDLE_OPS
    {"append",		{guml_filehandle_append},	CMD_ARGS },
#endif
    {"calc",		{guml_calculator},		CMD_ARGS },
#ifdef USE_FILE_HANDLE_OPS
    {"close",		{guml_filehandle_close},	CMD_ARGS },
#endif
    {"cmode",		{guml_cmode},			CMD_ARGS },
    {"date",		{guml_date},			CMD_ARGS },
    {"dirclose",        {guml_close_dir},               CMD_ARGS },
    {"diropen",         {guml_open_dir},                CMD_ARGS },
    {"dirread",         {guml_read_dir},                CMD_ARGS },
    {"email",		{guml_email},			CMD_ARGS },
#ifdef SITE_MOLSON
    {"encodepassword",	{molson_encode_password},	CMD_ARGS },
#endif
    {"environ",		{guml_environ},			CMD_ARGS },
    {"eq",		{guml_eq},			CMD_ARGS },
    {"exit",		{guml_exit},			CMD_ARGS },
    {"filedelete",	{guml_file_delete},		CMD_ARGS },
    {"fileexists",	{guml_file_exists},		CMD_ARGS },
    {"fileread",	{guml_file_read},		CMD_ARGS },
    {"filestatus",	{guml_file_status},		CMD_ARGS },
    {"filewrite",	{guml_file_write},		CMD_ARGS },
    {"fop",		{guml_fop},			CMD_ARGS },
    {"get",		{guml_get},			CMD_ARGS },
    {"htmlquote",	{guml_htmlquote},		CMD_ARGS },
    {"httpdecode",	{guml_httpdecode},		CMD_ARGS },
    {"httpencode",	{guml_httpencode},		CMD_ARGS },
    {"if",		{.c_arg_param = guml_if},	CMD_ARGS | CMD_PARAMS | CMD_QUOTED },
    {"include",		{guml_file_include},		CMD_ARGS },
#ifdef USE_FILE_HANDLE_OPS
    {"isopen",		{guml_filehandle_isopen},	CMD_ARGS },
#endif
    {"isdir",		{guml_isdir},			CMD_ARGS },
    {"isset",		{guml_isset},			CMD_ARGS },
    {"money",		{guml_parse_money},		CMD_ARGS },
    {"op",		{guml_op},			CMD_ARGS },
#ifdef USE_FILE_HANDLE_OPS
    {"open",		{guml_filehandle_open},		CMD_ARGS },
    {"output",		{guml_filehandle_output},	CMD_ARGS },
#endif
    {"param",		{.c_arg_param = guml_param},	CMD_ARGS | CMD_PARAMS },
    {"paramcount",	{.c_arg_param = guml_paramcount}, CMD_ARGS | CMD_PARAMS },
#ifdef USE_ORACLE
    {"plsqlcall",	{guml_plsqlcall},		CMD_ARGS },
#endif
    {"quote",		{guml_quote},			CMD_ARGS | CMD_QUOTED },
    {"rand",		{guml_rand},			CMD_ARGS },
#ifdef USE_FILE_HANDLE_OPS
    {"readline",	{guml_filehandle_readline},	CMD_ARGS },
#endif
    {"sendmail",	{guml_sendmail},		CMD_ARGS },
    {"set",		{guml_set},			CMD_ARGS },
    {"shell",		{guml_shell},			CMD_ARGS },
    {"shutdownguml",	{guml_shutdownguml},		CMD_ARGS },
#if defined(USE_SYBASE) || defined(USE_ORACLE) || defined(USE_KUBL) || defined(USE_INFORMIX) || defined (USE_MYSQL) || defined(USE_MSSQL)
    {"sqlexec",		{guml_sqlexec},			CMD_ARGS },
    {"sqlrow",		{guml_sqlrow},			CMD_ARGS },
#endif
    {"sqlquote",	{guml_sqlquote},		CMD_ARGS },
    {"strcmp",          {guml_strcmp},                  CMD_ARGS },
    {"strindex",	{guml_index},			CMD_ARGS },
    {"strip",		{guml_strip},			CMD_ARGS },
    {"strlength",	{guml_length},			CMD_ARGS },
    {"strlower",	{guml_lower_string},		CMD_ARGS },
    {"strsoundex",	{guml_soundex},			CMD_ARGS },
    {"strtok",		{guml_strtok},			CMD_ARGS },
    {"strupper",	{guml_upper_string},		CMD_ARGS },
    {"substr",		{guml_substr},			CMD_ARGS },
    {"time",		{guml_time},			CMD_ARGS },
    {"tmode",		{guml_tmode},			CMD_ARGS },
#ifdef TUXEDO
    {"tuxedo",		{guml_tuxedo},			CMD_ARGS },
    {"tuxedoresults",	{guml_tuxedo_results},		CMD_ARGS },
#endif
    {"unset",		{guml_unset},			CMD_ARGS },
    {"while",		{.c_arg_param = guml_while},	CMD_ARGS | CMD_PARAMS | CMD_QUOTED },
#ifdef USE_FILE_HANDLE_OPS
    {"writeline",	{guml_filehandle_writeline},	CMD_ARGS },
#endif

    {NULL, {NULL}, 0}
};
/* *INDENT-OFF* */

void init_commands(void)
{
    int i;
     
    for (i = 0; commlist[i].thecomm != NULL; i++)
        insert_hash(strdup(commlist[i].thecomm), (Data*)(&commlist[i]), calc_hash(commlist[i].thecomm),
                    HASH_BUILTIN | HASH_READONLY);
}

char* command_invoke(struct command* c, Data* out_string, char** args, int nargs, char**params, int nparams)
{
    if (c->cmd_flags & CMD_ARGS)
        if (c->cmd_flags & CMD_PARAMS)
            return (*c->cmd.c_arg_param)(out_string, args, nargs, params, nparams);
        else
            return (*c->cmd.c_arg)(out_string, args, nargs);
    else
        return "Unknown function type, no args or params";
}

int command_wants_quoted(struct command* c)
{
    return c->cmd_flags & CMD_QUOTED;
}
