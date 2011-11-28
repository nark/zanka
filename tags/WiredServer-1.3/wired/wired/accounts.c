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

#include <wired/wired.h>

#include "accounts.h"
#include "clients.h"
#include "chats.h"
#include "main.h"
#include "server.h"
#include "settings.h"

#define WD_ACCOUNT_GET_INSTANCE(array, count, index) \
	((count) > (index) ? wi_retain(WI_ARRAY((array), (index))) : NULL)

#define WD_ACCOUNT_GET_BOOL(array, count, index) \
	((count) > (index) ? wi_string_bool(WI_ARRAY((array), (index))) : false)

#define WD_ACCOUNT_GET_UINT32(array, count, index) \
	((count) > (index) ? wi_string_uint32(WI_ARRAY((array), (index))) : 0)


static int							_wd_accounts_delete_from_file(wi_file_t *, wi_string_t *);
static void							_wd_accounts_reload_user(wi_string_t *);
static void							_wd_accounts_reload_group(wi_string_t *);
static void							_wd_accounts_reload_client(wd_client_t *);
static void							_wd_sreply_privileges(wd_client_t *);

static void							wd_account_dealloc(wi_runtime_instance_t *);


static wi_lock_t					*wd_users_lock;
static wi_lock_t					*wd_groups_lock;

static wi_runtime_id_t				wd_account_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t			wd_account_runtime_class = {
	"wd_account_t",
	wd_account_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};


void wd_init_accounts(void) {
	wd_account_runtime_id = wi_runtime_register_class(&wd_account_runtime_class);

	wd_users_lock = wi_lock_init(wi_lock_alloc());
	wd_groups_lock = wi_lock_init(wi_lock_alloc());
}



#pragma mark -

wd_account_t * wd_account_alloc(void) {
	return wi_runtime_create_instance(wd_account_runtime_id, sizeof(wd_account_t));
}



wd_account_t * wd_account_init_user_with_array(wd_account_t *account, wi_array_t *array) {
	unsigned int		count;
	
	count						= wi_array_count(array);
	account->name				= WD_ACCOUNT_GET_INSTANCE(array, count, 0);
	account->password			= WD_ACCOUNT_GET_INSTANCE(array, count, 1);
	account->group				= WD_ACCOUNT_GET_INSTANCE(array, count, 2);
	account->get_user_info		= WD_ACCOUNT_GET_BOOL(array, count, 3);
	account->broadcast			= WD_ACCOUNT_GET_BOOL(array, count, 4);
	account->post_news			= WD_ACCOUNT_GET_BOOL(array, count, 5);
	account->clear_news			= WD_ACCOUNT_GET_BOOL(array, count, 6);
	account->download			= WD_ACCOUNT_GET_BOOL(array, count, 7);
	account->upload				= WD_ACCOUNT_GET_BOOL(array, count, 8);
	account->upload_anywhere	= WD_ACCOUNT_GET_BOOL(array, count, 9);
	account->create_folders		= WD_ACCOUNT_GET_BOOL(array, count, 10);
	account->alter_files		= WD_ACCOUNT_GET_BOOL(array, count, 11);
	account->delete_files		= WD_ACCOUNT_GET_BOOL(array, count, 12);
	account->view_dropboxes		= WD_ACCOUNT_GET_BOOL(array, count, 13);
	account->create_accounts	= WD_ACCOUNT_GET_BOOL(array, count, 14);
	account->edit_accounts		= WD_ACCOUNT_GET_BOOL(array, count, 15);
	account->delete_accounts	= WD_ACCOUNT_GET_BOOL(array, count, 16);
	account->elevate_privileges	= WD_ACCOUNT_GET_BOOL(array, count, 17);
	account->kick_users			= WD_ACCOUNT_GET_BOOL(array, count, 18);
	account->ban_users			= WD_ACCOUNT_GET_BOOL(array, count, 19);
	account->cannot_be_kicked	= WD_ACCOUNT_GET_BOOL(array, count, 20);
	account->download_speed		= WD_ACCOUNT_GET_UINT32(array, count, 21);
	account->upload_speed		= WD_ACCOUNT_GET_UINT32(array, count, 22);
	account->download_limit		= WD_ACCOUNT_GET_UINT32(array, count, 23);
	account->upload_limit		= WD_ACCOUNT_GET_UINT32(array, count, 24);
	account->set_topic			= WD_ACCOUNT_GET_BOOL(array, count, 25);
	account->files				= WD_ACCOUNT_GET_INSTANCE(array, count, 26);

	return account;
}



wd_account_t * wd_account_init_group_with_array(wd_account_t *account, wi_array_t *array) {
	unsigned int		count;
	
	count						= wi_array_count(array);
	account->name				= WD_ACCOUNT_GET_INSTANCE(array, count, 0);
	account->get_user_info		= WD_ACCOUNT_GET_BOOL(array, count, 1);
	account->broadcast			= WD_ACCOUNT_GET_BOOL(array, count, 2);
	account->post_news			= WD_ACCOUNT_GET_BOOL(array, count, 3);
	account->clear_news			= WD_ACCOUNT_GET_BOOL(array, count, 4);
	account->download			= WD_ACCOUNT_GET_BOOL(array, count, 5);
	account->upload				= WD_ACCOUNT_GET_BOOL(array, count, 6);
	account->upload_anywhere	= WD_ACCOUNT_GET_BOOL(array, count, 7);
	account->create_folders		= WD_ACCOUNT_GET_BOOL(array, count, 8);
	account->alter_files		= WD_ACCOUNT_GET_BOOL(array, count, 9);
	account->delete_files		= WD_ACCOUNT_GET_BOOL(array, count, 10);
	account->view_dropboxes		= WD_ACCOUNT_GET_BOOL(array, count, 11);
	account->create_accounts	= WD_ACCOUNT_GET_BOOL(array, count, 12);
	account->edit_accounts		= WD_ACCOUNT_GET_BOOL(array, count, 13);
	account->delete_accounts	= WD_ACCOUNT_GET_BOOL(array, count, 14);
	account->elevate_privileges	= WD_ACCOUNT_GET_BOOL(array, count, 15);
	account->kick_users			= WD_ACCOUNT_GET_BOOL(array, count, 16);
	account->ban_users			= WD_ACCOUNT_GET_BOOL(array, count, 17);
	account->cannot_be_kicked	= WD_ACCOUNT_GET_BOOL(array, count, 18);
	account->download_speed		= WD_ACCOUNT_GET_UINT32(array, count, 19);
	account->upload_speed		= WD_ACCOUNT_GET_UINT32(array, count, 20);
	account->download_limit		= WD_ACCOUNT_GET_UINT32(array, count, 21);
	account->upload_limit		= WD_ACCOUNT_GET_UINT32(array, count, 22);
	account->set_topic			= WD_ACCOUNT_GET_BOOL(array, count, 23);
	account->files				= WD_ACCOUNT_GET_INSTANCE(array, count, 25);

	return account;
}



static void wd_account_dealloc(wi_runtime_instance_t *instance) {
	wd_account_t		*account = instance;
	
	wi_release(account->name);
	wi_release(account->password);
	wi_release(account->group);
	wi_release(account->files);
}



#pragma mark -

wd_account_t * wd_accounts_read_user_and_group(wi_string_t *name) {
	wd_account_t		*user, *group;
	
	user = wd_accounts_read_user(name);
	
	if(!user)
		return NULL;
	
	if(wi_string_length(user->group) > 0) {
		group = wd_accounts_read_group(user->group);
		
		if(group) {
			user->get_user_info			= group->get_user_info;
			user->broadcast				= group->broadcast;
			user->post_news				= group->post_news;
			user->clear_news			= group->clear_news;
			user->download				= group->download;
			user->upload				= group->upload;
			user->upload_anywhere		= group->upload_anywhere;
			user->create_folders		= group->create_folders;
			user->alter_files			= group->alter_files;
			user->delete_files			= group->delete_files;
			user->view_dropboxes		= group->view_dropboxes;
			user->create_accounts		= group->create_accounts;
			user->edit_accounts			= group->edit_accounts;
			user->delete_accounts		= group->delete_accounts;
			user->elevate_privileges	= group->elevate_privileges;
			user->kick_users			= group->kick_users;
			user->ban_users				= group->ban_users;
			user->cannot_be_kicked		= group->cannot_be_kicked;
			user->download_speed		= group->download_speed;
			user->upload_speed			= group->upload_speed;
			user->download_limit		= group->download_limit;
			user->upload_limit			= group->upload_limit;
			user->set_topic				= group->set_topic;

			wi_release(user->files);
			user->files					= wi_retain(group->files);
		}
	}
	
	return user;
}



wd_account_t * wd_accounts_read_user(wi_string_t *name) {
	wi_file_t		*file;
	wi_array_t		*array;
	wi_string_t		*string;
	wd_account_t	*account = NULL;
	
	wi_lock_lock(wd_users_lock);
	
	file = wi_file_for_reading(wd_settings.users);
	
	if(!file) {
		wi_log_err(WI_STR("Could not open %@: %m"), wd_settings.users);

		goto end;
	}
	
	while((string = wi_file_read_config_line(file))) {
		array = wi_string_components_separated_by_string(string, WI_STR(":"));
		
		if(wi_array_count(array) > 0 && wi_is_equal(WI_ARRAY(array, 0), name)) {
			account = wd_account_init_user_with_array(wd_account_alloc(), array);
			
			break;
		}
	}
	
end:
	wi_lock_unlock(wd_users_lock);
	
	return wi_autorelease(account);
}



wd_account_t * wd_accounts_read_group(wi_string_t *name) {
	wi_file_t		*file;
	wi_array_t		*array;
	wi_string_t		*string;
	wd_account_t	*account = NULL;
	
	wi_lock_lock(wd_groups_lock);
	
	file = wi_file_for_reading(wd_settings.groups);
	
	if(!file) {
		wi_log_err(WI_STR("Could not open %@: %m"), wd_settings.groups);

		goto end;
	}
	
	while((string = wi_file_read_config_line(file))) {
		array = wi_string_components_separated_by_string(string, WI_STR(":"));
		
		if(wi_array_count(array) > 0 && wi_is_equal(WI_ARRAY(array, 0), name)) {
			account = wd_account_init_group_with_array(wd_account_alloc(), array);
			
			break;
		}
	}
	
end:
	wi_lock_unlock(wd_groups_lock);
	
	return wi_autorelease(account);
}



wi_boolean_t wd_accounts_create_user(wd_account_t *account) {
	wi_file_t		*file;
	wi_boolean_t	result = false;
	
	wi_lock_lock(wd_users_lock);

	file = wi_file_for_updating(wd_settings.users);

	if(!file) {
		wi_log_err(WI_STR("Could not open %@: %m"), wd_settings.users);

		goto end;
	}
	
	wi_file_write(file, WI_STR("%#@:%#@:%#@:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%u:%u:%u:%u:%d:%#@\n"),
				  account->name,
				  account->password,
				  account->group,
				  account->get_user_info,
				  account->broadcast,
				  account->post_news,
				  account->clear_news,
				  account->download,
				  account->upload,
				  account->upload_anywhere,
				  account->create_folders,
				  account->alter_files,
				  account->delete_files,
				  account->view_dropboxes,
				  account->create_accounts,
				  account->edit_accounts,
				  account->delete_accounts,
				  account->elevate_privileges,
				  account->kick_users,
				  account->ban_users,
				  account->cannot_be_kicked,
				  account->download_speed,
				  account->upload_speed,
				  account->download_limit,
				  account->upload_limit,
				  account->set_topic,
				  account->files);
	
	result = true;

end:
	wi_lock_unlock(wd_users_lock);
	
	return result;
}



wi_boolean_t wd_accounts_create_group(wd_account_t *account) {
	wi_file_t		*file;
	wi_boolean_t	result = false;
	
	wi_lock_lock(wd_groups_lock);

	file = wi_file_for_updating(wd_settings.groups);

	if(!file) {
		wi_log_err(WI_STR("Could not open %@: %m"), wd_settings.groups);

		goto end;
	}
	
	wi_file_write(file, WI_STR("%#@:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%u:%u:%u:%u:%d:%#@\n"),
				  account->name,
				  account->get_user_info,
				  account->broadcast,
				  account->post_news,
				  account->clear_news,
				  account->download,
				  account->upload,
				  account->upload_anywhere,
				  account->create_folders,
				  account->alter_files,
				  account->delete_files,
				  account->view_dropboxes,
				  account->create_accounts,
				  account->edit_accounts,
				  account->delete_accounts,
				  account->elevate_privileges,
				  account->kick_users,
				  account->ban_users,
				  account->cannot_be_kicked,
				  account->download_speed,
				  account->upload_speed,
				  account->download_limit,
				  account->upload_limit,
				  account->set_topic,
				  account->files);
	
	result = true;

end:
	wi_lock_unlock(wd_groups_lock);
	
	return result;
}



wi_boolean_t wd_accounts_edit_user(wd_account_t *account) {
	if(!wd_accounts_delete_user(account->name))
		return false;
	
	if(!wd_accounts_create_user(account))
		return false;
	
	_wd_accounts_reload_user(account->name);

	return true;
}



wi_boolean_t wd_accounts_edit_group(wd_account_t *account) {
	if(!wd_accounts_delete_group(account->name))
		return false;
	
	if(!wd_accounts_create_group(account))
		return false;
	
	_wd_accounts_reload_group(account->name);

	return true;
}



wi_boolean_t wd_accounts_delete_user(wi_string_t *name) {
	wi_file_t		*file;
	wi_boolean_t	result;
	
	wi_lock_lock(wd_users_lock);
	
	file = wi_file_for_updating(wd_settings.users);

	if(!file) {
		wi_log_err(WI_STR("Could not open %@: %m"), wd_settings.users);

		result = -1;
		goto end;
	}

	result = _wd_accounts_delete_from_file(file, name);
	
	if(!result)
		wd_reply(513, WI_STR("Account Not Found"));

end:
	wi_lock_unlock(wd_users_lock);
	
	return result;
}



wi_boolean_t wd_accounts_delete_group(wi_string_t *name) {
	wi_file_t		*file;
	wi_boolean_t	result;
	
	wi_lock_lock(wd_groups_lock);
	
	file = wi_file_for_updating(wd_settings.groups);

	if(!file) {
		wi_log_err(WI_STR("Could not open %@: %m"), wd_settings.groups);

		result = -1;
		goto end;
	}

	result = _wd_accounts_delete_from_file(file, name);
	
	if(!result)
		wd_reply(513, WI_STR("Account Not Found"));

end:
	wi_lock_unlock(wd_groups_lock);
	
	return result;
}



wi_boolean_t wd_accounts_clear_group(wi_string_t *name) {
	wi_file_t		*file, *tmpfile = NULL;
	wi_array_t		*array;
	wi_string_t		*string;
	wi_boolean_t	result = false;
	
	wi_lock_lock(wd_users_lock);
	
	file = wi_file_for_updating(wd_settings.users);

	if(!file) {
		wi_log_err(WI_STR("Could not open %@: %m"), wd_settings.users);

		goto end;
	}

	tmpfile = wi_file_temporary_file();
	
	if(!tmpfile) {
		wi_log_err(WI_STR("Could not create a temporary file: %m"));

		goto end;
	}
	
	while((string = wi_file_read_line(file)))
		wi_file_write(tmpfile, WI_STR("%@\n"), string);
	
	wi_file_truncate(file, 0);
	wi_file_seek(tmpfile, 0);
	
	while((string = wi_file_read_line(tmpfile))) {
		if(wi_string_length(string) > 0 && !wi_string_has_prefix(string, WI_STR("#"))) {
			array = wi_string_components_separated_by_string(string, WI_STR(":"));
			
			if(wi_array_count(array) > 2 && wi_is_equal(WI_ARRAY(array, 2), name)) {
				wi_array_replace_data_at_index(array, WI_STR(""), 2);
				
				string = wi_array_components_joined_by_string(array, WI_STR(":"));
			}
		}
			
		wi_file_write(file, WI_STR("%@\n"), string);
	}
	
end:
	wi_lock_unlock(wd_users_lock);
	
	return result;
}



wi_boolean_t wd_accounts_check_privileges(wd_account_t *account) {
	wd_client_t		*client = wd_client();
	
	if(!client->account->elevate_privileges) {
		if(account->get_user_info && !client->account->get_user_info)
			return false;

		if(account->broadcast && !client->account->broadcast)
			return false;

		if(account->post_news && !client->account->post_news)
			return false;

		if(account->clear_news && !client->account->clear_news)
			return false;

		if(account->download && !client->account->download)
			return false;

		if(account->upload && !client->account->upload)
			return false;

		if(account->upload_anywhere && !client->account->upload_anywhere)
			return false;

		if(account->create_folders && !client->account->create_folders)
			return false;

		if(account->alter_files && !client->account->alter_files)
			return false;

		if(account->delete_files && !client->account->delete_files)
			return false;

		if(account->view_dropboxes && !client->account->view_dropboxes)
			return false;

		if(account->create_accounts && !client->account->create_accounts)
			return false;

		if(account->edit_accounts && !client->account->edit_accounts)
			return false;

		if(account->delete_accounts && !client->account->delete_accounts)
			return false;

		if(account->elevate_privileges && !client->account->elevate_privileges)
			return false;

		if(account->kick_users && !client->account->kick_users)
			return false;

		if(account->ban_users && !client->account->ban_users)
			return false;

		if(account->cannot_be_kicked && !client->account->cannot_be_kicked)
			return false;

		if(account->set_topic && !client->account->set_topic)
			return false;
	}
	
	return true;
}



void wd_accounts_reload_users(void) {
	wi_list_node_t		*node;
	wd_client_t			*client;

	wi_list_rdlock(wd_clients);
	WI_LIST_FOREACH(wd_clients, node, client)
		_wd_accounts_reload_client(client);
	wi_list_unlock(wd_clients);
}



#pragma mark -

static int _wd_accounts_delete_from_file(wi_file_t *file, wi_string_t *name) {
	wi_file_t		*tmpfile;
	wi_array_t		*array;
	wi_string_t		*string;
	wi_boolean_t	result = false;
	
	tmpfile = wi_file_temporary_file();
	
	if(!tmpfile) {
		wi_log_err(WI_STR("Could not create a temporary file: %m"));

		return false;
	}
	
	while((string = wi_file_read_line(file))) {
		if(wi_string_length(string) == 0 || wi_string_has_prefix(string, WI_STR("#"))) {
			wi_file_write(tmpfile, WI_STR("%@\n"), string);
		} else {
			array = wi_string_components_separated_by_string(string, WI_STR(":"));
			
			if(wi_array_count(array) > 0 && wi_is_equal(WI_ARRAY(array, 0), name))
				result = true;
			else
				wi_file_write(tmpfile, WI_STR("%@\n"), string);
		}
	}
	
	wi_file_truncate(file, 0);
	wi_file_seek(tmpfile, 0);
	
	while((string = wi_file_read(tmpfile, WI_FILE_BUFFER_SIZE)))
		wi_file_write(file, WI_STR("%@"), string);
	
	return result;
}



static void _wd_accounts_reload_user(wi_string_t *name) {
	wi_list_node_t		*node;
	wd_client_t			*client;

	wi_list_rdlock(wd_clients);
	WI_LIST_FOREACH(wd_clients, node, client) {
		if(wi_is_equal(client->account->name, name))
			_wd_accounts_reload_client(client);
	}
	wi_list_unlock(wd_clients);
}



static void _wd_accounts_reload_group(wi_string_t *name) {
	wi_list_node_t		*node;
	wd_client_t			*client;

	wi_list_rdlock(wd_clients);
	WI_LIST_FOREACH(wd_clients, node, client) {
		if(wi_is_equal(client->account->group, name))
			_wd_accounts_reload_client(client);
	}
	wi_list_unlock(wd_clients);
}



static void _wd_accounts_reload_client(wd_client_t *client) {
	wd_account_t	*account;
	wi_boolean_t	admin;
	
	account = wd_accounts_read_user_and_group(client->account->name);
	
	if(!account)
		return;
	
	wi_retain(account);
	wi_release(client->account);
	
	client->account = account;

	wi_lock_lock(client->flag_lock);
	admin = client->admin;
	client->admin = (client->account->kick_users || client->account->ban_users);
	wi_lock_unlock(client->flag_lock);
	
	if(client->admin != admin) {
		wd_broadcast_lock();
		wd_client_broadcast_status(client);
		wd_broadcast_unlock();
	}

	wd_client_lock_socket(client);
	_wd_sreply_privileges(client);
	wd_client_unlock_socket(client);
}



static void _wd_sreply_privileges(wd_client_t *client) {
	wd_sreply(client->socket, 602, WI_STR("%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%u%c%u%c%u%c%u%c%d"),
			  client->account->get_user_info,			WD_FIELD_SEPARATOR,
			  client->account->broadcast,				WD_FIELD_SEPARATOR,
			  client->account->post_news,				WD_FIELD_SEPARATOR,
			  client->account->clear_news,				WD_FIELD_SEPARATOR,
			  client->account->download,				WD_FIELD_SEPARATOR,
			  client->account->upload,					WD_FIELD_SEPARATOR,
			  client->account->upload_anywhere,			WD_FIELD_SEPARATOR,
			  client->account->create_folders,			WD_FIELD_SEPARATOR,
			  client->account->alter_files,				WD_FIELD_SEPARATOR,
			  client->account->delete_files,			WD_FIELD_SEPARATOR,
			  client->account->view_dropboxes,			WD_FIELD_SEPARATOR,
			  client->account->create_accounts,			WD_FIELD_SEPARATOR,
			  client->account->edit_accounts,			WD_FIELD_SEPARATOR,
			  client->account->delete_accounts,			WD_FIELD_SEPARATOR,
			  client->account->elevate_privileges,		WD_FIELD_SEPARATOR,
			  client->account->kick_users,				WD_FIELD_SEPARATOR,
			  client->account->ban_users,				WD_FIELD_SEPARATOR,
			  client->account->cannot_be_kicked,		WD_FIELD_SEPARATOR,
			  client->account->download_speed,			WD_FIELD_SEPARATOR,
			  client->account->upload_speed,			WD_FIELD_SEPARATOR,
			  client->account->download_limit,			WD_FIELD_SEPARATOR,
			  client->account->upload_limit,			WD_FIELD_SEPARATOR,
			  client->account->set_topic);
}



#pragma mark -

void wd_reply_privileges(void) {
	_wd_sreply_privileges(wd_client());
}



void wd_reply_user_account(wi_string_t *name) {
	wd_account_t		*account;
	
	account = wd_accounts_read_user(name);
	
	if(!account) {
		wd_reply(513, WI_STR("Account Not Found"));
		
		return;
	}

	wd_reply(600, WI_STR("%#@%c%#@%c%#@%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%u%c%u%c%u%c%u%c%d"),
			 account->name,						WD_FIELD_SEPARATOR,
			 account->password,					WD_FIELD_SEPARATOR,
			 account->group,					WD_FIELD_SEPARATOR,
			 account->get_user_info,			WD_FIELD_SEPARATOR,
			 account->broadcast,				WD_FIELD_SEPARATOR,
			 account->post_news,				WD_FIELD_SEPARATOR,
			 account->clear_news,				WD_FIELD_SEPARATOR,
			 account->download,					WD_FIELD_SEPARATOR,
			 account->upload,					WD_FIELD_SEPARATOR,
			 account->upload_anywhere,			WD_FIELD_SEPARATOR,
			 account->create_folders,			WD_FIELD_SEPARATOR,
			 account->alter_files,				WD_FIELD_SEPARATOR,
			 account->delete_files,				WD_FIELD_SEPARATOR,
			 account->view_dropboxes,			WD_FIELD_SEPARATOR,
			 account->create_accounts,			WD_FIELD_SEPARATOR,
			 account->edit_accounts,			WD_FIELD_SEPARATOR,
			 account->delete_accounts,			WD_FIELD_SEPARATOR,
			 account->elevate_privileges,		WD_FIELD_SEPARATOR,
			 account->kick_users,				WD_FIELD_SEPARATOR,
			 account->ban_users,				WD_FIELD_SEPARATOR,
			 account->cannot_be_kicked,			WD_FIELD_SEPARATOR,
			 account->download_speed,			WD_FIELD_SEPARATOR,
			 account->upload_speed,				WD_FIELD_SEPARATOR,
			 account->download_limit,			WD_FIELD_SEPARATOR,
			 account->upload_limit,				WD_FIELD_SEPARATOR,
			 account->set_topic);
}



void wd_reply_group_account(wi_string_t *name) {
	wd_account_t		*account;
	
	account = wd_accounts_read_group(name);
	
	if(!account) {
		wd_reply(513, WI_STR("Account Not Found"));
		
		return;
	}

	wd_reply(601, WI_STR("%#@%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%d%c%u%c%u%c%u%c%u%c%d"),
			 account->name,					WD_FIELD_SEPARATOR,
			 account->get_user_info,		WD_FIELD_SEPARATOR,
			 account->broadcast,			WD_FIELD_SEPARATOR,
			 account->post_news,			WD_FIELD_SEPARATOR,
			 account->clear_news,			WD_FIELD_SEPARATOR,
			 account->download,				WD_FIELD_SEPARATOR,
			 account->upload,				WD_FIELD_SEPARATOR,
			 account->upload_anywhere,		WD_FIELD_SEPARATOR,
			 account->create_folders,		WD_FIELD_SEPARATOR,
			 account->alter_files,			WD_FIELD_SEPARATOR,
			 account->delete_files,			WD_FIELD_SEPARATOR,
			 account->view_dropboxes,		WD_FIELD_SEPARATOR,
			 account->create_accounts,		WD_FIELD_SEPARATOR,
			 account->edit_accounts,		WD_FIELD_SEPARATOR,
			 account->delete_accounts,		WD_FIELD_SEPARATOR,
			 account->elevate_privileges,	WD_FIELD_SEPARATOR,
			 account->kick_users,			WD_FIELD_SEPARATOR,
			 account->ban_users,			WD_FIELD_SEPARATOR,
			 account->cannot_be_kicked,		WD_FIELD_SEPARATOR,
			 account->download_speed,		WD_FIELD_SEPARATOR,
			 account->upload_speed,			WD_FIELD_SEPARATOR,
			 account->download_limit,		WD_FIELD_SEPARATOR,
			 account->upload_limit,			WD_FIELD_SEPARATOR,
			 account->set_topic);
}



void wd_reply_user_list(void) {
	wi_file_t		*file;
	wi_string_t		*string;
	unsigned int	index;

	wi_lock_lock(wd_users_lock);
	
	file = wi_file_for_reading(wd_settings.users);

	if(!file) {
		wi_log_err(WI_STR("Could not open %@: %m"), wd_settings.users);

		goto end;
	}

	while((string = wi_file_read_config_line(file))) {
		index = wi_string_index_of_string(string, WI_STR(":"), 0);
		
		if(index != WI_NOT_FOUND && index > 0) {
			wi_string_delete_characters_from_index(string, index);
			
			wd_reply(610, WI_STR("%#@"), string);
		}
	}

end:
	wd_reply(611, WI_STR("Done"));
	
	wi_lock_unlock(wd_users_lock);
}



void wd_reply_group_list(void) {
	wi_file_t		*file;
	wi_string_t		*string;
	unsigned int	index;

	wi_lock_lock(wd_groups_lock);
	
	file = wi_file_for_reading(wd_settings.groups);

	if(!file) {
		wi_log_err(WI_STR("Could not open %@: %m"), wd_settings.groups);

		goto end;
	}

	while((string = wi_file_read_config_line(file))) {
		index = wi_string_index_of_string(string, WI_STR(":"), 0);
		
		if(index != WI_NOT_FOUND && index > 0) {
			wi_string_delete_characters_from_index(string, index);
			
			wd_reply(620, WI_STR("%#@"), string);
		}
	}

end:
	wd_reply(621, WI_STR("Done"));
	
	wi_lock_unlock(wd_groups_lock);
}
