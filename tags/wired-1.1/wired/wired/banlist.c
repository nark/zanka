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
#include <math.h>

#include "config.h"
#include "banlist.h"
#include "main.h"
#include "settings.h"
#include "utility.h"


struct wd_list					wd_tempbans;


int wd_check_ban(char *ip) {
	struct wd_list_node		*node;
	struct wd_tempban		*tempban;
	int						result = 1;

	/* first check the list of temporary bans */
	pthread_mutex_lock(&(wd_tempbans.mutex));
	for(node = wd_tempbans.first; node != NULL; node = node->next) {
		tempban = node->data;

		if(strcmp(ip, tempban->ip) == 0) {
			result = -1;

			break;
		}
	}
	pthread_mutex_unlock(&(wd_tempbans.mutex));

	/* then check the banlist if we're configured to do so */
	if(result > 0 && strlen(wd_settings.banlist) > 0) {
		FILE		*fp;
		char		buffer[BUFSIZ], *p;

		/* open the banlist file */
		fp = fopen(wd_settings.banlist, "r");
		
		if(!fp) {
			wd_log(LOG_WARNING, "Could not open %s: %s",
				wd_settings.banlist, strerror(errno));
			
			return 0;
		}
	
		while(fgets(buffer, sizeof(buffer), fp) != NULL) {
			/* remove the linebreak if any */
			if((p = strchr(buffer, '\n')) != NULL)
				*p = '\0';
	
			/* ignore comments */
			if(buffer[0] == '#' || buffer[0] == '\0')
				continue;
			
			if(strchr(buffer, '*')) {
				/* test wildcard string */
				if(wd_ip_wildcard(buffer, ip)) {
					result = -1;
					
					break;
				}
			}
			else if(strchr(buffer, '/')) {
				/* test netmask string */
				if(wd_ip_netmask(buffer, ip)) {
					result = -1;
					
					break;
				}
			} else {
				/* test absolute string */
				if(strcmp(ip, buffer) == 0) {
					result = -1;
					
					break;
				}
			}
		}
		
		fclose(fp);
	}
	
	return result;
}



#pragma mark -

void wd_update_tempbans(void) {
	struct wd_list_node		*node;
	struct wd_tempban		*tempban;

	pthread_mutex_lock(&(wd_tempbans.mutex));
	for(node = wd_tempbans.first; node != NULL; node = node->next) {
		tempban = node->data;

		if(tempban->time + wd_settings.bantime < (unsigned int) time(NULL)) {
			wd_list_delete(&wd_tempbans, node);

			free(tempban);
		}
	}
	pthread_mutex_unlock(&(wd_tempbans.mutex));
}



#pragma mark -

int wd_ip_wildcard(char *match, char *test) {
	char	*ip, *o, *m, *t;
	int		result = 0;
	
	/* we're going to modify the ip */
	o = ip = strdup(test);
	
	while((m = strsep(&match, ".")) && (t = strsep(&ip, "."))) {
		if(strcmp(m, t) == 0 || strcmp(m, "*") == 0)
			result++;
	}
	
	free(o);

	return result == 4 ? 1 : 0;
}



int wd_ip_netmask(char *match, char *test) {
	char			*p, *netmask;
	unsigned int	ip_u = 0, netmask_u = 0, test_u = 0;
	unsigned int	bits;
	
	/* separate ip and netmask */
	p		= strchr(match, '/');
	netmask	= p + 1;
	*p		= '\0';
	
	/* convert to decimals */
	ip_u	= wd_iptou(match);
	test_u	= wd_iptou(test);

	/* check if the netmask is in ip form */
	if(strchr(netmask, '.')) {
		netmask_u	= wd_iptou(netmask);
	} else {
		bits		= strtoul(netmask, NULL, 10);
		netmask_u	= ((unsigned int) pow(2, bits) - 1) << (32 - bits);
	}
	
	return (ip_u & netmask_u) == (test_u & netmask_u);
}



unsigned int wd_iptou(char *ip) {
	char	*ap, *o, *p;
	int		i = 3, out = 0;
	
	/* we're going to modify the ip */
	o = p = strdup(ip);
	
	while((ap = strsep(&p, ".")))
		out += strtoul(ap, NULL, 10) * (unsigned int) pow(256, i--);
	
	free(o);
	
	return out;
}
