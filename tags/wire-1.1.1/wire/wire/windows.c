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
#include <readline/readline.h>
#include <wired/wired.h>

#include "client.h"
#include "terminal.h"
#include "transfers.h"
#include "windows.h"

static void							wr_window_dealloc(wi_runtime_instance_t *);

static wr_wid_t						wr_window_wid(void);


wi_list_t							*wr_windows;

wr_window_t							*wr_console_window;
wr_window_t							*wr_current_window;

static wi_runtime_id_t				wr_window_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t			wr_window_runtime_class = {
	"wr_window_t",
	wr_window_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};


void wr_init_windows(void) {
	wr_window_runtime_id = wi_runtime_register_class(&wr_window_runtime_class);

	wr_windows = wi_list_init(wi_list_alloc());

	wr_console_window = wr_window_init_with_chat(wr_window_alloc(), WR_PUBLIC_CID);
	wr_windows_add_window(wr_console_window);
	wi_release(wr_console_window);

	wr_windows_show_window(wr_console_window);
}



void wr_clear_windows(void) {
	wi_list_node_t	*node, *next_node;
	wr_window_t		*window;

	for(node = wi_list_first_node(wr_windows); node; node = next_node) {
		next_node	= wi_list_node_next_node(node);
		window		= wi_list_node_data(node);
		
		if(window != wr_console_window)
			wr_windows_close_window(window);
	}
	
	wr_windows_show_window(wr_console_window);
}



#pragma mark -

wr_window_t * wr_window_alloc(void) {
	return wi_runtime_create_instance(wr_window_runtime_id, sizeof(wr_window_t));
}



wr_window_t * wr_window_init(wr_window_t *window) {
	window->buffer		= wi_terminal_buffer_init_with_terminal(wi_terminal_buffer_alloc(), wr_terminal);
	window->wid			= wr_window_wid();
	window->status		= WR_WINDOW_STATUS_IDLE;
	
	return window;
}



wr_window_t * wr_window_init_with_chat(wr_window_t *window, wr_cid_t cid) {
	window = wr_window_init(window);

	window->type	= WR_WINDOW_TYPE_CHAT;
	window->cid		= cid;
	
	return window;
}



wr_window_t * wr_window_init_with_user(wr_window_t *window, wr_user_t *user) {
	window = wr_window_init(window);
	
	window->type		= WR_WINDOW_TYPE_USER;
	window->uid			= user->uid;
	window->topic.topic	= wi_retain(user->nick);
	
	return window;
}



static void wr_window_dealloc(wi_runtime_instance_t *instance) {
	wr_window_t		*window = instance;

	wi_release(window->topic.nick);
	wi_release(window->topic.date);
	wi_release(window->topic.topic);

	wi_release(window->buffer);
}



#pragma mark -

static wr_wid_t wr_window_wid(void) {
	wr_window_t		*window;

	if(wi_list_count(wr_windows) > 0) {
		window = wi_list_last_data(wr_windows);
		
		return window->wid + 1;
	}

	return 1;
}



#pragma mark -

void wr_windows_add_window(wr_window_t *window) {
	wr_user_t		*user;

	wi_list_append_data(wr_windows, window);
	wi_terminal_add_buffer(wr_terminal, window->buffer);

	if(window->type == WR_WINDOW_TYPE_USER) {
		user = wr_user_with_uid(window->uid);

		wr_wprintf_prefix(window, WI_STR("Opened new window for private messages with %@"), user->nick);
		wr_wprintf_prefix(window, WI_STR("Use ctrl-N/ctrl-P to cycle windows"), user->nick);
	}
}



void wr_windows_close_window(wr_window_t *window) {
	wi_list_node_t	*node;
	wr_window_t		*previous_window;
	
	node = wi_list_node_with_data(wr_windows, window);
	previous_window = wi_list_node_previous_data(node);

	if(!previous_window)
		previous_window = wi_list_last_data(wr_windows);
	
	if(previous_window)
		wr_windows_show_window(previous_window);
	
	wi_list_remove_node(wr_windows, node);

	wi_terminal_add_buffer(wr_terminal, window->buffer);
}



void wr_windows_show_next(void) {
	wi_list_node_t	*node;
	wr_window_t		*next_window;
	
	node = wi_list_node_with_data(wr_windows, wr_current_window);
	next_window = wi_list_node_next_data(node);

	if(!next_window)
		next_window = wi_list_first_data(wr_windows);

	if(next_window)
		wr_windows_show_window(next_window);
}



void wr_windows_show_previous(void) {
	wi_list_node_t	*node;
	wr_window_t		*previous_window;
	
	node = wi_list_node_with_data(wr_windows, wr_current_window);
	previous_window = wi_list_node_previous_data(node);
	
	if(!previous_window)
		previous_window = wi_list_last_data(wr_windows);
	
	if(previous_window)
		wr_windows_show_window(previous_window);
}



void wr_windows_show_window(wr_window_t *window) {
	if(wr_current_window != window) {
		wr_current_window = window;
		wr_current_window->status = WR_WINDOW_STATUS_IDLE;
		
		wi_terminal_clear_screen(wr_terminal);
		wi_terminal_set_active_buffer(wr_terminal, wr_current_window->buffer);
		wi_terminal_buffer_redraw(wr_current_window->buffer);

		wr_draw_header();
		wr_draw_divider();
	}
}



#pragma mark -

wr_window_t * wr_window_with_chat(wr_cid_t cid) {
	wi_list_node_t	*node;
	wr_window_t		*window;

	if(cid == WR_PUBLIC_CID)
		return wr_console_window;

	WI_LIST_FOREACH(wr_windows, node, window) {
		if(window->type == WR_WINDOW_TYPE_CHAT && window->cid == cid)
			return window;
	}
	
	return NULL;
}



wr_window_t * wr_window_with_user(wr_user_t *user) {
	wi_list_node_t	*node;
	wr_window_t		*window;
	
	WI_LIST_FOREACH(wr_windows, node, window) {
		if(window->type == WR_WINDOW_TYPE_USER && window->uid == user->uid)
			return window;
	}
	
	return NULL;
}



#pragma mark -

void wr_printf(wi_string_t *fmt, ...) {
	wi_string_t		*string;
	va_list			ap;

	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);

	wr_wprint(wr_current_window, string);

	wi_release(string);
}



void wr_wprintf(wr_window_t *window, wi_string_t *fmt, ...) {
	wi_string_t		*string;
	va_list			ap;

	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);

	wr_wprint(window, string);
	
	wi_release(string);
}



void wr_printf_prefix(wi_string_t *fmt, ...) {
	wi_string_t		*string;
	va_list			ap;

	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);

	wr_wprintf_prefix(wr_current_window, WI_STR("%@"), string);

	wi_release(string);
}



void wr_wprintf_prefix(wr_window_t *window, wi_string_t *fmt, ...) {
	wi_string_t		*string;
	va_list			ap;

	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);

	wr_wprintf(window, WI_STR("%s%s%s%@"),
		WR_PREFIX_COLOR,
		WR_PREFIX,
		WR_END_COLOR,
		string);

	wi_release(string);
}



void wr_printf_block(wi_string_t *fmt, ...) {
	wi_string_t		*string;
	va_list			ap;

	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);

	wr_wprintf_block(wr_current_window, WI_STR("%@"), string);
	
	wi_release(string);
}



void wr_wprintf_block(wr_window_t *window, wi_string_t *fmt, ...) {
	wi_array_t		*array;
	wi_string_t		*string;
	va_list			ap;
	unsigned int	i, count;

	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);

	array = wi_string_components_separated_by_string(string, WI_STR("\n"));
	count = wi_array_count(array);
	
	for(i = 0; i < count; i++)
		wr_wprintf(window, WI_STR("   %@"), WI_ARRAY(array, i));

	wi_release(string);
}



void wr_wprint(wr_window_t *window, wi_string_t *string) {
	wi_string_t		*timestamp;

	timestamp = wi_date_string_with_format(wi_date(), wr_timestamp_format);

	if(wi_terminal_buffer_printf(window->buffer, WI_STR("%@ %@"), timestamp, string)) {
		window->status = WR_WINDOW_STATUS_IDLE;
	} else {
		if(window->status < WR_WINDOW_STATUS_ACTION)
			window->status = WR_WINDOW_STATUS_ACTION;
	}

	wr_terminal_reset_location();
	
	wr_draw_divider();
}



void wr_wprint_say(wr_window_t *window, wi_string_t *nick, wi_string_t *chat) {
	wi_string_t		*prefix;
	const char		*color;
	unsigned int	length;

	length = wi_string_length(wr_nick);

	if(length > 4)
		length = 4;

	prefix = wi_string_substring_to_index(wr_nick, length);
	
	if(wi_string_has_prefix(chat, prefix)) {
		color = WR_HIGHLIGHT_COLOR;
		
		if(window->status < WR_WINDOW_STATUS_HIGHLIGHT)
			window->status = WR_WINDOW_STATUS_HIGHLIGHT;
	} else {
		color = WR_NICK_COLOR;
		
		if(window->status < WR_WINDOW_STATUS_CHAT)
			window->status = WR_WINDOW_STATUS_CHAT;
	}
		
	wr_wprintf(window, WI_STR("%s<%s%s%@%s%s>%s %@"),
		WR_SAY_COLOR,
		WR_END_COLOR,
		color,
		nick,
		WR_END_COLOR,
		WR_SAY_COLOR,
		WR_END_COLOR,
		chat);
}



void wr_wprint_me(wr_window_t *window, wi_string_t *nick, wi_string_t *chat) {
	wi_string_t		*prefix;
	const char		*color;
	unsigned int	length;

	length = wi_string_length(wr_nick);

	if(length > 4)
		length = 4;

	prefix = wi_string_substring_to_index(wr_nick, length);
	
	if(wi_string_has_prefix(chat, prefix)) {
		color = WR_HIGHLIGHT_COLOR;
		
		if(window->status < WR_WINDOW_STATUS_HIGHLIGHT)
			window->status = WR_WINDOW_STATUS_HIGHLIGHT; 
	} else {
		color = NULL;
		
		if(window->status < WR_WINDOW_STATUS_CHAT)
			window->status = WR_WINDOW_STATUS_CHAT;
	}

	wr_wprintf(window, WI_STR("%s*%s %s%@%s %@"),
		WR_ME_COLOR,
		WR_END_COLOR,
		color ? color : "",
		nick,
		color ? WR_END_COLOR : "",
		chat);
}



void wr_wprint_msg(wr_window_t *window, wi_string_t *nick, wi_string_t *message) {
	if(window->status < WR_WINDOW_STATUS_HIGHLIGHT)
		window->status = WR_WINDOW_STATUS_HIGHLIGHT;
	
	wr_wprintf(window, WI_STR("%s<%s%s%@%s%s>%s %@"),
		WR_SAY_COLOR,
		WR_END_COLOR,
		WR_HIGHLIGHT_COLOR,
		nick,
		WR_END_COLOR,
		WR_SAY_COLOR,
		WR_END_COLOR,
		message);
}



void wr_print_server_info(void) {
	wi_string_t			*string, *interval;

	wr_printf_prefix(WI_STR("Server info:"));

	wr_printf_block(WI_STR("Name:         %@"), wr_server->name);
	wr_printf_block(WI_STR("Description:  %@"), wr_server->description);

	interval = wi_time_interval_string(wi_date_time_interval_since_now(wr_server->startdate));
	string = wi_date_string_with_format(wr_server->startdate, WI_STR("%a %b %e %T %Y"));
	wr_printf_block(WI_STR("Uptime:       %@, since %@"), interval, string);

	wr_printf_block(WI_STR("Files:        %@"), wr_files_string_for_count(wr_server->files));
	wr_printf_block(WI_STR("Size:         %@"), wr_files_string_for_size(wr_server->size));
	wr_printf_block(WI_STR("Version:      %@"), wr_server->version);
	wr_printf_block(WI_STR("Protocol:     %.1f"), wr_server->protocol);
	wr_printf_block(WI_STR("SSL Protocol: %@"), wi_socket_cipher_version(wr_socket));
	wr_printf_block(WI_STR("Cipher:       %@/%u bits"),
		wi_socket_cipher_name(wr_socket),
		wi_socket_cipher_bits(wr_socket));
	wr_printf_block(WI_STR("Certificate:  %@/%u bits, %@"),
		wi_socket_certificate_name(wr_socket),
		wi_socket_certificate_bits(wr_socket),
		wi_socket_certificate_hostname(wr_socket));
}



void wr_print_topic(void) {
	wr_printf_prefix(WI_STR("Topic: %#@"), wr_current_window->topic.topic);
	
	if(wr_current_window->topic.nick) {
		wr_printf_prefix(WI_STR("Topic set by %@ - %@"),
			wr_current_window->topic.nick, wr_current_window->topic.date);
	}
}



void wr_print_users(void) {
	wi_list_node_t  *node;
	wr_user_t       *user;
	unsigned int    max_length = 0;

	WI_LIST_FOREACH(wr_users, node, user)
		max_length = WI_MAX(max_length, wi_string_length(user->nick));

	wr_printf_prefix(WI_STR("Users currently online:"));

	WI_LIST_FOREACH(wr_users, node, user)
		wr_print_user(user, max_length);
}



void wr_print_user(wr_user_t *user, unsigned int max_length) {
	const char		*color;

	if(user->admin && !user->idle)
		color = WR_ADMIN_COLOR;
	else if(user->admin)
		color = WR_ADMIN_IDLE_COLOR;
	else if(!user->idle)
		color = WR_USER_COLOR;
	else
		color = WR_USER_IDLE_COLOR;

	wr_printf_block(WI_STR("%s%@%s%*s%@"),
		color,
		user->nick,
		WR_END_COLOR,
		max_length - wi_string_length(user->nick) + 4,
		" ",
		user->status);
}



void wr_print_file(wr_file_t *file, wi_boolean_t path, unsigned int max_length) {
	wi_string_t		*name, *size;
	const char		*color;

	switch(file->type) {
		case WR_FILE_UPLOADS:
			color = WR_UPLOADS_COLOR;
			break;

		case WR_FILE_DROPBOX:
			color = WR_DROPBOX_COLOR;
			break;

		case WR_FILE_DIRECTORY:
			color = WR_DIRECTORY_COLOR;
			break;

		case WR_FILE_FILE:
		default:
			color = WR_FILE_COLOR;
			break;
	}

	if(file->type == WR_FILE_FILE)
		size = wr_files_string_for_size(file->size);
	else
		size = wr_files_string_for_count(file->size);
	
	name = path ? file->path : file->name;

	wr_printf_block(WI_STR("%s%@%s%@%*s%@"),
		color,
		name,
		WR_END_COLOR,
		file->type != WR_FILE_FILE
			? WI_STR("/")
			: WI_STR(" "),
		max_length - wi_string_length(name) + 4,
		" ",
		size);
}



#pragma mark -

void wr_draw_header(void) {
	wi_string_t		*topic;
	wi_size_t		size;
	
	topic = wi_copy(wr_current_window->topic.topic);
	
	if(!topic)
		topic = wi_string_init(wi_string_alloc());

	wi_terminal_adjust_string_to_fit_width(wr_terminal, topic);
	
	size = wi_terminal_size(wr_terminal);
	
	wi_terminal_move_printf(wr_terminal, wi_make_point(0, 0), WI_STR("%s%@%s"),
	   WR_INTERFACE_COLOR,
	   topic,
	   WR_END_COLOR);
	wi_terminal_move(wr_terminal, wi_make_point(rl_point % size.width, size.height - 1));
	
	wi_release(topic);
}



void wr_draw_transfers(wi_boolean_t force) {
	static wi_time_interval_t	update;
	wi_list_node_t				*node;
	wi_string_t					*string, *status;
	wr_transfer_t				*transfer;
	wi_time_interval_t			interval;
	unsigned int				i = 0;
	
	interval = wi_time_interval();
	
	if(!force && interval - update < 1.0)
		return;
	
	update = interval;
	
	wi_terminal_set_scroll(wr_terminal, wi_make_range(1 + wi_list_count(wr_transfers),
													  wi_terminal_size(wr_terminal).height - 3));
	
	WI_LIST_FOREACH(wr_transfers, node, transfer) {
		wi_terminal_move(wr_terminal, wi_make_point(0, i + 1));
		wi_terminal_clear_line(wr_terminal);
		
		if(transfer->state == WR_TRANSFER_RUNNING && interval - transfer->start_time > 0.0) {
			transfer->speed = ((double) transfer->transferred - transfer->offset) / (interval - transfer->start_time);
			
			status = wi_string_with_format(WI_STR("%@/%@, %@/s"),
				wr_files_string_for_size(transfer->transferred),
				wr_files_string_for_size(transfer->size),
				wr_files_string_for_size(transfer->speed));
		}
		else if(transfer->state == WR_TRANSFER_QUEUED) {
			status = wi_string_with_format(WI_STR("queued at %u"),
				transfer->queue);
		}
		else {
			status = wi_string_with_cstring("waiting");
		}
		
		string = wi_string_with_format(WI_STR("%u %3.0f%%  %@"),
			transfer->tid,
			transfer->size > 0
				? 100 * ((double) transfer->transferred / (double) transfer->size)
				: 0,
			transfer->name);
		
		wi_terminal_adjust_string_to_fit_width(wr_terminal, string);
		wi_string_delete_characters_from_index(string, wi_string_length(string) - wi_string_length(status));
		wi_string_append_string(string, status);
		
		wi_terminal_printf(wr_terminal, WI_STR("%@"), string);
		
		i++;
	}
	
	wr_terminal_reset_location();
}



void wr_draw_divider(void) {
	wi_list_node_t		*node;
	wi_string_t			*string, *action, *position;
	wr_window_t			*window;
	wi_size_t			size;
	wi_range_t			scroll;
	wi_point_t			location;
	const char			*color;
	unsigned int		line, lines, windows;
	
	string = wi_string_with_format(WI_STR("%s%@"), WR_PREFIX, wr_nick);
	
	if(wr_connected && wr_server) {
		wi_string_append_format(string, WI_STR(" - %@ - %u %@"),
								wr_server->name,
								wi_list_count(wr_users),
								wi_list_count(wr_users) == 1
									? WI_STR("user")
									: WI_STR("users"));
	}
	
	action = wi_string();
	windows = 0;
	
	WI_LIST_FOREACH(wr_windows, node, window) {
		switch(window->status) {
			case WR_WINDOW_STATUS_ACTION:
				color = WR_INTERFACE_COLOR;
				break;

			case WR_WINDOW_STATUS_CHAT:
				color = WR_STATUS_COLOR;
				break;

			case WR_WINDOW_STATUS_HIGHLIGHT:
				color = WR_HIGHLIGHT_COLOR;
				break;
				
			default:
				color = NULL;
				break;
		}
		
		if(color) {
			if(windows > 0)
				wi_string_append_string(action, WI_STR(","));
			
			wi_string_append_format(action, WI_STR("%s%s%s%u%s%s"),
				WR_END_COLOR,
				WR_INTERFACE_COLOR,
				color,
				window->wid,
				WR_END_COLOR,
				WR_INTERFACE_COLOR);
			
			windows++;
		}
	}

	if(windows > 0)
		wi_string_append_format(string, WI_STR(" [%@]"), action);
	
	line = wi_terminal_buffer_current_line(wr_current_window->buffer);
	lines = wi_terminal_buffer_lines(wr_current_window->buffer);
	scroll = wi_terminal_scroll(wr_terminal);
	
	if(lines == 0 || line == lines)
		position = NULL;
	else if(line <= scroll.length)
		position = wi_string_with_cstring("TOP");
	else
		position = wi_string_with_format(WI_STR("%.0f%%"), 100 * ((double) (line - scroll.length)  / (double) lines));
	
	wi_terminal_adjust_string_to_fit_width(wr_terminal, string);
	
	if(position) {
		wi_string_delete_characters_from_index(string, wi_string_length(string) - wi_string_length(position));
		wi_string_append_string(string, position);
	}

	size = wi_terminal_size(wr_terminal);

	location = wi_terminal_location(wr_terminal);
	wi_terminal_move_printf(wr_terminal, wi_make_point(0, size.height - 2), WI_STR("%s%@%s"),
		WR_INTERFACE_COLOR,
		string,
		WR_END_COLOR);
	wi_terminal_move(wr_terminal, location);
}
