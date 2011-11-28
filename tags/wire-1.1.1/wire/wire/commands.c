/* $Id$ */

/*
 *  Copyright (c) 2004-2006 Axel Andersson
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

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <openssl/ssl.h>
#include <readline/readline.h>
#include <wired/wired.h>

#include "client.h"
#include "commands.h"
#include "ignores.h"
#include "main.h"
#include "terminal.h"
#include "transfers.h"
#include "users.h"
#include "version.h"
#include "windows.h"

static unsigned int				wr_command_index(wi_string_t *);
static void						wr_command_usage(wi_string_t *);

static void						wr_cmd_ban(wi_array_t *);
static void						wr_cmd_broadcast(wi_array_t *);
static void						wr_cmd_cd(wi_array_t *);
static void						wr_cmd_charset(wi_array_t *);
static void						wr_cmd_clear(wi_array_t *);
static void						wr_cmd_clearnews(wi_array_t *);
static void						wr_cmd_close(wi_array_t *);
static void						wr_cmd_comment(wi_array_t *);
static void						wr_cmd_disconnect(wi_array_t *);
static void						wr_cmd_echo(wi_array_t *);
static void						wr_cmd_get(wi_array_t *);
static void						wr_cmd_help(wi_array_t *);
static void						wr_cmd_icon(wi_array_t *);
static void						wr_cmd_ignore(wi_array_t *);
static void						wr_cmd_info(wi_array_t *);
static void						wr_cmd_kick(wi_array_t *);
static void						wr_cmd_ls(wi_array_t *);
static void						wr_cmd_load(wi_array_t *);
static void						wr_cmd_log(wi_array_t *);
static void						wr_cmd_open(wi_array_t *);
static void						wr_cmd_me(wi_array_t *);
static void						wr_cmd_mkdir(wi_array_t *);
static void						wr_cmd_msg(wi_array_t *);
static void						wr_cmd_mv(wi_array_t *);
static void						wr_cmd_news(wi_array_t *);
static void						wr_cmd_nick(wi_array_t *);
static void						wr_cmd_ping(wi_array_t *);
static void						wr_cmd_post(wi_array_t *);
static void						wr_cmd_put(wi_array_t *);
static void						wr_cmd_pwd(wi_array_t *);
static void						wr_cmd_quit(wi_array_t *);
static void						wr_cmd_reply(wi_array_t *);
static void						wr_cmd_rm(wi_array_t *);
static void						wr_cmd_say(wi_array_t *);
static void						wr_cmd_save(wi_array_t *);
static void						wr_cmd_search(wi_array_t *);
static void						wr_cmd_serverinfo(wi_array_t *);
static void						wr_cmd_start(wi_array_t *);
static void						wr_cmd_stat(wi_array_t *);
static void						wr_cmd_status(wi_array_t *);
static void						wr_cmd_stop(wi_array_t *);
static void						wr_cmd_timestamp(wi_array_t *);
static void						wr_cmd_topic(wi_array_t *);
static void						wr_cmd_type(wi_array_t *);
static void						wr_cmd_unignore(wi_array_t *);
static void						wr_cmd_uptime(wi_array_t *);
static void						wr_cmd_version(wi_array_t *);
static void						wr_cmd_who(wi_array_t *);


static wr_commands_t			wr_commands[] = {
	{ "ban",
	  true, "<user> <message>",
	  true, 2, 1, WR_COMPLETER_NICKNAME,
	  wr_cmd_ban },
	{ "broadcast",
	  true, "<message>",
	  true, 1, 0, WR_COMPLETER_NICKNAME,
	  wr_cmd_broadcast },
	{ "cd",
	  true, "<path>",
	  true, 1, -1, WR_COMPLETER_DIRECTORY,
	  wr_cmd_cd },
	{ "charset",
	  true, "<charset>",
	  false, 1, -1, WR_COMPLETER_NONE,
	  wr_cmd_charset },
	{ "clear",
	  true, "",
	  false, 0, -1, WR_COMPLETER_NONE,
	  wr_cmd_clear },
	{ "clearnews",
	  true, "",
	  true, 0, -1, WR_COMPLETER_NONE,
	  wr_cmd_clearnews },
	{ "close",
	  true, "",	
	  false, 0, -1, WR_COMPLETER_NONE,
	  wr_cmd_close },
	{ "comment",
	  true, "<path> <comment>",
	  true, 1, 1, WR_COMPLETER_FILENAME,
	  wr_cmd_comment },
	{ "connect",
	  false, "<server> [-l <login>] [-p <password>] [-P <port>]",
	  false, 1, -1, WR_COMPLETER_NONE,
	  wr_cmd_open },
	{ "delete",
	  true, "<path>",
	  true, 1, -1, WR_COMPLETER_FILENAME,
	  wr_cmd_rm },
	{ "disconnect",
	  true, "",	
	  true, 0, -1, WR_COMPLETER_NONE,
	  wr_cmd_disconnect },
	{ "echo",
	  false, "<text>",
	  false, 1, 0, WR_COMPLETER_NONE,
	  wr_cmd_echo },
	{ "exit",
	  false, "",
	  false, 0, -1, WR_COMPLETER_NONE,
	  wr_cmd_quit },
	{ "get",
	  true, "<path>",
	  true, 1, -1, WR_COMPLETER_FILENAME,
	  wr_cmd_get },
	{ "help",
	  true, "[<command>]",
	  false, 0, -1, WR_COMPLETER_COMMAND,
	  wr_cmd_help },
	{ "icon",
	  true, "<path>",
	  false, 1, -1, WR_COMPLETER_LOCAL_FILENAME,
	  wr_cmd_icon },
	{ "ignore",
	  true, "[<nick>]",
	  false, 0, -1, WR_COMPLETER_NICKNAME,
	  wr_cmd_ignore },
	{ "ignores",
	  true, "[<nick>]",
	  false, 0, -1, WR_COMPLETER_NICKNAME,
	  wr_cmd_ignore },
	{ "info",
	  true, "<user>",
	  true, 1, -1, WR_COMPLETER_NICKNAME,
	  wr_cmd_info },
	{ "join",
	  false, "<server> [-l <login>] [-p <password>] [-P <port>]",
	  false, 1, -1, WR_COMPLETER_NONE,
	  wr_cmd_open },
	{ "kick",
	  true, "<user> <message>",
	  true, 1, 1, WR_COMPLETER_NICKNAME,
	  wr_cmd_kick },
	{ "load",
	  true, "<bookmark>",
	  false, 1, -1, WR_COMPLETER_BOOKMARK,
	  wr_cmd_load },
	{ "log",
	  true, "<filename>",
	  false, 1, -1, WR_COMPLETER_NONE,
	  wr_cmd_log },
	{ "ls",
	  true, "<path>",
	  true, 0, -1, WR_COMPLETER_DIRECTORY,
	  wr_cmd_ls },
	{ "me",
	  true, "<chat>",
	  true, 1, 0, WR_COMPLETER_NICKNAME,
	  wr_cmd_me },
	{ "mkdir",
	  true, "<path>",
	  true, 1, 0, WR_COMPLETER_FILENAME,
	  wr_cmd_mkdir },
	{ "move",
	  true, "<path> <path>",
	  true, 2, -1, WR_COMPLETER_FILENAME,
	  wr_cmd_mv },
	{ "msg",
	  true, "<user> <message>",
	  true, 2, 1, WR_COMPLETER_NICKNAME,
	  wr_cmd_msg },
	{ "mv",
	  true, "<path> <path>",
	  true, 2, -1, WR_COMPLETER_FILENAME,
	  wr_cmd_mv },
	{ "news",
	  true, "[-<number> | -ALL]",
	  true, 0, -1, WR_COMPLETER_NONE,
	  wr_cmd_news },
	{ "nick",
	  true, "<nick>",
	  false, 1, 0, WR_COMPLETER_NICKNAME,
	  wr_cmd_nick },
	{ "open",
	  true, "<server> [-l <login>] [-p <password>] [-P <port>]",
	  false, 1, -1, WR_COMPLETER_NONE,
	  wr_cmd_open },
	{ "ping",
	  true, "",
	  true, 0, -1, WR_COMPLETER_NONE,
	  wr_cmd_ping },
	{ "post",
	  true, "<message>",
	  true, 1, 0, WR_COMPLETER_NICKNAME,
	  wr_cmd_post },
	{ "put",
	  true, "<path>",
	  true, 1, -1, WR_COMPLETER_LOCAL_FILENAME,
	  wr_cmd_put },
	{ "pwd",
	  true, "",
	  true, 0, -1, WR_COMPLETER_NONE,
	  wr_cmd_pwd },
	{ "quit",
	  true, "",
	  false, 0, -1, WR_COMPLETER_NONE,
	  wr_cmd_quit },
	{ "remove",
	  true, "<path>",
	  true, 1, -1, WR_COMPLETER_FILENAME,
	  wr_cmd_rm },
	{ "reply",
	  true, "<message>",
	  true, 1, 0, WR_COMPLETER_NICKNAME,
	  wr_cmd_reply },
	{ "rm",
	  true, "<path>",
	  true, 1, -1, WR_COMPLETER_FILENAME,
	  wr_cmd_rm },
	{ "save",
	  true, "<bookmark>",
	  false, 1, -1, WR_COMPLETER_BOOKMARK,
	  wr_cmd_save },
	{ "say",
	  false, "<chat>",
	  true, 1, 0, WR_COMPLETER_NICKNAME,
	  wr_cmd_say },
	{ "search",
	  true, "<query>",
	  true, 1, -1, WR_COMPLETER_FILENAME,
	  wr_cmd_search },
	{ "server",
	  false, "<server> [-l <login>] [-p <password>] [-P <port>]",
	  false, 1, -1, WR_COMPLETER_NONE,
	  wr_cmd_open },
	{ "serverinfo",
	  true, "",
	  true, 0, -1, WR_COMPLETER_NONE,
	  wr_cmd_serverinfo },
	{ "start",
	  true, "<transfer>",
	  true, 1, -1, WR_COMPLETER_NONE,
	  wr_cmd_start },
	{ "stat",
	  true, "<path>",
	  true, 1, -1, WR_COMPLETER_FILENAME,
	  wr_cmd_stat },
	{ "status",
	  true, "<status>",
	  false, 1, 0, WR_COMPLETER_NONE,
	  wr_cmd_status },
	{ "stop",
	  true, "<transfer>",
	  true, 1, -1, WR_COMPLETER_NONE,
	  wr_cmd_stop },
	{ "timestamp",
	  true, "[<format>]",
	  false, 0, 0, WR_COMPLETER_NONE,
	  wr_cmd_timestamp },
	{ "topic",
	  true, "[<topic>]",
	  true, 0, 0, WR_COMPLETER_NICKNAME,
	  wr_cmd_topic },
	{ "type",
	  true, "<path> (folder | uploads | dropbox)",
	  true, 2, -1, WR_COMPLETER_FILENAME,
	  wr_cmd_type },
	{ "unignore",
	  true, "[<ignore> | <nick>]",
	  false, 0, -1, WR_COMPLETER_IGNORE,
	  wr_cmd_unignore },
	{ "uptime",
	  true, "",
	  false, 0, -1, WR_COMPLETER_NONE,
	  wr_cmd_uptime },
	{ "version",
	  true, "",
	  false, 0, -1, WR_COMPLETER_NONE,
	  wr_cmd_version },
	{ "who",
	  true, "",
	  true, 0, -1, WR_COMPLETER_NONE,
	  wr_cmd_who },
	{ "whois",
	  false, "<user>",
	  true, 1, -1, WR_COMPLETER_NICKNAME,
	  wr_cmd_info },
};

wi_string_t					*wr_last_command;


void wr_parse_file(wi_file_t *file) {
	wi_string_t		*string;
	
	while((string = wi_file_read_config_line(file)))
		wr_parse_command(string, false);
}



void wr_parse_command(wi_string_t *buffer, wi_boolean_t chat) {
	wi_array_t		*array = NULL;
	wi_string_t		*command = NULL, *arguments;
	unsigned int	index;	
	
	if(chat && !wi_string_has_prefix(buffer, WI_STR("/")))
		wi_string_insert_string_at_index(buffer, wr_connected ? WI_STR("say ") : WI_STR("echo "), 0);
	
	wi_parse_wire_command(buffer, &command, &arguments);
	
	index = wr_command_index(command);
	
	if(index == WI_NOT_FOUND) {
		wr_printf_prefix(WI_STR("%@: Command not recognized"), command);

		return;
	}
	
	if(wr_commands[index].connected && !wr_connected) {
		wr_printf_prefix(WI_STR("%@: %@"), command, WI_STR("Not connected"));

		return;
	}
	
	array = wi_autorelease(wi_array_init_with_argument_string(wi_array_alloc(), arguments, wr_commands[index].optindex));

	if(wi_array_count(array) < wr_commands[index].optargs) {
		wr_command_usage(command);

		return;
	}

	wi_release(wr_last_command);
	wr_last_command = wi_string_init_with_cstring(wi_string_alloc(), wr_commands[index].name);

	((*wr_commands[index].action) (array));
}



static unsigned int wr_command_index(wi_string_t *command) {
	const char		*cstring;
	unsigned int	i, max, length;

	cstring = wi_string_cstring(command);
	length = wi_string_length(command);
	max = WI_ARRAY_SIZE(wr_commands);

	for(i = 0; i < max; i++) {
		if(strncasecmp(cstring, wr_commands[i].name, length) == 0)
			return i;
	}

	return WI_NOT_FOUND;
}



static void wr_command_usage(wi_string_t *command) {
	unsigned int	index;

	index = wr_command_index(command);

	if(index == WI_NOT_FOUND) {
		wr_printf_prefix(WI_STR("%@: Command not recognized"), command);

		return;
	}

	wr_printf_prefix(WI_STR("Usage: %s %s"),
		wr_commands[index].name, wr_commands[index].usage);
}



wr_completer_t wr_command_completer(wi_string_t *buffer) {
	wi_string_t			*command, *arguments;
	wr_completer_t		completer;
	unsigned int		index;

	/* complete nicks if empty */
	if(wi_string_length(buffer) == 0 || !wi_string_has_prefix(buffer, WI_STR("/")))
		return WR_COMPLETER_NICKNAME;

	/* complete commands if beginning with slash and contains no spaces */
	if(wi_string_index_of_string(buffer, WI_STR(" "), 0) == WI_NOT_FOUND)
		return WR_COMPLETER_COMMAND;

	/* get command */
	wi_parse_wire_command(buffer, &command, &arguments);

	index = wr_command_index(command);

	if(index == WI_NOT_FOUND) {
		completer = WR_COMPLETER_NONE;
	} else {
		completer = wr_commands[index].completer;

		wi_release(wr_last_command);
		wr_last_command = wi_string_init_with_cstring(wi_string_alloc(), wr_commands[index].name);
	}

	return completer;
}



#pragma mark -

char * wr_readline_command_generator(const char *text, int state) {
	static int		i, max, length;
	const char		*name;
	char			*match;
	int				bytes;
	wi_boolean_t	help;

	if(state == 0) {
		i		= 0;
		max		= WI_ARRAY_SIZE(wr_commands);
		length	= strlen(text);
	}

	while(i < max) {
		name = wr_commands[i].name;
		help = wr_commands[i].help;

		i++;

		if(*text == '/') {
			if(help && strncasecmp(name, text + 1, length - 1) == 0) {
				bytes = strlen(name) + 2;
				match = wi_malloc(bytes);
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

static void wr_cmd_ban(wi_array_t *arguments) {
	wi_string_t		*nick, *message;
	wr_user_t		*user;

	nick = WI_ARRAY(arguments, 0);
	user = wr_user_with_nick(nick);

	if(!user) {
		wr_printf_prefix(WI_STR("ban: %@: Client not found"),
			nick);

		return;
	}

	if(wi_array_count(arguments) > 1)
		message = WI_ARRAY(arguments, 1);
	else
		message = NULL;
	
	wr_send_command(WI_STR("BAN %u%c%#@"),
		user->uid,		WR_FIELD_SEPARATOR,
		message);
}



/*
	/broadcast <message>
*/

static void wr_cmd_broadcast(wi_array_t *arguments) {
	wr_send_command(WI_STR("BROADCAST %#@"), WI_ARRAY(arguments, 0));
}



/*
	/cd <path>
*/

static void wr_cmd_cd(wi_array_t *arguments) {
	wi_string_t		*path;
	
	path = wr_files_full_path(WI_ARRAY(arguments, 0));
	wi_release(wr_files_cwd);
	wr_files_cwd = wi_retain(path);
	
	wr_printf_prefix(WI_STR("Changed directory to: %@"), wr_files_cwd);
}



/*
	/charset <charset>
*/

static void wr_cmd_charset(wi_array_t *arguments) {
	wi_string_encoding_t	*encoding;
	wi_string_t				*charset;
	int						options;
	
	charset = WI_ARRAY(arguments, 0);
	options = WI_STRING_ENCODING_IGNORE | WI_STRING_ENCODING_TRANSLITERATE;
	encoding = wi_string_encoding_init_with_charset(wi_string_encoding_alloc(),
													charset,
													options);
	
	if(!encoding) {
		wr_printf_prefix(WI_STR("charset: Could not use charset \"%@\": %m"), charset);
	} else {
		wi_release(wr_client_string_encoding);
		wr_client_string_encoding = wi_retain(encoding);
		
		wr_printf_prefix(WI_STR("Using character set %@"),
			charset);
	}
	
	wi_release(encoding);
}



/*
	/clear
*/

static void wr_cmd_clear(wi_array_t *arguments) {
	wr_terminal_clear();
}



/*
	/clearnews
*/

static void wr_cmd_clearnews(wi_array_t *arguments) {
	wr_send_command(WI_STR("CLEARNEWS"));
}



/*
	/close
*/

static void wr_cmd_close(wi_array_t *arguments) {
	if(wr_current_window == wr_console_window) {
		if(wr_connected)
			wr_disconnect();
		else
			wr_printf_prefix(WI_STR("%@: %@"), wr_last_command, WI_STR("Not connected"));
	} else {
		wr_windows_close_window(wr_current_window);
	}
}



/*
	/comment <path> <comment>
*/

static void wr_cmd_comment(wi_array_t *arguments) {
	wi_string_t		*path, *comment;
	
	path = wr_files_full_path(WI_ARRAY(arguments, 0));
	comment = wi_array_count(arguments) == 1 ? WI_STR("") : WI_ARRAY(arguments, 1);

	wr_send_command(WI_STR("COMMENT %#@%c%#@"),
		path,		WR_FIELD_SEPARATOR,
		comment);
}



/*
	/disconnect
*/

static void wr_cmd_disconnect(wi_array_t *arguments) {
	wr_disconnect();
}



/*
	/echo <text>
*/

static void wr_cmd_echo(wi_array_t *arguments) {
	wr_printf_prefix(WI_STR("%@"), WI_ARRAY(arguments, 0));
}



/*
	/get <path>
*/

static void wr_cmd_get(wi_array_t *arguments) {
	unsigned int		i, count;
	
	count = wi_array_count(arguments);
	
	for(i = 0; i < count; i++)
		wr_transfer_download(WI_ARRAY(arguments, i));
	
	wr_draw_transfers(true);
}



/*
	/help [<command>]
*/

static void wr_cmd_help(wi_array_t *arguments) {
	wi_string_t			*string;
	wi_size_t			size;
	unsigned int		i, x, max, length, max_length;

	if(wi_array_count(arguments) > 0) {
		wr_command_usage(WI_ARRAY(arguments, 0));
	} else {
		wr_printf_prefix(WI_STR("Commands:"));

		max = WI_ARRAY_SIZE(wr_commands) - 1;
		max_length = 0;

		for(i = 0; i < max; i++) {
			if(wr_commands[i].help) {
				length = strlen(wr_commands[i].name);
				max_length = WI_MAX(length, max_length);
			}
		}
		
		size = wi_terminal_size(wr_terminal);
		string = NULL;

		for(i = 0, x = 0; i < max; i++) {
			if(wr_commands[i].help) {
				if(!string)
					string = wi_string_init(wi_string_alloc());

				wi_string_append_format(string, WI_STR("   %s%*s"),
					wr_commands[i].name,
					max_length - strlen(wr_commands[i].name) + 1,
					" ");

				if(wi_terminal_width_of_string(wr_terminal, string) >=
				   size.width - max_length - max_length) {
					wr_printf(WI_STR("%@"), string);
					
					wi_release(string);
					string = NULL;
				}
			}
		}
		
		if(string) {
			wr_printf(WI_STR("%@"), string);
	
			wi_release(string);
		}
	}
}



/*
	/icon <path>
*/

static void wr_cmd_icon(wi_array_t *arguments) {
	wi_string_t		*path, *string;

	path = wi_string_by_normalizing_path(WI_ARRAY(arguments, 0));
	string = wi_string_init_with_contents_of_file(wi_string_alloc(), wi_string_by_normalizing_path(path));
	
	if(string) {
		wi_release(wr_icon);
		wr_icon = wi_retain(wi_string_base64(string));
		
		if(wr_connected)
			wr_send_command(WI_STR("ICON %u%c%#@"), 0, WR_FIELD_SEPARATOR, wr_icon);

		wi_release(string);
	} else {
		wr_printf_prefix(WI_STR("icon: %@: %m"), path);
	}
}



/*
	/ignore [<nick>]
*/

static void wr_cmd_ignore(wi_array_t *arguments) {
	wi_list_node_t	*node;
	wi_string_t		*string;
	wr_ignore_t		*ignore;

	if(wi_array_count(arguments) > 0) {
		string = WI_ARRAY(arguments, 0);
		ignore = wr_ignore_init_with_string(wr_ignore_alloc(), string);

		if(ignore) {
			wr_printf_prefix(WI_STR("Ignoring \"%@\""),
				wr_ignore_string(ignore));
			
			wi_list_append_data(wr_ignores, ignore);
			wi_release(ignore);
		} else {
			wr_printf_prefix(WI_STR("ignore: Could not compile regular expression \"%@\": %m"),
				string);
		}
	} else {
		wr_printf_prefix(WI_STR("Ignores:"));

		if(wi_list_count(wr_ignores) == 0) {
			wr_printf_block(WI_STR("(none)"));
		} else {
			WI_LIST_FOREACH(wr_ignores, node, ignore)
				wr_printf_block(WI_STR("%u: %@"), wr_ignore_id(ignore), wr_ignore_string(ignore));
		}
	}
}



/*
	/info <user>
*/

static void wr_cmd_info(wi_array_t *arguments) {
	wi_string_t		*nick;
	wr_user_t		*user;

	nick = WI_ARRAY(arguments, 0);
	user = wr_user_with_nick(nick);

	if(!user) {
		wr_printf_prefix(WI_STR("info: %@: Client not found"),
			nick);

		return;
	}

	wr_send_command(WI_STR("INFO %u"), user->uid);
}



/*
	/kick <user> <message>
*/

static void wr_cmd_kick(wi_array_t *arguments) {
	wi_string_t		*nick, *message;
	wr_user_t		*user;

	nick = WI_ARRAY(arguments, 0);
	user = wr_user_with_nick(nick);

	if(!user) {
		wr_printf_prefix(WI_STR("kick: %@: Client not found"),
			nick);

		return;
	}

	if(wi_array_count(arguments) > 1)
		message = WI_ARRAY(arguments, 1);
	else
		message = NULL;
	
	wr_send_command(WI_STR("KICK %u%c%#@"),
		user->uid,		WR_FIELD_SEPARATOR,
		message);
}



/*
	/ls <path>
*/

static void wr_cmd_ls(wi_array_t *arguments) {
	wr_clear_files();
	wr_ls_state = WR_LS_LISTING;

	if(wi_array_count(arguments) == 0)
		wr_files_ld = wi_retain(wr_files_cwd);
	else
		wr_files_ld = wi_retain(wr_files_full_path(WI_ARRAY(arguments, 0)));

	wr_send_command(WI_STR("LIST %@"), wr_files_ld);
}



/*
	/load <bookmark>
*/

static void wr_cmd_load(wi_array_t *arguments) {
	wi_string_t		*path;
	wi_file_t		*file;
	
	path = wi_user_home();
	wi_string_append_path_component(path, WI_STR(WR_WIRE_PATH));
	wi_string_append_path_component(path, WI_ARRAY(arguments, 0));
	
	file = wi_file_for_reading(path);
	
	if(file)
		wr_parse_file(file);
	else
		wr_printf_prefix(WI_STR("load: %@: %m"), path);
}



/*
	/log <filename>
*/

static void wr_cmd_log(wi_array_t *arguments) {
	wi_string_t		*path, *string;
	
	path = wi_user_home();
	wi_string_append_path_component(path, WI_ARRAY(arguments, 0));
	
	string = wi_copy(wi_terminal_buffer_string(wr_current_window->buffer));
	wi_string_append_string(string, WI_STR("\n"));
	
	if(!wi_string_write_to_file(string, path))
		wr_printf_prefix(WI_STR("log: %@: %m"), path);
	else
		wr_printf_prefix(WI_STR("log: \"%@\" saved"), path);
	
	wi_release(string);
}



/*
	/me <chat>
*/

static void wr_cmd_me(wi_array_t *arguments) {
	wr_send_command(WI_STR("ME %u%c%#@"),
		1,		WR_FIELD_SEPARATOR,
		WI_ARRAY(arguments, 0));
}



/*
	/mkdir <path>
*/

static void wr_cmd_mkdir(wi_array_t *arguments) {
	wi_string_t		*path;
	
	path = wr_files_full_path(WI_ARRAY(arguments, 0));

	wr_send_command(WI_STR("FOLDER %#@"), path);
}



/*
	/msg <user> <message>
*/

static void wr_cmd_msg(wi_array_t *arguments) {
	wr_user_t		*user;
	wr_window_t		*window;
	wi_string_t		*nick, *message;

	nick = WI_ARRAY(arguments, 0);
	user = wr_user_with_nick(nick);

	if(!user) {
		wr_printf_prefix(WI_STR("msg: %@: Client not found"),
			nick);

		return;
	}

	message = WI_ARRAY(arguments, 1);
	
	wr_send_command(WI_STR("MSG %u%c%#@"),
		user->uid,		WR_FIELD_SEPARATOR,
		message);
	
	window = wr_window_with_user(user);
	
	if(!window) {
		window = wr_window_init_with_user(wr_window_alloc(), user);
		wr_windows_add_window(window);
		wi_release(window);
	}

	wr_windows_show_window(window);
	wr_wprint_say(window, wr_nick, message);
}



/*
	/mv <path> <path>
*/

static void wr_cmd_mv(wi_array_t *arguments) {
	wi_string_t		*from, *to;
	
	from	= wr_files_full_path(WI_ARRAY(arguments, 0));
	to		= wr_files_full_path(WI_ARRAY(arguments, 1));

	wr_send_command(WI_STR("MOVE %#@%c%#@"),
		from,		WR_FIELD_SEPARATOR,
		to);
}



/*
	/news
*/

static void wr_cmd_news(wi_array_t *arguments) {
	wi_string_t		*limit, *value;
	
	if(wi_array_count(arguments) == 0) {
		wr_news_limit = 10;
	} else {
		limit = WI_ARRAY(arguments, 0);
		
		if(!wi_string_has_prefix(limit, WI_STR("-"))) {
			wr_command_usage(WI_STR("news"));
			
			return;
		}
		
		value = wi_string_substring_from_index(limit, 1);
		
		if(wi_is_equal(value, WI_STR("ALL")))
			wr_news_limit = -1;
		else
			wr_news_limit = wi_string_int32(value);
		
		if(wr_news_limit == 0) {
			wr_command_usage(WI_STR("news"));

			return;
		}
	}
	
	wr_send_command(WI_STR("NEWS"));
}



/*
	/nick <name>
*/

static void wr_cmd_nick(wi_array_t *arguments) {
	wi_string_t		*nick;
	
	nick = WI_ARRAY(arguments, 0);
	
	if(!wi_is_equal(nick, wr_nick)) {
		wi_release(wr_nick);
		wr_nick = wi_retain(nick);
		
		wr_draw_divider();
		
		if(wr_connected)
			wr_send_command(WI_STR("NICK %#@"), wr_nick);
	}
}



/*
	/open <server> [-l <login>] [-p <password>]
*/

static void wr_cmd_open(wi_array_t *arguments) {
	wi_string_t		*login, *password, *host;
	wi_url_t		*url;
	const char		**argv;
	unsigned int	argc, i, port;
	int				ch;
	
	url = NULL;
	login = password = NULL;
	port = 0;
	
	argc = wi_array_count(arguments);
	argv = wi_array_argv(arguments);
	
	wi_getopt_reset();

	while((ch = getopt(argc, (char **) argv, "hl:P:p:")) != -1) {
		switch(ch) {
			case 'l':
				login = wi_string_with_cstring(optarg);
				break;

			case 'P':
				port = wi_string_uint32(wi_string_with_cstring(optarg));
				break;

			case 'p':
				password = wi_string_with_cstring(optarg);
				break;

			case '?':
			case 'h':
			default:
				wr_command_usage(WI_STR("open"));

				return;
				break;
		}
	}
	
	for(i = 0; i < argc; i++)
		free((char *) argv[i]);
	
	free(argv);
	
	url = wi_autorelease(wi_url_init_with_string(wi_url_alloc(), WI_ARRAY(arguments, 0)));
	host = wi_url_host(url);
	
	if(port == 0)
		port = wi_url_port(url);

	if(wi_string_length(host) == 0) {
		wr_command_usage(WI_STR("open"));
		
		return;
	}
	
	wr_connect(host, port, login, password);
}



/*
	/ping
*/

static void wr_cmd_ping(wi_array_t *arguments) {
	wr_ping_time = wi_time_interval();
	
	wr_send_command(WI_STR("PING"));
}



/*
	/post <message>
*/

static void wr_cmd_post(wi_array_t *arguments) {
	wr_send_command(WI_STR("POST %#@"), WI_ARRAY(arguments, 0));
}



/*
	/put <path>
*/

static void wr_cmd_put(wi_array_t *arguments) {
	unsigned int		i, count;
	
	count = wi_array_count(arguments);
	
	for(i = 0; i < count; i++)
		wr_transfer_upload(WI_ARRAY(arguments, i));
	
	wr_draw_transfers(true);
}



/*
	/pwd
*/

static void wr_cmd_pwd(wi_array_t *arguments) {
	wr_printf_prefix(WI_STR("Current working directory: %@"), wr_files_cwd);
}



/*
	/quit
*/

static void wr_cmd_quit(wi_array_t *arguments) {
	wr_running = 0;
}




/*
	/reply <message>
*/

static void wr_cmd_reply(wi_array_t *arguments) {
	wr_user_t	*user;

	if(wr_reply_uid == 0) {
		wr_printf_prefix(WI_STR("reply: No one has sent you a message yet"));

		return;
	}

	user = wr_user_with_uid(wr_reply_uid);

	if(!user) {
		wr_printf_prefix(WI_STR("reply: Client not found"));

		return;
	}

	wr_send_command(WI_STR("MSG %u%c%#@"),
		user->uid,		WR_FIELD_SEPARATOR,
		WI_ARRAY(arguments, 0));

	wr_printf_prefix(WI_STR("Sent private message to %@"), user->nick);
}



/*
	/rm <path>
*/

static void wr_cmd_rm(wi_array_t *arguments) {
	wi_string_t		*path;
	
	path = wr_files_full_path(WI_ARRAY(arguments, 0));

	wr_send_command(WI_STR("DELETE %#@"), path);
}



/*
	/say <chat>
*/

static void wr_cmd_say(wi_array_t *arguments) {
	wi_string_t		*chat;
	
	chat = WI_ARRAY(arguments, 0);
	
	switch(wr_current_window->type) {
		case WR_WINDOW_TYPE_CHAT:
			wr_send_command(WI_STR("SAY %u%c%#@"),
				wr_current_window->cid,		WR_FIELD_SEPARATOR,
				chat);
			break;
			
		case WR_WINDOW_TYPE_USER:
			wr_send_command(WI_STR("MSG %u%c%#@"),
				wr_current_window->uid,		WR_FIELD_SEPARATOR,
				chat);
			
			wr_wprint_say(wr_current_window, wr_nick, chat);
			break;
	}
}



/*
	/search <query>
*/

static void wr_cmd_search(wi_array_t *arguments) {
	wr_clear_files();
	
	wr_send_command(WI_STR("SEARCH %#@"), WI_ARRAY(arguments, 0));
}



/*
	/serverinfo
*/

static void wr_cmd_serverinfo(wi_array_t *arguments) {
	wr_print_server_info();
}



/*
	/save <bookmark>
*/

static void wr_cmd_save(wi_array_t *arguments) {
	wi_file_t		*file;
	wi_string_t		*path;

	path = wi_user_home();
	wi_string_append_path_component(path, WI_STR(WR_WIRE_PATH));
	wi_string_append_path_component(path, WI_ARRAY(arguments, 0));
	
	file = wi_file_for_writing(path);

	if(!file) {
		wr_printf_prefix(WI_STR("save: %@: %m"), path);

		return;
	}
	
	wi_file_write(file, WI_STR("charset %@\n"), wi_string_encoding_charset(wr_client_string_encoding));
	wi_file_write(file, WI_STR("nick %@\n"), wr_nick);

	if(wi_string_length(wr_status) > 0)
		wi_file_write(file, WI_STR("status %@\n"), wr_status);

	if(wr_connected) {
		if(wi_string_length(wr_login) > 0 && wi_string_length(wr_password) > 0)
			wi_file_write(file, WI_STR("open %@ -l %@ -p %@\n"), wr_host, wr_login, wr_password);
		else if(wi_string_length(wr_login) > 0)
			wi_file_write(file, WI_STR("open %@ -l %@\n"), wr_host, wr_login);
		else
			wi_file_write(file, WI_STR("open %@\n"), wr_host);
	}

	wr_printf_prefix(WI_STR("save: \"%@\" saved"), path);
}



/*
	/start <transfer>
*/

static void wr_cmd_start(wi_array_t *arguments) {
	wr_transfer_t	*transfer;
	wr_tid_t		tid;

	tid = wi_string_uint32(WI_ARRAY(arguments, 0));
	
	if(tid == 0) {
		wr_command_usage(WI_STR("stop"));

		return;
	}

	transfer = wr_transfer_with_tid(tid);

	if(!transfer) {
		wr_printf_prefix(WI_STR("start: Could not find transfer with id %u"),
			tid);

		return;
	}

	if(transfer->state == WR_TRANSFER_RUNNING) {
		wr_printf_prefix(WI_STR("start: Transfer of \"%@\" has already started"),
			transfer->name);

		return;
	}
	
	wr_transfer_start(transfer);
}



/*
	/stat <path>
*/

static void wr_cmd_stat(wi_array_t *arguments) {
	wi_string_t		*path;
	
	path = wr_files_full_path(WI_ARRAY(arguments, 0));
	
	wr_stat_state = WR_STAT_FILE;
	wr_send_command(WI_STR("STAT %@"), path);
}



/*
	/status <status>
*/

static void wr_cmd_status(wi_array_t *arguments) {
	wi_string_t		*status;
	
	status = WI_ARRAY(arguments, 0);
	
	if(!wi_is_equal(status, wr_status)) {
		wi_release(wr_status);
		wr_status = wi_retain(status);
		
		if(wr_connected)
			wr_send_command(WI_STR("STATUS %#@"), wr_status);
	}
}



/*
	/stop <transfer>
*/

static void wr_cmd_stop(wi_array_t *arguments) {
	wr_transfer_t	*transfer;
	wr_tid_t		tid;

	tid = wi_string_uint32(WI_ARRAY(arguments, 0));
	
	if(tid == 0) {
		wr_command_usage(WI_STR("stop"));

		return;
	}

	transfer = wr_transfer_with_tid(tid);

	if(!transfer) {
		wr_printf_prefix(WI_STR("stop: Could not find transfer with id %u"),
			tid);

		return;
	}

	if(transfer->state == WR_TRANSFER_RUNNING) {
		wr_printf_prefix(WI_STR("Aborting transfer of \"%@\""),
			transfer->name);
	} else {
		wr_printf_prefix(WI_STR("Removing transfer of \"%@\""),
			transfer->name);
	}

	wr_transfer_stop(transfer);

	wr_draw_transfers(true);
}



/*
	/timestamp <format>
*/

static void wr_cmd_timestamp(wi_array_t *arguments) {
	if(wi_array_count(arguments) == 0) {
		wi_release(wr_timestamp_format);
		wr_timestamp_format = wi_retain(WI_STR(""));
	} else {
		wi_release(wr_timestamp_format);
		wr_timestamp_format = wi_retain(WI_ARRAY(arguments, 0));
	}
}



/*
	/topic <topic>
*/

static void wr_cmd_topic(wi_array_t *arguments) {
	if(wi_array_count(arguments) == 0) {
		wr_print_topic();
	} else {
		wr_send_command(WI_STR("TOPIC %u%c%#@"),
			1,		WR_FIELD_SEPARATOR,
			WI_ARRAY(arguments, 0));
	}
}



/*
	/type <path> <type>
*/

static void wr_cmd_type(wi_array_t *arguments) {
	wi_string_t			*path, *string;
	wr_file_type_t		type;

	path = wr_files_full_path(WI_ARRAY(arguments, 0));
	string = WI_ARRAY(arguments, 1);

	if(wi_is_equal(string, WI_STR("folder")))
		type = WR_FILE_DIRECTORY;
	else if(wi_is_equal(string, WI_STR("uploads")))
		type = WR_FILE_UPLOADS;
	else if(wi_is_equal(string, WI_STR("dropbox")))
		type = WR_FILE_DROPBOX;
	else {
		wr_command_usage(WI_STR("type"));

		return;
	}

	wr_send_command(WI_STR("TYPE %#@%c%u"),
		path,		WR_FIELD_SEPARATOR,
		type);
}



/*
	/unignore [<ignore> | <nick>]
*/

static void wr_cmd_unignore(wi_array_t *arguments) {
	wi_list_node_t	*node;
	wi_string_t		*string;
	wr_ignore_t		*ignore;
	wr_iid_t		iid;

	if(wi_array_count(arguments) > 0) {
		string = WI_ARRAY(arguments, 0);
		iid = wi_string_uint32(string);
		
		if(iid > 0)
			ignore = wr_ignore_with_iid(iid);
		else
			ignore = wr_ignore_with_string(string);
		
		if(ignore) {
			wr_printf_prefix(WI_STR("No longer ignoring \"%@\""),
				wr_ignore_string(ignore));
			
			wi_list_remove_data(wr_ignores, ignore);
		} else {
			wr_printf_prefix(WI_STR("No ignore matching \"%@\""), string);
		}
	} else {
		wr_printf_prefix(WI_STR("Ignores:"));

		if(wi_list_count(wr_ignores) == 0) {
			wr_printf_block(WI_STR("(none)"));
		} else {
			WI_LIST_FOREACH(wr_ignores, node, ignore)
				wr_printf_block(WI_STR("%u: %@"), wr_ignore_id(ignore), wr_ignore_string(ignore));
		}
	}
}



/*
	/uptime
*/

static void wr_cmd_uptime(wi_array_t *arguments) {
	wi_string_t			*string;
	wi_time_interval_t	interval;

	interval	= wi_date_time_interval_since_now(wr_start_date);
	string		= wi_time_interval_string(interval);

	wr_printf_prefix(WI_STR("Up %@, received %.2f KB, transferred %.2f KB"),
		string,
		(double) wr_received_bytes / 1024.0,
		(double) wr_transferred_bytes / 1024.0);
	
	wi_release(string);
}



/*
	/version
*/

static void wr_cmd_version(wi_array_t *arguments) {
	wr_printf_prefix(WI_STR("Wire %@, protocol %@, %s, readline %s"),
		wr_version_string,
		wr_protocol_version_string,
		SSLeay_version(SSLEAY_VERSION),
		rl_library_version);
}



/*
	/who
*/

static void wr_cmd_who(wi_array_t *arguments) {
	wr_print_users();
}
