/* tuxedo.c */

#include <stdio.h>
#include <stdlib.h>

#include "clisrv.h"
#include "msg.hxx"
#include "fldnames.h"

#include "global.h"

extern int fatal_error;

TPMsg *msg = NULL;

/* unset a variable */
char *guml_tuxedo (Data *out_string, char *args[], int nargs)
{
	static char error_buf[1024];
	int   i;
	long  key;
	char  *w1 = NULL, *w2 = NULL;

	if (nargs == 0)
		return "\\tuxedo requires atleast one parameter.";

	msg = new TPMsg;

	// setup input parameters for tuxedo call

	i=1;
	while (i < nargs)
	{
		if (!split_string(args[i], ':', &w1, &w2))
			return "\\tuxedo -- args 2..N must be in the form key:value";

		if ((key = FieldLookUp(w1)) == -1L)
		{
			sprintf(error_buf, "\\tuxedo -- Unable to lookup key '%s'.", args[i]);
			return error_buf;
		}
		if (msg->Put(key, w2) == APP_FAIL)
		{
			sprintf(error_buf, "\\tuxedo -- Unable to add key '%s'.", args[i-1]);
			return error_buf;
		}
		i++;
	}

	// Call the service which return statement details

	if (msg->SendMsg(args[0]) == APP_FAIL)
		return "\\tuxedo -- SendMsg call failed";

	// Check the service return code

	if (tpurcode == APP_FAIL)
		return "\\tuxedo -- the service encountered an error";

	return NULL;
}

char *guml_tuxedo_results(Data *out_string, char *args[], int nargs)
{
	long msg_id, msg_size, tmp_long;
	char *tmp, *tmp_string, tmp_num_buf[64];
	int  first_field = 1, msg_type;

	if (nargs != 0)
		return "\\tuxedoresults requires no parameters";

	if (msg == NULL)
		return "\\tuxedoresults -- no pending transaction";

	msg->Restore();
	while (msg->Attributes(&msg_id, &msg_type, &msg_size))
	{
		if (first_field)
			first_field = 0;
		else
			add_char(out_string, ' ');

		tmp = FieldNameLookUp(msg_id);
		switch (msg_type)
		{
			case MSGT_STRING:
				tmp_string = (char *)malloc(msg_size);
				msg->Get(msg_id, tmp_string);
				insert_hash(strdup(tmp), create_string(tmp_string, 0), calc_hash(tmp), 0);
				add_string(out_string, tmp);
				break;
			case MSGT_DOUBLE:	// 8 byte floating point
			case MSGT_LONG:		// 4 bytes
			case MSGT_SHORT:	// 2 bytes
			case MSGT_BYTE:		// 1 byte
				msg->Get(msg_id, &tmp_long);
				sprintf(tmp_num_buf, "%ld", tmp_long);
				insert_hash(strdup(tmp), create_string(tmp_num_buf, 0), calc_hash(tmp), 0);
				add_string(out_string, tmp);
				break;
			default:
				sprintf(tmp_num_buf, "unsupported field type");
				insert_hash(strdup(tmp), create_string(tmp_num_buf, 0), calc_hash(tmp), 0);
				add_string(out_string, tmp);
				break;
		}
	}

	delete msg;
	msg = NULL;

	return NULL;
}
