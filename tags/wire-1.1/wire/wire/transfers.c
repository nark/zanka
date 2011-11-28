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

#include <wired/wired.h>

#include "client.h"
#include "files.h"
#include "main.h"
#include "terminal.h"
#include "transfers.h"
#include "windows.h"

static void							wr_transfer_dealloc(wi_runtime_instance_t *);

static wr_tid_t						wr_transfer_tid(void);


wi_list_t							*wr_transfers;

static wi_runtime_id_t				wr_transfer_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t			wr_transfer_runtime_class = {
	"wr_transfer_t",
	wr_transfer_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};



void wr_init_transfers(void) {
	wr_transfer_runtime_id = wi_runtime_register_class(&wr_transfer_runtime_class);

	wr_transfers = wi_list_init(wi_list_alloc());
}



void wr_clear_transfers(void) {
	wi_list_remove_all_data(wr_transfers);
}



#pragma mark -

wr_transfer_t * wr_transfer_alloc(void) {
	return wi_runtime_create_instance(wr_transfer_runtime_id, sizeof(wr_transfer_t));
}



wr_transfer_t * wr_transfer_init(wr_transfer_t *transfer) {
	transfer->tid = wr_transfer_tid();
	
	return transfer;
}



wr_transfer_t * wr_transfer_init_download(wr_transfer_t *transfer) {
	transfer = wr_transfer_init(transfer);
	
	transfer->type  = WR_TRANSFER_DOWNLOAD;
	
	return transfer;
}



wr_transfer_t * wr_transfer_init_upload(wr_transfer_t *transfer) {
	transfer = wr_transfer_init(transfer);
	
	transfer->type  = WR_TRANSFER_UPLOAD;
	
	return transfer;
}



static void wr_transfer_dealloc(wi_runtime_instance_t *instance) {
	wr_transfer_t		*transfer = instance;

	wr_runloop_remove_socket(transfer->socket);
	wi_release(transfer->socket);
	
	wi_release(transfer->file);
	
	wi_release(transfer->name);
	wi_release(transfer->path);
	wi_release(transfer->local_path);

	wi_release(transfer->key);
	wi_release(transfer->checksum);
}



#pragma mark -

static wr_tid_t wr_transfer_tid(void) {
	wr_transfer_t		*transfer;

	if(wi_list_count(wr_transfers) > 0) {
		transfer = wi_list_last_data(wr_transfers);
		
		return transfer->tid + 1;
	}

	 return 1;
}



#pragma mark -

void wr_transfer_download(wi_string_t *path) {
	wr_transfer_t		*transfer;
	struct stat			sb;
	
	transfer = wi_autorelease(wr_transfer_init_download(wr_transfer_alloc()));
	transfer->path = wi_retain(wr_files_full_path(path));
	transfer->name = wi_retain(wi_string_last_path_component(transfer->path));
	transfer->local_path = wi_retain(wi_user_home());
	wi_string_append_path_component(transfer->local_path, transfer->name);
	
	if(wi_file_stat(transfer->local_path, &sb)) {
		wr_printf_prefix(WI_STR("get: File already exists at %@"),
			transfer->local_path);

		wi_release(transfer);
		
		return;
	}
	
	if(!wi_string_has_suffix(transfer->local_path, WI_STR(WR_TRANSFERS_SUFFIX)))
		wi_string_append_string(transfer->local_path, WI_STR(WR_TRANSFERS_SUFFIX));
	
	if(wi_file_stat(transfer->local_path, &sb)) {
		transfer->offset = sb.st_size;
		
		if(sb.st_size >= WR_CHECKSUM_SIZE)
			transfer->checksum = wi_retain(wi_file_sha1(transfer->local_path, WR_CHECKSUM_SIZE));
	}
	
	transfer->file = wi_retain(wi_file_for_updating(transfer->local_path));
	
	if(!transfer->file) {
		wr_printf_prefix(WI_STR("get: Could not open %@: %m"),
			transfer->local_path);
		
		return;
	}
	
	wi_list_append_data(wr_transfers, transfer);
	
	if(transfer->tid == 1)
		wr_transfer_start(transfer);
}



void wr_transfer_upload(wi_string_t *path) {
	wr_transfer_t		*transfer;
	struct stat			sb;
	
	transfer = wi_autorelease(wr_transfer_init_upload(wr_transfer_alloc()));
	transfer->local_path = wi_retain(wi_string_by_expanding_tilde_in_path(path));
	wi_string_normalize_path(transfer->local_path);
	transfer->name = wi_retain(wi_string_last_path_component(transfer->local_path));
	transfer->path = wi_retain(wr_files_full_path(transfer->name));
	
	if(!wi_file_stat(transfer->local_path, &sb)) {
		wr_printf_prefix(WI_STR("put: Could not open %@: %m"),
			transfer->local_path);
		
		return;
	}
	
	transfer->file = wi_retain(wi_file_for_updating(transfer->local_path));
	
	if(!transfer->file) {
		wr_printf_prefix(WI_STR("put: Could not open %@: %m"),
			transfer->local_path);

		return;
	}
	
	transfer->size = sb.st_size;
	transfer->checksum = wi_retain(wi_file_sha1(transfer->local_path, WR_CHECKSUM_SIZE));
	
	wi_list_append_data(wr_transfers, transfer);
	
	if(transfer->tid == 1)
		wr_transfer_start(transfer);
}



#pragma mark -

void wr_transfer_start(wr_transfer_t *transfer) {
	if(transfer->state == WR_TRANSFER_WAITING) {
		if(transfer->type == WR_TRANSFER_DOWNLOAD) {
			wr_stat_state = WR_STAT_TRANSFER;
			wr_send_command(WI_STR("STAT %#@"), transfer->path);
		} else {
			wr_send_command(WI_STR("PUT %#@%c%llu%c%#@"),
				transfer->path,			WR_FIELD_SEPARATOR,
				transfer->size,			WR_FIELD_SEPARATOR,
				transfer->checksum);
		}
	}
}



void wr_transfer_stop(wr_transfer_t *transfer) {
	wi_list_remove_data(wr_transfers, transfer);

	transfer = wi_list_first_data(wr_transfers);

	if(transfer) {
		wi_thread_sleep(0.1);
		
		wr_transfer_start(transfer);
	}

	wr_terminal_redraw();
}



#pragma mark -

int wr_runloop_download_callback(wi_socket_t *socket) {
	wi_string_t		*path;
	wr_transfer_t	*transfer;
	char			buf[8192];
	int				bytes;
	
	bytes = wi_socket_read_buffer(socket, 15.0, buf, sizeof(buf));
	transfer = wr_transfer_with_socket(socket);

	if(bytes > 0) {
		transfer->transferred += bytes;
		wr_received_bytes += bytes;
		
		if(wi_file_write_buffer(transfer->file, buf, bytes) < 0) {
			wr_printf_prefix(WI_STR("Could not write to %@: %m"),
				transfer->local_path);

			wr_transfer_stop(transfer);
		} else {
			wr_draw_transfers(false);
		}
	} else {
		if(bytes < 0) {
			wr_printf_prefix(WI_STR("Transfer of \"%@\" failed: %m"),
				transfer->name);
		} else {
			if(transfer->transferred == transfer->size) {
				wr_printf_prefix(WI_STR("Transfer of \"%@\" completed"),
					transfer->name);

				path = wi_string_by_deleting_path_extension(transfer->local_path);
				
				wi_file_rename(transfer->local_path, path);
			} else {
				wr_printf_prefix(WI_STR("Transfer of \"%@\" stopped"),
					transfer->name);
			}
		}

		wr_transfer_stop(transfer);
	}

	return 0;
}



int wr_runloop_upload_callback(wi_socket_t *socket) {
	wr_transfer_t	*transfer;
	char			buf[8192];
	int				bytes;

	transfer = wr_transfer_with_socket(socket);
	bytes = wi_file_read_buffer(transfer->file, buf, sizeof(buf));

	if(bytes > 0) {
		bytes = wi_socket_write_buffer(socket, 15.0, buf, bytes);

		if(bytes < 0) {
			wr_printf_prefix(WI_STR("Transfer of \"%@\" failed: %m"),
				transfer->name);

			wr_transfer_stop(transfer);
		} else {
			transfer->transferred += bytes;
			wr_transferred_bytes += bytes;
		
			wr_draw_transfers(false);
		}
	} else {
		if(bytes < 0) {
			wr_printf_prefix(WI_STR("Could not read from %@: %m"),
				transfer->local_path);
		} else {
			if(transfer->transferred == transfer->size) {
				wr_printf_prefix(WI_STR("Transfer of \"%@\" completed"),
					transfer->name);
			} else {
				wr_printf_prefix(WI_STR("Transfer of \"%@\" stopped"),
					transfer->name);
			}
		}
		
		wr_transfer_stop(transfer);
	}
	
	return 0;
}



#pragma mark -

wr_transfer_t * wr_transfer_with_tid(wr_tid_t tid) {
	wi_list_node_t  *node;
	wr_transfer_t   *transfer;

	WI_LIST_FOREACH(wr_transfers, node, transfer) {
		if(transfer->tid == tid)
			return transfer;
	}

	return NULL;
}



wr_transfer_t * wr_transfer_with_path(wi_string_t *path) {
	wi_list_node_t  *node;
	wr_transfer_t   *transfer;

	WI_LIST_FOREACH(wr_transfers, node, transfer) {
		if(wi_is_equal(transfer->path, path))
			return transfer;
	}

	return NULL;
}



wr_transfer_t * wr_transfer_with_socket(wi_socket_t *socket) {
	wi_list_node_t  *node;
	wr_transfer_t   *transfer;

	WI_LIST_FOREACH(wr_transfers, node, transfer) {
		if(transfer->socket == socket)
			return transfer;
	}

	return NULL;
}
