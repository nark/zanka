/* $Id$ */

/*
 *  Copyright (c) 2004 Axel Andersson
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

#ifndef WR_COMMANDS_H
#define WR_COMMANDS_H 1

#include <stdio.h>
#include <stdbool.h>

#include "main.h"
#include "utility.h"


#define ARRAY_SIZE(array)		(sizeof(array) / sizeof(*(array)))


struct wr_commands {
	char						*name;

	bool						help;
	char						*usage;

	unsigned int				optargs;
	unsigned int				optindex;
	wr_completer_t				completer;

	void						(*action)(int, char **);
};


void							wr_parse_file(FILE *);
int								wr_parse_command(char *, bool);
int								wr_command_index(char *);
void							wr_command_usage(char *);
wr_completer_t					wr_command_completer(char *);

char *							wr_rl_command_generator(const char *, int);

void							wr_cmd_ban(int, char **);
void							wr_cmd_broadcast(int, char **);
void							wr_cmd_cd(int, char **);
void							wr_cmd_clear(int, char **);
void							wr_cmd_clearnews(int, char **);
void							wr_cmd_close(int, char **);
void							wr_cmd_comment(int, char **);
void							wr_cmd_get(int, char **);
void							wr_cmd_help(int, char **);
void							wr_cmd_icon(int, char **);
void							wr_cmd_ignore(int, char **);
void							wr_cmd_info(int, char **);
void							wr_cmd_kick(int, char **);
void							wr_cmd_ls(int, char **);
void							wr_cmd_load(int, char **);
void							wr_cmd_log(int, char **);
void							wr_cmd_open(int, char **);
void							wr_cmd_me(int, char **);
void							wr_cmd_mkdir(int, char **);
void							wr_cmd_msg(int, char **);
void							wr_cmd_mv(int, char **);
void							wr_cmd_news(int, char **);
void							wr_cmd_nick(int, char **);
void							wr_cmd_post(int, char **);
void							wr_cmd_put(int, char **);
void							wr_cmd_pwd(int, char **);
void							wr_cmd_quit(int, char **);
void							wr_cmd_reply(int, char **);
void							wr_cmd_rm(int, char **);
void							wr_cmd_say(int, char **);
void							wr_cmd_save(int, char **);
void							wr_cmd_start(int, char **);
void							wr_cmd_stat(int, char **);
void							wr_cmd_status(int, char **);
void							wr_cmd_stop(int, char **);
void							wr_cmd_topic(int, char **);
void							wr_cmd_type(int, char **);
void							wr_cmd_unignore(int, char **);
void							wr_cmd_uptime(int, char **);
void							wr_cmd_version(int, char **);
void							wr_cmd_who(int, char **);


extern char						*wr_last_command;

#endif /* WR_COMMANDS_H */
