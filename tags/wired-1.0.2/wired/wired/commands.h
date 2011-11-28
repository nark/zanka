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


struct server_commands {
	char							*name;
	unsigned int					state;				/* minimum state required */
	bool							args;				/* requires arguments? */
	bool							activate;			/* activates idle clients? */
	int								permission;			/* minimum permission required */
	void							(*action)(char *);
};


void *								wd_ctl_thread(void *);

void								wd_parse_command(char *);
int									wd_command_index(char *);

void								wd_cmd_authenticate(char *);
void								wd_cmd_ban(char *);
void								wd_cmd_broadcast(char *);
void								wd_cmd_clearnews(char *);
void								wd_cmd_client(char *);
void								wd_cmd_creategroup(char *);
void								wd_cmd_createuser(char *);
void								wd_cmd_decline(char *);
void								wd_cmd_delete(char *);
void								wd_cmd_deletegroup(char *);
void								wd_cmd_deleteuser(char *);
void								wd_cmd_editgroup(char *);
void								wd_cmd_edituser(char *);
void								wd_cmd_folder(char *);
void								wd_cmd_get(char *);
void								wd_cmd_groups(char *);
void								wd_cmd_hello(char *);
void								wd_cmd_icon(char *);
void								wd_cmd_info(char *);
void								wd_cmd_invite(char *);
void								wd_cmd_join(char *);
void								wd_cmd_kick(char *);
void								wd_cmd_leave(char *);
void								wd_cmd_list(char *);
void								wd_cmd_me(char *);
void								wd_cmd_move(char *);
void								wd_cmd_msg(char *);
void								wd_cmd_news(char *);
void								wd_cmd_nick(char *);
void								wd_cmd_pass(char *);
void								wd_cmd_ping(char *);
void								wd_cmd_post(char *);
void								wd_cmd_privchat(char *);
void								wd_cmd_privileges(char *);
void								wd_cmd_put(char *);
void								wd_cmd_readgroup(char *);
void								wd_cmd_readuser(char *);
void								wd_cmd_say(char *);
void								wd_cmd_search(char *);
void								wd_cmd_slaves(char *);
void								wd_cmd_stat(char *);
void								wd_cmd_user(char *);
void								wd_cmd_users(char *);
void								wd_cmd_who(char *);


extern struct server_commands		wd_server_commands[];

#endif /* WD_COMMANDS_H */
