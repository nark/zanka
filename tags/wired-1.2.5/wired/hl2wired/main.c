/* $Id$ */

/*
 *  Copyright (c) 2003-2004 Axel Andersson
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

#include <sys/types.h>
#include <sys/param.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <math.h>
#include <err.h>
#include <errno.h>
#include <openssl/sha.h>

#include "config.h"


void usage(void);


int main(int argc, char *argv[]) {
	SHA_CTX					c;
	static unsigned char	hex[] = "0123456789abcdef";
	unsigned char			value, sha[SHA_DIGEST_LENGTH], sha_password[SHA_DIGEST_LENGTH * 2 + 1];
	char					*file, ch, login[32], password[32];
	int						fd, flags[42], i, lowbit, highbit, err = 0;
	
	/* parse options */
	while((ch = getopt(argc, argv, "h")) != -1) {
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
	
	/* loop over files */
	while((file = *argv++)) {
		/* reset */
		fd = -1;
		memset(flags, 0, sizeof(flags));
		memset(sha_password, 0, sizeof(sha_password));
	
		/* open for reading */
		fd = open(file, O_RDONLY);
		
		if(fd < 0) {
			warn("%s", file);
			
			goto err;
		}
		
		/* there are 41 boolean flags */
		for(i = 0; i < 41; i++) {
			lowbit = i % 8;
			highbit = i / 8;
			
			/* skip 4 bytes and seek to the byte we're looking at */
			if(lseek(fd, 4 + highbit, SEEK_SET) < 0) {
				warn("%s", file);
				
				goto err;
			}
			
			/* read this byte */
			if(read(fd, &value, 1) < 0) {
				warn("%s", file);
				
				goto err;
			}
			
			if((unsigned char) (256 / pow(2, lowbit + 1)) & value)
				flags[i] = 1;
		}
		
		/* login name at static position */
		if(lseek(fd, 666, SEEK_SET) < 0) {
			warn("%s", file);
			
			goto err;
		}
		
		/* read login name */
		if(read(fd, &login, sizeof(login)) < 0) {
			warn("%s", file);
			
			goto err;
		}
		
		/* password at static position */
		if(lseek(fd, 702, SEEK_SET) < 0) {
			warn("%s", file);
			
			goto err;
		}
		
		/* read password */
		if(read(fd, &password, sizeof(password)) < 0) {
			warn("%s", file);
			
			goto err;
		}
		
		/* "decrypt" */
		for(i = 0; i < (int) strlen(password); i++)
			password[i] = 255 - password[i];

		if(strlen(password) > 0) {
			/* checksum decrypted password */
			SHA1_Init(&c);
			SHA1_Update(&c, password, strlen(password));
			SHA1_Final(sha, &c);
			
			/* map into hexadecimal */
			for(i = 0; i < SHA_DIGEST_LENGTH; i++) {
				sha_password[i+i]	= hex[sha[i] >> 4];
				sha_password[i+i+1]	= hex[sha[i] & 0x0F];
			}
		}
		
		/* print in wired format on stdout */
		printf("%s:%s:%s:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d\n",
			login,			/* name */
			sha_password,	/* password */
			"",				/* group */
			flags[24],		/* get user info */
			flags[32],		/* broadcast */
			flags[21],		/* post news */
			flags[33],		/* clear news */
			flags[2],		/* download */
			flags[1],		/* upload */
			flags[25],		/* upload anywhere */
			flags[5],		/* create folders */
			flags[4],		/* alter files */
			flags[0],		/* delete files */
			flags[30],		/* view drop boxes */
			flags[14],		/* create accounts */
			flags[17],		/* edit accounts */
			flags[15],		/* delete accounts */
			flags[22],		/* kick users */
			flags[22],		/* ban users */
			flags[23],		/* cannot be kicked */
			0,				/* download speed limit */
			0,				/* upload speed limit */
			0,				/* download limit */
			0,				/* upload limit */
			0);				/* set topic */
			
		goto next;

err:
		err = 1;

next:
		if(fd > 0)
			close(fd);
	}

	return err;
}



void usage(void) {
	fprintf(stderr,
"Usage: hl2wired account/UserData\n\
       hl2wired account/UserData >> %s/users\n\
       hl2wired */UserData >> %s/users\n\
\n\
By Axel Andersson <%s>\n", WD_ROOT, WD_ROOT, WD_BUGREPORT);

	exit(2);
}
