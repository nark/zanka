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

#include "config.h"

#include <sys/types.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <errno.h>
#include <readline/readline.h>

#include "client.h"
#include "commands.h"
#include "main.h"
#include "utility.h"


char					*wr_last_command;

struct wr_commands		wr_commands[] = {
	{ "ban",
	  true, "<user> <message>",
	  2, 1, WR_COMPLETER_NICKNAME,
	  wr_cmd_ban },
	{ "broadcast",
	  true, "<message>",
	  1, 0, WR_COMPLETER_NICKNAME,
	  wr_cmd_broadcast },
	{ "cd",
	  true, "<path>",
	  1, -1, WR_COMPLETER_DIRECTORY,
	  wr_cmd_cd },
	{ "clear",
	  true, "",
	  0, -1, WR_COMPLETER_NONE,
	  wr_cmd_clear },
	{ "clearnews",
	  true, "",
	  0, -1, WR_COMPLETER_NONE,
	  wr_cmd_clearnews },
	{ "close",
	  true, "",					
	  0, -1, WR_COMPLETER_NONE,
	  wr_cmd_close },
	{ "comment",
	  true, "<path> <comment>",
	  2, 1, WR_COMPLETER_FILENAME,
	  wr_cmd_comment },
	{ "connect",
	  false, "<server> [-l <login>] [-p <password>]",	
	  1, -1, WR_COMPLETER_NONE,
	  wr_cmd_open },
	{ "exit",
	  false, "",
	  0, -1, WR_COMPLETER_NONE,
	  wr_cmd_quit },
	{ "get",
	  true, "<path>",
	  1, -1, WR_COMPLETER_FILENAME,
	  wr_cmd_get },
	{ "help",
	  true, "[<command>]",
	  0, -1, WR_COMPLETER_COMMAND,
	  wr_cmd_help },
	{ "icon",
	  true, "<icon>",
	  1, -1, WR_COMPLETER_NONE,
	  wr_cmd_icon },
	{ "ignore",
	  true, "[<nick>]",
	  0, -1, WR_COMPLETER_NICKNAME,
	  wr_cmd_ignore },
	{ "info",
	  true, "<user>",
	  1, -1, WR_COMPLETER_NICKNAME,
	  wr_cmd_info },
	{ "join",
	  false, "<server> [-l <login>] [-p <password>]",	
	  1, -1, WR_COMPLETER_NONE,
	  wr_cmd_open },
	{ "kick",
	  true, "<user> <message>",
	  2, 1, WR_COMPLETER_NICKNAME,
	  wr_cmd_kick },
	{ "load",
	  true, "<bookmark>",
	  1, -1, WR_COMPLETER_BOOKMARK,
	  wr_cmd_load },
	{ "log",
	  true, "<filename>",
	  1, -1, WR_COMPLETER_NONE,
	  wr_cmd_log },
	{ "ls",
	  true, "<path>",
	  0, -1, WR_COMPLETER_DIRECTORY,
	  wr_cmd_ls },
	{ "me",
	  true, "<chat>",
	  1, 0, WR_COMPLETER_NICKNAME,
	  wr_cmd_me },
	{ "mkdir",
	  true, "<path>",
	  1, 0, WR_COMPLETER_FILENAME,
	  wr_cmd_mkdir },
	{ "msg",
	  true, "<user> <message>",
	  2, 1, WR_COMPLETER_NICKNAME,
	  wr_cmd_msg },
	{ "mv",
	  true, "<path> <path>",
	  2, -1, WR_COMPLETER_FILENAME,
	  wr_cmd_mv },
	{ "news",
	  true, "[-<number> | -ALL]",	
	  0, -1, WR_COMPLETER_NONE,
	  wr_cmd_news },
	{ "nick",
	  true, "<nick>",
	  1, 0, WR_COMPLETER_NICKNAME,
	  wr_cmd_nick },
	{ "open",
	  true, "<server> [-l <login>] [-p <password>]",	
	  1, -1, WR_COMPLETER_NONE,
	  wr_cmd_open },
	{ "post",
	  true, "<message>",
	  1, 0, WR_COMPLETER_NICKNAME,
	  wr_cmd_post },
	{ "put",
	  true, "<path>",
	  1, -1, WR_COMPLETER_LOCAL_FILENAME,
	  wr_cmd_put },
	{ "pwd",
	  true, "",
	  0, -1, WR_COMPLETER_NONE,
	  wr_cmd_pwd },
	{ "quit",
	  true, "",
	  0, -1, WR_COMPLETER_NONE,
	  wr_cmd_quit },
	{ "reply",
	  true, "<message>",
	  1, 0, WR_COMPLETER_NICKNAME,
	  wr_cmd_reply },
	{ "rm",
	  true, "<path>",
	  1, -1, WR_COMPLETER_FILENAME,
	  wr_cmd_rm },
	{ "save",
	  true, "<bookmark>",
	  1, -1, WR_COMPLETER_BOOKMARK,
	  wr_cmd_save },
	{ "say",
	  false, "<chat>",
	  1, 0, WR_COMPLETER_NICKNAME,
	  wr_cmd_say },
	{ "server",
	  false, "<server> [-l <login>] [-p <password>]",	
	  1, -1, WR_COMPLETER_NONE,
	  wr_cmd_open },
	{ "start",
	  true, "<transfer>",
	  1, -1, WR_COMPLETER_NONE,
	  wr_cmd_start },
	{ "stat",
	  true, "<path>",
	  1, -1, WR_COMPLETER_FILENAME,
	  wr_cmd_stat },
	{ "status",
	  true, "<status>",
	  1, 0, WR_COMPLETER_NONE,
	  wr_cmd_status },
	{ "stop",
	  true, "<transfer>",
	  1, -1, WR_COMPLETER_NONE,
	  wr_cmd_stop },
	{ "topic",
	  true, "",
	  1, 0, WR_COMPLETER_NICKNAME,
	  wr_cmd_topic },
	{ "type",
	  true, "<path> (folder | uploads | dropbox)",
	  2, -1, WR_COMPLETER_FILENAME,
	  wr_cmd_type },
	{ "unignore",
	  true, "[<ignore> | <nick>]",
	  0, -1, WR_COMPLETER_IGNORE,
	  wr_cmd_unignore },
	{ "uptime",
	  true, "",
	  0, -1, WR_COMPLETER_NONE,
	  wr_cmd_uptime },
	{ "version",
	  true, "",
	  0, -1, WR_COMPLETER_NONE,
	  wr_cmd_version },
	{ "who",
	  true, "",
	  0, -1, WR_COMPLETER_NONE,
	  wr_cmd_who },
	{ "whois",
	  false, "<user>",
	  1, -1, WR_COMPLETER_NICKNAME,
	  wr_cmd_info },
};


void wr_parse_file(FILE *fp) {
	char	buffer[BUFSIZ], *p;
	
	while(fgets(buffer, sizeof(buffer), fp) != NULL) {
		/* remove the linebreak if any */
		if((p = strchr(buffer, '\n')) != NULL)
			*p = '\0';
		
		/* ignore comments and empty lines */
		if(!*buffer || *buffer == '#')
			continue;

		/* go go command */
		wr_parse_command(buffer, false);
	}
}



int wr_parse_command(char *buffer, bool chat) {
	char		*start, *command = NULL, *arg = NULL;
	char		**argv = NULL;
	int			index, argc = 0;
	
	/* skip / if we're coming from the input window */
	if(chat) {
		if(*buffer == '/')
			buffer++;
		else
			command = strdup("say");
	}

	if(!command) {
		/* loop over the command */
		start = buffer;
		
		while(*buffer && !isspace(*buffer))
			buffer++;

		/* get command */
		command = (char *) malloc(buffer - start + 1);
		memcpy(command, start, buffer - start);
		command[buffer - start] = '\0';
	}

	/* verify command */
	index = wr_command_index(command);
	
	if(index < 0) {
		wr_printf_prefix("%s: Command not recognized\n", command);

		goto end;
	}
	
	/* loop over argument string */
	start = buffer;
	
	while(*buffer)
		buffer++;
	
	if(isspace(*start))
		start++;

	/* get argument */
	arg = (char *) malloc(buffer - start + 1);
	memcpy(arg, start, buffer - start);
	arg[buffer - start] = '\0';
	
	/* get argument vector */
	wr_argv_create(arg, wr_commands[index].optindex, &argc, &argv);
	
	/* verify argument */
	if(argc < wr_commands[index].optargs) {
		wr_command_usage(command);
		
		goto end;
	}
	
	/* go go command */
	((*wr_commands[index].action) (argc, argv));
	
	/* set last command */
	wr_last_command = wr_commands[index].name;

end:
	/* clean up */
	if(command)
		free(command);

	if(arg)
		free(arg);
	
	if(argc > 0)
		wr_argv_free(argc, argv);
	
	return index;
}



int wr_command_index(char *command) {
	int		i, max, length;
	
	max = ARRAY_SIZE(wr_commands) - 1;
	length = strlen(command);

	for(i = 0; i < max; i++) {
		if(strncasecmp(command, wr_commands[i].name, length) == 0)
			return i;
	}

	return -1;
}



void wr_command_usage(char *command) {
	int		index;
	
	/* get command */
	index = wr_command_index(command);

	if(index < 0) {
		wr_printf_prefix("%s: Command not recognized\n", command);

		return;
	}
	
	/* print usage */
	wr_printf_prefix("Usage: %s %s\n", wr_commands[index].name, wr_commands[index].usage);
}



wr_completer_t wr_command_completer(char *buffer) {
	char			*p, *start, *command = NULL;
	wr_completer_t	completer;
	int				index;
	
	/* complete nicks if empty */
	if(!*buffer || *buffer != '/') {
		completer = WR_COMPLETER_NICKNAME;
		
		goto end;
	}
	
	/* complete commands if beginning with slash and contains no spaces */
	if(*buffer == '/') {
		if((p = strchr(buffer, ' ')) == NULL) {
			completer = WR_COMPLETER_COMMAND;
			
			goto end;
		}
	}
	
	/* loop over the command */
	start = buffer + 1;
	
	while(*buffer && !isspace(*buffer))
		buffer++;

	/* get command */
	command = (char *) malloc(buffer - start + 1);
	memcpy(command, start, buffer - start);
	command[buffer - start] = '\0';
	
	/* get command index */
	index = wr_command_index(command);

	if(index < 0) {
		completer = WR_COMPLETER_NONE;
		
		goto end;
	}
	
	/* get completer type */
	completer = wr_commands[index].completer;

end:
	/* clean up */
	if(command)
		free(command);
	
	return completer;
}



#pragma mark -

char * wr_rl_command_generator(const char *text, int state) {
	static int		i, max, length;
	char			*name, *match;
	int				bytes;
	bool			help;
	
	if(!state) {
		i = 0;
		max = ARRAY_SIZE(wr_commands) - 1;
		length = strlen(text);
	}

	while(i <= max) {
		name = wr_commands[i].name;
		help = wr_commands[i].help;
		i++;
		
		if(text[0] == '/') {
			if(help && strncasecmp(name, text + 1, length - 1) == 0) {
				bytes = strlen(name) + 2;
				match = (char *) malloc(bytes);
				snprintf(match, bytes, "/%s", name);
				
				return match;
			}
		} else {
			if(help && strncasecmp(name, text, length) == 0)
				return strdup(name);
		}
	}
	
	return NULL;
}



#pragma mark -

/*
	/ban <user> <message>
*/

void wr_cmd_ban(int argc, char *argv[]) {
	wr_user_t	*user;
	
	/* get user */
	user = wr_get_user_with_nick(argv[0]);
	
	if(!user) {
		wr_printf_prefix("Client not found\n");
		
		return;
	}
	
	/* kick user */
	wr_send_command("BAN %u%s%s%s",
		user->uid,
		WR_FIELD_SEPARATOR,
		argv[1],
		WR_MESSAGE_SEPARATOR);
}



/*
	/broadcast <message>
*/

void wr_cmd_broadcast(int argc, char *argv[]) {
	/* post news */
	wr_send_command("BROADCAST %s%s",
		argv[0],
		WR_MESSAGE_SEPARATOR);
}



/*
	/cd <path>
*/

void wr_cmd_cd(int argc, char *argv[]) {
	char	path[MAXPATHLEN];
	
	/* save previous */
	strlcpy(path, wr_files_cwd, sizeof(path));
	
	/* expand path */
	wr_path_expand(wr_files_cwd, argv[0], sizeof(wr_files_cwd));
	
	/* dump if different */
	if(strcmp(path, wr_files_cwd) != 0)
		wr_list_free(&wr_files);
	
	wr_printf_prefix("Changed directory to: %s\n", wr_files_cwd);
	wr_draw_divider();
}



/*
	/clear
*/

void wr_cmd_clear(int argc, char *argv[]) {
	wr_term_clear();
}



/*
	/clearnews
*/

void wr_cmd_clearnews(int argc, char *argv[]) {
	/* send command */
	wr_send_command("CLEARNEWS%s",
		WR_MESSAGE_SEPARATOR);
}



/*
	/close
*/

void wr_cmd_close(int argc, char *argv[]) {
	/* close */
	wr_close();
}



/*
	/comment <path> <comment>
*/

void wr_cmd_comment(int argc, char *argv[]) {
	char	path[MAXPATHLEN];
	
	/* expand path */
	wr_path_expand(path, argv[0], sizeof(path));

	/* send message */
	wr_send_command("COMMENT %s%s%s%s",
		path,
		WR_FIELD_SEPARATOR,
		argv[1],
		WR_MESSAGE_SEPARATOR);
}



/*
	/get <path>
*/

void wr_cmd_get(int argc, char *argv[]) {
	wr_transfer_t		*transfer;
	wr_list_node_t		*node;
	struct stat			sb;
	
	/* create transfer */
	transfer = (wr_transfer_t *) malloc(sizeof(wr_transfer_t));
	memset(transfer, 0, sizeof(wr_transfer_t));
	
	/* set values */
	transfer->sd = -1;
	transfer->type = WR_TRANSFER_DOWNLOAD;
	transfer->state = WR_TRANSFER_WAITING;
	
	/* set paths */
	wr_path_expand(transfer->path, argv[0], sizeof(transfer->path));
	strlcpy(transfer->local_path, basename_np(transfer->path),
		sizeof(transfer->local_path));
	snprintf(transfer->local_path_partial, sizeof(transfer->local_path_partial),
		"%s.WireTransfer", transfer->local_path);
	
	/* check for existing file */
	if(stat(transfer->local_path, &sb) == 0) {
		wr_printf_prefix("get: File already exists at \"%s\"\n",
			transfer->local_path);

		free(transfer);
		return;
	}
	
	/* check for existing partial file */
	if(stat(transfer->local_path_partial, &sb) == 0) {
		/* set offset */
		transfer->offset = sb.st_size;
		transfer->transferred = sb.st_size;
		
		/* XXX checksum */
	}
			
	/* add to list */
	node = wr_list_add(&wr_transfers, transfer);
	
	/* set id */
	if(node->previous)
		transfer->tid = ((wr_transfer_t *) WR_LIST_DATA(WR_LIST_PREVIOUS(node)))->tid + 1;
	else
		transfer->tid = 1;

	if((wr_transfer_t *) WR_LIST_DATA(WR_LIST_FIRST(wr_transfers)) == transfer) {
		/* set state */
		wr_stat_state = WR_STAT_TRANSFER;
		
		/* request file information */
		wr_send_command("STAT %s%s",
			transfer->path,
			WR_MESSAGE_SEPARATOR);
	}
}



/*
	/help [<command>]
*/

void wr_cmd_help(int argc, char *argv[]) {
	int		i, x, max, length, max_length;
	
	/* display help */
	if(argc > 0) {
		wr_command_usage(argv[0]);
	} else {
		wr_printf_prefix("Commands:\n");

		max = ARRAY_SIZE(wr_commands) - 1;
		max_length = 0;

		for(i = 0; i < max; i++) {
			if(wr_commands[i].help) {
				length = strlen(wr_commands[i].name);
				max_length = length > max_length ? length : max_length;
			}
		}
			
		
		for(i = 0, x = 0; i < max; i++) {
			if(wr_commands[i].help) {
				wr_printf("   %s%*s",
					wr_commands[i].name,
					max_length - strlen(wr_commands[i].name) + 1,
					" ");
		
				x += max_length + 3;
		
				if(x >= CO - max_length - max_length) {
					x = 0;
		
					wr_printf("\n");
				}
			}
		}

		wr_printf("\n");
	}
}



/*
	/icon <icon>
*/

void wr_cmd_icon(int argc, char *argv[]) {
	wr_uid_t	icon;

	/* set new icon */
	icon = strtoul(argv[0], NULL, 10);

	if(icon != wr_icon) {
		wr_icon = icon;

		wr_send_command("ICON %u%s",
			wr_icon,
			WR_MESSAGE_SEPARATOR);
	}
}



/*
	/ignore [<nick>]
*/

void wr_cmd_ignore(int argc, char *argv[]) {
	wr_list_node_t	*node;
	wr_ignore_t		*ignore;
	char			error[WR_REGEXP_SIZE];
	int				result;
	
	if(argc > 0) {
		/* create ignore */
		ignore = (wr_ignore_t *) malloc(sizeof(wr_ignore_t));
		memset(ignore, 0, sizeof(wr_ignore_t));
		
		/* save string */
		strlcpy(ignore->string, argv[0], sizeof(ignore->string));
		
		/* create regex */
		if((result = regcomp(&ignore->regex, ignore->string,
							 REG_EXTENDED | REG_ICASE | REG_NOSUB)) != 0) {
			regerror(result, &ignore->regex, error, sizeof(error));
			
			wr_printf_prefix("Could not compile regular expression \"%s\": %s",
				ignore->string, error);
			
			free(ignore);
			return;
		}
		
		/* add to list */
		node = wr_list_add(&wr_ignores, ignore);

		/* set id */
		if(WR_LIST_PREVIOUS(node))
			ignore->iid = ((wr_ignore_t *) WR_LIST_DATA(WR_LIST_PREVIOUS(node)))->iid + 1;
		else
			ignore->iid = 1;
		
		/* print success */
		wr_printf_prefix("Ignoring \"%s\"\n", ignore->string);
	} else {
		/* list active ignores */
		wr_printf_prefix("Ignores:\n");
		WR_LIST_LOCK(wr_ignores);
		WR_LIST_FOREACH(wr_ignores, node, ignore)
			wr_printf_block("%u: %s", ignore->iid, ignore->string);
		WR_LIST_UNLOCK(wr_ignores);
	}
}



/*
	/info <user>
*/

void wr_cmd_info(int argc, char *argv[]) {
	wr_user_t	*user;
	
	/* get user */
	user = wr_get_user_with_nick(argv[0]);
	
	if(!user) {
		wr_printf_prefix("Client not found\n");
		
		return;
	}
	
	/* send message */
	wr_send_command("INFO %u%s",
		user->uid,
		WR_MESSAGE_SEPARATOR);
}



/*
	/kick <user> <message>
*/

void wr_cmd_kick(int argc, char *argv[]) {
	wr_user_t	*user;
	
	/* get user */
	user = wr_get_user_with_nick(argv[0]);
	
	if(!user) {
		wr_printf_prefix("Client not found\n");
		
		return;
	}
	
	/* kick user */
	wr_send_command("KICK %u%s%s%s",
		user->uid,
		WR_FIELD_SEPARATOR,
		argv[1],
		WR_MESSAGE_SEPARATOR);
}



/*
	/ls <path>
*/

void wr_cmd_ls(int argc, char *argv[]) {
	char	path[MAXPATHLEN];
	
	/* re-create list */
	wr_list_free(&wr_files);
	wr_list_create(&wr_files);
	
	/* set state */
	wr_ls_state = WR_LS_LISTING;
	
	/* set listing directory */
	if(argc == 0) {
		strlcpy(wr_files_ld, wr_files_cwd, sizeof(wr_files_ld));
	} else {
		wr_path_expand(path, argv[0], sizeof(path));
		strlcpy(wr_files_ld, path, sizeof(wr_files_ld));
	}
	
	/* request list */
	wr_send_command("LIST %s%s",
		wr_files_ld,
		WR_MESSAGE_SEPARATOR);
}



/*
	/load <bookmark>
*/

void wr_cmd_load(int argc, char *argv[]) {
	FILE	*fp;
	char	path[MAXPATHLEN];

	/* read specified bookmark */
	snprintf(path, sizeof(path), "%s/.wire/%s", getenv("HOME"), argv[0]);
	fp = fopen(path, "r");
	
	if(!fp) {
		wr_printf_prefix("load: %s: %s\n", path, strerror(errno));
	} else {
		wr_parse_file(fp);
		fclose(fp);
	}
}



/*
	/log <filename>
*/

void wr_cmd_log(int argc, char *argv[]) {
	FILE	*fp;
	char	path[MAXPATHLEN], real_path[MAXPATHLEN];

	/* set filename */
	snprintf(path, sizeof(path), "%s/%s", getenv("HOME"), argv[0]);
	fp = fopen(path, "w");
	
	if(!fp) {
		/* print error */
		wr_printf_prefix("log: %s: %s\n", path, strerror(errno));
	} else {
		/* write output */
		fprintf(fp, wr_term_buffer);
		fclose(fp);

		/* print success */
		realpath(path, real_path);
		wr_printf_prefix("log: \"%s\" saved\n", real_path);
	}
}



/*
	/me <chat>
*/

void wr_cmd_me(int argc, char *argv[]) {
	/* send chat */
	wr_send_command("ME %u%s%s%s",
		1,
		WR_FIELD_SEPARATOR,
		argv[0],
		WR_MESSAGE_SEPARATOR);
}



/*
	/mkdir <path>
*/

void wr_cmd_mkdir(int argc, char *argv[]) {
	char	path[MAXPATHLEN];
	
	/* expand paths */
	wr_path_expand(path, argv[0], sizeof(path));
	
	/* send command */
	wr_send_command("FOLDER %s%s",
		path,
		WR_MESSAGE_SEPARATOR);
}



/*
	/msg <user> <message>
*/

void wr_cmd_msg(int argc, char *argv[]) {
	wr_user_t	*user;
	
	/* get user */
	user = wr_get_user_with_nick(argv[0]);
	
	if(!user) {
		wr_printf_prefix("Client not found\n");
		
		return;
	}
	
	/* send message */
	wr_send_command("MSG %u%s%s%s",
		user->uid,
		WR_FIELD_SEPARATOR,
		argv[1],
		WR_MESSAGE_SEPARATOR);
	
	/* print */
	wr_printf_prefix("Sent private message to %s\n", user->nick);
}



/*
	/mv <path> <path>
*/

void wr_cmd_mv(int argc, char *argv[]) {
	char	from[MAXPATHLEN];
	char	to[MAXPATHLEN];
	
	/* expand paths */
	wr_path_expand(from, argv[0], sizeof(from));
	wr_path_expand(to, argv[1], sizeof(to));
	
	if(to[strlen(to) - 1] == '/')
		strlcat(to, basename_np(from), sizeof(to));
	
	/* send command */
	wr_send_command("MOVE %s%s%s%s",
		from,
		WR_FIELD_SEPARATOR,
		to,
		WR_MESSAGE_SEPARATOR);
}



/*
	/news
*/

void wr_cmd_news(int argc, char *argv[]) {
	/* limit number of articles */
	if(argc == 0) {
		wr_news_limit = 10;
	} else {
		if(strcasecmp(argv[0], "-ALL") == 0)
			wr_news_limit = INT_MAX;
		else 
			wr_news_limit = strtol(argv[0] + 1, NULL, 10);
	}

	/* request news */
	wr_send_command("NEWS%s",
		WR_MESSAGE_SEPARATOR);
}



/*
	/nick <name>
*/

void wr_cmd_nick(int argc, char *argv[]) {
	/* set new nick */
	if(strcmp(argv[0], wr_nick) != 0) {
		strlcpy(wr_nick, argv[0], sizeof(wr_nick));

		wr_draw_divider();

		wr_send_command("NICK %s%s",
			wr_nick,
			WR_MESSAGE_SEPARATOR);
	}
}



/*
	/open <server> [-l <login>] [-p <password>]
*/

void wr_cmd_open(int argc, char *argv[]) {
	char		*ap, *host = NULL, *address = NULL, *port = NULL, *login = NULL, *password = NULL;
	int			ch;

	/* get host */
	host = argv[0];
	
	/* parse arguments */
	getopt_reset_np();
	
	while((ch = getopt(argc, argv, "hl:p:")) != -1) {
		switch(ch) {
			case 'l':
				login = strdup(optarg);
				break;

			case 'p':
				password = strdup(optarg);
				break;
				
			case '?':
			case 'h':
			default:
				wr_command_usage("open");
				goto end;
				break;
		}
	}
	
	/* default values */
	if(!login)
		login = strdup("guest");
	
	if(!password)
		password = strdup("");
	
	/* extract port from address */
	while((ap = strsep(&host, ":")) != NULL) {
		if(!address)
			address = strdup(ap);
		else if(!port)
			port = strdup(ap);
	}
	
	/* default port */
	if(!port)
		port = strdup("2000");

	/* connect */
	wr_connect(address, strtol(port, NULL, 10), login, password);

end:
	/* clean up */
	if(address)
		free(address);

	if(port)
		free(port);

	if(login)
		free(login);

	if(password)
		free(password);
}



/*
	/post <message>
*/

void wr_cmd_post(int argc, char *argv[]) {
	/* post news */
	wr_send_command("POST %s%s",
		argv[0],
		WR_MESSAGE_SEPARATOR);
}



/*
	/put <path>
*/

void wr_cmd_put(int argc, char *argv[]) {
	wr_transfer_t			*transfer;
	wr_list_node_t			*node;
	SHA_CTX					c;
	FILE					*fp;
	struct stat				sb;
	static unsigned char	hex[] = "0123456789abcdef";
	unsigned char			buffer[BUFSIZ], sha[SHA_DIGEST_LENGTH];
	char					real_path[MAXPATHLEN];
	int						i, bytes, total = 0;
	
	/* create transfer */
	transfer = (wr_transfer_t *) malloc(sizeof(wr_transfer_t));
	memset(transfer, 0, sizeof(wr_transfer_t));
	
	/* set values */
	transfer->sd = -1;
	transfer->type = WR_TRANSFER_UPLOAD;
	transfer->state = WR_TRANSFER_WAITING;
	
	/* expand local path */
	if(argv[0][0] == '~') {
		snprintf(real_path, sizeof(real_path), "%s/%s", getenv("HOME"), argv[0] + 1);
		realpath(real_path, transfer->local_path_partial);
	} else {
		realpath(argv[0], real_path);
		strlcpy(transfer->local_path_partial, real_path,
				sizeof(transfer->local_path_partial));
	}
	
	/* set remote path */
	wr_path_expand(transfer->path, basename_np(transfer->local_path_partial),
				   sizeof(transfer->path));
	
	/* stat local path */
	if(stat(transfer->local_path_partial, &sb) < 0) {
		wr_printf_prefix("put: %s: %s\n",
			transfer->local_path_partial, strerror(errno));
		
		free(transfer);
		return;
	}
	
	/* set size */
	transfer->size = sb.st_size;
	
	/* checksum the existing file */
	fp = fopen(transfer->local_path_partial, "r");
	
	if(!fp) {
		wr_printf_prefix("put: %s: %s\n",
			transfer->local_path_partial, strerror(errno));
		
		free(transfer);
		return;
	}
	
	SHA1_Init(&c);

	/* checksum at most WR_CHECKSUM_SIZE bytes */
	while((bytes = fread(buffer, 1, sizeof(buffer), fp))) {
		SHA1_Update(&c, buffer, bytes);
		total += bytes;
		
		if(total >= WR_CHECKSUM_SIZE)
			break;
	}
	
	SHA1_Final(sha, &c);
	fclose(fp);

	/* map into hex characters */
	for(i = 0; i < SHA_DIGEST_LENGTH; i++) {
		transfer->checksum[i+i]		= hex[sha[i] >> 4];
		transfer->checksum[i+i+1]	= hex[sha[i] & 0x0F];
	}
	
	transfer->checksum[i+i] = '\0';
		
	/* add to list */
	node = wr_list_add(&wr_transfers, transfer);
	
	/* set id */
	if(node->previous)
		transfer->tid = ((wr_transfer_t *) WR_LIST_DATA(WR_LIST_PREVIOUS(node)))->tid + 1;
	else
		transfer->tid = 1;

	if((wr_transfer_t *) WR_LIST_DATA(WR_LIST_FIRST(wr_transfers)) == transfer) {
		/* request transfer */
		wr_send_command("PUT %s%s%llu%s%s%s",
			transfer->path,
			WR_FIELD_SEPARATOR,
			transfer->size,
			WR_FIELD_SEPARATOR,
			transfer->checksum,
			WR_MESSAGE_SEPARATOR);
	}
}



/*
	/pwd
*/

void wr_cmd_pwd(int argc, char *argv[]) {
	/* print current working directory */
	wr_printf_prefix("Current working directory: %s\n", wr_files_cwd);
}



/*
	/quit
*/

void wr_cmd_quit(int argc, char *argv[]) {
	/* quit */
	wr_running = 0;
}




/*
	/reply <message>
*/

void wr_cmd_reply(int argc, char *argv[]) {
	wr_user_t	*user;
	
	/* check uid */
	if(!wr_reply_uid) {
		wr_printf_prefix("reply: No one has sent you a message yet\n");
		
		return;
	}
	
	/* get user */
	user = wr_get_user(wr_reply_uid);
	
	if(!user) {
		wr_printf_prefix("Client not found\n");
		
		return;
	}
	
	/* send message */
	wr_send_command("MSG %u%s%s%s",
		user->uid,
		WR_FIELD_SEPARATOR,
		argv[0],
		WR_MESSAGE_SEPARATOR);

	/* print */
	wr_printf_prefix("Sent private message to %s\n", user->nick);
}



/*
	/rm <path>
*/

void wr_cmd_rm(int argc, char *argv[]) {
	char	path[MAXPATHLEN];
	
	/* expand paths */
	wr_path_expand(path, argv[0], sizeof(path));
	
	/* send command */
	wr_send_command("DELETE %s%s",
		path,
		WR_MESSAGE_SEPARATOR);
}



/*
	/say <chat>
*/

void wr_cmd_say(int argc, char *argv[]) {
	/* send chat */
	wr_send_command("SAY %u%s%s%s",
		1,
		WR_FIELD_SEPARATOR,
		argv[0],
		WR_MESSAGE_SEPARATOR);
}



/*
	/save <bookmark>
*/

void wr_cmd_save(int argc, char *argv[]) {
	FILE		*fp = NULL;
	char		path[MAXPATHLEN];

	/* check if connected */
	if(wr_socket == -1) {
		wr_printf_prefix("save: You are not connected to a server\n");
		
		goto end;
	}
	
	/* open bookmark */
	snprintf(path, sizeof(path), "%s/.wire/%s", getenv("HOME"), argv[0]);
	fp = fopen(path, "w");
	
	if(!fp) {
		wr_printf_prefix("save: %s: %s\n", path, strerror(errno));
		
		goto end;
	}
	
	/* write settings */
	fprintf(fp, "nick %s\n", wr_nick);
	fprintf(fp, "icon %u\n", wr_icon);
	
	if(strlen(wr_login) > 0 && strlen(wr_password) > 0)
		fprintf(fp, "open %s -l %s -p %s\n", wr_host, wr_login, wr_password);
	else if(strlen(wr_login) > 0)
		fprintf(fp, "open %s -l %s\n", wr_host, wr_login);
	else
		fprintf(fp, "open %s\n", wr_host);
	
	/* print success */
	wr_printf_prefix("save: \"%s\" saved\n", argv[0]);
	
end:
	/* clean up */
	if(fp)
		fclose(fp);
}



/*
	/start <transfer>
*/

void wr_cmd_start(int argc, char *argv[]) {
	wr_transfer_t	*transfer;

	/* get transfer */
	transfer = wr_get_transfer_with_tid(strtoul(argv[0], NULL, 10));
	
	if(!transfer) {
		wr_printf_prefix("start: Could not find transfer with id %s\n",
			argv[0]);
		
		return;
	}
	
	if(transfer->state == WR_TRANSFER_RUNNING) {
		wr_printf_prefix("start: Transfer of \"%s\" has already started\n",
			transfer->path);
		
		return;
	}
	
	if(transfer->type == WR_TRANSFER_DOWNLOAD) {
		/* set state */
		wr_stat_state = WR_STAT_TRANSFER;
		
		/* request file information */
		wr_send_command("STAT %s%s",
			transfer->path,
			WR_MESSAGE_SEPARATOR);
	} else {
		/* request transfer */
		wr_send_command("PUT %s%s%llu%s%s%s",
			transfer->path,
			WR_FIELD_SEPARATOR,
			transfer->size,
			WR_FIELD_SEPARATOR,
			transfer->checksum,
			WR_MESSAGE_SEPARATOR);
	}
}



/*
	/stat <path>
*/

void wr_cmd_stat(int argc, char *argv[]) {
	char		path[MAXPATHLEN];
	
	/* expand path */
	wr_path_expand(path, argv[0], sizeof(path));

	/* set state */
	wr_stat_state = WR_STAT_FILE;
	
	/* send stat */
	wr_send_command("STAT %s%s",
		path,
		WR_MESSAGE_SEPARATOR);
}



/*
	/status <status>
*/

void wr_cmd_status(int argc, char *argv[]) {
	/* send topic */
	wr_send_command("STATUS %s%s",
		argv[0],
		WR_MESSAGE_SEPARATOR);
}



/*
	/stop <transfer>
*/

void wr_cmd_stop(int argc, char *argv[]) {
	wr_transfer_t	*transfer;

	/* get transfer */
	transfer = wr_get_transfer_with_tid(strtoul(argv[0], NULL, 10));
	
	if(!transfer) {
		wr_printf_prefix("stop: Could not find transfer with id %s\n",
			argv[0]);
		
		return;
	}
	
	/* print success */
	if(transfer->state == WR_TRANSFER_RUNNING) {
		wr_printf_prefix("Aborting transfer of \"%s\"\n",
			transfer->path);
	} else {
		wr_printf_prefix("Removing transfer of \"%s\"\n",
			transfer->path);
	}
	
	/* remove transfer */
	wr_close_transfer(transfer);
	wr_draw_transfers();
}



/*
	/topic <topic>
*/

void wr_cmd_topic(int argc, char *argv[]) {
	/* send topic */
	wr_send_command("TOPIC %u%s%s%s",
		1,
		WR_FIELD_SEPARATOR,
		argv[0],
		WR_MESSAGE_SEPARATOR);
}



/*
	/type <path> <type>
*/

void wr_cmd_type(int argc, char *argv[]) {
	char			path[MAXPATHLEN];
	unsigned int	type;
	
	/* expand path */
	wr_path_expand(path, argv[0], sizeof(path));
	
	/* get type */
	if(strcmp(argv[1], "folder") == 0)
		type = WR_FILE_DIRECTORY;
	else if(strcmp(argv[1], "uploads") == 0)
		type = WR_FILE_UPLOADS;
	else if(strcmp(argv[1], "dropbox") == 0)
		type = WR_FILE_DROPBOX;
	else {
		wr_command_usage("help");
		
		return;
	}
	
	/* set type */
	wr_send_command("TYPE %s%s%u%s",
		path,
		WR_FIELD_SEPARATOR,
		type,
		WR_MESSAGE_SEPARATOR);
}



/*
	/unignore [<ignore> | <nick>]
*/

void wr_cmd_unignore(int argc, char *argv[]) {
	wr_list_node_t	*node, *value = NULL;
	wr_ignore_t		*ignore;
	unsigned int	iid;
	
	if(argc > 0) {
		/* is it an id? */
		iid = strtoul(argv[0], NULL, 10);
		
		/* find ignore */
		WR_LIST_LOCK(wr_ignores);
		WR_LIST_FOREACH(wr_ignores, node, ignore) {
			if(iid == ignore->iid || strcmp(ignore->string, argv[0]) == 0) {
				value = node;
				
				break;
			}
		}
		WR_LIST_UNLOCK(wr_ignores);
		
		/* print success/failure */
		if(value) {
			wr_printf_prefix("No longer ignoring \"%s\"\n",
				((wr_ignore_t *) WR_LIST_DATA(value))->string);
		} else {
			wr_printf_prefix("No ignore matching \"%s\"\n", argv[0]);
		}
	} else {
		/* list active ignores */
		wr_printf_prefix("Ignores:\n");
		WR_LIST_LOCK(wr_ignores);
		WR_LIST_FOREACH(wr_ignores, node, ignore)
			wr_printf_block("%u: %s", ignore->iid, ignore->string);
		WR_LIST_UNLOCK(wr_ignores);
	}
}



/*
	/uptime
*/

void wr_cmd_uptime(int argc, char *argv[]) {
	int			days, hours, minutes, seconds;
	char		uptime[26];

	/* get time */
	seconds = time(NULL) - wr_start_time;
	
	days = seconds / 86400;
	seconds -= days * 86400;
	
	hours = seconds / 3600;
	seconds -= hours * 3600;
	
	minutes = seconds / 60;
	seconds -= minutes * 60;

	if(days > 0) {
		snprintf(uptime, sizeof(uptime), "%u:%.2u:%.2u:%.2u days",
			days, hours, minutes, seconds);
	}
	else if(hours > 0) {
		snprintf(uptime, sizeof(uptime), "%.2u:%.2u:%.2u hours",
			hours, minutes, seconds);
	}
	else if(minutes > 0) {
		snprintf(uptime, sizeof(uptime), "%.2u:%.2u minutes",
			minutes, seconds);
	}
	else {
		snprintf(uptime, sizeof(uptime), "00:%.2u seconds",
			seconds);
	}
	
	wr_printf_prefix("Up %s, using %.2f KB of %.0f KB chat buffer, received %.2f KB, transferred %.2f KB\n",
		uptime,
		(double) wr_term_buffer_offset / 1024,
		(double) wr_term_buffer_size / 1024,
		(double) wr_received_bytes / 1024,
		(double) wr_transferred_bytes / 1024);
}



/*
	/version
*/

void wr_cmd_version(int argc, char *argv[]) {
	/* print version */
	wr_printf_prefix("Wire %s, protocol %s, %s, readline %s\n",
		WR_PACKAGE_VERSION,
		WR_PROTOCOL_VERSION,
		SSLeay_version(SSLEAY_VERSION),
		rl_library_version);
}



/*
	/who
*/

void wr_cmd_who(int argc, char *argv[]) {
	wr_list_node_t	*node;
	wr_user_t		*user;
	unsigned int	length, max_length = 0;
	
	/* find max string length */
	WR_LIST_LOCK(wr_users);
	WR_LIST_FOREACH(wr_users, node, user) {
		length = strlen(user->nick);
		max_length = length > max_length ? length : max_length;
		
		length = strlen(user->login);
		max_length = length > max_length ? length : max_length;

		length = strlen(user->ip);
		max_length = length > max_length ? length : max_length;
	}

	/* print users */
	wr_printf_prefix("Users currently online:\n");
	
	WR_LIST_FOREACH(wr_users, node, user)
		wr_print_user(node->data, max_length);
	WR_LIST_UNLOCK(wr_users);
}
