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

#include <sys/param.h>
#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <syslog.h>
#include <errno.h>
#include <pthread.h>

#include "config.h"
#include "main.h"
#include "news.h"
#include "server.h"
#include "settings.h"
#include "utility.h"


pthread_mutex_t				wd_news_mutex = PTHREAD_MUTEX_INITIALIZER;


void wd_send_news(void) {
	FILE	*fp;
	char	buffer[8192];

	/* open the news file */
	fp = fopen(wd_settings.news, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			wd_settings.news, strerror(errno));

		goto end;
	}

	/* read and send */
	while((wd_fget_news(fp, buffer, sizeof(buffer))) > 0)
		wd_reply(320, "%s", buffer);
	
end:
	wd_reply(321, "Done");

    /* clean up */
    if(fp)
        fclose(fp);
}



int wd_fget_news(FILE *fp, char *line, size_t length) {
	unsigned int	i;
	int				ch;
	
	for(i = 0; i < length && (ch = fgetc(fp)) != EOF && ch != 29; i++)
		line[i] = ch;
	
	line[i] = '\0';
	
	return i;
}



void wd_post_news(char *arg) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	FILE			*fp = NULL, *tmp = NULL;
	char			buffer[8192], post_time[WD_DATETIME_SIZE], *post = NULL;
	size_t			bytes, n;
	time_t			now;
	unsigned int	lines = 0;
	
	/* lock */
    pthread_mutex_lock(&wd_news_mutex);

	/* open the news file */
	fp = fopen(wd_settings.news, "r");
	
	if(!fp) {
		wd_log(LOG_ERR, "Could not open %s: %s",
			wd_settings.news, strerror(errno));
		
		goto end;
	}

	/* open a temp file for writing */
	tmp = tmpfile();
	
	if(!tmp) {
		wd_log(LOG_ERR, "Could not create temporary file: %s",
			strerror(errno));
		
		goto end;
	}
	
	/* create a time string */
	now = time(NULL);
	wd_time_to_iso8601(now, post_time, sizeof(post_time));
	
	/* create the post */
	bytes = strlen(client->nick) + strlen(post_time) + strlen(arg) + 3;
	post = (char *) malloc(bytes);
	snprintf(post, bytes, "%s%c%s%c%s",
		client->nick,
		WD_FIELD_SEPARATOR,
		post_time,
		WD_FIELD_SEPARATOR,
		arg);
	
	/* write the post to the temporary file */
	fprintf(tmp, "%s%c", post, WD_GROUP_SEPARATOR);
	
	/* read the old news file and append it to the temporary file */
	while((n = fread(buffer, 1, sizeof(buffer), fp)))
		fwrite(buffer, 1, n, tmp);
	
	/* reopen the news file as writable */
	fp = freopen(wd_settings.news, "w", fp);
	
	if(!fp) {
		wd_log(LOG_ERR, "Could not open %s: %s",
			wd_settings.news, strerror(errno));
		
        goto end;
	}
	
	/* start over at the beginning of the temporary file */
	rewind(tmp);
	
	/* now copy the temporary file to the news file */
	while((wd_fget_news(tmp, buffer, sizeof(buffer))) > 0) {
		/* write this record */
		fprintf(fp, "%s%c", buffer, WD_GROUP_SEPARATOR);
		
		/* done? */
		if(++lines == wd_settings.newslimit)
			break;
	}

	/* send to all clients */
	wd_broadcast(WD_PUBLIC_CHAT, 322, "%s", post);

end:
    /* clean up */
	if(fp)
		fclose(fp);
    
	if(tmp)
		fclose(tmp);

	if(post)
		free(post);
    
    /* unlock */
    pthread_mutex_unlock(&wd_news_mutex);
}



void wd_clear_news(void) {
	FILE	*fp = NULL;
	
	/* lock */
    pthread_mutex_lock(&wd_news_mutex);

	/* open the news file */
	fp = fopen(wd_settings.news, "w");
	
	if(!fp) {
		wd_log(LOG_ERR, "Could not open %s: %s",
			wd_settings.news, strerror(errno));

		goto end;
	}
		
end:
	/* clean up */
	if(fp)
		fclose(fp);
    
    /* unlock */
    pthread_mutex_unlock(&wd_news_mutex);
}
