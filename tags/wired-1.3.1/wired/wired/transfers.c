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

#include <sys/fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <openssl/ssl.h>
#include <wired/wired.h>

#include "files.h"
#include "main.h"
#include "server.h"
#include "settings.h"
#include "transfers.h"

#define WD_TRANSFERS_TIMER_INTERVAL		60.0
#define WD_TRANSFERS_WAITING_INTERVAL	20.0

#define WD_TRANSFER_BUFFER_SIZE			8192

static void								wd_update_transfers(wi_timer_t *);

static void								wd_transfers_update_queue(void);

static wd_transfer_t *					wd_transfer_alloc(void);
static wd_transfer_t *					wd_transfer_init_with_client(wd_transfer_t *, wd_client_t *);
static wd_transfer_t *					wd_transfer_init_download_with_client(wd_transfer_t *, wd_client_t *);
static wd_transfer_t *					wd_transfer_init_upload_with_client(wd_transfer_t *, wd_client_t *);
static void								wd_transfer_dealloc(wi_runtime_instance_t *);
static wi_string_t *					wd_transfer_description(wi_runtime_instance_t *);

static void								wd_transfer_set_state(wd_transfer_t *, wd_transfer_state_t);

static void								wd_transfer_download(wd_transfer_t *);
static void								wd_transfer_upload(wd_transfer_t *);


wi_list_t								*wd_transfers;

static wi_timer_t						*wd_transfers_timer;

static wi_runtime_id_t					wd_transfer_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				wd_transfer_runtime_class = {
	"wd_transfer_t",
	wd_transfer_dealloc,
	NULL,
	NULL,
	wd_transfer_description,
	NULL
};


void wd_init_transfers(void) {
	wd_transfer_runtime_id = wi_runtime_register_class(&wd_transfer_runtime_class);

	wd_transfers = wi_list_init(wi_list_alloc());

	wd_transfers_timer = wi_timer_init_with_function(wi_timer_alloc(),
													 wd_update_transfers,
													 WD_TRANSFERS_TIMER_INTERVAL,
													 true);
}



void wd_schedule_transfers(void) {
	wi_timer_schedule(wd_transfers_timer);
}



static void wd_update_transfers(wi_timer_t *timer) {
	wi_list_node_t		*node, *next_node;
	wd_transfer_t		*transfer;
	wi_time_interval_t	interval;
	wi_boolean_t		update = false;

	if(wi_list_count(wd_transfers) > 0) {
		interval = wi_time_interval();

		wi_list_wrlock(wd_transfers);
		for(node = wi_list_first_node(wd_transfers); node; node = next_node) {
			next_node	= wi_list_node_next_node(node);
			transfer	= wi_list_node_data(node);

			if(transfer->state == WD_TRANSFER_WAITING) {
				if(transfer->queue_time + WD_TRANSFERS_WAITING_INTERVAL < interval) {
					wi_list_remove_node(wd_transfers, node);

					update = true;
				}
			}
		}
		wi_list_unlock(wd_transfers);

		if(update)
			wd_transfers_update_queue();
	}
}



void wd_dump_transfers(void) {
	wi_log_debug(WI_STR("Transfers:"));
	wi_log_debug(WI_STR("%@"), wd_transfers);
}



#pragma mark -

void wd_transfers_queue_download(wi_string_t *path, wi_file_offset_t offset) {
	wd_client_t			*client = wd_client();
	wi_string_t			*realpath;
	wd_transfer_t		*transfer;
	struct stat			sb;
	
	realpath = wd_files_real_path(path);
	wi_string_resolve_aliases_in_path(realpath);
	
	if(!wi_file_stat(realpath, &sb)) {
		wi_log_err(WI_STR("Could not open %@: %m"), realpath);
		wd_reply_error();

		return;
	}
	
	transfer				= wd_transfer_init_download_with_client(wd_transfer_alloc(), client);
	transfer->path			= wi_retain(path);
	transfer->realpath		= wi_retain(realpath);
	transfer->size			= sb.st_size;
	transfer->offset		= offset;
	transfer->transferred	= offset;
	
	wi_list_wrlock(wd_transfers);
	wi_list_append_data(wd_transfers, transfer);
	wi_list_unlock(wd_transfers);
	wi_release(transfer);
	
	wd_transfers_update_queue();
}



void wd_transfers_queue_upload(wi_string_t *path, wi_file_offset_t size, wi_string_t *checksum) {
	wd_client_t			*client = wd_client();
	wi_string_t			*realpath, *filechecksum;
	wd_transfer_t		*transfer;
	wi_file_offset_t	offset;
	struct stat			sb;
	
	realpath = wd_files_real_path(path);
	wi_string_resolve_aliases_in_path(realpath);
	
	if(wi_file_stat(realpath, &sb)) {
		wd_reply(521, WI_STR("File or Directory Exists"));

		return;
	}
	
	if(!wi_string_has_suffix(realpath, WI_STR(WD_TRANSFERS_PARTIAL_EXTENSION)))
		wi_string_append_string(realpath, WI_STR(WD_TRANSFERS_PARTIAL_EXTENSION));
	
	if(!wi_file_stat(realpath, &sb)) {
		offset = 0;
	} else {
		offset = sb.st_size;
		
		if(sb.st_size >= WD_FILES_CHECKSUM_SIZE) {
			filechecksum = wi_file_sha1(realpath, WD_FILES_CHECKSUM_SIZE);
			
			if(!wi_is_equal(filechecksum, checksum)) {
				wd_reply(522, WI_STR("Checksum Mismatch"));
				
				return;
			}
		}
	}
	
	transfer				= wd_transfer_init_upload_with_client(wd_transfer_alloc(), client);
	transfer->path			= wi_retain(path);
	transfer->realpath		= wi_retain(realpath);
	transfer->size			= size;
	transfer->offset		= offset;
	transfer->transferred	= offset;
	
	wi_list_wrlock(wd_transfers);
	wi_list_append_data(wd_transfers, transfer);
	wi_list_unlock(wd_transfers);
	wi_release(transfer);
	
	wd_transfers_update_queue();
}



wi_boolean_t wd_transfers_can_queue(wd_transfer_type_t type) {
	wd_client_t		*client = wd_client();
	uint32_t		i, count, limit;
	
	limit = (type == WD_TRANSFER_DOWNLOAD) ? wd_settings.clientdownloads : wd_settings.clientuploads;
	count = wd_transfers_count_of_client(client, type);
	
	if(count >= limit) {
		if(count > limit) {
			return false;
		} else {
			for(i = 0; i < 10; i++) {
				wi_thread_sleep(1.0);

				count = wd_transfers_count_of_client(client, type);
				
				if(count < limit)
					break;
			}
			
			if(count >= limit)
				return false;
		}
	}
	
	return true;
}



unsigned int wd_transfers_count_of_client(wd_client_t *client, wd_transfer_type_t type) {
	wi_list_node_t	*node;
	wd_transfer_t	*transfer;
	unsigned int	count = 0;    
	
	wi_list_rdlock(wd_transfers);
	WI_LIST_FOREACH(wd_transfers, node, transfer) {
		if(transfer->client == client && transfer->type == type) {
			if(transfer->state <= WD_TRANSFER_RUNNING)
				count++;
		}
	}
	wi_list_unlock(wd_transfers);

	return count;
}



void wd_transfers_remove_client(wd_client_t *client) {
	wi_list_node_t	*node, *next_node;
	wd_transfer_t	*transfer;
	wi_boolean_t	update = false;

	wi_list_wrlock(wd_transfers);
	for(node = wi_list_first_node(wd_transfers); node; node = next_node) {
		next_node	= wi_list_node_next_node(node);
		transfer	= wi_list_node_data(node);

		if(transfer->state <= WD_TRANSFER_RUNNING &&
		   transfer->client == client) {
			if(transfer->state == WD_TRANSFER_RUNNING) {
				wi_list_unlock(wd_transfers);
				wd_transfer_set_state(transfer, WD_TRANSFER_STOP);
				
				wi_condition_lock_lock_when_condition(transfer->state_lock, WD_TRANSFER_STOPPED, 5.0);
				wi_condition_lock_unlock(transfer->state_lock);
				wi_list_wrlock(wd_transfers);
			} else {
				wi_list_remove_node(wd_transfers, node);

				update = true;
			}
		}
	}
	wi_list_unlock(wd_transfers);
	
	if(update)
		wd_transfers_update_queue();
}



#pragma mark -

void wd_transfers_update_queue(void) {
	wi_list_node_t      *client_node, *transfer_node;
	wd_transfer_t       *transfer;
	wd_client_t         *client;
	unsigned int        position_downloads, position_uploads;
	unsigned int        client_downloads, client_uploads;
	unsigned int        all_downloads, all_uploads;
	unsigned int        position;

	wi_list_rdlock(wd_clients);
	wi_list_rdlock(wd_transfers);

	/* count total number of active transfers */
	all_downloads = all_uploads = 0;

	WI_LIST_FOREACH(wd_transfers, transfer_node, transfer) {
		if(transfer->state == WD_TRANSFER_WAITING ||
		   transfer->state == WD_TRANSFER_RUNNING) {
			if(transfer->type == WD_TRANSFER_DOWNLOAD)
				all_downloads++;
			else
				all_uploads++;
		}
	}

	WI_LIST_FOREACH(wd_clients, client_node, client) {
		position_downloads = position_uploads = 0;
		client_downloads = client_uploads = 0;

		/* count number of active transfers for this client */
		WI_LIST_FOREACH(wd_transfers, transfer_node, transfer) {
			if(transfer->client == client) {
				if(transfer->state == WD_TRANSFER_WAITING ||
				   transfer->state == WD_TRANSFER_RUNNING) {
					if(transfer->type == WD_TRANSFER_DOWNLOAD)
						client_downloads++;
					else
						client_uploads++;
				}
			}
		}

		/* traverse the transfer queue */
		WI_LIST_FOREACH(wd_transfers, transfer_node, transfer) {
			if(transfer->type == WD_TRANSFER_DOWNLOAD)
				position_downloads++;
			else
				position_uploads++;

			if(transfer->state == WD_TRANSFER_QUEUED && transfer->client == client) {
				/* calculate number in queue */
				if(transfer->type == WD_TRANSFER_DOWNLOAD) {
					if(all_downloads >= wd_settings.totaldownloads)
						position = position_downloads - all_downloads;
					else if(client_downloads >= wd_settings.clientdownloads)
						position = position_downloads - client_downloads;
					else
						position = 0;
				} else {
					if(all_uploads >= wd_settings.totaluploads)
						position = position_uploads - all_uploads;
					else if(client_uploads >= wd_settings.clientuploads)
						position = position_uploads - client_uploads;
					else
						position = 0;
				}

				if(position > 0) {
					if(transfer->queue != position) {
						/* queue position changed */
						transfer->queue = position;

						wd_client_lock_socket(client);
						wd_sreply(client->socket, 401, WI_STR("%#@%c%u"),
								  transfer->path,	WD_FIELD_SEPARATOR,
								  transfer->queue);
						wd_client_unlock_socket(client);
					}
				} else {
					/* queue position reached 0 */
					transfer->queue = 0;
					transfer->state = WD_TRANSFER_WAITING;
					transfer->queue_time = wi_time_interval();

					wd_client_lock_socket(client);
					wd_sreply(client->socket, 400, WI_STR("%#@%c%llu%c%#@"),
							  transfer->path,		WD_FIELD_SEPARATOR,
							  transfer->offset,		WD_FIELD_SEPARATOR,
							  transfer->hash);
					wd_client_unlock_socket(client);

					if(transfer->type == WD_TRANSFER_DOWNLOAD) {
						all_downloads++;
						client_downloads++;
					} else {
						all_uploads++;
						client_uploads++;
					}
				}
			}
		}
	}

	wi_list_unlock(wd_transfers);
	wi_list_unlock(wd_clients);
}



#pragma mark -

wd_transfer_t * wd_transfer_alloc(void) {
	return wi_runtime_create_instance(wd_transfer_runtime_id, sizeof(wd_transfer_t));
}



static wd_transfer_t * wd_transfer_init_with_client(wd_transfer_t *transfer, wd_client_t *client) {
	transfer->state			= WD_TRANSFER_QUEUED;
	transfer->client		= wi_retain(client);
	transfer->hash			= wi_retain(wi_data_sha1(wi_data_with_random_bytes(1024)));
	transfer->state_lock	= wi_condition_lock_init_with_condition(wi_condition_lock_alloc(), transfer->state);

	return transfer;
}



static wd_transfer_t * wd_transfer_init_download_with_client(wd_transfer_t *transfer, wd_client_t *client) {
	transfer				= wd_transfer_init_with_client(transfer, client);
	transfer->type			= WD_TRANSFER_DOWNLOAD;
	
	return transfer;
}



static wd_transfer_t * wd_transfer_init_upload_with_client(wd_transfer_t *transfer, wd_client_t *client) {
	transfer				= wd_transfer_init_with_client(transfer, client);
	transfer->type			= WD_TRANSFER_UPLOAD;
	
	return transfer;
}



static void wd_transfer_dealloc(wi_runtime_instance_t *instance) {
	wd_transfer_t		*transfer = instance;

	wi_release(transfer->socket);
	wi_release(transfer->client);

	wi_release(transfer->path);
	wi_release(transfer->realpath);

	wi_release(transfer->state_lock);
}



static wi_string_t * wd_transfer_description(wi_runtime_instance_t *instance) {
	wd_transfer_t		*transfer = instance;
	
	return wi_string_with_format(WI_STR("<%s %p>{path = %@, client = %@}"),
		wi_runtime_class_name(transfer),
		transfer,
		transfer->path,
		transfer->client);
}



#pragma mark -

wd_transfer_t * wd_transfer_with_hash(wi_string_t *hash) {
	wi_list_node_t	*node;
	wd_transfer_t	*transfer, *value = NULL;

	wi_list_rdlock(wd_transfers);
	WI_LIST_FOREACH(wd_transfers, node, transfer) {
		if(wi_is_equal(transfer->hash, hash)) {
			value = wi_autorelease(wi_retain(transfer));

			break;          
		}
	}
	wi_list_unlock(wd_transfers);

	return value;
}



#pragma mark -

static void wd_transfer_set_state(wd_transfer_t *transfer, wd_transfer_state_t state) {
	wi_condition_lock_lock(transfer->state_lock);
	transfer->state = state;
	wi_condition_lock_unlock_with_condition(transfer->state_lock, transfer->state);
}




static inline void wd_transfer_limit_download_speed(wd_transfer_t *transfer, ssize_t bytes, wi_time_interval_t now, wi_time_interval_t then) {
	unsigned int	limit, totallimit;
	
	if(transfer->client->account->download_speed > 0 || wd_settings.totaldownloadspeed > 0) {
		totallimit = (wd_settings.totaldownloadspeed > 0)
			? (float) wd_settings.totaldownloadspeed / (float) wd_current_downloads
			: 0;
		
		if(totallimit > 0 && transfer->client->account->download_speed > 0)
			limit = WI_MIN(totallimit, transfer->client->account->download_speed);
		else if(totallimit > 0)
			limit = totallimit;
		else
			limit = transfer->client->account->download_speed;

		if(limit > 0) {
			while(transfer->speed > limit) {
				usleep(10000);
				now += 0.01;
				
				transfer->speed = bytes / (now - then);
			}
		}
	}
}



static inline void wd_transfer_limit_upload_speed(wd_transfer_t *transfer, ssize_t bytes, wi_time_interval_t now, wi_time_interval_t then) {
	unsigned int	limit, totallimit;
	
	if(transfer->client->account->upload_speed > 0 || wd_settings.totaluploadspeed > 0) {
		totallimit = (wd_settings.totaluploadspeed > 0)
			? (float) wd_settings.totaluploadspeed / (float) wd_current_uploads
			: 0;
		
		if(totallimit > 0 && transfer->client->account->upload_speed > 0)
			limit = WI_MIN(totallimit, transfer->client->account->upload_speed);
		else if(totallimit > 0)
			limit = totallimit;
		else
			limit = transfer->client->account->upload_speed;

		if(limit > 0) {
			while(transfer->speed > limit) {
				usleep(10000);
				now += 0.01;
				
				transfer->speed = bytes / (now - then);
			}
		}
	}
}



#pragma mark -

void wd_transfer_thread(wi_runtime_instance_t *argument) {
	wi_pool_t			*pool;
	wd_transfer_t		*transfer = argument;
	
	pool = wi_pool_init(wi_pool_alloc());
	
	wd_transfer_set_state(transfer, WD_TRANSFER_RUNNING);

	if(transfer->type == WD_TRANSFER_DOWNLOAD)
		wd_transfer_download(transfer);
	else
		wd_transfer_upload(transfer);

	wi_list_wrlock(wd_transfers);
	wi_list_remove_data(wd_transfers, transfer);
	wi_list_unlock(wd_transfers);

	wd_transfers_update_queue();
	
	wi_release(pool);
}



static void wd_transfer_download(wd_transfer_t *transfer) {
	wi_pool_t				*pool;
	SSL						*ssl;
	char					buffer[WD_TRANSFER_BUFFER_SIZE];
	wi_time_interval_t		interval, speedinterval, statusinterval;
	ssize_t					bytes, speedbytes, statsbytes;
	unsigned int			i = 0;
	int						fd, sd, state;

	pool = wi_pool_init(wi_pool_alloc());
	
	/* start download */
	wi_log_l(WI_STR("Sending \"%@\" to %@/%@/%@"),
		transfer->path,
		transfer->client->nick, transfer->client->login, transfer->client->ip);

	sd = wi_socket_descriptor(transfer->socket);
	ssl = wi_socket_ssl(transfer->socket);
	interval = speedinterval = statusinterval = wi_time_interval();
	speedbytes = statsbytes = 0;

	/* open local file */
	fd = open(wi_string_cstring(transfer->realpath), O_RDONLY, 0);

	if(fd < 0) {
		wi_log_err(WI_STR("Could not open %@: %s"),
			transfer->realpath, strerror(errno));

		goto end;
	}

	lseek(fd, transfer->offset, SEEK_SET);

	/* update status */
	wi_lock_lock(wd_status_lock);
	wd_current_downloads++;
	wd_total_downloads++;
	wd_write_status(true);
	wi_lock_unlock(wd_status_lock);

	while(transfer->state == WD_TRANSFER_RUNNING) {
		if(!pool)
			pool = wi_pool_init(wi_pool_alloc());
		
		/* read data */
		bytes = read(fd, buffer, sizeof(buffer));

		if(bytes <= 0)
			break;

		/* wait for timeout */
		do {
			state = wi_socket_wait_descriptor(sd, 0.1, false, true);
		} while(state == 0 && transfer->state == WD_TRANSFER_RUNNING);

		if(transfer->state != WD_TRANSFER_RUNNING)  {
			/* invalid state */
			break;
		}

		if(state < 0) {
			if(wi_error_code() == EINTR) {
				/* got a signal */
				continue;
			} else {
				/* error in TCP communication */
				wi_log_err(WI_STR("Could not read from %@: %m"),
					transfer->client->ip);

				break;
			}
		}

		/* write data */
		if(SSL_write(ssl, buffer, bytes) <= 0)
			break;

		/* update counters */
		interval = wi_time_interval();
		transfer->transferred += bytes;
		speedbytes += bytes;
		statsbytes += bytes;

		/* update speed */
		transfer->speed = speedbytes / (interval - speedinterval);

		wd_transfer_limit_download_speed(transfer, speedbytes, interval, speedinterval);
		
		if(interval - speedinterval > 30.0) {
			speedbytes = 0;
			speedinterval = interval;
		}

		/* update status */
		if(interval - statusinterval > wd_current_downloads) {
			wi_lock_lock(wd_status_lock);
			wd_downloads_traffic += statsbytes;
			wd_write_status(false);
			wi_lock_unlock(wd_status_lock);

			statsbytes = 0;
			statusinterval = interval;
		}
		
		if(++i % 100 == 0) {
			wi_release(pool);
			pool = NULL;
		}
	}

	/* update status */
	wd_transfer_set_state(transfer, WD_TRANSFER_STOPPED);
	wi_lock_lock(wd_status_lock);
	wd_current_downloads--;
	wd_downloads_traffic += statsbytes;
	wd_write_status(true);
	wi_lock_unlock(wd_status_lock);

	wi_log_l(WI_STR("Sent %llu/%llu bytes of \"%@\" to %@/%@/%@"),
		transfer->transferred - transfer->offset,
		transfer->size,
		transfer->path,
		transfer->client->nick, transfer->client->login, transfer->client->ip);

end:
	wi_socket_close(transfer->socket);

	if(fd >= 0)
		close(fd);
	
	wi_release(pool);
}



static void wd_transfer_upload(wd_transfer_t *transfer) {
	wi_pool_t				*pool;
	wi_string_t				*path;
	SSL						*ssl;
	char					buffer[WD_TRANSFER_BUFFER_SIZE];
	wi_time_interval_t		interval, speedinterval, statusinterval;
	ssize_t					bytes, speedbytes, statsbytes;
	unsigned int			i = 0;
	int						sd, fd, state;

	pool = wi_pool_init(wi_pool_alloc());

	/* start upload */
	wi_log_l(WI_STR("Receiving \"%@\" from %@/%@/%@"),
		transfer->path,
		transfer->client->nick, transfer->client->login, transfer->client->ip);
	
	sd = wi_socket_descriptor(transfer->socket);
	ssl = wi_socket_ssl(transfer->socket);
	interval = speedinterval = statusinterval = wi_time_interval();
	speedbytes = statsbytes = 0;

	/* open the file */
	fd = open(wi_string_cstring(transfer->realpath), O_WRONLY | O_APPEND | O_CREAT, 0666);

	if(fd < 0) {
		wi_log_err(WI_STR("Could not open %@: %s"),
			transfer->realpath, strerror(errno));

		goto end;
	}

	/* update status */
	wi_lock_lock(wd_status_lock);
	wd_current_uploads++;
	wd_total_uploads++;
	wd_write_status(true);
	wi_lock_unlock(wd_status_lock);

	while(transfer->state == WD_TRANSFER_RUNNING) {
		if(!pool)
			pool = wi_pool_init(wi_pool_alloc());
		
		/* wait for timeout */
		do {
			state = wi_socket_wait_descriptor(sd, 0.1, true, false);
		} while(state == 0 && transfer->state == WD_TRANSFER_RUNNING);

		if(transfer->state != WD_TRANSFER_RUNNING)  {
			/* invalid state */
			break;
		}

		if(state < 0) {
			if(wi_error_code() == EINTR) {
				/* got a signal */
				continue;
			} else {
				/* error in TCP communication */
				wi_log_err(WI_STR("Could not read from %@: %m"),
					transfer->client->ip);

				break;
			}
		}

		/* read data */
		bytes = SSL_read(ssl, buffer, sizeof(buffer));

		if(bytes <= 0)
			break;

		/* write data */
		if(write(fd, buffer, bytes) <= 0)
			break;

		/* update counters */
		interval = wi_time_interval();
		transfer->transferred += bytes;
		speedbytes += bytes;
		statsbytes += bytes;

		/* update speed */
		transfer->speed = speedbytes / (interval - speedinterval);

		wd_transfer_limit_upload_speed(transfer, speedbytes, interval, speedinterval);
		
		if(interval - speedinterval > 30.0) {
			speedbytes = 0;
			speedinterval = interval;
		}

		/* update status */
		if(interval - statusinterval > wd_current_uploads) {
			wi_lock_lock(wd_status_lock);
			wd_uploads_traffic += statsbytes;
			wd_write_status(false);
			wi_lock_unlock(wd_status_lock);

			statsbytes = 0;
			statusinterval = interval;
		}
		
		if(++i % 100 == 0) {
			wi_release(pool);
			pool = NULL;
		}
	}

	/* update status */
	wd_transfer_set_state(transfer, WD_TRANSFER_STOPPED);
	wi_lock_lock(wd_status_lock);
	wd_uploads_traffic += statsbytes;
	wd_current_uploads--;
	wd_write_status(true);
	wi_lock_unlock(wd_status_lock);

	if(transfer->transferred == transfer->size) {
		path = wi_string_by_deleting_path_extension(transfer->realpath);

		if(wi_file_rename(transfer->realpath, path)) {
			path = wi_string_by_appending_string(transfer->path, WI_STR(WD_TRANSFERS_PARTIAL_EXTENSION));

			wd_files_move_comment(path, transfer->path);
		} else {
			wi_log_warn(WI_STR("Could not move %@ to %@: %m"),
				transfer->realpath, path);
		}
	}

	wi_log_l(WI_STR("Received %llu/%llu bytes of \"%@\" from %@/%@/%@"),
		transfer->transferred - transfer->offset,
		transfer->size,
		transfer->path,
		transfer->client->nick, transfer->client->login, transfer->client->ip);

end:
	wi_socket_close(transfer->socket);

	if(fd >= 0)
		close(fd);
	
	wi_release(pool);
}
