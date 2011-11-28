/* $Id$ */

/*
 *  Copyright (c) 2004-2007 Axel Andersson
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
#include <string.h>
#include <errno.h>

#include "client.h"
#include "files.h"
#include "main.h"
#include "terminal.h"
#include "transfers.h"
#include "windows.h"

static void							wr_transfer_dealloc(wi_runtime_instance_t *);

static wr_tid_t						wr_transfer_tid(void);


wi_string_t							*wr_download_path;
wi_mutable_array_t					*wr_transfers;
wi_boolean_t						wr_transfers_recursive_upload;

static wi_runtime_id_t				wr_transfer_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t			wr_transfer_runtime_class = {
	"wr_transfer_t",
	wr_transfer_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};



void wr_transfers_init(void) {
	wr_transfer_runtime_id = wi_runtime_register_class(&wr_transfer_runtime_class);

	wr_transfers = wi_array_init(wi_mutable_array_alloc());

	wr_transfers_set_download_path(WI_STR("~"));
}



void wr_transfers_clear(void) {
	wi_mutable_array_remove_all_data(wr_transfers);
}



#pragma mark -

wi_integer_t wr_runloop_download_callback(wi_socket_t *socket) {
	wi_string_t		*local_path;
	wr_transfer_t	*transfer;
	char			buf[8192];
	wi_integer_t	bytes;
	
	bytes = wi_socket_read_buffer(socket, 15.0, buf, sizeof(buf));
	transfer = wr_transfers_transfer_with_socket(socket);
	
	if(transfer) {
		local_path = wi_array_first_data(transfer->local_paths);
		
		if(bytes > 0) {
			transfer->file_transferred += bytes;
			transfer->total_transferred += bytes;
			wr_received_bytes += bytes;
			
			if(wi_file_write_buffer(transfer->file, buf, bytes) < 0) {
				wr_printf_prefix(WI_STR("Could not write to %@: %m"),
					local_path);

				wr_transfer_stop(transfer);
			} else {
				wr_draw_transfers(false);
			}
		} else {
			if(bytes < 0) {
				wr_printf_prefix(WI_STR("Transfer of \"%@\" failed: %m"),
					wi_array_first_data(transfer->remote_paths));
			} else {
				if(transfer->file_transferred == wr_file_size(wi_array_first_data(transfer->files))) {
					wr_printf_prefix(WI_STR("Transfer of \"%@\" completed"),
						wi_array_first_data(transfer->remote_paths));
					
					transfer->state = WR_TRANSFER_FINISHED;
				} else {
					wr_printf_prefix(WI_STR("Transfer of \"%@\" stopped"),
						wi_array_first_data(transfer->remote_paths));
				}
			}

			wr_transfer_close(transfer);
			wr_transfer_start_next_or_stop(transfer);
		}
	}

	return 0;
}



wi_integer_t wr_runloop_upload_callback(wi_socket_t *socket) {
	wi_string_t		*local_path;
	wr_transfer_t	*transfer;
	char			buf[8192];
	wi_integer_t	bytes;

	transfer = wr_transfers_transfer_with_socket(socket);
	
	if(transfer) {
		local_path = wi_array_first_data(transfer->local_paths);
		bytes = wi_file_read_buffer(transfer->file, buf, sizeof(buf));
		
		if(bytes > 0) {
			bytes = wi_socket_write_buffer(socket, 15.0, buf, bytes);
			
			if(bytes < 0) {
				wr_printf_prefix(WI_STR("Transfer of \"%@\" failed: %m"),
					wi_array_first_data(transfer->remote_paths));
				
				wr_transfer_stop(transfer);
			} else {
				transfer->file_transferred += bytes;
				transfer->total_transferred += bytes;
				wr_transferred_bytes += bytes;
				
				wr_draw_transfers(false);
			}
		} else {
			if(bytes < 0) {
				wr_printf_prefix(WI_STR("Could not read from %@: %m"),
					local_path);
			} else {
				if(transfer->file_transferred == wr_file_size(wi_array_first_data(transfer->files))) {
					wr_printf_prefix(WI_STR("Transfer of \"%@\" completed"),
						wi_array_first_data(transfer->remote_paths));
				} else {
					wr_printf_prefix(WI_STR("Transfer of \"%@\" stopped"),
						wi_array_first_data(transfer->remote_paths));
				}
			}
			
			wr_transfer_close(transfer);
			wr_transfer_start_next_or_stop(transfer);
		}
	}
	
	return 0;
}



#pragma mark -

void wr_transfers_set_download_path(wi_string_t *download_path) {
	if(wi_is_equal(download_path, wr_download_path))
		return;
	
	wi_release(wr_download_path);
	wr_download_path = wi_retain(download_path);
	
	wr_printf_prefix(WI_STR("Using download path %@"), download_path);
}



#pragma mark -

void wr_transfers_download(wi_string_t *path) {
	wr_transfer_t		*transfer;
	
	transfer = wi_autorelease(wr_transfer_init_download(wr_transfer_alloc()));
	transfer->name = wi_retain(wi_string_last_path_component(path));
	transfer->master_path = wi_retain(path);
	
	wi_mutable_array_add_data(wr_transfers, transfer);
	
	if(transfer->tid == 1)
		wr_transfer_start(transfer);
}



void wr_transfers_upload(wi_string_t *path) {
	wr_transfer_t		*transfer;
	wr_file_t			*file;
	
	transfer = wi_autorelease(wr_transfer_init_upload(wr_transfer_alloc()));
	transfer->name = wi_retain(wi_string_last_path_component(path));
	transfer->master_path = wi_retain(wr_files_full_path(transfer->name));
	transfer->source_path = wi_retain(wi_string_by_normalizing_path(path));
	
	file = wi_autorelease(wr_file_init_with_local_path(wr_file_alloc(), transfer->source_path));
	
	if(!file) {
		wr_printf_prefix(WI_STR("put: Could not open %@: %m"),
			transfer->source_path);
		
		return;
	}
	
	if(!wr_transfer_upload_add_file(transfer, file)) {
		wr_printf_prefix(WI_STR("put: Could not add files from %@: %m"),
			transfer->source_path);
		
		return;
	}
	
	wi_mutable_array_add_data(wr_transfers, transfer);
	
	if(transfer->tid == 1)
		wr_transfer_start(transfer);
}



#pragma mark -

wr_transfer_t * wr_transfer_alloc(void) {
	return wi_runtime_create_instance(wr_transfer_runtime_id, sizeof(wr_transfer_t));
}



wr_transfer_t * wr_transfer_init(wr_transfer_t *transfer) {
	transfer->tid = wr_transfer_tid();
	transfer->remote_paths = wi_array_init(wi_mutable_array_alloc());
	transfer->local_paths = wi_array_init(wi_mutable_array_alloc());
	transfer->files = wi_array_init(wi_mutable_array_alloc());
	
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

	wi_release(transfer->name);
	wi_release(transfer->master_path);
	wi_release(transfer->source_path);
	wi_release(transfer->remote_paths);
	wi_release(transfer->local_paths);
	wi_release(transfer->files);

	wi_release(transfer->key);
	wi_release(transfer->checksum);
}



#pragma mark -

static wr_tid_t wr_transfer_tid(void) {
	wr_transfer_t		*transfer;

	if(wi_array_count(wr_transfers) > 0) {
		transfer = wi_array_last_data(wr_transfers);
		
		return transfer->tid + 1;
	}

	return 1;
}



#pragma mark -

void wr_transfer_download_add_files(wr_transfer_t *transfer, wi_array_t *files) {
	wi_enumerator_t	*enumerator;
	wr_file_t		*file;
	
	enumerator = wi_array_data_enumerator(files);
	
	while((file = wi_enumerator_next_data(enumerator)))
		wr_transfer_download_add_file(transfer, file, true);
}



void wr_transfer_download_add_file(wr_transfer_t *transfer, wr_file_t *file, wi_boolean_t recursive) {
	wi_string_t		*remote_path, *local_path, *parent_path;
	
	remote_path = wr_file_path(file);
	
	if(recursive) {
		local_path = wi_string_by_appending_path_component(transfer->name,
			wi_string_substring_from_index(remote_path, wi_string_length(transfer->master_path)));
	} else {
		local_path = wi_string_last_path_component(remote_path);
	}
	
	local_path = wi_string_by_appending_path_component(wi_string_by_normalizing_path(wr_download_path), local_path);
	parent_path = wi_string_by_deleting_last_path_component(local_path);
	
	wi_fs_create_directory(parent_path, 0755);

	if(wr_file_type(file) == WR_FILE_FILE) {
		wi_mutable_array_add_data(transfer->remote_paths, remote_path);
		wi_mutable_array_add_data(transfer->local_paths, local_path);
		wi_mutable_array_add_data(transfer->files, file);
		
		transfer->total_size += wr_file_size(file);
	} else {
		if(!wi_fs_path_exists(local_path, NULL)) {
			if(!wi_fs_create_directory(local_path, 0755)) {
				wr_printf_prefix(WI_STR("get: Unable to create directory at %@: %m"),
					local_path);
			}
		}
	}
}



wi_boolean_t wr_transfer_upload_add_file(wr_transfer_t *transfer, wr_file_t *file) {
	WI_FTS			*fts = NULL;
	WI_FTSENT		*p;
	wi_string_t		*local_path, *remote_path;
	wr_file_t		*fts_file;
	char			*paths[2];
	
	if(wr_file_type(file) == WR_FILE_FILE) {
		wi_mutable_array_add_data(transfer->local_paths, wr_file_path(file));
		wi_mutable_array_add_data(transfer->remote_paths, wr_files_full_path(transfer->name));
		wi_mutable_array_add_data(transfer->files, file);
		
		transfer->total_size += wr_file_size(file);
	} else {
		wr_transfers_recursive_upload = true;
		transfer->recursive = true;

		paths[0] = (char *) wi_string_cstring(wr_file_path(file));
		paths[1] = NULL;
		
		errno = 0;
		fts = wi_fts_open(paths, WI_FTS_NOSTAT | WI_FTS_LOGICAL, NULL);
		
		if(!fts)
			return false;
		
		if(fts && errno != 0) {
			wi_fts_close(fts);
			
			return false;
		}
		
		while((p = wi_fts_read(fts))) {
			if(p->fts_level > 10) {
				wi_fts_set(fts, p, WI_FTS_SKIP);
				
				continue;
			}
			
			switch(p->fts_info) {
				case WI_FTS_DC:
					errno = ELOOP;
					
					wr_printf_prefix(WI_STR("put: Could not read %s: %s"),
						strerror(errno));
					
					continue;
					break;
					
				case WI_FTS_DP:
					continue;
					break;
					
				case WI_FTS_DNR:
				case WI_FTS_ERR:
					wr_printf_prefix(WI_STR("put: Could not read %s: %s"),
						strerror(p->fts_errno));
					
					continue;
					break;
			}
			
			if(p->fts_name[0] == '.') {
				wi_fts_set(fts, p, WI_FTS_SKIP);
				
				continue;
			}
			
			local_path = wi_string_with_cstring(p->fts_path);
			remote_path = wi_string_by_normalizing_path(wi_string_by_appending_path_component(transfer->master_path,
				wi_string_substring_from_index(local_path, wi_string_length(transfer->source_path))));
			
			if(p->fts_info == WI_FTS_D) {
				wr_send_command(WI_STR("FOLDER %#@"), remote_path);
			} else {
				wi_mutable_array_add_data(transfer->local_paths, local_path);
				wi_mutable_array_add_data(transfer->remote_paths, remote_path);

				fts_file = wr_file_init_with_local_path(wr_file_alloc(), local_path);
				transfer->total_size += wr_file_size(fts_file);
				wi_mutable_array_add_data(transfer->files, fts_file);
				wi_release(fts_file);
			}
		}
		
		wi_fts_close(fts);
	}
	
	return true;
}



void wr_transfer_upload_remove_files(wr_transfer_t *transfer, wi_array_t *files) {
	wi_enumerator_t		*enumerator;
	wr_file_t			*file;
	wi_uinteger_t		i, count;
	
	count = wi_array_count(transfer->remote_paths);
	enumerator = wi_array_data_enumerator(files);
	
	while((file = wi_enumerator_next_data(enumerator))) {
		for(i = 0; i < count; i++) {
			if(wi_is_equal(wr_file_path(file), WI_ARRAY(transfer->remote_paths, i))) {
				transfer->total_size -= wr_file_size(WI_ARRAY(transfer->files, i));
				
				wi_mutable_array_remove_data_at_index(transfer->remote_paths, i);
				wi_mutable_array_remove_data_at_index(transfer->local_paths, i);
				wi_mutable_array_remove_data_at_index(transfer->files, i);
				
				count--;
				
				break;
			}
		}
	}
	
	wr_transfers_recursive_upload = false;
}



#pragma mark -

void wr_transfer_start(wr_transfer_t *transfer) {
	if(transfer->state == WR_TRANSFER_WAITING) {
		if(transfer->type == WR_TRANSFER_DOWNLOAD) {
			wr_stat_state = WR_STAT_TRANSFER;
			
			if(wi_array_count(transfer->remote_paths) == 0)
				wr_send_command(WI_STR("STAT %#@"), transfer->master_path);
			else
				wr_send_command(WI_STR("STAT %#@"), wi_array_first_data(transfer->remote_paths));
		} else {
			if(transfer->recursive && !transfer->listed) {
				wr_ls_state = WR_LS_TRANSFER;
				
				wr_files_clear();
				wr_send_command(WI_STR("LISTRECURSIVE %#@"), transfer->master_path);
			} else {
				wr_transfer_request(transfer);
			}
		}
	}
}



void wr_transfer_start_next_or_stop(wr_transfer_t *transfer) {
	if(wi_array_count(transfer->remote_paths) > 0) {
		transfer->state = WR_TRANSFER_WAITING;
		
		wr_transfer_start(transfer);
	} else {
		if(transfer->recursive) {
			if(transfer->type == WR_TRANSFER_DOWNLOAD) {
				wr_printf_prefix(WI_STR("Finished directory download of \"%@\""),
					transfer->master_path);
			} else {
				wr_printf_prefix(WI_STR("Finished directory upload of \"%@\""),
					transfer->master_path);
			}
		}

		wr_transfer_stop(transfer);
	}
}



void wr_transfer_request(wr_transfer_t *transfer) {
	wi_string_t			*local_path;
	wi_fs_stat_t		sb;

	if(wi_array_count(transfer->local_paths) == 0) {
		wr_transfer_start_next_or_stop(transfer);
		
		return;
	}

	if(transfer->type == WR_TRANSFER_DOWNLOAD) {
		local_path = wi_array_first_data(transfer->local_paths);
		
		if(wi_fs_stat_path(local_path, &sb)) {
			if(!transfer->recursive) {
				wr_printf_prefix(WI_STR("get: File already exists at %@"),
					 local_path);
			}
			
			wr_transfer_close(transfer);
			
			if(transfer->recursive) {
				transfer->total_transferred += sb.size;
				wr_transfer_start_next_or_stop(transfer);
			}
			
			return;
		}
		
		if(!wi_string_has_suffix(local_path, WI_STR(WR_TRANSFERS_SUFFIX))) {
			local_path = wi_string_by_appending_string(local_path, WI_STR(WR_TRANSFERS_SUFFIX));
			
			wi_mutable_array_replace_data_at_index(transfer->local_paths, local_path, 0);
		}
		
		if(wi_fs_stat_path(local_path, &sb)) {
			transfer->file_offset = sb.size;
			
			if(sb.size >= WR_CHECKSUM_SIZE)
				transfer->checksum = wi_retain(wi_fs_sha1_for_path(local_path, WR_CHECKSUM_SIZE));
		}
		
		transfer->file = wi_retain(wi_file_for_updating(local_path));
		
		if(!transfer->file) {
			wr_printf_prefix(WI_STR("get: Could not open %@: %m"),
				local_path);
			
			wr_transfer_close(transfer);
			
			if(transfer->recursive)
				wr_transfer_start_next_or_stop(transfer);
			
			return;
		}
		
		transfer->file_size = wr_file_size(wi_array_first_data(transfer->files));
	
		wr_send_command(WI_STR("GET %#@%c%llu"),
			wi_array_first_data(transfer->remote_paths),	WR_FIELD_SEPARATOR,
			transfer->file_offset);
	} else {
		local_path = wi_array_first_data(transfer->local_paths);

		transfer->file = wi_retain(wi_file_for_reading(local_path));
		 
		if(!transfer->file) {
			wr_printf_prefix(WI_STR("put: Could not open %@: %m"),
				local_path);
			
			wr_transfer_close(transfer);
			
			if(transfer->recursive)
				wr_transfer_start_next_or_stop(transfer);
			
			return;
		}
		
		if(!wi_fs_stat_path(local_path, &sb)) {
			wr_printf_prefix(WI_STR("put: Could not open %@: %m"),
				local_path);
			
			wr_transfer_close(transfer);
			
			if(transfer->recursive)
				wr_transfer_start_next_or_stop(transfer);
			
			return;
		}

		transfer->file_size = sb.size;
		transfer->checksum = wi_retain(wi_fs_sha1_for_path(local_path, WR_CHECKSUM_SIZE));
		
		wr_send_command(WI_STR("PUT %#@%c%llu%c%#@"),
						wi_array_first_data(transfer->remote_paths),	WR_FIELD_SEPARATOR,
						transfer->file_size,							WR_FIELD_SEPARATOR,
						transfer->checksum);
	}
}



void wr_transfer_open(wr_transfer_t *transfer, wi_file_offset_t offset, wi_string_t *key) {
	wi_address_t		*address;
	
	address = wi_autorelease(wi_copy(wr_address));
	wi_address_set_port(address, wi_address_port(address) + 1);
	
	transfer->state				= WR_TRANSFER_RUNNING;
	transfer->file_offset		= offset;
	transfer->total_offset		+= offset;
	transfer->file_transferred	= offset;
	transfer->total_transferred	+= offset;
	transfer->key				= wi_retain(key);
	transfer->start_time		= wi_time_interval();
	transfer->socket			= wi_socket_init_with_address(wi_socket_alloc(), address, WI_SOCKET_TCP);
	
	wi_socket_set_interactive(transfer->socket, false);
	
	if(!wi_socket_connect(transfer->socket, 15.0)) {
		wr_printf_prefix(WI_STR("Could not connect to %@: %m"), wi_address_string(address));
		
		wr_transfer_close(transfer);
		
		return;
	}
	
	if(!wi_socket_connect_tls(transfer->socket, wr_socket_tls, 15.0)) {
		wr_printf_prefix(WI_STR("Could not connect to %@: %m"), wi_address_string(address));
		
		wr_transfer_close(transfer);
		
		return;
	}
	
	wi_file_seek(transfer->file, transfer->file_offset);
	
	if(transfer->type == WR_TRANSFER_DOWNLOAD) {
		wi_socket_set_direction(transfer->socket, WI_SOCKET_READ);
		wr_runloop_add_socket(transfer->socket, wr_runloop_download_callback);
	} else {
		wi_socket_set_direction(transfer->socket, WI_SOCKET_WRITE);
		wr_runloop_add_socket(transfer->socket, wr_runloop_upload_callback);
	}
	
	wr_send_command_on_socket(transfer->socket, WI_STR("TRANSFER %#@"), transfer->key);
	
	wr_printf_prefix(WI_STR("Starting transfer of \"%@\""), wi_array_first_data(transfer->remote_paths));
	
	wr_draw_transfers(true);
}



void wr_transfer_close(wr_transfer_t *transfer) {
	wi_string_t		*local_path, *path;
	
	if(transfer->type == WR_TRANSFER_DOWNLOAD && transfer->state == WR_TRANSFER_FINISHED) {
		local_path = wi_array_first_data(transfer->local_paths);
		path = wi_string_by_deleting_path_extension(local_path);
		wi_fs_rename_path(local_path, path);
	}
	
	wi_mutable_array_remove_data_at_index(transfer->remote_paths, 0);
	wi_mutable_array_remove_data_at_index(transfer->local_paths, 0);
	wi_mutable_array_remove_data_at_index(transfer->files, 0);

	if(transfer->file) {
		wi_file_close(transfer->file);
		wi_release(transfer->file);
		transfer->file = NULL;
	}
		
	wi_release(transfer->key);
	transfer->key = NULL;

	wi_release(transfer->checksum);
	transfer->checksum = NULL;

	if(transfer->socket) {
		wr_runloop_remove_socket(transfer->socket);
		wi_socket_close(transfer->socket);
		wi_release(transfer->socket);
		transfer->socket = NULL;
	}
}



void wr_transfer_stop(wr_transfer_t *transfer) {
	wi_mutable_array_remove_data(wr_transfers, transfer);

	transfer = wi_array_first_data(wr_transfers);

	if(transfer) {
		wi_thread_sleep(0.1);
		
		wr_transfer_start(transfer);
	}

	wr_terminal_redraw();
}



#pragma mark -

wr_transfer_t * wr_transfers_transfer_with_tid(wr_tid_t tid) {
	wi_enumerator_t	*enumerator;
	wr_transfer_t   *transfer;

	enumerator = wi_array_data_enumerator(wr_transfers);
	
	while((transfer = wi_enumerator_next_data(enumerator))) {
		if(transfer->tid == tid)
			return transfer;
	}

	return NULL;
}



wr_transfer_t * wr_transfers_transfer_with_remote_path(wi_string_t *remote_path) {
	wi_enumerator_t	*enumerator, *path_enumerator;
	wi_string_t		*path;
	wr_transfer_t   *transfer;

	enumerator = wi_array_data_enumerator(wr_transfers);
	
	while((transfer = wi_enumerator_next_data(enumerator))) {
		if(wi_is_equal(transfer->master_path, remote_path))
			return transfer;

		path_enumerator = wi_array_data_enumerator(transfer->remote_paths);
		
		while((path = wi_enumerator_next_data(path_enumerator))) {
			if(wi_is_equal(path, remote_path))
				return transfer;
		}
	}

	return NULL;
}



wr_transfer_t * wr_transfers_transfer_with_socket(wi_socket_t *socket) {
	wi_enumerator_t	*enumerator;
	wr_transfer_t   *transfer;

	enumerator = wi_array_data_enumerator(wr_transfers);
	
	while((transfer = wi_enumerator_next_data(enumerator))) {
		if(transfer->socket == socket)
			return transfer;
	}

	return NULL;
}
