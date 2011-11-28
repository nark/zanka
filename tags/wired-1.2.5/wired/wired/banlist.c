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

#include "config.h"

#include <sys/param.h>
#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <syslog.h>
#include <errno.h>
#include <math.h>

#include "banlist.h"
#include "main.h"
#include "settings.h"
#include "utility.h"


wd_list_t				wd_tempbans;


bool wd_ip_is_banned(char *ip) {
	wd_list_node_t		*node;
	wd_tempban_t		*tempban;
	bool				banned = false;

	/* check the list of temporary bans */
	WD_LIST_LOCK(wd_tempbans);
	WD_LIST_FOREACH(wd_tempbans, node, tempban) {
		if(strcmp(ip, tempban->ip) == 0) {
			banned = true;

			break;
		}
	}
	WD_LIST_UNLOCK(wd_tempbans);
	
	if(banned)
		goto end;

	/* check the banlist if we're configured to do so */
	if(strlen(wd_settings.banlist) > 0) {
		FILE		*fp;
		char		buffer[BUFSIZ], *p;

		/* open the banlist file */
		fp = fopen(wd_settings.banlist, "r");
		
		if(fp) {
			while(fgets(buffer, sizeof(buffer), fp) != NULL) {
				/* remove the linebreak if any */
				if((p = strchr(buffer, '\n')) != NULL)
					*p = '\0';
		
				/* ignore comments */
				if(buffer[0] == '#' || buffer[0] == '\0')
					continue;
				
				if(strchr(buffer, '*')) {
					/* test wildcard string */
					if(wd_ip_matches_wildcard(ip, buffer)) {
						banned = true;
						
						break;
					}
				}
				else if(strchr(buffer, '/')) {
					/* test netmask string */
					if(wd_ip_matches_netmask(ip, buffer)) {
						banned = true;
						
						break;
					}
				} else {
					/* test absolute string */
					if(strcmp(ip, buffer) == 0) {
						banned = true;
						
						break;
					}
				}
			}
			
			fclose(fp);
		} else {
			wd_log(LOG_WARNING, "Could not open %s: %s",
				wd_settings.banlist, strerror(errno));
		}
	}

end:
	return banned;
}



#pragma mark -

void wd_update_tempbans(void) {
	wd_list_node_t		*node, *node_next;
	wd_tempban_t		*tempban;
	time_t				now;
	
	/* get time */
	now = time(NULL);

	/* loop over tempbans and remove expired */
	WD_LIST_LOCK(wd_tempbans);
	for(node = WD_LIST_FIRST(wd_tempbans); node != NULL; node = node_next) {
		node_next = WD_LIST_NEXT(node);
		tempban = WD_LIST_DATA(node);
		
		if(tempban->time + wd_settings.bantime < (unsigned int) now) {
			free(tempban);
			
			wd_list_delete(&wd_tempbans, node);
		}
	}
	WD_LIST_UNLOCK(wd_tempbans);
}



#pragma mark -

bool wd_ip_matches_wildcard(char *ip, char *match) {
	char	i[16], m[16];
	char	*ii, *mm, *p1, *p2;
	int		matches = 0;
	
	strlcpy(i, ip, sizeof(i));
	ii = i;

	strlcpy(m, match, sizeof(m));
	mm = m;
	
	while((p1 = strsep(&ii, ".")) && (p2 = strsep(&mm, "."))) {
		if(strcmp(p1, p2) == 0 || strcmp(p2, "*") == 0)
			matches++;
	}

	return matches == 4 ? true : false;
}



bool wd_ip_matches_netmask(char *ip, char *match) {
	char			m[32], netmask[16];
	char			*p;
	unsigned int	ip_u, match_u, netmask_u;
	
	strlcpy(m, match, sizeof(m));
	
	if((p = strchr(m, '/'))) {
		strlcpy(netmask, p + 1, sizeof(netmask));
		
		*p = '\0';
	}
	
	ip_u		= wd_iptou(ip);
	match_u		= wd_iptou(m);
	
	if(strchr(netmask, '.'))
		netmask_u = wd_iptou(netmask);
	else
		netmask_u = pow(2.0, 32.0) - pow(2.0, (float) 32 - strtoul(netmask, NULL, 10));
	
	return ((ip_u & netmask_u) == (match_u & netmask_u));
}



unsigned int wd_iptou(char *ip) {
	unsigned int	a, b, c, d;
	
	if(sscanf(ip, "%u.%u.%u.%u", &a, &b, &c, &d) == 4)
		return (a << 24) + (b << 16) + (c << 8) + d;
	
	return 0;
}
