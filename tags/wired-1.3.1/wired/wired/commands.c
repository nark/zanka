/* $Id$ */

/*
 *  Copyright (c) 2003-2006 Axel Andersson
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

#include <string.h>
#include <wired/wired.h>

#include "accounts.h"
#include "banlist.h"
#include "clients.h"
#include "chats.h"
#include "commands.h"
#include "files.h"
#include "main.h"
#include "news.h"
#include "server.h"
#include "settings.h"
#include "trackers.h"
#include "transfers.h"
#include "version.h"

#include "clients.h"

struct _wd_commands {
	const char					*name;

	/* minimum state required */
	wd_client_state_t			state;

	/* minimum number of arguments required */
	unsigned int				args;

	/* activates idle clients? */
	wi_boolean_t				activate;

	void						(*action)(wi_array_t *);
};
typedef struct _wd_commands		wd_commands_t;


static void						wd_parse_command(wi_string_t *);
static unsigned int				wd_command_index(wi_string_t *);

static void						wd_cmd_ban(wi_array_t *);
static void						wd_cmd_banner(wi_array_t *);
static void						wd_cmd_broadcast(wi_array_t *);
static void						wd_cmd_clearnews(wi_array_t *);
static void						wd_cmd_client(wi_array_t *);
static void						wd_cmd_comment(wi_array_t *);
static void						wd_cmd_creategroup(wi_array_t *);
static void						wd_cmd_createuser(wi_array_t *);
static void						wd_cmd_decline(wi_array_t *);
static void						wd_cmd_delete(wi_array_t *);
static void						wd_cmd_deletegroup(wi_array_t *);
static void						wd_cmd_deleteuser(wi_array_t *);
static void						wd_cmd_dump(wi_array_t *);
static void						wd_cmd_editgroup(wi_array_t *);
static void						wd_cmd_edituser(wi_array_t *);
static void						wd_cmd_folder(wi_array_t *);
static void						wd_cmd_get(wi_array_t *);
static void						wd_cmd_groups(wi_array_t *);
static void						wd_cmd_hello(wi_array_t *);
static void						wd_cmd_icon(wi_array_t *);
static void						wd_cmd_info(wi_array_t *);
static void						wd_cmd_invite(wi_array_t *);
static void						wd_cmd_join(wi_array_t *);
static void						wd_cmd_kick(wi_array_t *);
static void						wd_cmd_leave(wi_array_t *);
static void						wd_cmd_list(wi_array_t *);
static void						wd_cmd_listrecursive(wi_array_t *);
static void						wd_cmd_me(wi_array_t *);
static void						wd_cmd_move(wi_array_t *);
static void						wd_cmd_msg(wi_array_t *);
static void						wd_cmd_news(wi_array_t *);
static void						wd_cmd_nick(wi_array_t *);
static void						wd_cmd_pass(wi_array_t *);
static void						wd_cmd_ping(wi_array_t *);
static void						wd_cmd_post(wi_array_t *);
static void						wd_cmd_privchat(wi_array_t *);
static void						wd_cmd_privileges(wi_array_t *);
static void						wd_cmd_put(wi_array_t *);
static void						wd_cmd_readgroup(wi_array_t *);
static void						wd_cmd_readuser(wi_array_t *);
static void						wd_cmd_say(wi_array_t *);
static void						wd_cmd_search(wi_array_t *);
static void						wd_cmd_stat(wi_array_t *);
static void						wd_cmd_status(wi_array_t *);
static void						wd_cmd_topic(wi_array_t *);
static void						wd_cmd_type(wi_array_t *);
static void						wd_cmd_user(wi_array_t *);
static void						wd_cmd_users(wi_array_t *);
static void						wd_cmd_who(wi_array_t *);


static wd_commands_t			wd_commands[] = {
 { "BAN",
   WD_CLIENT_STATE_LOGGED_IN,		2,		true,		wd_cmd_ban },
 { "BANNER",
   WD_CLIENT_STATE_LOGGED_IN,		0,		true,		wd_cmd_banner },
 { "BROADCAST",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_broadcast },
 { "CLEARNEWS",
   WD_CLIENT_STATE_LOGGED_IN,		0,		true,		wd_cmd_clearnews },
 { "CLIENT",
   WD_CLIENT_STATE_SAID_HELLO,		0,		true,		wd_cmd_client },
 { "COMMENT",
   WD_CLIENT_STATE_LOGGED_IN,		2,		true,		wd_cmd_comment },
 { "CREATEGROUP",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_creategroup },
 { "CREATEUSER",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_createuser },
 { "DECLINE",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_decline },
 { "DELETE",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_delete },
 { "DELETEGROUP",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_deletegroup },
 { "DELETEUSER",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_deleteuser },
 { "DUMP",
   WD_CLIENT_STATE_LOGGED_IN,		0,		true,		wd_cmd_dump },
 { "EDITGROUP",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_editgroup },
 { "EDITUSER",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_edituser },
 { "FOLDER",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_folder },
 { "GET",
   WD_CLIENT_STATE_LOGGED_IN,		2,		true,		wd_cmd_get },
 { "GROUPS",
   WD_CLIENT_STATE_LOGGED_IN,		0,		true,		wd_cmd_groups },
 { "HELLO",
   WD_CLIENT_STATE_CONNECTED,		0,		true,		wd_cmd_hello },
 { "ICON",
   WD_CLIENT_STATE_SAID_HELLO,		1,		true,		wd_cmd_icon },
 { "INFO",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_info },
 { "INVITE",
   WD_CLIENT_STATE_LOGGED_IN,		2,		true,		wd_cmd_invite },
 { "JOIN",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_join },
 { "KICK",
   WD_CLIENT_STATE_LOGGED_IN,		2,		true,		wd_cmd_kick },
 { "LEAVE",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_leave },
 { "LIST",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_list },
 { "LISTRECURSIVE",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_listrecursive },
 { "ME",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_me },
 { "MOVE",
   WD_CLIENT_STATE_LOGGED_IN,		2,		true,		wd_cmd_move },
 { "MSG",
   WD_CLIENT_STATE_LOGGED_IN,		2,		true,		wd_cmd_msg },
 { "NEWS",
   WD_CLIENT_STATE_LOGGED_IN,		0,		true,		wd_cmd_news },
 { "NICK",
   WD_CLIENT_STATE_SAID_HELLO,		1,		true,		wd_cmd_nick },
 { "PASS",
   WD_CLIENT_STATE_GAVE_USER,		1,		true,		wd_cmd_pass },
 { "PING",
   WD_CLIENT_STATE_CONNECTED,		0,		false,		wd_cmd_ping },
 { "POST",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_post },
 { "PRIVCHAT",
   WD_CLIENT_STATE_LOGGED_IN,		0,		true,		wd_cmd_privchat },
 { "PRIVILEGES",
   WD_CLIENT_STATE_LOGGED_IN,		0,		true,		wd_cmd_privileges },
 { "PUT",
   WD_CLIENT_STATE_LOGGED_IN,		3,		true,		wd_cmd_put },
 { "READGROUP",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_readgroup },
 { "READUSER",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_readuser },
 { "SAY",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_say },
 { "SEARCH",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_search },
 { "STAT",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_stat },
 { "STATUS",
   WD_CLIENT_STATE_SAID_HELLO,		1,		true,		wd_cmd_status },
 { "TOPIC",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_topic },
 { "TYPE",
   WD_CLIENT_STATE_LOGGED_IN,		2,		true,		wd_cmd_type },
 { "USER",
   WD_CLIENT_STATE_SAID_HELLO,		1,		true,		wd_cmd_user },
 { "USERS",
   WD_CLIENT_STATE_LOGGED_IN,		0,		true,		wd_cmd_users },
 { "WHO",
   WD_CLIENT_STATE_LOGGED_IN,		1,		true,		wd_cmd_who },
};


void wd_control_thread(wi_runtime_instance_t *argument) {
	wi_pool_t		*pool;
	wd_client_t		*client = argument;
	wi_string_t		*string;
	unsigned int	i = 0;
	int				state;
	
	pool = wi_pool_init(wi_pool_alloc());

	wd_clients_add_client(client);
	wd_client_set(client);

	while(client->state <= WD_CLIENT_STATE_LOGGED_IN) {
		if(!pool)
			pool = wi_pool_init(wi_pool_alloc());
		
		if(client->buffer_offset == 0) {
			do {
				state = wi_socket_wait(client->socket, 0.1);
			} while(state == 0 && client->state <= WD_CLIENT_STATE_LOGGED_IN);
			
			if(client->state > WD_CLIENT_STATE_LOGGED_IN) {
				/* invalid state */
				break;
			}

			if(state < 0) {
				if(wi_error_code() == EINTR) {
					/* got a signal */
					continue;
				} else {
					/* error in TCP communication */
					wi_log_err(WI_STR("Could not read from %@: %m"), client->ip);

					break;
				}
			}
		}

		wd_client_lock_socket(client);
		string = wi_socket_read_to_string(client->socket, 0.0, WI_STR(WD_MESSAGE_SEPARATOR_STR));
		wd_client_unlock_socket(client);
		
		if(!string || wi_string_length(string) == 0) {
			if(!string)
				wi_log_info(WI_STR("Could not read from %@: %m"), client->ip);
			
			break;
		}

		wd_parse_command(string);
		
		if(++i % 10 == 0) {
			wi_release(pool);
			pool = NULL;
		}
	}
	
	/* announce parting if client disconnected by itself */
	if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
		client->state = WD_CLIENT_STATE_DISCONNECTED;

		wd_broadcast_lock();
		wd_client_broadcast_leave(client, WD_PUBLIC_CID);
		wd_broadcast_unlock();
	}

	/* update status for clients logged in and above */
	if(client->state >= WD_CLIENT_STATE_LOGGED_IN) {
		wi_lock_lock(wd_status_lock);
		wd_current_users--;
		wd_write_status(true);
		wi_lock_unlock(wd_status_lock);
	}

	wi_log_info(WI_STR("Disconnect from %@"), client->ip);
	
	wi_socket_close(client->socket);
	
	wd_clients_remove_client(client);
	
	wi_release(pool);
}



#pragma mark -

static void wd_parse_command(wi_string_t *buffer) {
	wd_client_t		*client = wd_client();
	wi_array_t		*arguments;
	wi_string_t		*command;
	unsigned int	index;
	
	wi_parse_wired_command(buffer, &command, &arguments);

	index = wd_command_index(command);

	if(index == WI_NOT_FOUND) {
		wd_reply(501, WI_STR("Command Not Recognized"));

		return;
	}

	if(client->state < wd_commands[index].state)
		return;

	if(wi_array_count(arguments) < wd_commands[index].args) {
		wd_reply(503, WI_STR("Syntax Error"));

		return;
	}

	if(wd_commands[index].activate) {
		client->idle_time = wi_time_interval();

		if(client->idle) {
			client->idle = false;

			wd_broadcast_lock();
			wd_client_broadcast_status(client);
			wd_broadcast_unlock();
		}
	}
	
	((*wd_commands[index].action) (arguments));
}



static unsigned int wd_command_index(wi_string_t *command) {
	const char		*cstring;
	unsigned int	i, min, max;
	int				cmp;

	cstring = wi_string_cstring(command);
	min = 0;
	max = WI_ARRAY_SIZE(wd_commands) - 1;

	do {
		i = (min + max) / 2;
		cmp = strcasecmp(cstring, wd_commands[i].name);

		if(cmp == 0)
			return i;
		else if(cmp < 0 && i > 0)
			max = i - 1;
		else if(cmp > 0)
			min = i + 1;
		else
			break;
	} while(min <= max);

	return WI_NOT_FOUND;
}



#pragma mark -

/*
	BAN <uid> <reason>
*/

static void wd_cmd_ban(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wd_client_t		*peer;
	wd_uid_t		uid;
	
	if(!client->account->ban_users) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}

	uid = wi_string_uint32(WI_ARRAY(arguments, 0));
	peer = wd_client_with_uid(uid);

	if(!peer) {
		wd_reply(512, WI_STR("Client Not Found"));

		return;
	}

	if(peer->account->cannot_be_kicked) {
		wd_reply(515, WI_STR("Cannot Be Disconnected"));

		return;
	}

	wd_broadcast_lock();
	wd_broadcast(WD_PUBLIC_CID, 307, WI_STR("%u%c%u%c%#@"),
				 peer->uid,		WD_FIELD_SEPARATOR,
				 client->uid,	WD_FIELD_SEPARATOR,
				 WI_ARRAY(arguments, 1));
	wd_broadcast_unlock();

	wi_log_ll(WI_STR("%@/%@/%@ banned %@/%@/%@"),
		client->nick, client->login, client->ip,
		peer->nick, peer->login, peer->ip);

	wd_tempban(peer->ip);

	wi_lock_lock(peer->flag_lock);
	peer->state = WD_CLIENT_STATE_DISCONNECTED;
	wi_lock_unlock(peer->flag_lock);
}



/*
	BANNER
*/

static void wd_cmd_banner(wi_array_t *arguments) {
	wd_reply(203, WI_STR("%#@"), wd_banner);
}




/*
	BROADCAST <message>
*/

static void wd_cmd_broadcast(wi_array_t *arguments) {
	wd_client_t	*client = wd_client();

	if(!client->account->broadcast) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}

	wd_broadcast_lock();
	wd_broadcast(WD_PUBLIC_CID, 309, WI_STR("%u%c%#@"),
				 client->uid,	WD_FIELD_SEPARATOR,
				 WI_ARRAY(arguments, 0));
	wd_broadcast_unlock();
}



/*
	CLEARNEWS
*/

static void wd_cmd_clearnews(wi_array_t *arguments) {
	wd_client_t	*client = wd_client();

	if(!client->account->clear_news) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}

	wd_clear_news();
}



/*
	CLIENT <application-version>
*/

static void wd_cmd_client(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();

	if(client->state != WD_CLIENT_STATE_SAID_HELLO)
		return;

	client->version = wi_retain(WI_ARRAY(arguments, 0));
}



/*
	COMMENT <path> <comment>
*/

static void wd_cmd_comment(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wi_string_t		*path;

	if(!client->account->alter_files) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}
	
	path = WI_ARRAY(arguments, 0);

	if(!wd_files_path_is_valid(path)) {
		wd_reply(520, WI_STR("File or Directory Not Found"));

		return;
	}

	if(!client->account->view_dropboxes) {
		if(wd_files_path_is_dropbox(path)) {
			wd_reply(520, WI_STR("File or Directory Not Found"));

			return;
		}
	}

	wd_files_set_comment(wi_string_by_normalizing_path(path), WI_ARRAY(arguments, 1));
}



/*
	CREATEGROUP <...>
*/

static void wd_cmd_creategroup(wi_array_t *arguments) {
	wd_client_t			*client = wd_client();
	wd_account_t		*account;

	if(!client->account->create_accounts) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}
	
	account = wd_accounts_read_group(WI_ARRAY(arguments, 0));
	
	if(account) {
		wd_reply(514, WI_STR("Account Exists"));
		
		return;
	}
	
	account = wi_autorelease(wd_account_init_group_with_array(wd_account_alloc(), arguments));
	
	if(!wd_accounts_check_privileges(account)) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}
	
	if(wd_accounts_create_group(account)) {
		wi_log_ll(WI_STR("%@/%@/%@ created the group \"%@\""),
			client->nick, client->login, client->ip,
			account->name);
	}
}



/*
	CREATEUSER <...>
*/

static void wd_cmd_createuser(wi_array_t *arguments) {
	wd_client_t			*client = wd_client();
	wd_account_t		*account;

	if(!client->account->create_accounts) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}
	
	account = wd_accounts_read_user(WI_ARRAY(arguments, 0));
	
	if(account) {
		wd_reply(514, WI_STR("Account Exists"));
		
		return;
	}
	
	account = wi_autorelease(wd_account_init_user_with_array(wd_account_alloc(), arguments));
	
	if(!wd_accounts_check_privileges(account)) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}
	
	if(wd_accounts_create_user(account)) {
		wi_log_ll(WI_STR("%@/%@/%@ created the user \"%@\""),
			client->nick, client->login, client->ip,
			account->name);
	}
}



/*
	DECLINE <cid>
*/

static void wd_cmd_decline(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wd_chat_t		*chat;
	wd_cid_t		cid;
	
	cid = wi_string_uint32(WI_ARRAY(arguments, 0));
	chat = wd_chat_with_cid(cid);
	
	if(!chat)
		return;

	if(wd_chat_contains_client(chat, client))
		return;

	wd_broadcast_lock();
	wd_broadcast(chat->cid, 332, WI_STR("%u%c%u"),
				 chat->cid,		WD_FIELD_SEPARATOR,
				 client->uid);
	wd_broadcast_unlock();
}



/*
	DELETE <path>
*/

static void wd_cmd_delete(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wi_string_t		*path, *properpath;

	if(!client->account->delete_files) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}
	
	path = WI_ARRAY(arguments, 0);

	if(!wd_files_path_is_valid(path)) {
		wd_reply(520, WI_STR("File or Directory Not Found"));

		return;
	}

	if(!client->account->view_dropboxes) {
		if(wd_files_path_is_dropbox(path)) {
			wd_reply(520, WI_STR("File or Directory Not Found"));

			return;
		}
	}

	properpath = wi_string_by_normalizing_path(path);
	
	if(wd_files_delete_path(properpath)) {
		wi_log_ll(WI_STR("%@/%@/%@ deleted \"%@\""),
			client->nick, client->login, client->ip,
			properpath);
	}
}



/*
	DELETEGROUP <name>
*/

static void wd_cmd_deletegroup(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wi_string_t		*group;

	if(!client->account->delete_accounts) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}
	
	group = WI_ARRAY(arguments, 0);

	if(wd_accounts_delete_group(group)) {
		wd_accounts_clear_group(group);

		wi_log_ll(WI_STR("%@/%@/%@ deleted the group \"%@\""),
			client->nick, client->login, client->ip,
			group);
	}
}



/*
	DELETEUSER <name>
*/

static void wd_cmd_deleteuser(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wi_string_t		*user;

	if(!client->account->delete_accounts) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}
	
	user = WI_ARRAY(arguments, 0);

	if(wd_accounts_delete_user(user)) {
		wi_log_ll(WI_STR("%@/%@/%@ deleted the user \"%@\""),
			client->nick, client->login, client->ip,
			user);
	}
}



/*
	DUMP
*/

static void wd_cmd_dump(wi_array_t *arguments) {
	wd_dump_clients();
	wd_dump_chats();
	wd_dump_tempbans();
	wd_dump_trackers();
	wd_dump_transfers();
}



/*
	EDITGROUP <...>
*/

static void wd_cmd_editgroup(wi_array_t *arguments) {
	wd_client_t			*client = wd_client();
	wd_account_t		*account;

	if(!client->account->edit_accounts) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}
	
	account = wi_autorelease(wd_account_init_group_with_array(wd_account_alloc(), arguments));
	
	if(!wd_accounts_check_privileges(account)) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}
	
	if(wd_accounts_edit_group(account)) {
		wi_log_ll(WI_STR("%@/%@/%@ modified the group \"%@\""),
			client->nick, client->login, client->ip,
			account->name);
	}
}



/*
	EDITUSER <...>
*/

static void wd_cmd_edituser(wi_array_t *arguments) {
	wd_client_t			*client = wd_client();
	wd_account_t		*account;

	if(!client->account->edit_accounts) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}
	
	account = wi_autorelease(wd_account_init_user_with_array(wd_account_alloc(), arguments));
	
	if(!wd_accounts_check_privileges(account)) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}
	
	if(wd_accounts_edit_user(account)) {
		wi_log_ll(WI_STR("%@/%@/%@ modified the user \"%@\""),
			client->nick, client->login, client->ip,
			account->name);
	}
}



/*
	FOLDER <path>
*/

static void wd_cmd_folder(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wi_string_t		*path, *parentpath, *realpath, *properpath;
	wd_file_type_t	type;
	
	path = WI_ARRAY(arguments, 0);

	if(!wd_files_path_is_valid(path)) {
		wd_reply(520, WI_STR("File or Directory Not Found"));

		return;
	}

	if(!client->account->view_dropboxes) {
		if(wd_files_path_is_dropbox(path)) {
			wd_reply(520, WI_STR("File or Directory Not Found"));

			return;
		}
	}
	
	realpath	= wd_files_real_path(path);
	
	wi_string_resolve_aliases_in_path(realpath);
	
	parentpath	= wi_string_by_deleting_last_path_component(realpath);
	type		= wd_files_type(parentpath);

	if(type == WD_FILE_TYPE_UPLOADS || type == WD_FILE_TYPE_DROPBOX) {
		if(!client->account->upload) {
			wd_reply(516, WI_STR("Permission Denied"));

			return;
		}
	} else {
		if(!client->account->upload_anywhere &&
		   !client->account->create_folders) {
			wd_reply(516, WI_STR("Permission Denied"));
			
			return;
		}
	}

	properpath = wi_string_by_normalizing_path(path);

	if(wd_files_create_path(properpath, type)) {
		wi_log_ll(WI_STR("%@/%@/%@ created \"%@\""),
			client->nick, client->login, client->ip,
			properpath);
	}
}



/*
	GET <path> <offset>
*/

static void wd_cmd_get(wi_array_t *arguments) {
	wd_client_t			*client = wd_client();
	wi_string_t			*path, *properpath;
	wi_file_offset_t	offset;

	if(!client->account->download) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}
	
	path = WI_ARRAY(arguments, 0);

	if(!wd_files_path_is_valid(path)) {
		wd_reply(520, WI_STR("File or Directory Not Found"));

		return;
	}

	if(!client->account->view_dropboxes) {
		if(wd_files_path_is_dropbox(path)) {
			wd_reply(520, WI_STR("File or Directory Not Found"));

			return;
		}
	}

	if(!wd_transfers_can_queue(WD_TRANSFER_DOWNLOAD)) {
		wd_reply(523, WI_STR("Queue Limit Exceeded"));

		return;
	}
	
	properpath	= wi_string_by_normalizing_path(path);
	offset		= wi_string_uint64(WI_ARRAY(arguments, 1));

	wd_transfers_queue_download(properpath, offset);
}



/*
	GROUPS
*/

static void wd_cmd_groups(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();

	if(!client->account->edit_accounts) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}

	wd_reply_group_list();
}



/*
	HELLO
*/

static void wd_cmd_hello(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wi_string_t		*string;

	if(client->state != WD_CLIENT_STATE_CONNECTED)
		return;

	if(wd_ip_is_banned(client->ip)) {
		wd_reply(511, WI_STR("Banned"));
		wi_log_info(WI_STR("Connection from %@ denied, host is banned"),
			client->ip);

		client->state = WD_CLIENT_STATE_DISCONNECTED;
		return;
	}

	string = wi_date_iso8601_string(wd_start_date);

	wd_reply(200, WI_STR("%#@%c%#@%c%#@%c%#@%c%#@%c%u%c%llu"),
			 wd_server_version_string,		WD_FIELD_SEPARATOR,
			 wd_protocol_version_string,	WD_FIELD_SEPARATOR,
			 wd_settings.name,				WD_FIELD_SEPARATOR,
			 wd_settings.description,		WD_FIELD_SEPARATOR,
			 string,						WD_FIELD_SEPARATOR,
			 wd_files_unique_count,			WD_FIELD_SEPARATOR,
			 wd_files_unique_size);
	
	client->state = WD_CLIENT_STATE_SAID_HELLO;
}



/*
	ICON <icon> <image>
*/

static void wd_cmd_icon(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wd_icon_t		icon;

	icon = wi_string_uint32(WI_ARRAY(arguments, 0));

	/* set icon if changed */
	if(client->icon != icon) {
		client->icon = icon;

		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			wd_broadcast_lock();
			wd_client_broadcast_status(client);
			wd_broadcast_unlock();
		}
	}

	/* copy custom icon if changed */
	if(wi_array_count(arguments) > 1) {
		wi_release(client->image);
		client->image = wi_retain(WI_ARRAY(arguments, 1));

		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			wd_broadcast_lock();
			wd_broadcast(WD_PUBLIC_CID, 340, WI_STR("%u%c%#@"),
						 client->uid,	WD_FIELD_SEPARATOR,
						 client->image);
			wd_broadcast_unlock();
		}
	}
}



/*
	INFO <uid>
*/

static void wd_cmd_info(wi_array_t *arguments) {
	wd_client_t			*client = wd_client();
	wi_list_node_t		*node;
	wi_string_t			*info, *login, *idle, *downloads, *uploads;
	wd_client_t			*peer;
	wd_transfer_t		*transfer;
	wd_uid_t			uid;

	if(!client->account->get_user_info) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}

	uid = wi_string_uint32(WI_ARRAY(arguments, 0));
	peer = wd_client_with_uid(uid);

	if(!peer) {
		wd_reply(512, WI_STR("Client Not Found"));

		return;
	}
	
	downloads	= wi_string();
	uploads		= wi_string();

	wi_list_rdlock(wd_transfers);
	WI_LIST_FOREACH(wd_transfers, node, transfer) {
		if(transfer->client == peer && transfer->state == WD_TRANSFER_RUNNING) {
			if(!client->account->view_dropboxes) {
				if(wd_files_path_is_dropbox(transfer->path))
					continue;
			}
			
			info = wi_string_with_format(WI_STR("%#@%c%llu%c%llu%c%u"),
										 transfer->path,		WD_RECORD_SEPARATOR,
										 transfer->transferred,	WD_RECORD_SEPARATOR,
										 transfer->size,		WD_RECORD_SEPARATOR,
										 transfer->speed);
			
			if(transfer->type == WD_TRANSFER_DOWNLOAD) {
				if(wi_string_length(downloads) > 0)
					wi_string_append_format(downloads, WI_STR("%c"), WD_GROUP_SEPARATOR);

				wi_string_append_string(downloads, info);
			} else {
				if(wi_string_length(uploads) > 0)
					wi_string_append_format(uploads, WI_STR("%c"), WD_GROUP_SEPARATOR);

				wi_string_append_string(uploads, info);
			}
		}
	}
	wi_list_unlock(wd_transfers);
	
	login	= wi_date_iso8601_string(wi_date_with_time_interval(peer->login_time));
	idle	= wi_date_iso8601_string(wi_date_with_time_interval(peer->idle_time));

	wd_reply(308, WI_STR("%u%c%u%c%u%c%u%c%#@%c%#@%c%#@%c%#@%c%#@%c%#@%c%u%c%#@%c%#@%c%#@%c%#@%c%#@%c%#@"),
			 peer->uid,								WD_FIELD_SEPARATOR,
			 peer->idle,							WD_FIELD_SEPARATOR,
			 peer->admin,							WD_FIELD_SEPARATOR,
			 peer->icon,							WD_FIELD_SEPARATOR,
			 peer->nick,							WD_FIELD_SEPARATOR,
			 peer->login,							WD_FIELD_SEPARATOR,
			 peer->ip,								WD_FIELD_SEPARATOR,
			 peer->host,							WD_FIELD_SEPARATOR,
			 peer->version,							WD_FIELD_SEPARATOR,
			 wi_socket_cipher_name(peer->socket),	WD_FIELD_SEPARATOR,
			 wi_socket_cipher_bits(peer->socket),	WD_FIELD_SEPARATOR,
			 login,									WD_FIELD_SEPARATOR,
			 idle,									WD_FIELD_SEPARATOR,
			 downloads,								WD_FIELD_SEPARATOR,
			 uploads,								WD_FIELD_SEPARATOR,
			 peer->status,							WD_FIELD_SEPARATOR,
			 peer->image);
}



/*
	INVITE <uid> <cid>
*/

static void wd_cmd_invite(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wd_client_t		*peer;
	wd_chat_t		*chat;
	wd_uid_t		uid;
	wd_cid_t		cid;

	uid = wi_string_uint32(WI_ARRAY(arguments, 0));
	peer = wd_client_with_uid(uid);

	if(!peer) {
		wd_reply(512, WI_STR("Client Not Found"));

		return;
	}

	cid = wi_string_uint32(WI_ARRAY(arguments, 1));
	chat = wd_chat_with_cid(cid);

	if(!chat)
		return;

	if(!wd_chat_contains_client(chat, client))
		return;

	if(wd_chat_contains_client(chat, peer))
		return;

	wd_client_lock_socket(peer);
	wd_sreply(peer->socket, 331, WI_STR("%u%c%u"),
			  cid,		WD_FIELD_SEPARATOR,
			  client->uid);
	wd_client_unlock_socket(peer);
}



/*
	JOIN <cid>
*/

static void wd_cmd_join(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wd_chat_t		*chat;
	wd_cid_t		cid;

	cid = wi_string_uint32(WI_ARRAY(arguments, 0));
	chat = wd_chat_with_cid(cid);

	if(!chat)
		return;

	if(wd_chat_contains_client(chat, client))
		return;

	wd_chat_add_client(chat, client);
}



/*
	KICK <uid> <reason>
*/

static void wd_cmd_kick(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wd_client_t		*peer;
	wd_uid_t		uid;

	if(!client->account->kick_users) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}

	uid = wi_string_uint32(WI_ARRAY(arguments, 0));
	peer = wd_client_with_uid(uid);

	if(!peer) {
		wd_reply(512, WI_STR("Client Not Found"));

		return;
	}

	if(peer->account->cannot_be_kicked) {
		wd_reply(515, WI_STR("Cannot Be Disconnected"));

		return;
	}

	wd_broadcast_lock();
	wd_broadcast(WD_PUBLIC_CID, 306, WI_STR("%u%c%u%c%#@"),
				 peer->uid,		WD_FIELD_SEPARATOR,
				 client->uid,	WD_FIELD_SEPARATOR,
				 WI_ARRAY(arguments, 1));
	wd_broadcast_unlock();

	wi_log_ll(WI_STR("%@/%@/%@ kicked %@/%@/%@"),
		client->nick, client->login, client->ip,
		peer->nick, peer->login, peer->ip);

	wi_lock_lock(peer->flag_lock);
	peer->state = WD_CLIENT_STATE_DISCONNECTED;
	wi_lock_unlock(peer->flag_lock);
}



/*
	LEAVE <cid>
*/

static void wd_cmd_leave(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wd_chat_t		*chat;
	wd_cid_t		cid;

	cid = wi_string_uint32(WI_ARRAY(arguments, 0));

	if(cid == WD_PUBLIC_CID)
		return;

	chat = wd_chat_with_cid(cid);

	if(!chat)
		return;

	wd_chat_remove_client(chat, client);

	wd_broadcast_lock();
	wd_client_broadcast_leave(client, cid);
	wd_broadcast_unlock();
}



/*
	LIST <path>
*/

static void wd_cmd_list(wi_array_t *arguments) {
	wi_string_t		*path;
	
	path = WI_ARRAY(arguments, 0);
	
	if(!wd_files_path_is_valid(path)) {
		wd_reply(520, WI_STR("File or Directory Not Found"));

		return;
	}
	
	wd_files_list_path(wi_string_by_normalizing_path(path), false);
}



/*
	LISTRECURSIVE <path>
*/

static void wd_cmd_listrecursive(wi_array_t *arguments) {
	wi_string_t		*path;
	
	path = WI_ARRAY(arguments, 0);
	
	if(!wd_files_path_is_valid(path)) {
		wd_reply(520, WI_STR("File or Directory Not Found"));

		return;
	}
	
	wd_files_list_path(wi_string_by_normalizing_path(path), true);
}



/*
	ME <cid> <chat>
*/

static void wd_cmd_me(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wi_array_t		*array;
	wi_string_t		*string;
	wd_chat_t		*chat;
	wd_cid_t		cid;
	unsigned int	i, count;

	cid = wi_string_uint32(WI_ARRAY(arguments, 0));
	chat = wd_chat_with_cid(cid);
	
	if(!chat)
		return;

	if(!wd_chat_contains_client(chat, client))
		return;

	array = wi_string_components_separated_by_string(WI_ARRAY(arguments, 1), WI_STR("\n\r"));
	count = wi_array_count(array);
	
	wd_broadcast_lock();
	for(i = 0; i < count; i++) {
		string = WI_ARRAY(array, i);
		
		if(wi_string_length(string) > 0) {
			wd_broadcast(cid, 301, WI_STR("%u%c%u%c%#@"),
						 cid,			WD_FIELD_SEPARATOR,
						 client->uid,	WD_FIELD_SEPARATOR,
						 string);
		}
	}
	wd_broadcast_unlock();
}



/*
	MOVE <path> <path>
*/

static void wd_cmd_move(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wi_string_t		*frompath, *topath;
	wi_string_t		*properfrompath, *propertopath;
	
	frompath	= WI_ARRAY(arguments, 0);
	topath		= WI_ARRAY(arguments, 1);

	if(!wd_files_path_is_valid(frompath) || !wd_files_path_is_valid(topath)) {
		wd_reply(520, WI_STR("File or Directory Not Found"));

		return;
	}

	if(!client->account->view_dropboxes) {
		if(wd_files_path_is_dropbox(frompath)) {
			wd_reply(520, WI_STR("File or Directory Not Found"));

			return;
		}
	}

	properfrompath	= wi_string_by_normalizing_path(frompath);
	propertopath	= wi_string_by_normalizing_path(topath);

	if(wd_files_move_path(properfrompath, propertopath)) {
		wi_log_ll(WI_STR("%@/%@/%@ moved \"%@\" to \"%@\""),
			client->nick, client->login, client->ip,
			properfrompath, propertopath);
	}
}



/*
	MSG <uid> <message>
*/

static void wd_cmd_msg(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wd_client_t		*peer;
	wd_uid_t		uid;

	uid = wi_string_uint32(WI_ARRAY(arguments, 0));
	peer = wd_client_with_uid(uid);

	if(!peer) {
		wd_reply(512, WI_STR("Client Not Found"));

		return;
	}

	wd_client_lock_socket(peer);
	wd_sreply(peer->socket, 305, WI_STR("%u%c%#@"),
			  client->uid,	WD_FIELD_SEPARATOR,
			  WI_ARRAY(arguments, 1));
	wd_client_unlock_socket(peer);
}



/*
	NEWS
*/

static void wd_cmd_news(wi_array_t *arguments) {
	wd_reply_news();
}



/*
	NICK <nick>
*/

static void wd_cmd_nick(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wi_string_t		*nick;

	if(client->state < WD_CLIENT_STATE_SAID_HELLO)
		return;
	
	nick = WI_ARRAY(arguments, 0);

	if(!wi_is_equal(nick, client->nick)) {
		wi_release(client->nick);
		client->nick = wi_retain(nick);

		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			wd_broadcast_lock();
			wd_client_broadcast_status(client);
			wd_broadcast_unlock();
		}
	}
}



/*
	PASS <password>
*/

static void wd_cmd_pass(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wi_string_t		*password;
	wd_chat_t		*chat;

	if(client->state != WD_CLIENT_STATE_GAVE_USER)
		return;
	
	client->account = wi_retain(wd_accounts_read_user_and_group(client->login));
	
	if(!client->account) {
		wd_reply(510, WI_STR("Login Failed"));
		wi_log_info(WI_STR("Login from %@/%@/%@ failed: %@"),
			client->nick, client->login, client->ip,
			WI_STR("No such account"));

		return;
	}
	
	password = WI_ARRAY(arguments, 0);
	
	if(!wi_is_equal(client->account->password, password)) {
		wd_reply(510, WI_STR("Login Failed"));
		wi_log_info(WI_STR("Login from %@/%@/%@ failed: %@"),
			client->nick, client->login, client->ip,
			WI_STR("Wrong password"));

		return;
	}
	
	wi_log_info(WI_STR("Login from %@/%@/%@ succeeded"),
	   client->nick, client->login, client->ip);

	wi_lock_lock(client->flag_lock);
	client->admin = (client->account->kick_users || client->account->ban_users);
	client->state = WD_CLIENT_STATE_LOGGED_IN;
	wi_lock_unlock(client->flag_lock);

	wi_lock_lock(wd_status_lock);
	wd_current_users++;
	wd_total_users++;
	wd_write_status(true);
	wi_lock_unlock(wd_status_lock);

	wd_reply(201, WI_STR("%u"), client->uid);
	
	chat = wd_chat_with_cid(WD_PUBLIC_CID);
	wd_chat_add_client(chat, client);
}



/*
	PING
*/

static void wd_cmd_ping(wi_array_t *arguments) {
	wd_reply(202, WI_STR("Pong"));
}



/*
	POST <message>
*/

static void wd_cmd_post(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();

	if(!client->account->post_news) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}

	wd_post_news(WI_ARRAY(arguments, 0));
}



/*
	PRIVCHAT
*/

static void wd_cmd_privchat(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wd_chat_t		*chat;

	chat = wd_chat_init_private(wd_chat_alloc());

	wi_list_wrlock(wd_chats);
	wi_list_append_data(wd_chats, chat);
	wi_list_append_data(chat->clients, client);
	wi_list_unlock(wd_chats);

	wd_reply(330, WI_STR("%u"), chat->cid);
}



/*
	PRIVILEGES
*/

static void wd_cmd_privileges(wi_array_t *arguments) {
	wd_reply_privileges();
}



/*
	PUT <path> <size> <checksum>
*/

static void wd_cmd_put(wi_array_t *arguments) {
	wd_client_t			*client = wd_client();
	wi_string_t			*path, *realpath, *parentpath, *properpath;
	wi_file_offset_t	size;
	
	path = WI_ARRAY(arguments, 0);

	if(!wd_files_path_is_valid(path)) {
		wd_reply(520, WI_STR("File or Directory Not Found"));

		return;
	}
	
	realpath	= wd_files_real_path(path);

	wi_string_resolve_aliases_in_path(realpath);
	
	parentpath	= wi_string_by_deleting_last_path_component(realpath);

	switch(wd_files_type(parentpath)) {
		case WD_FILE_TYPE_UPLOADS:
		case WD_FILE_TYPE_DROPBOX:
			if(!client->account->upload) {
				wd_reply(516, WI_STR("Permission Denied"));

				return;
			}
			break;

		default:
			if(!client->account->upload_anywhere) {
				wd_reply(516, WI_STR("Permission Denied"));

				return;
			}
			break;
	}

	if(!wd_transfers_can_queue(WD_TRANSFER_UPLOAD)) {
		wd_reply(523, WI_STR("Queue Limit Exceeded"));

		return;
	}
	
	properpath	= wi_string_by_normalizing_path(path);
	size		= wi_string_uint64(WI_ARRAY(arguments, 1));

	wd_transfers_queue_upload(properpath, size, WI_ARRAY(arguments, 2));
}



/*
	READGROUP <name>
*/

static void wd_cmd_readgroup(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();

	if(!client->account->edit_accounts) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}

	wd_reply_group_account(WI_ARRAY(arguments, 0));
}



/*
	READUSER <name>
*/

static void wd_cmd_readuser(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();

	if(!client->account->edit_accounts) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}

	wd_reply_user_account(WI_ARRAY(arguments, 0));
}



/*
	SAY <cid> <message>
*/

static void wd_cmd_say(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wi_array_t		*array;
	wi_string_t		*string;
	wd_chat_t		*chat;
	wd_cid_t		cid;
	unsigned int	i, count;

	cid = wi_string_uint32(WI_ARRAY(arguments, 0));
	chat = wd_chat_with_cid(cid);
	
	if(!chat)
		return;

	if(!wd_chat_contains_client(chat, client))
		return;

	array = wi_string_components_separated_by_string(WI_ARRAY(arguments, 1), WI_STR("\n\r"));
	count = wi_array_count(array);
	
	wd_broadcast_lock();
	for(i = 0; i < count; i++) {
		string = WI_ARRAY(array, i);
		
		if(wi_string_length(string) > 0) {
			wd_broadcast(cid, 300, WI_STR("%u%c%u%c%#@"),
						 cid,			WD_FIELD_SEPARATOR,
						 client->uid,	WD_FIELD_SEPARATOR,
						 string);
		}
	}
	wd_broadcast_unlock();
}



/*
	SEARCH <query>
*/

static void wd_cmd_search(wi_array_t *arguments) {
	wd_files_search(WI_ARRAY(arguments, 0));
}



/*
	STAT <path>
*/

static void wd_cmd_stat(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wi_string_t		*path;
	
	path = WI_ARRAY(arguments, 0);

	if(!wd_files_path_is_valid(path)) {
		wd_reply(520, WI_STR("File or Directory Not Found"));

		return;
	}

	if(!client->account->view_dropboxes) {
		if(wd_files_path_is_dropbox(path)) {
			wd_reply(520, WI_STR("File or Directory Not Found"));

			return;
		}
	}

	wd_files_stat_path(wi_string_by_normalizing_path(path));
}



/*
	STATUS <status>
*/

static void wd_cmd_status(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wi_string_t		*status;

	if(client->state < WD_CLIENT_STATE_SAID_HELLO)
		return;

	status = WI_ARRAY(arguments, 0);

	if(!wi_is_equal(status, client->status)) {
		wi_release(client->status);
		client->status = wi_retain(status);

		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			wd_broadcast_lock();
			wd_client_broadcast_status(client);
			wd_broadcast_unlock();
		}
	}
}



/*
	TOPIC <cid> <topic>
*/

static void wd_cmd_topic(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wd_chat_t		*chat;
	wd_cid_t		cid;

	cid = wi_string_uint32(WI_ARRAY(arguments, 0));
	chat = wd_chat_with_cid(cid);

	if(!chat)
		return;

	if(cid == WD_PUBLIC_CID) {
		if(!client->account->set_topic) {
			wd_reply(516, WI_STR("Permission Denied"));

			return;
		}
	} else {
		if(!wd_chat_contains_client(chat, client))
			return;
	}

	wd_chat_set_topic(chat, WI_ARRAY(arguments, 1));

	wd_broadcast_lock();
	wd_chat_broadcast_topic(chat);
	wd_broadcast_unlock();
}



/*
	TYPE <path> <type>
*/

static void wd_cmd_type(wi_array_t *arguments) {
	wd_client_t			*client = wd_client();
	wi_string_t			*path, *properpath;
	wd_file_type_t		type;

	if(!client->account->alter_files) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}

	path = WI_ARRAY(arguments, 0);

	if(!wd_files_path_is_valid(path)) {
		wd_reply(520, WI_STR("File or Directory Not Found"));

		return;
	}

	if(!client->account->view_dropboxes) {
		if(wd_files_path_is_dropbox(path)) {
			wd_reply(520, WI_STR("File or Directory Not Found"));

			return;
		}
	}

	properpath	= wi_string_by_normalizing_path(path);
	type		= wi_string_uint32(WI_ARRAY(arguments, 1));

	wd_files_set_type(properpath, type);
}



/*
	USER <user>
*/

static void wd_cmd_user(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();

	if(client->state != WD_CLIENT_STATE_SAID_HELLO)
		return;

	client->login = wi_retain(WI_ARRAY(arguments, 0));
	
	if(!client->nick)
		client->nick = wi_retain(client->login);

	client->state = WD_CLIENT_STATE_GAVE_USER;
}



/*
	USERS
*/

static void wd_cmd_users(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();

	if(!client->account->edit_accounts) {
		wd_reply(516, WI_STR("Permission Denied"));
		
		return;
	}
	
	wd_reply_user_list();
}



/*
	WHO <cid>
*/

static void wd_cmd_who(wi_array_t *arguments) {
	wd_client_t		*client = wd_client();
	wd_chat_t		*chat;
	wd_cid_t		cid;

	cid = wi_string_uint32(WI_ARRAY(arguments, 0));
	chat = wd_chat_with_cid(cid);

	if(!chat)
		return;

	if(!wd_chat_contains_client(chat, client))
		return;

	wd_chat_reply_client_list(chat);
}
