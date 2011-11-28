/* $Id$ */

/*
 *  Copyright (c) 2003-2006 Axel Andersson
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *  1. Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include "config.h"

#include <sys/types.h>
#include <sys/param.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <math.h>
#include <errno.h>
#include <openssl/sha.h>
#include <wired/wired.h>

static void					usage(void);


int main(int argc, const char **argv) {
	wi_pool_t		*pool;
	wi_string_t		*sha1;
	unsigned char	value;
	const char		*file;
	char			ch, login[32], password[32];
	int				fd, flags[42], i, lowbit, highbit, err = 0;

	wi_initialize();
	wi_load(argc, argv);

	pool		= wi_pool_init(wi_pool_alloc());
	wi_log_tool	= true;
	
	while((ch = getopt(argc, (char * const *) argv, "h")) != -1) {
		switch(ch) {
			case 'h':
			case '?':
			default:
				usage();
				break;
		}
	}

	argc -= optind;
	argv += optind;
	
	if(argc < 1)
		usage();

	while((file = *argv++)) {
		fd = -1;
		memset(flags, 0, sizeof(flags));

		fd = open(file, O_RDONLY);

		if(fd < 0) {
			wi_log_err(WI_STR("%s: %s"), file, strerror(errno));

			goto err;
		}

		for(i = 0; i < 41; i++) {
			lowbit = i % 8;
			highbit = i / 8;

			if(lseek(fd, 4 + highbit, SEEK_SET) < 0) {
				wi_log_err(WI_STR("%s: %s"), file, strerror(errno));

				goto err;
			}

			if(read(fd, &value, 1) < 0) {
				wi_log_err(WI_STR("%s: %s"), file, strerror(errno));

				goto err;
			}

			if((unsigned char) (256 / pow(2, lowbit + 1)) & value)
				flags[i] = 1;
		}

		if(lseek(fd, 666, SEEK_SET) < 0) {
			wi_log_err(WI_STR("%s: %s"), file, strerror(errno));

			goto err;
		}

		if(read(fd, &login, sizeof(login)) < 0) {
			wi_log_err(WI_STR("%s: %s"), file, strerror(errno));

			goto err;
		}

		if(lseek(fd, 702, SEEK_SET) < 0) {
			wi_log_err(WI_STR("%s: %s"), file, strerror(errno));

			goto err;
		}

		if(read(fd, &password, sizeof(password)) < 0) {
			wi_log_err(WI_STR("%s: %s"), file, strerror(errno));

			goto err;
		}

		/* "decrypt" */
		for(i = 0; i < (int) strlen(password); i++)
			password[i] = 255 - password[i];

		sha1 = wi_string_sha1(wi_string_with_cstring(password));

		printf("%s:%s:%s:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%s\n",
			login,						/* name */
			wi_string_cstring(sha1),	/* password */
			"",							/* group */
			flags[24],					/* get user info */
			flags[32],					/* broadcast */
			flags[21],					/* post news */
			flags[33],					/* clear news */
			flags[2],					/* download */
			flags[1],					/* upload */
			flags[25],					/* upload anywhere */
			flags[5],					/* create folders */
			flags[4],					/* alter files */
			flags[0],					/* delete files */
			flags[30],					/* view drop boxes */
			flags[14],					/* create accounts */
			flags[17],					/* edit accounts */
			flags[15],					/* delete accounts */
			flags[22],					/* kick users */
			flags[22],					/* ban users */
			flags[23],					/* cannot be kicked */
			0,							/* download speed limit */
			0,							/* upload speed limit */
			0,							/* download limit */
			0,							/* upload limit */
			0,	   						/* set topic */
			"");						/* files root */

		goto next;

err:
		err = 1;

next:
		if(fd > 0)
			close(fd);
	}

	wi_release(pool);

	return err;
}



static void usage(void) {
	fprintf(stderr,
"Usage: hl2wired account/UserData\n\
       hl2wired account/UserData >> %s/users\n\
       hl2wired */UserData >> %s/users\n\
\n\
By Axel Andersson <%s>\n", WD_ROOT, WD_ROOT, WD_BUGREPORT);

	exit(2);
}
