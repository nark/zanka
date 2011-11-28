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

#ifndef WR_TRANSFERS_H
#define WR_TRANSFERS_H 1

#define WR_TRANSFERS_SUFFIX			".WiredTransfer"


enum _wr_transfer_type {
	WR_TRANSFER_DOWNLOAD			= 0,
	WR_TRANSFER_UPLOAD
};
typedef enum _wr_transfer_type		wr_transfer_type_t;


enum _wr_transfer_state {
	WR_TRANSFER_WAITING				= 0,
	WR_TRANSFER_QUEUED,
	WR_TRANSFER_RUNNING
};
typedef enum _wr_transfer_state		wr_transfer_state_t;


typedef wi_uinteger_t				wr_tid_t;

struct _wr_transfer {
	wi_runtime_base_t				base;
	
	wr_tid_t						tid;
	wr_transfer_state_t				state;
	wr_transfer_type_t				type;
	
	wi_socket_t						*socket;
	wi_file_t						*file;
	
	wi_string_t						*name;
	wi_string_t						*path;
	wi_string_t						*local_path;
	
	wi_string_t						*key;
	wi_string_t						*checksum;
	
	uint32_t						queue;
	wi_time_interval_t				start_time;

	wi_file_offset_t				offset;
	wi_file_offset_t				size;
	wi_file_offset_t				transferred;
	uint32_t						speed;
};
typedef struct _wr_transfer			wr_transfer_t;


void								wr_transfers_init(void);
void								wr_transfers_clear(void);

wi_integer_t						wr_runloop_download_callback(wi_socket_t *);
wi_integer_t						wr_runloop_upload_callback(wi_socket_t *);

void								wr_transfers_download(wi_string_t *);
void								wr_transfers_upload(wi_string_t *);

wr_transfer_t *						wr_transfers_transfer_with_tid(wr_tid_t);
wr_transfer_t *						wr_transfers_transfer_with_path(wi_string_t *);
wr_transfer_t *						wr_transfers_transfer_with_socket(wi_socket_t *);

wr_transfer_t *						wr_transfer_alloc(void);
wr_transfer_t *						wr_transfer_init(wr_transfer_t *);
wr_transfer_t *						wr_transfer_init_download(wr_transfer_t *);
wr_transfer_t *						wr_transfer_init_upload(wr_transfer_t *);

void								wr_transfer_start(wr_transfer_t *);
void								wr_transfer_stop(wr_transfer_t *);


extern wi_array_t					*wr_transfers;

#endif /* WR_TRANSFERS_H */
