/* $Id$ */

/*
 *  Copyright (c) 2004-2011 Axel Andersson
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
#include <readline/readline.h>
#include <wired/wired.h>

#include "client.h"
#include "commands.h"
#include "ignores.h"
#include "main.h"
#include "spec.h"
#include "terminal.h"
#include "users.h"
#include "windows.h"

struct _wr_commands {
	const char							*name;

	wi_boolean_t						help;
	const char							*description;
	const char							*usage;

	wi_boolean_t						connected;
	wi_uinteger_t						optargs;
	wi_integer_t						optindex;
	wr_completer_t						completer;

	void								(*action)(wi_array_t *);
};
typedef struct _wr_commands				wr_commands_t;


static wi_uinteger_t					wr_commands_index_for_command(wi_string_t *);
static void								wr_commands_print_usage_for_command(wi_string_t *);
static void								wr_commands_split_command(wi_string_t *, wi_string_t **, wi_string_t **);
static void								wr_commands_send_message(wi_p7_message_t *, wi_string_t *);

static void								wr_command_broadcast(wi_array_t *);
static void								wr_command_charset(wi_array_t *);
static void								wr_command_clear(wi_array_t *);
static void								wr_command_close(wi_array_t *);
static void								wr_command_disconnect(wi_array_t *);
static void								wr_command_echo(wi_array_t *);
static void								wr_command_help(wi_array_t *);
static void								wr_command_icon(wi_array_t *);
static void								wr_command_ignore(wi_array_t *);
static void								wr_command_info(wi_array_t *);
static void								wr_command_invite(wi_array_t *);
static void								wr_command_load(wi_array_t *);
static void								wr_command_log(wi_array_t *);
static void								wr_command_open(wi_array_t *);
static void								wr_command_me(wi_array_t *);
static void								wr_command_msg(wi_array_t *);
static void								wr_command_nick(wi_array_t *);
static void								wr_command_privchat(wi_array_t *);
static void								wr_command_quit(wi_array_t *);
static void								wr_command_say(wi_array_t *);
static void								wr_command_save(wi_array_t *);
static void								wr_command_serverinfo(wi_array_t *);
static void								wr_command_status(wi_array_t *);
static void								wr_command_timestamp(wi_array_t *);
static void								wr_command_topic(wi_array_t *);
static void								wr_command_unignore(wi_array_t *);
static void								wr_command_uptime(wi_array_t *);
static void								wr_command_version(wi_array_t *);
static void								wr_command_who(wi_array_t *);


#define WR_COMMAND_INFO_DESCRIPTION		"Get info for the user"
#define WR_COMMAND_INFO_USAGE			"<user>"

#define WR_COMMAND_OPEN_DESCRIPTION		"Connect to a server"
#define WR_COMMAND_OPEN_USAGE			"[-l <login>] [-p <password>] [-P <port>] <server>"

#define WR_COMMAND_QUIT_DESCRIPTION		"Quit wire"
#define WR_COMMAND_QUIT_USAGE			""

static wr_commands_t			wr_commands[] = {
	{ "broadcast",
	  true, "Broadcast a message to all users", "<message>",
	  true, 1, 0, WR_COMPLETER_NICKNAME,
	  wr_command_broadcast },
	{ "charset",
	  true, "Set the character set that is used to convert text from the server", "<charset>",
	  false, 1, -1, WR_COMPLETER_NONE,
	  wr_command_charset },
	{ "clear",
	  true, "Clear all output", "",
	  false, 0, -1, WR_COMPLETER_NONE,
	  wr_command_clear },
	{ "close",
	  true, "Close the current window, or disconnect from the server if in main window", "",	
	  false, 0, -1, WR_COMPLETER_NONE,
	  wr_command_close },
	{ "connect",
	  false, WR_COMMAND_OPEN_DESCRIPTION, WR_COMMAND_OPEN_USAGE,
	  false, 1, -1, WR_COMPLETER_NONE,
	  wr_command_open },
	{ "disconnect",
	  true, "Disconnect from the server", "",	
	  true, 0, -1, WR_COMPLETER_NONE,
	  wr_command_disconnect },
	{ "echo",
	  false, "Print the string", "<text>",
	  false, 1, 0, WR_COMPLETER_NONE,
	  wr_command_echo },
	{ "exit",
	  false, WR_COMMAND_QUIT_DESCRIPTION, WR_COMMAND_QUIT_USAGE,
	  false, 0, -1, WR_COMPLETER_NONE,
	  wr_command_quit },
	{ "help",
	  true, "Print a list of commands, or help for a specific command", "[<command>]",
	  false, 0, -1, WR_COMPLETER_COMMAND,
	  wr_command_help },
	{ "icon",
	  true, "Load a custom icon from a 32x32 PNG image file", "<path>",
	  false, 1, -1, WR_COMPLETER_LOCAL_FILENAME,
	  wr_command_icon },
	{ "ignore",
	  true, "Add the user to the ignore list", "[<nick>]",
	  false, 0, -1, WR_COMPLETER_NICKNAME,
	  wr_command_ignore },
	{ "ignores",
	  true, "List ignores", "[<nick>]",
	  false, 0, -1, WR_COMPLETER_NICKNAME,
	  wr_command_ignore },
	{ "info",
	  true, WR_COMMAND_INFO_DESCRIPTION, WR_COMMAND_INFO_USAGE,
	  true, 1, -1, WR_COMPLETER_NICKNAME,
	  wr_command_info },
	{ "invite",
	  true, "Invite the user to the current private chat", "<user>",
	  true, 1, -1, WR_COMPLETER_NICKNAME,
	  wr_command_invite },
	{ "join",
	  false, WR_COMMAND_OPEN_DESCRIPTION, WR_COMMAND_OPEN_USAGE,
	  false, 1, -1, WR_COMPLETER_NONE,
	  wr_command_open },
	{ "load",
	  true, "Load the bookmark from the ~/.wire/ directory", "<bookmark>",
	  false, 1, -1, WR_COMPLETER_BOOKMARK,
	  wr_command_load },
	{ "log",
	  true, "Save a copy of the current output to a file", "<filename>",
	  false, 1, -1, WR_COMPLETER_NONE,
	  wr_command_log },
	{ "me",
	  true, "Say text as action chat", "<chat>",
	  true, 1, 0, WR_COMPLETER_NICKNAME,
	  wr_command_me },
	{ "msg",
	  true, "Send a private message to the user", "<user> <message>",
	  true, 2, 1, WR_COMPLETER_NICKNAME,
	  wr_command_msg },
	{ "nick",
	  true, "Set your current nick name", "<nick>",
	  false, 1, 0, WR_COMPLETER_NICKNAME,
	  wr_command_nick },
	{ "open",
	  true, WR_COMMAND_OPEN_DESCRIPTION, WR_COMMAND_OPEN_USAGE,
	  false, 1, -1, WR_COMPLETER_NONE,
	  wr_command_open },
	{ "privchat",
	  true, "Create a private chat, optionally inviting the user", "[<user>]",
	  true, 0, -1, WR_COMPLETER_NICKNAME,
	  wr_command_privchat },
	{ "quit",
	  true, WR_COMMAND_QUIT_DESCRIPTION, WR_COMMAND_QUIT_USAGE,
	  false, 0, -1, WR_COMPLETER_NONE,
	  wr_command_quit },
	{ "save",
	  true, "Save a bookmark to the ~/.wire/ directory", "<bookmark>",
	  false, 1, -1, WR_COMPLETER_BOOKMARK,
	  wr_command_save },
	{ "say",
	  false, "Say text", "<chat>",
	  true, 1, 0, WR_COMPLETER_NICKNAME,
	  wr_command_say },
	{ "server",
	  false, WR_COMMAND_OPEN_DESCRIPTION, WR_COMMAND_OPEN_USAGE,
	  false, 1, -1, WR_COMPLETER_NONE,
	  wr_command_open },
	{ "serverinfo",
	  true, "Print server info", "",
	  true, 0, -1, WR_COMPLETER_NONE,
	  wr_command_serverinfo },
	{ "status",
	  true, "Set your current status message", "<status>",
	  false, 0, 0, WR_COMPLETER_NONE,
	  wr_command_status },
	{ "timestamp",
	  true, "Set or disable the timestamp", "[<format>]",
	  false, 0, 0, WR_COMPLETER_NONE,
	  wr_command_timestamp },
	{ "topic",
	  true, "Set or print the chat topic", "[<topic>]",
	  true, 0, 0, WR_COMPLETER_NICKNAME,
	  wr_command_topic },
	{ "unignore",
	  true, "Remove the user or the ignore from the ignore list", "[<ignore> | <nick>]",
	  false, 0, -1, WR_COMPLETER_IGNORE,
	  wr_command_unignore },
	{ "uptime",
	  true, "Print uptime statistics for wire", "",
	  false, 0, -1, WR_COMPLETER_NONE,
	  wr_command_uptime },
	{ "version",
	  true, "Print version information for wire", "",
	  false, 0, -1, WR_COMPLETER_NONE,
	  wr_command_version },
	{ "who",
	  true, "Print the user list", "",
	  true, 0, -1, WR_COMPLETER_NONE,
	  wr_command_who },
	{ "whois",
	  false, WR_COMMAND_INFO_DESCRIPTION, WR_COMMAND_INFO_USAGE,
	  true, 1, -1, WR_COMPLETER_NICKNAME,
	  wr_command_info },
};


static wi_mutable_dictionary_t			*wr_commands_transactions;
static wi_p7_uint32_t					wr_commands_transaction;


void wr_commands_initialize(void) {
	wr_commands_transactions = wi_dictionary_init(wi_mutable_dictionary_alloc());
}



#pragma mark -

void wr_commands_parse_file(wi_file_t *file) {
	wi_string_t		*string;
	
	while((string = wi_file_read_config_line(file)))
		wr_commands_parse_command(string, false);
}



void wr_commands_parse_command(wi_string_t *buffer, wi_boolean_t chat) {
	wi_array_t		*array = NULL;
	wi_string_t		*command = NULL, *arguments;
	wi_uinteger_t	index;	
	
	if(chat && !wi_string_has_prefix(buffer, WI_STR("/")))
		buffer = wi_string_by_inserting_string_at_index(buffer, wr_connected ? WI_STR("say ") : WI_STR("echo "), 0);
	
	wr_commands_split_command(buffer, &command, &arguments);
	
	index = wr_commands_index_for_command(command);
	
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
		wr_commands_print_usage_for_command(command);

		return;
	}
	
	((*wr_commands[index].action) (array));
}



static wi_uinteger_t wr_commands_index_for_command(wi_string_t *command) {
	const char		*cstring;
	wi_uinteger_t	i, max, length;

	cstring = wi_string_cstring(command);
	length = wi_string_length(command);
	max = WI_ARRAY_SIZE(wr_commands);

	for(i = 0; i < max; i++) {
		if(strncasecmp(cstring, wr_commands[i].name, length) == 0)
			return i;
	}

	return WI_NOT_FOUND;
}



static void wr_commands_print_usage_for_command(wi_string_t *command) {
	wi_uinteger_t	index;

	index = wr_commands_index_for_command(command);

	if(index == WI_NOT_FOUND) {
		wr_printf_prefix(WI_STR("%@: Command not recognized"), command);

		return;
	}

	wr_printf_prefix(WI_STR("%s: %s"),
		wr_commands[index].name, wr_commands[index].description);
	
	wr_printf_prefix(WI_STR("Usage: %s %s"),
		wr_commands[index].name, wr_commands[index].usage);
}



static void wr_commands_split_command(wi_string_t *buffer, wi_string_t **out_command, wi_string_t **out_arguments) {
	wi_uinteger_t	index;
	
	index = wi_string_index_of_string(buffer, WI_STR(" "), 0);
	
	if(index != WI_NOT_FOUND) {
		*out_command	= wi_string_substring_to_index(buffer, index);
		*out_arguments	= wi_string_substring_from_index(buffer, index + 1);
	} else {
		*out_command	= wi_autorelease(wi_copy(buffer));
		*out_arguments	= wi_string();
	}
	
	if(wi_string_has_prefix(*out_command, WI_STR("/")))
		*out_command = wi_string_by_deleting_characters_to_index(*out_command, 1);
}



static void wr_commands_send_message(wi_p7_message_t *message, wi_string_t *command) {
	wi_p7_message_set_uint32_for_name(message, wr_commands_transaction, WI_STR("wired.transaction"));
	
	wi_mutable_dictionary_set_data_for_key(wr_commands_transactions, command, WI_INT32(wr_commands_transaction));
	
	wr_client_send_message(message);
	
	wr_commands_transaction++;
}



#pragma mark -

wi_string_t * wr_commands_command_for_message(wi_p7_message_t *message) {
	wi_p7_uint32_t		transaction;
	
	if(wi_p7_message_get_uint32_for_name(message, &transaction, WI_STR("wired.transaction")))
		return wi_dictionary_data_for_key(wr_commands_transactions, WI_INT32(transaction));
	
	return NULL;
}



wr_completer_t wr_commands_completer_for_command(wi_string_t *buffer) {
	wi_string_t			*command, *arguments;
	wr_completer_t		completer;
	wi_uinteger_t		index;

	if(wi_string_length(buffer) == 0 || !wi_string_has_prefix(buffer, WI_STR("/")))
		return WR_COMPLETER_NICKNAME;

	if(wi_string_index_of_string(buffer, WI_STR(" "), 0) == WI_NOT_FOUND)
		return WR_COMPLETER_COMMAND;

	wi_parse_wire_command(buffer, &command, &arguments);

	index = wr_commands_index_for_command(command);

	if(index == WI_NOT_FOUND)
		completer = WR_COMPLETER_NONE;
	else
		completer = wr_commands[index].completer;

	return completer;
}



#pragma mark -

char * wr_readline_command_generator(const char *text, int state) {
	static wi_integer_t		i, max, length;
	const char				*name;
	char					*match;
	wi_integer_t			bytes;
	wi_boolean_t			help;

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
	/broadcast <message>
*/

static void wr_command_broadcast(wi_array_t *arguments) {
	wi_p7_message_t		*message;
	
	message = wi_p7_message_with_name(WI_STR("wired.message.send_broadcast"), wr_p7_spec);
	wi_p7_message_set_string_for_name(message, WI_ARRAY(arguments, 0), WI_STR("wired.message.broadcast"));
	wr_commands_send_message(message, WI_STR("broadcast"));
}



/*
	/charset <charset>
*/

static void wr_command_charset(wi_array_t *arguments) {
	if(!wr_client_set_charset(WI_ARRAY(arguments, 0)))
		wr_printf_prefix(WI_STR("charset: Could not use charset \"%@\": %m"), WI_ARRAY(arguments, 0));
}



/*
	/clear
*/

static void wr_command_clear(wi_array_t *arguments) {
	wr_terminal_clear();
}



/*
	/close
*/

static void wr_command_close(wi_array_t *arguments) {
	wi_p7_message_t		*message;
	
	if(wr_window_is_public_chat(wr_current_window)) {
		if(wr_connected)
			wr_client_disconnect();
		else
			wr_printf_prefix(WI_STR("close: %@"), WI_STR("Not connected"));
	} else {
		if(wr_window_is_private_chat(wr_current_window)) {
			message = wi_p7_message_with_name(WI_STR("wired.chat.leave_chat"), wr_p7_spec);
			wi_p7_message_set_uint32_for_name(message, wr_chat_id(wr_window_chat(wr_current_window)), WI_STR("wired.chat.id"));
			wr_commands_send_message(message, WI_STR("close"));
		}
		
		wr_windows_close_window(wr_current_window);
	}
}



/*
	/disconnect
*/

static void wr_command_disconnect(wi_array_t *arguments) {
	wr_client_disconnect();
}



/*
	/echo <text>
*/

static void wr_command_echo(wi_array_t *arguments) {
	wr_printf_prefix(WI_STR("%@"), WI_ARRAY(arguments, 0));
}



/*
	/help [<command>]
*/

static void wr_command_help(wi_array_t *arguments) {
	wi_mutable_string_t		*string;
	wi_size_t				size;
	wi_uinteger_t			i, x, max, length, max_length;

	if(wi_array_count(arguments) > 0) {
		wr_commands_print_usage_for_command(WI_ARRAY(arguments, 0));
	} else {
		wr_printf_prefix(WI_STR("Commands:"));

		max			= WI_ARRAY_SIZE(wr_commands) - 1;
		max_length	= 0;

		for(i = 0; i < max; i++) {
			if(wr_commands[i].help) {
				length = strlen(wr_commands[i].name);
				max_length = WI_MAX(length, max_length);
			}
		}
		
		size		= wi_terminal_size(wr_terminal);
		string		= wi_mutable_string();

		for(i = 0, x = 0; i < max; i++) {
			if(wr_commands[i].help) {
				if(!string)
					string = wi_string_init(wi_string_alloc());

				wi_mutable_string_append_format(string, WI_STR("   %s%*s"),
					wr_commands[i].name,
					max_length - strlen(wr_commands[i].name) + 1,
					" ");

				if(wi_terminal_width_of_string(wr_terminal, string) >=
				   size.width - max_length - max_length) {
					wr_printf(WI_STR("%@"), string);
					
					wi_mutable_string_set_string(string, WI_STR(""));
				}
			}
		}
		
		if(wi_string_length(string) > 0)
			wr_printf(WI_STR("%@"), string);
	}
}



/*
	/icon <path>
*/

static void wr_command_icon(wi_array_t *arguments) {
	wi_p7_message_t		*message;
	wi_string_t			*path;
	wi_data_t			*data;

	path = wi_string_by_normalizing_path(WI_ARRAY(arguments, 0));
	data = wi_data_init_with_contents_of_file(wi_data_alloc(), path);
	
	if(data) {
		wi_release(wr_icon_path);
		wr_icon_path = wi_retain(path);
		
		wi_release(wr_icon);
		wr_icon = wi_retain(data);
		
		if(wr_connected) {
			message = wi_p7_message_with_name(WI_STR("wired.user.set_icon"), wr_p7_spec);
			wi_p7_message_set_data_for_name(message, wr_icon, WI_STR("wired.user.icon"));
			wr_commands_send_message(message, WI_STR("icon"));
		}

		wi_release(data);
	} else {
		wr_printf_prefix(WI_STR("icon: %@: %m"), path);
	}
}



/*
	/ignore [<nick>]
*/

static void wr_command_ignore(wi_array_t *arguments) {
	wi_enumerator_t	*enumerator;
	wi_string_t		*string;
	wr_ignore_t		*ignore;

	if(wi_array_count(arguments) > 0) {
		string = WI_ARRAY(arguments, 0);
		ignore = wr_ignore_init_with_string(wr_ignore_alloc(), string);

		if(ignore) {
			wr_printf_prefix(WI_STR("Ignoring \"%@\""),
				wr_ignore_string(ignore));
			
			wi_mutable_array_add_data(wr_ignores, ignore);
			wi_release(ignore);
		} else {
			wr_printf_prefix(WI_STR("ignore: Could not compile regular expression \"%@\": %m"),
				string);
		}
	} else {
		wr_printf_prefix(WI_STR("Ignores:"));

		if(wi_array_count(wr_ignores) == 0) {
			wr_printf_block(WI_STR("(none)"));
		} else {
			enumerator = wi_array_data_enumerator(wr_ignores);
			
			while((ignore = wi_enumerator_next_data(enumerator)))
				wr_printf_block(WI_STR("%u: %@"), wr_ignore_id(ignore), wr_ignore_string(ignore));
		}
	}
}



/*
	/info <user> [<user> ...]
*/

static void wr_command_info(wi_array_t *arguments) {
	wi_enumerator_t		*enumerator;
	wi_p7_message_t		*message;
	wi_string_t			*nick;
	wr_user_t			*user;
	
	enumerator = wi_array_data_enumerator(arguments);
	
	while((nick = wi_enumerator_next_data(enumerator))) {
		user = wr_chat_user_with_nick(wr_public_chat, nick);

		if(!user) {
			wr_printf_prefix(WI_STR("info: %@: Client not found"),
				nick);

			continue;
		}

		message = wi_p7_message_with_name(WI_STR("wired.user.get_info"), wr_p7_spec);
		wi_p7_message_set_uint32_for_name(message, wr_user_id(user), WI_STR("wired.user.id"));
		wr_commands_send_message(message, WI_STR("info"));
	}
}



/*
	/invite <user> [<user> ...]
*/

static void wr_command_invite(wi_array_t *arguments) {
	wi_enumerator_t		*enumerator;
	wi_p7_message_t		*message;
	wi_string_t			*nick;
	wr_user_t			*user;
	wr_chat_t			*chat;
	
	if(!wr_window_is_private_chat(wr_current_window)) {
		wr_printf_prefix(WI_STR("invite: Current window is not a private chat"));
		
		return;
	}
	
	chat			= wr_window_chat(wr_current_window);
	enumerator		= wi_array_data_enumerator(arguments);
	
	while((nick = wi_enumerator_next_data(enumerator))) {
		user = wr_chat_user_with_nick(wr_public_chat, nick);

		if(!user) {
			wr_printf_prefix(WI_STR("invite: %@: Client not found"),
				nick);

			continue;
		}
		
		message = wi_p7_message_with_name(WI_STR("wired.chat.invite_user"), wr_p7_spec);
		wi_p7_message_set_uint32_for_name(message, wr_user_id(user), WI_STR("wired.user.id"));
		wi_p7_message_set_uint32_for_name(message, wr_chat_id(chat), WI_STR("wired.chat.id"));
		wr_commands_send_message(message, WI_STR("invite"));
	}
}



/*
	/load <bookmark>
*/

static void wr_command_load(wi_array_t *arguments) {
	wi_mutable_string_t		*path;
	wi_file_t				*file;
	
	path = wi_user_home();
	path = wi_string_by_appending_path_component(path, WI_STR(WR_WIRE_PATH));
	path = wi_string_by_appending_path_component(path, WI_ARRAY(arguments, 0));
	
	file = wi_file_for_reading(path);
	
	if(file)
		wr_commands_parse_file(file);
	else
		wr_printf_prefix(WI_STR("load: %@: %m"), path);
}



/*
	/log <filename>
*/

static void wr_command_log(wi_array_t *arguments) {
	wi_mutable_string_t		*string;
	wi_string_t				*path;
	
	path = wi_user_home();
	path = wi_string_by_appending_path_component(path, WI_ARRAY(arguments, 0));

	string = wi_mutable_copy(wi_terminal_buffer_string(wr_window_buffer(wr_current_window)));

	wi_mutable_string_append_string(string, WI_STR("\n"));
	
	if(!wi_string_write_to_file(string, path))
		wr_printf_prefix(WI_STR("log: %@: %m"), path);
	else
		wr_printf_prefix(WI_STR("log: \"%@\" saved"), path);
	
	wi_release(string);
}



/*
	/me <chat>
*/

static void wr_command_me(wi_array_t *arguments) {
	wi_p7_message_t		*message;
	wi_string_t			*chat;
	
	chat = WI_ARRAY(arguments, 0);
	
	if(wr_window_is_chat(wr_current_window)) {
		message = wi_p7_message_with_name(WI_STR("wired.chat.send_me"), wr_p7_spec);
		wi_p7_message_set_uint32_for_name(message, wr_chat_id(wr_window_chat(wr_current_window)), WI_STR("wired.chat.id"));
		wi_p7_message_set_string_for_name(message, chat, WI_STR("wired.chat.me"));
		wr_commands_send_message(message, WI_STR("me"));
	}
}



/*
	/msg <user> <message>
*/

static void wr_command_msg(wi_array_t *arguments) {
	wi_p7_message_t		*message;
	wi_string_t			*nick;
	wr_user_t			*user;
	wr_window_t			*window;

	nick = WI_ARRAY(arguments, 0);
	user = wr_chat_user_with_nick(wr_public_chat, nick);

	if(!user) {
		wr_printf_prefix(WI_STR("msg: %@: Client not found"),
			nick);

		return;
	}
	
	message = wi_p7_message_with_name(WI_STR("wired.message.send_message"), wr_p7_spec);
	wi_p7_message_set_uint32_for_name(message, wr_user_id(user), WI_STR("wired.user.id"));
	wi_p7_message_set_string_for_name(message, WI_ARRAY(arguments, 1), WI_STR("wired.message.message"));
	wr_commands_send_message(message, WI_STR("msg"));
	
	window = wr_windows_window_with_user(user);
	
	if(!window) {
		window = wr_window_init_with_user(wr_window_alloc(), user);
		wr_windows_add_window(window);
		wi_release(window);
	}

	wr_windows_show_window(window);
	wr_wprint_say(window, wr_nick, WI_ARRAY(arguments, 1));
}



/*
	/nick <name>
*/

static void wr_command_nick(wi_array_t *arguments) {
	wi_p7_message_t		*message;
	wi_string_t			*nick;
	
	nick = WI_ARRAY(arguments, 0);
	
	if(!wi_is_equal(nick, wr_nick)) {
		wi_release(wr_nick);
		wr_nick = wi_retain(nick);
		
		wr_draw_divider();
		
		if(wr_connected) {
			message = wi_p7_message_with_name(WI_STR("wired.user.set_nick"), wr_p7_spec);
			wi_p7_message_set_string_for_name(message, nick, WI_STR("wired.user.nick"));
			wr_commands_send_message(message, WI_STR("nick"));
		}
	}
}



/*
	/open [-l <login>] [-p <password>] <server>
*/

static void wr_command_open(wi_array_t *arguments) {
	wi_mutable_array_t		*argv;
	wi_string_t				*login, *password, *host;
	wi_url_t				*url;
	const char				**xargv;
	wi_uinteger_t			port;
	int						ch;
	
	url			= NULL;
	login		= NULL;
	password	= NULL;
	port		= 0;

	argv = wi_autorelease(wi_mutable_copy(arguments));
	
	wi_mutable_array_insert_data_at_index(argv, WI_STR("open"), 0);
	
	xargv = wi_array_create_argv(argv);
	
	wi_getopt_reset();

	while((ch = getopt(wi_array_count(argv), (char **) xargv, "hl:P:p:")) != -1) {
		switch(ch) {
			case 'l':
				login = wi_string_with_cstring(optarg);
				break;

			case 'P':
				port = wi_string_uinteger(wi_string_with_cstring(optarg));
				break;

			case 'p':
				password = wi_string_with_cstring(optarg);
				break;

			case '?':
			case 'h':
			default:
				wr_commands_print_usage_for_command(WI_STR("open"));

				return;
				break;
		}
	}
	
	wi_array_destroy_argv(wi_array_count(argv), xargv);
	
	if((wi_uinteger_t) optind >= wi_array_count(argv)) {
		wr_commands_print_usage_for_command(WI_STR("open"));
		
		return;
	}
	
	url = wi_autorelease(wi_url_init_with_string(wi_url_alloc(), WI_ARRAY(argv, optind)));
	host = wi_url_host(url);
	
	if(port == 0)
		port = wi_url_port(url);
	
	if(wi_string_length(host) == 0) {
		wr_commands_print_usage_for_command(WI_STR("open"));
		
		return;
	}
	
	wr_client_connect(host, port, login, password);
}



/*
	/privchat [<user>]
*/

static void wr_command_privchat(wi_array_t *arguments) {
	wi_p7_message_t		*message;
	wi_string_t			*nick;
	wr_user_t			*user;
	
	if(wi_array_count(arguments) > 0) {
		nick = WI_ARRAY(arguments, 0);
		user = wr_chat_user_with_nick(wr_public_chat, nick);
		
		if(!user) {
			wr_printf_prefix(WI_STR("privchat: %@: Client not found"),
				nick);

			return;
		}
		
		wr_private_chat_invite_uid = wr_user_id(user);
	}
	
	message = wi_p7_message_with_name(WI_STR("wired.chat.create_chat"), wr_p7_spec);
	wr_commands_send_message(message, WI_STR("privchat"));
}



/*
	/quit
*/

static void wr_command_quit(wi_array_t *arguments) {
	wr_running = 0;
}




/*
	/save <bookmark>
 */

static void wr_command_save(wi_array_t *arguments) {
	wi_file_t		*file;
	wi_string_t		*path, *login, *password, *port;
	
	path = wi_user_home();
	path = wi_string_by_appending_path_component(path, WI_STR(WR_WIRE_PATH));
	path = wi_string_by_appending_path_component(path, WI_ARRAY(arguments, 0));
	
	file = wi_file_for_writing(path);
	
	if(!file) {
		wr_printf_prefix(WI_STR("save: %@: %m"), path);
		
		return;
	}
	
	wi_file_write_format(file, WI_STR("charset %@\n"), wi_string_encoding_charset(wr_client_string_encoding));
	wi_file_write_format(file, WI_STR("timestamp %@\n"), wr_timestamp_format);
	wi_file_write_format(file, WI_STR("nick %@\n"), wr_nick);
	
	if(wi_string_length(wr_status) > 0)
		wi_file_write_format(file, WI_STR("status %@\n"), wr_status);
	
	if(wr_icon_path)
		wi_file_write_format(file, WI_STR("icon %@\n"), wr_icon_path);
	
	if(wr_connected) {
		if(wi_string_length(wi_p7_socket_user_name(wr_p7_socket)) > 0)
			login = wi_string_with_format(WI_STR("-l %@"), wi_p7_socket_user_name(wr_p7_socket));
		else
			login = NULL;
		
		if(wi_string_length(wr_password) > 0)
			password = wi_string_with_format(WI_STR("-p %@"), wr_password);
		else
			password = NULL;
		
		if(wi_address_port(wi_socket_address(wr_socket)) != WR_PORT)
			port = wi_string_with_format(WI_STR("-P %u"), wi_address_port(wi_socket_address(wr_socket)));
		else
			port = NULL;
		
		wi_file_write_format(file, WI_STR("open %#@ %#@ %#@ %@\n"),
			login, password, port, wi_address_string(wi_socket_address(wr_socket)));
	}
	
	wr_printf_prefix(WI_STR("save: \"%@\" saved"), path);
}



/*
	/say <chat>
*/

static void wr_command_say(wi_array_t *arguments) {
	wi_p7_message_t		*message;
	wi_string_t			*chat;
	
	chat = WI_ARRAY(arguments, 0);
	
	if(wr_window_is_chat(wr_current_window)) {
		message = wi_p7_message_with_name(WI_STR("wired.chat.send_say"), wr_p7_spec);
		wi_p7_message_set_uint32_for_name(message, wr_chat_id(wr_window_chat(wr_current_window)), WI_STR("wired.chat.id"));
		wi_p7_message_set_string_for_name(message, chat, WI_STR("wired.chat.say"));
		wr_commands_send_message(message, WI_STR("say"));
	}
	else if(wr_window_is_user(wr_current_window)) {
		message = wi_p7_message_with_name(WI_STR("wired.message.send_message"), wr_p7_spec);
		wi_p7_message_set_uint32_for_name(message, wr_user_id(wr_window_user(wr_current_window)), WI_STR("wired.user.id"));
		wi_p7_message_set_string_for_name(message, chat, WI_STR("wired.message.message"));
		wr_commands_send_message(message, WI_STR("say"));
		
		wr_wprint_say(wr_current_window, wr_nick, chat);
	}
}



/*
	/serverinfo
*/

static void wr_command_serverinfo(wi_array_t *arguments) {
	wi_string_t			*string, *interval;

	wr_printf_prefix(WI_STR("Server info:"));

	wr_printf_block(WI_STR("Name:         %@"), wr_server_name(wr_server));
	wr_printf_block(WI_STR("Description:  %@"), wr_server_description(wr_server));

	interval	= wi_time_interval_string(wi_date_time_interval_since_now(wr_server_start_time(wr_server)));
	string		= wi_date_string_with_format(wr_server_start_time(wr_server), WI_STR("%a %b %e %T %Y"));

	wr_printf_block(WI_STR("Uptime:       %@, since %@"), interval, string);

	wr_printf_block(WI_STR("Files:        %u %@"),
		wr_server_files_count(wr_server),
		wr_server_files_count(wr_server) == 1
			? WI_STR("file")
			: WI_STR("files"));
	wr_printf_block(WI_STR("Size:         %@"), wr_string_for_bytes(wr_server_files_size(wr_server)));
	wr_printf_block(WI_STR("Version:      %@ %@ (%u) on %@ %@ (%@)"),
		wr_server_application_name(wr_server),
		wr_server_application_version(wr_server),
		wr_server_application_build(wr_server),
		wr_server_os_name(wr_server),
		wr_server_os_version(wr_server),
		wr_server_arch(wr_server));
	wr_printf_block(WI_STR("Protocol:     %@ %@"),
		wi_p7_socket_remote_protocol_name(wr_p7_socket),
		wi_p7_socket_remote_protocol_version(wr_p7_socket));
	wr_printf_block(WI_STR("Cipher:       %@/%u bits"),
		wi_cipher_name(wi_p7_socket_cipher(wr_p7_socket)),
		wi_cipher_bits(wi_p7_socket_cipher(wr_p7_socket)));
	wr_printf_block(WI_STR("Compression:  Yes, compression ratio %.2f"),
		wi_p7_socket_compression_ratio(wr_p7_socket));
}



/*
	/status <status>
*/

static void wr_command_status(wi_array_t *arguments) {
	wi_p7_message_t		*message;
	wi_string_t			*status;
	
	if(wi_array_count(arguments) > 0)
		status = WI_ARRAY(arguments, 0);
	else
		status = WI_STR("");
	
	if(!wi_is_equal(status, wr_status)) {
		wi_release(wr_status);
		wr_status = wi_retain(status);
		
		if(wr_connected) {
			message = wi_p7_message_with_name(WI_STR("wired.user.set_status"), wr_p7_spec);
			wi_p7_message_set_string_for_name(message, status, WI_STR("wired.user.status"));
			wr_commands_send_message(message, WI_STR("status"));
		}
	}
}



/*
	/timestamp [<format>]
*/

static void wr_command_timestamp(wi_array_t *arguments) {
	if(wi_array_count(arguments) == 0)
		wr_windows_set_timestamp_format(WI_STR(""));
	else
		wr_windows_set_timestamp_format(WI_ARRAY(arguments, 0));
}



/*
	/topic <topic>
*/

static void wr_command_topic(wi_array_t *arguments) {
	wi_p7_message_t		*message;
	
	if(wr_window_is_chat(wr_current_window)) {
		if(wi_array_count(arguments) == 0) {
			wr_print_topic();
		} else {
			message = wi_p7_message_with_name(WI_STR("wired.chat.set_topic"), wr_p7_spec);
			wi_p7_message_set_uint32_for_name(message, wr_chat_id(wr_window_chat(wr_current_window)), WI_STR("wired.chat.id"));
			wi_p7_message_set_string_for_name(message, WI_ARRAY(arguments, 0), WI_STR("wired.chat.topic.topic"));
			wr_commands_send_message(message, WI_STR("topic"));
		}
	}
}



/*
	/unignore [<ignore> | <nick>]
*/

static void wr_command_unignore(wi_array_t *arguments) {
	wi_enumerator_t	*enumerator;
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
			
			wi_mutable_array_remove_data(wr_ignores, ignore);
		} else {
			wr_printf_prefix(WI_STR("No ignore matching \"%@\""), string);
		}
	} else {
		wr_printf_prefix(WI_STR("Ignores:"));

		if(wi_array_count(wr_ignores) == 0) {
			wr_printf_block(WI_STR("(none)"));
		} else {
			enumerator = wi_array_data_enumerator(wr_ignores);
			
			while((ignore = wi_enumerator_next_data(enumerator)))
				wr_printf_block(WI_STR("%u: %@"), wr_ignore_id(ignore), wr_ignore_string(ignore));
		}
	}
}



/*
	/uptime
*/

static void wr_command_uptime(wi_array_t *arguments) {
	wi_string_t			*string;
	wi_time_interval_t	interval;

	interval	= wi_date_time_interval_since_now(wr_start_date);
	string		= wi_time_interval_string(interval);

	wr_printf_prefix(WI_STR("Up %@"), string);
}



/*
	/version
*/

static void wr_command_version(wi_array_t *arguments) {
	wr_printf_prefix(WI_STR("Wire %s (%u), protocol %@ %@"),
		WR_VERSION,
		WI_REVISION,
		wi_p7_spec_name(wr_p7_spec),
		wi_p7_spec_version(wr_p7_spec));
}



/*
	/who
*/

static void wr_command_who(wi_array_t *arguments) {
	if(wr_window_is_chat(wr_current_window))
		wr_print_users(wr_current_window);
}
