/* oracle.c */
/* interface into icky oracle land */

#ifdef USE_ORACLE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include <oratypes.h>
#include <ocidfn.h>
#include <ociapr.h>
#include <ocidem.h>

#include "global.h"

#define OCI_MORE_INSERT_PIECES -3129 /* for osetpi() */

#define MAX_SELECT_LIST        100 /* safety net */

#define PARSE_NO_DEFER           0
#define PARSE_V7_LNG             2

 /* oparse flags */
#define DEFER_PARSE 1
#define VERSION_7 2
 
#define NPOS 16
#define DSCLEN 240

struct describe
{
	sb4				dbsize;
	sb2				dbtype;
	sb1				buf[33];
	sb4				buflen;
	sb4				dsize;
	sb2				precision;
	sb2				scale;
	sb2				nullok;
};
 
struct define
{
	ub1				*buf;
	sb2				indp;
	ub2				col_retlen, col_retcode;
};

#define DYNAMIC_COLS

#ifdef DYNAMIC_COLS
struct describe *desc = NULL;
struct define	*def  = NULL;
#else
struct describe desc[100];
struct define	def [100];
#endif

extern int free_err_res;
int numcols = 0;

Lda_Def lda;
Cda_Def return_cursor;
int return_open=0;
ub4		hda[HDA_SIZE/4];

int sql_initted = 0;
Data cmd = { NULL, 0 };

#define LONG_BUFSIZE 8192
ub1 *long_buf = NULL;

#ifdef NEED_SQL_ENVIRONMENT
char *sql_init_environ(void)
{
  putenv("ORACLE_HOME=" DB_ROOT);
  putenv("ORACLE_SID=" DB_HOST);
  putenv("TNS_ADMIN=" ORAADMIN);

  return NULL;
}
#endif

char *cursor_error(Cda_Def *cda) {
  text msg[512];
  sword n;
  Data err_msg = {NULL, 0};

  add_string_size(&err_msg, "-- ORACLE ERROR --\n", 19);
  n = oerhms(&lda, cda->rc, msg, (sword) sizeof(msg));
  msg[n] = '\0';
  add_string(&err_msg, msg);
  add_char(&err_msg, '\n');
  oclose(cda);
  return err_msg.data;
}


char *oci_error(Cda_Def *cda) {
  text msg[512];
  sword n;
  Data err_msg = { NULL, 0 };

  add_string_size(&err_msg,"-- ORACLE ERROR --\n",19);
  n = oerhms(&lda, cda->rc, msg, (sword) sizeof (msg));
  msg[n] = '\0';
  add_string(&err_msg,msg);
  add_char(&err_msg,'\n');
  add_string_size(&err_msg,"Processing OCI function ",24);
  add_string(&err_msg,oci_func_tab[cda->fc]);
  add_char(&err_msg,'\n');
  if (cmd.data != NULL) {
	add_string_data(&err_msg,&cmd);
	add_char(&err_msg,'\n');
  }
  if (cda != &return_cursor) {
    writelog("Closing a temp cursor in oci_error");
    if (oclose(cda)) {
      writelog("Closing of temp cursor from oci_error failed!");
    }
  }
  return err_msg.data;
}

/* loggin in to server */
char *sql_init()
{
  text username[132];

#ifndef LOG_ONLY_ERRORS
  writelog("Start connecting to oracle");
#endif

  sprintf (username, "%s/%s@%s", DB_USERID, DB_PASSWORD, DB_DB);

  if (olog(&lda, (ub1*)hda, username, -1, (text*)0, -1, (text*)0, -1, OCI_LM_DEF)){
	free_err_res = 2;
	return oci_error(&lda);
  }

  sql_initted = 1;

#ifndef LOG_ONLY_ERRORS
  writelog("Done connecting to oracle");
#endif

  return NULL;
}

/* log out from server */
char *sql_shutdown()
{
  if(long_buf!=NULL) {
	free(long_buf);
	long_buf=NULL;
  }

  if (!sql_initted) return NULL;

  if (ologof(&lda))
    return "Error logging off!\n";

  return NULL;
}

char *describe_define(Cda_Def *cda) {
  int col = 0, col2 = 0, size;

  if (numcols != 0) {
	int i;
	for(i = 0; i < numcols; i++) {
	  if(desc[i].dbtype!=SQLT_LNG) free(def[i].buf);
	}
#ifdef DYNAMIC_COLS
	free(def);
	free(desc);
	def  = NULL;
	desc = NULL;
#endif
	numcols = 0;
  }

  /* Describe the select-list items. */
  for (col = 0; col < MAX_SELECT_LIST; col++) {
#ifdef DYNAMIC_COLS
	if (col == 0)
	  desc = malloc(sizeof(struct describe));
	else
	  desc = realloc(desc, sizeof(struct describe) * (col+1));
#endif
	desc[col].buflen = 33;
	if (odescr(cda, col + 1, &desc[col].dbsize,
			   &desc[col].dbtype, desc[col].buf,
			   &desc[col].buflen, &desc[col].dsize,
			   &desc[col].precision, &desc[col].scale,
			   &desc[col].nullok)) {
	  /* Break on end of select list. */
	  if (cda->rc == VAR_NOT_IN_LIST)
		break;
	  else {
		numcols = 0;
#ifdef DYNAMIC_COLS
		free(desc);
		def = NULL;
		desc = NULL;
#endif
		free_err_res = 2;
		return oci_error(cda);
	  }
	}
  }

#ifdef DYNAMIC_COLS
  def = malloc(sizeof(struct define) * (col+1));
#endif
  for (col2 = 0; col2 < col; col2++) {

/* fprintf(tmplog,"described: col: %d  dsize: %d  dbsize: %d  dbtype: %d\n",
	col2, desc[col2].dsize, desc[col2].dbsize, desc[col2].dbtype); */

  /* note that we don't deal w/ binary types (24) */

    if(desc[col2].dbtype==SQLT_LNG) {
	  if(long_buf==NULL)
		long_buf=malloc(LONG_BUFSIZE+1); /* test?? */
	  odefin(cda, col2+1, long_buf, LONG_BUFSIZE, STRING_TYPE, -1, &def[col2].indp, 0, 0, -1, 0, 0);
	}
	else {
	  size = desc[col2].dsize+1;
	  def[col2].buf = malloc(size);
	  memset(def[col2].buf, 0, size);
	  if (odefin(cda, col2 + 1, def[col2].buf, size, STRING_TYPE,
				 -1, &def[col2].indp, (text *) 0, -1, -1,
				 &def[col2].col_retlen, &def[col2].col_retcode)) {
		int i;
		for(i = 0; i < col2; i++)
		  if (desc[i].dbtype != SQLT_LNG)
		    free(def[i].buf);
		numcols = 0;
#ifdef DYNAMIC_COLS
		free(def);
		free(desc);
		def = NULL;
		desc = NULL;
#endif
		free_err_res = 2;
		return oci_error(cda);
	  }
	}
  }

  numcols = col;

  return NULL;
}

/* guml interface for calling PL/SQL stored procedures */
char *guml_plsqlcall(Data *out_string, char *args[], int nargs) {
  int pl, in_literal, n;
  char *idx, *ph;
  Cda_Def tmpcurs;
  char tmpchr;
  char *dd_err_msg;

  ub2 col_rcode;
  char *context = "context pointer";
/*  ub1 piece;
  ub4 iteration;
  ub4 plsqltable; */
  ub4 buflength;

#ifndef LOG_ONLY_ERRORS
  writelog("Start plsql call");
#endif

  if(!sql_initted) sql_init();
  else if(return_open) {
	if (oclose(&return_cursor)) {
	  free_err_res = 2;
	  return oci_error(&return_cursor);
	}
	return_open=0;
  }

  /* disgusting workaround for oracle's apalling lameness:
	 first arg is a cursor structure which returns result set.
	 we put the :retcurs in there ourselves and put it in a
	 begin/end block.  rrrrgh */

  for(idx=args[0]; *idx!='('&&*idx!='\0'; idx++) ;
  tmpchr=*idx;
  *idx='\0';

  add_string_size(&cmd,"BEGIN\n",6);
  add_string(&cmd,args[0]);
  add_string_size(&cmd,"(:retcurs",9);
  if(tmpchr!='\0'&&*(idx+1)!=')') add_char(&cmd,',');
  if(tmpchr!='\0') add_string(&cmd,idx+1);
  add_string_size(&cmd,"\nEND;\n",6);

  *idx=tmpchr;

  if (oopen(&tmpcurs, &lda, (text *) 0, -1, -1, (text *) 0, -1)) {
	ologof(&lda);
	return cursor_error(&tmpcurs);
	return "Error opening temp database cursor!\n";
  }
  if (oopen(&return_cursor, &lda, (text *) 0, -1, -1, (text *) 0, -1)) {
	ologof(&lda);
	return "Error opening return database cursor!\n";
  }
  return_open=1;

  if(oparse(&tmpcurs, (text *)(cmd.data), (sb4) -1,
            (sword) PARSE_NO_DEFER, (ub4) PARSE_V7_LNG)) {
    free(cmd.data);
    cmd.data = NULL;
	cmd.length = 0;
	free_err_res = 2;
    return oci_error(&tmpcurs);
  }

  /* bind that return cursor, white boy */
  if(obndra(&tmpcurs, (text *) ":retcurs", -1, (ub1 *) &return_cursor, 
            -1, SQLT_CUR, -1, (sb2 *) 0, (ub2 *) 0, (ub2 *) 0,
            (ub4) 0, (ub4 *) 0, (text *) 0, 0, 0)) {
    free(cmd.data);
    cmd.data = NULL;
	cmd.length = 0;
	free_err_res = 2;
	return oci_error(&tmpcurs);
  }

  /* here's more evidence of oracle's supreme suckiness: can't bind in
	 long data types longer than 3784 characters (!?) directly.  or can we?
	 documentation is self-contradictory on this..

	 anyway, obindps()/ogetpi()/osetpi() is bound (ha.) to work..

	 only *one* in-bound variable allowed.  sorry, but that's oracle's fault..
  */

  pl=1;

  for(in_literal=FALSE; *idx!='\0' && pl==1; idx++) {
	if(*idx=='\'') in_literal = ~in_literal;
	if(*idx==':' && !in_literal) {
	  for(ph=idx++, n=0; *idx && (isalnum(*idx)||*idx=='_') && n<31; idx++, n++) ;
	  tmpchr=*idx;
	  *idx='\0';
	  if(strlen(ph+1)) { /* skip the : */

		if (obindps(&tmpcurs, 0, (text *)ph, strlen(ph),
					(ub1 *)context, 999999999, /* <-- ?? */
					SQLT_LNG, (sword)0, (sb2 *)0,
					(ub2 *)0, &col_rcode, 0, 0, 0, 0,
					0, (ub4 *)0, (text *)0, 0, 0)) {

		  free(cmd.data);
		  cmd.data = NULL;
		  cmd.length = 0;
		  free_err_res = 2;
		  return oci_error(&tmpcurs);
		}
		pl++;
	  }
	  *idx=tmpchr;
	}
  }

  if(pl>1) {
	if (oexec(&tmpcurs)) {
	  if(-tmpcurs.rc == OCI_MORE_INSERT_PIECES) {
		buflength=(ub4)strlen(args[1]);
		if(osetpi(&tmpcurs, OCI_LAST_PIECE, args[1], &buflength) ) {
		  free(cmd.data);
		  cmd.data = NULL;
		  cmd.length = 0;
		  free_err_res = 2;
		  return oci_error(&tmpcurs);
		}
	  }
	  else {
		free(cmd.data);
		cmd.data = NULL;
		cmd.length = 0;
		free_err_res = 2;
		return oci_error(&tmpcurs);
	  }
	}
  }

  if (oexec(&tmpcurs)) {
	free(cmd.data);
	cmd.data = NULL;
	cmd.length = 0;
	free_err_res = 2;
	return oci_error(&tmpcurs);
  }

  /* attempt describe_define on return cursor */
  if((dd_err_msg = describe_define(&return_cursor)) != NULL) {
	free(cmd.data);
	cmd.data = NULL;
	cmd.length = 0;
	return dd_err_msg;
  }

  /* Close the cursor on which the PL/SQL block executed. */
  if (oclose(&tmpcurs)) {
	free(cmd.data);
	cmd.data = NULL;
	cmd.length = 0;
	free_err_res = 2;
	return oci_error(&tmpcurs);
  }

  ocom(&lda);  /* oracle's afraid of committment.  ha. */

  free(cmd.data);
  cmd.data = NULL;
  cmd.length = 0;

#ifndef LOG_ONLY_ERRORS
  writelog("Done with plsqlcall");
#endif

  return NULL;
}

/* guml interface for SQL */
char *guml_sqlexec(Data *out_string, char *args[], int nargs)
{
  int sql_function;
  int pl, in_literal, n;
  char *idx, *ph;
  char tmpchr;
  char *dd_err_msg;

  ub2 col_rcode;
  char *context = "context pointer";
/*  ub1 piece;
  ub4 iteration;
  ub4 plsqltable; */
  ub4 buflength;

#ifndef LOG_ONLY_ERRORS
  writelog("Starting sqlexec");
#endif

  if(!sql_initted) sql_init();
  else if(return_open) {
	if (oclose(&return_cursor)) {
	  free_err_res = 2;
	  return oci_error(&return_cursor);
	}
	return_open = 0;
  }

  if (oopen(&return_cursor, &lda, (text *) 0, -1, -1, (text *) 0, -1)) {
	ologof(&lda);
	return "Error opening database cursor!";
  }
  return_open=1;

  if(cmd.data!=NULL) {
	free(cmd.data);
  }

  cmd.data = strdup(args[0]);
  cmd.length = strlen(args[0])+1;

  if (oparse(&return_cursor, (text *) args[0], (sb4) -1,
            (sword) PARSE_NO_DEFER, (ub4) PARSE_V7_LNG)) {
	free(cmd.data);
	cmd.data = NULL;
	cmd.length = 0;
	free_err_res = 2;
    return oci_error(&return_cursor);
  }

  sql_function = return_cursor.ft;

  if (sql_function == FT_SELECT)
    if ((dd_err_msg = describe_define(&return_cursor)) != NULL) {
	  free(cmd.data);
      cmd.data = NULL;
	  cmd.length = 0;
      return dd_err_msg;
    }

  pl=1;

  for(in_literal=FALSE, idx=args[0]; *idx!='\0' && pl==1; idx++) {
	if(*idx=='\'') in_literal = ~in_literal;
	if(*idx==':' && !in_literal) {
	  for(ph=idx++, n=0; *idx && (isalnum(*idx)||*idx=='_') && n<31; idx++, n++) ;
	  tmpchr=*idx;
	  *idx='\0';
	  if(strlen(ph+1)) { /* skip the : */

		if (obindps(&return_cursor, 0, (text *)ph, strlen(ph),
					(ub1 *)context, 999999999, /* <-- ?? */
					SQLT_LNG, (sword)0, (sb2 *)0,
					(ub2 *)0, &col_rcode, 0, 0, 0, 0,
					0, (ub4 *)0, (text *)0, 0, 0)) {

		  free(cmd.data);
		  cmd.data = NULL;
		  cmd.length = 0;
		  free_err_res = 2;
		  return oci_error(&return_cursor);
		}
		pl++;
	  }
	  *idx=tmpchr;
	}
  }

  if(pl>1) {
	if (oexec(&return_cursor)) {
	  if(-return_cursor.rc == OCI_MORE_INSERT_PIECES) {

		buflength=(ub4)strlen(args[1]);
		if(osetpi(&return_cursor, OCI_LAST_PIECE, args[1], &buflength) ) {
		  free(cmd.data);
		  cmd.data = NULL;
		  cmd.length = 0;
		  free_err_res = 2;
		  return oci_error(&return_cursor);
		}

	  }
	  else {
		free(cmd.data);
		cmd.data = NULL;
		cmd.length = 0;
		free_err_res = 2;
		return oci_error(&return_cursor);
	  }
	}
  }

  if (oexec(&return_cursor)) {
	free(cmd.data);
	cmd.data = NULL;
	cmd.length = 0;
	free_err_res = 2;
	return oci_error(&return_cursor);
  }

  ocom(&lda);  /* commit THIS, sucka */

  free(cmd.data);
  cmd.data = NULL;
  cmd.length = 0;

#ifndef LOG_ONLY_ERRORS
  writelog("Done with sqlexec");
#endif

  return NULL;
}

/* get a row of returned data */
char *guml_sqlrow(Data *out_string, char *args[], int nargs)
{
    int col;
    sb4 off;
    ub4 retlen;
    Data bigbuf = { NULL, 0 };

    if (!sql_initted)
        return "\\sqlrow -- you must be executing a script first!";

    /* Fetch a row.  Break on end of fetch, disregard null fetch "error". */

    if (ofetch(&return_cursor))
    {
        if (return_cursor.rc == NO_DATA_FOUND)
        {
            for(col = 0; col < numcols; col++)
                if (desc[col].dbtype!=SQLT_LNG && def[col].buf!=NULL)
                    free(def[col].buf);
#ifdef DYNAMIC_COLS
            free(def);
            free(desc);
            def = NULL;
            desc = NULL;
#endif
            if (oclose(&return_cursor))
            {
                free_err_res = 2;
                return oci_error(&return_cursor);
            }
            return_open=0;
            numcols = 0;
        }
	else if (return_cursor.rc != NULL_VALUE_RETURNED)
        {
            free_err_res = 2;
            return oci_error(&return_cursor);
        }
        return NULL;
    }

    for (col = 0; col<numcols; col++)
    {
        if(desc[col].dbtype!=SQLT_LNG)
        {
            if(col<nargs)
                insert_hash(strdup(args[col]), create_string(rtrim(def[col].buf), 0), calc_hash(args[col]), 0);
        }
        else
        {
            if (!long_buf)
                return "\\sqlrow -- long_buf should have been allocated by describe_define!";

            bigbuf.data = NULL;
            bigbuf.length = 0;
            for(off=0,retlen=1;retlen>0;off+=LONG_BUFSIZE)
            {
                oflng(&return_cursor,col+1,long_buf,LONG_BUFSIZE,1,&retlen,off);
                long_buf[retlen]='\0';

                if (col >= nargs) /* stop oflng'ing if we're not storing the value */
                    break;

                if (retlen > 0)
                    add_string(&bigbuf,long_buf);
            }

            if (col < nargs)
            {
                if (!bigbuf.data)
                    insert_hash(strdup(args[col]), create_string("", 0), calc_hash(args[col]), 0);
                else
                {
                    insert_hash(strdup(args[col]), create_string(bigbuf.data, 1), calc_hash(args[col]), 0);
                    bigbuf.data = NULL;
                    bigbuf.length = 0;
                }
            }
            else if (bigbuf.data != NULL)
            {
                free(bigbuf.data);
                bigbuf.data = NULL;
                bigbuf.length = 0;
            }
        }
    }

    add_string_size(out_string,"true",4);

    return NULL;
}

/* end */

#endif
