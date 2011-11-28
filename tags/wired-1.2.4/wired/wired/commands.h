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

#ifndef WD_COMMANDS_H
#define WD_COMMANDS_H 1

#include <stdbool.h>

#include "server.h"


struct wd_commands {
	char							*name;

	/* minimum state required */
	wd_client_state_t				state;				
	
	/* minimum number of arguments required */
	int								args;			

	/* activates idle clients? */
	bool							activate;			

	/* minimum permission required */
	int								permission;			

	void							(*action)(int, char **);
};
typedef struct wd_commands			wd_commands_t;


void *								wd_ctl_thread(void *);

void								wd_parse_command(char *);
int									wd_command_index(char *);

void								wd_cmd_ban(int, char **);
void								wd_cmd_banner(int, char **);
void								wd_cmd_broadcast(int, char **);
void								wd_cmd_clearnews(int, char **);
void								wd_cmd_client(int, char **);
void								wd_cmd_comment(int, char **);
void								wd_cmd_creategroup(int, char **);
void								wd_cmd_createuser(int, char **);
void								wd_cmd_decline(int, char **);
void								wd_cmd_delete(int, char **);
void								wd_cmd_deletegroup(int, char **);
void								wd_cmd_deleteuser(int, char **);
void								wd_cmd_editgroup(int, char **);
void								wd_cmd_edituser(int, char **);
void								wd_cmd_folder(int, char **);
void								wd_cmd_get(int, char **);
void								wd_cmd_groups(int, char **);
void								wd_cmd_hello(int, char **);
void								wd_cmd_icon(int, char **);
void								wd_cmd_info(int, char **);
void								wd_cmd_invite(int, char **);
void								wd_cmd_join(int, char **);
void								wd_cmd_kick(int, char **);
void								wd_cmd_leave(int, char **);
void								wd_cmd_list(int, char **);
void								wd_cmd_me(int, char **);
void								wd_cmd_move(int, char **);
void								wd_cmd_msg(int, char **);
void								wd_cmd_news(int, char **);
void								wd_cmd_nick(int, char **);
void								wd_cmd_pass(int, char **);
void								wd_cmd_ping(int, char **);
void								wd_cmd_post(int, char **);
void								wd_cmd_privchat(int, char **);
void								wd_cmd_privileges(int, char **);
void								wd_cmd_put(int, char **);
void								wd_cmd_readgroup(int, char **);
void								wd_cmd_readuser(int, char **);
void								wd_cmd_say(int, char **);
void								wd_cmd_search(int, char **);
void								wd_cmd_slaves(int, char **);
void								wd_cmd_stat(int, char **);
void								wd_cmd_status(int, char **);
void								wd_cmd_topic(int, char **);
void								wd_cmd_type(int, char **);
void								wd_cmd_user(int, char **);
void								wd_cmd_users(int, char **);
void								wd_cmd_who(int, char **);


extern wd_commands_t				wd_commands[];

#endif /* WD_COMMANDS_H */
