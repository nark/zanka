/* $Id$ */

/*
 *  Copyright (c) 2003-2004 Axel Andersson
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

#include <sys/param.h>
#include <sys/mount.h>
#include <sys/fcntl.h>
#include <sys/time.h>
#ifdef HAVE_SYS_VFS_H
#include <sys/vfs.h>
#endif
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <syslog.h>
#include <errno.h>
#include <ctype.h>
#include <libgen.h>
#include <fts.h>
#include <dirent.h>
#include <pthread.h>
#include <openssl/rand.h>
#include <openssl/sha.h>

#include "accounts.h"
#include "files.h"
#include "main.h"
#include "server.h"
#include "settings.h"
#include "utility.h"


static int					wd_name_sort(const FTSENT **, const FTSENT **);


struct wd_list				wd_transfers;


void wd_list_path(char *path) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	struct statfs		buf;
	struct stat			sb;
	FTS					*fts = NULL;
	FTSENT				*p, *chp, *cur;
	off_t				size;
	char				real_path[MAXPATHLEN], wired_path[MAXPATHLEN], *paths[2];
	bool				upload = false;
	unsigned int		type;
	
	/* get real access path */
	snprintf(real_path, sizeof(real_path), ".%s", path);

#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* resolve mac aliases */
	wd_apple_resolve_alias(real_path, real_path, sizeof(real_path));
#endif

	/* check type */
	switch(wd_gettype(real_path, NULL)) {
		case WD_FILE_TYPE_DROPBOX:
			/* check for drop box privilege */
			if(wd_getpriv(client->login, WD_PRIV_VIEW_DROPBOXES) != 1)
				goto last;

			/* FALLTHROUGH */
		
		case WD_FILE_TYPE_UPLOADS:
			/* check for upload privilege */
			if(wd_getpriv(client->login, WD_PRIV_UPLOAD) == 1)
				upload = true;
			break;
		
		default:
			/* check for upload anywhere privilege */
			if(wd_getpriv(client->login, WD_PRIV_UPLOAD_ANYWHERE) == 1)
				upload = true;
			break;
	}
	
	/* file system stat it */
	memset(&buf, 0, sizeof(buf));
	
	if(upload) {
		if(statfs(real_path, &buf) < 0) {
			wd_log(LOG_WARNING, "Could not open %s: %s", real_path, strerror(errno));
			wd_file_error();

			goto end;
		}
	}
	
	/* create argument vector */
	paths[0] = real_path;
	paths[1] = NULL;

	/* follow symbolic links | don't change directory | don't stat */
	fts = fts_open(paths, FTS_LOGICAL | FTS_NOCHDIR | FTS_NOSTAT, wd_name_sort);
	
	if(!fts) {
		wd_log(LOG_WARNING, "Could not open %s: %s", real_path, strerror(errno));
		wd_file_error();

		goto end;
	}

	/* traverse the directory */
	while((p = fts_read(fts)) != NULL) {
		/* get children */
		chp = fts_children(fts, 0);

		if(chp != NULL) {
			for(cur = chp; cur != NULL; cur = cur->fts_link) {
				/* skip . files */
				if(cur->fts_name[0] == '.') {
					fts_set(fts, cur, FTS_SKIP);
					
					continue;
				}
				
				/* skip WIRED */
				if(strcmp(cur->fts_name, "WIRED") == 0) {
					fts_set(fts, cur, FTS_SKIP);
					
					continue;
				}
				
				/* get a real access path */
				snprintf(real_path, sizeof(real_path), "%s/%s",
					cur->fts_path,
					cur->fts_name);

#ifdef HAVE_CORESERVICES_CORESERVICES_H
				/* resolve mac aliases */
				wd_apple_resolve_alias(real_path, real_path, sizeof(real_path));
#endif

				/* stat */
				if(stat(real_path, &sb) < 0) {
					if(lstat(real_path, &sb) < 0) {
						fts_set(fts, cur, FTS_SKIP);
					
						continue;
					}
				}
				
				/* get the file type */
				type = wd_gettype(real_path, &sb);
				
				switch(type) {
					case WD_FILE_TYPE_DROPBOX:
						if(wd_getpriv(client->login, WD_PRIV_VIEW_DROPBOXES) == 1)
							size = wd_count_path(real_path);
						else
							size = 0;
						break;

					case WD_FILE_TYPE_DIR:
					case WD_FILE_TYPE_UPLOADS:
						size = wd_count_path(real_path);
						break;
					
					case WD_FILE_TYPE_FILE:
					default:
						size = sb.st_size;
						break;
				}
				
				/* create display path */
				snprintf(wired_path, sizeof(wired_path), "%s%s%s",
					path,
					path[strlen(path) - 1] == '/'
						? "" /* skip extra '/' */
						: "/",
					cur->fts_name);
				
				/* reply a 410 for each file */
				wd_reply(410, "%s%s%u%s%llu",
						 wired_path,
						 WD_FIELD_SEPARATOR,
						 type,
						 WD_FIELD_SEPARATOR,
						 size);
			}
			
			/* don't do recursive listings */
			fts_set(fts, p, FTS_SKIP);
		}
	}

last:
	wd_reply(411, "%s%s%llu",
			 path,
			 WD_FIELD_SEPARATOR,
			 (unsigned long long) buf.f_bavail * (unsigned long long) buf.f_bsize);

end:
	/* clean up */
	if(fts)
		fts_close(fts);
}



off_t wd_count_path(char *real_path) {
	FTS			*fts = NULL;
	FTSENT		*p, *chp, *cur;
	char		*paths[2];
	off_t		size = 0;

	/* create argument vector */
	paths[0] = real_path;
	paths[1] = NULL;
	
	/* follow symbolic links | don't change directory | don't stat */
	fts = fts_open(paths, FTS_LOGICAL | FTS_NOCHDIR | FTS_NOSTAT, NULL);
	
	if(!fts) {
		wd_log(LOG_WARNING, "Could not open %s: %s", real_path, strerror(errno));
		wd_file_error();
		
		goto end;
	}
	
	/* now traverse the directory */
	while((p = fts_read(fts)) != NULL) {
		/* get children */
		chp = fts_children(fts, 0);
		
		if(chp != NULL) {
			for(cur = chp; cur != NULL; cur = cur->fts_link) {
				/* skip . files */
				if(cur->fts_name[0] == '.') {
					fts_set(fts, cur, FTS_SKIP);
					
					continue;
				}

				/* skip WIRED */
				if(strcmp(cur->fts_name, "WIRED") == 0) {
					fts_set(fts, cur, FTS_SKIP);
					
					continue;
				}
					
				size++;
			}

			/* don't do recursive listings */
			fts_set(fts, p, FTS_SKIP);
		}
	}
	
end:
	/* clean up */
	if(fts)
		fts_close(fts);
	
	return size;
}



void wd_stat_path(char *path) {
	FILE					*fp;
	SHA_CTX					c;
	struct stat				sb;
	size_t					bytes;
	char					real_path[MAXPATHLEN];
	char					mtime[26], ctime[26], buffer[BUFSIZ];
	static unsigned char	hex[] = "0123456789abcdef";
	unsigned char			sha[SHA_DIGEST_LENGTH], sha_output[SHA_DIGEST_LENGTH * 2 + 1];
	off_t					size;
	int						i, type, total = 0;

	/* get real path */
	snprintf(real_path, sizeof(real_path), ".%s", path);

#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* resolve mac alias */
	wd_apple_resolve_alias_path(real_path, real_path, sizeof(real_path));
#endif

	/* stat the actual file */
	if(stat(real_path, &sb) < 0) {
		wd_log(LOG_WARNING, "Could not open %s: %s", real_path, strerror(errno));
		wd_file_error();

		return;
	}
	
	/* get file type */
	type = wd_gettype(real_path, &sb);

	switch(type) {
		case WD_FILE_TYPE_DIR:
		case WD_FILE_TYPE_UPLOADS:
		case WD_FILE_TYPE_DROPBOX:
			size = wd_count_path(real_path);
			break;
		
		case WD_FILE_TYPE_FILE:
		default:
			size = sb.st_size;
			break;
	}
	
	/* format time strings */
	wd_time_to_iso8601(localtime(&(sb.st_mtime)), mtime, sizeof(mtime));
	wd_time_to_iso8601(localtime(&(sb.st_ctime)), ctime, sizeof(ctime));
	
	/* zero out checksum */
	memset(sha_output, 0, sizeof(sha_output));

	/* calculate a SHA-1 checksum for files */
	if(type == WD_FILE_TYPE_FILE) {
		/* open the file */
		fp = fopen(real_path, "r");
		
		if(!fp) {
			wd_log(LOG_WARNING, "Could not open %s: %s", real_path, strerror(errno));
			wd_file_error();

			return;
		}
		
		SHA1_Init(&c);
	
		if(size >= WD_CHECKSUM_SIZE) {
			/* don't read the entire file for checksum, as that will take quite some time */
			while((bytes = fread(buffer, 1, sizeof(buffer), fp))) {
				SHA1_Update(&c, buffer, bytes);
				total += bytes;
				
				if(total >= WD_CHECKSUM_SIZE)
					break;
			}
		} else {
			/* the file is small enough, checksum it all */
			while((bytes = fread(buffer, 1, sizeof(buffer), fp)))
				SHA1_Update(&c, buffer, bytes);
		}
		
		SHA1_Final(sha, &c);
	
		/* map into hex characters */
		for(i = 0; i < SHA_DIGEST_LENGTH; i++) {
			sha_output[i+i]		= hex[sha[i] >> 4];
			sha_output[i+i+1]	= hex[sha[i] & 0x0F];
		}
		
		sha_output[i+i] = '\0';

		fclose(fp);
	}
	
	/* send the info message */
	wd_reply(402, "%s%s%u%s%llu%s%s%s%s%s%s",
			 path,
			 WD_FIELD_SEPARATOR,
			 type,
			 WD_FIELD_SEPARATOR,
			 size,
			 WD_FIELD_SEPARATOR,
			 ctime,
			 WD_FIELD_SEPARATOR,
			 mtime,
			 WD_FIELD_SEPARATOR,
			 sha_output);
}



void wd_create_path(char *path) {
	char	real_path[MAXPATHLEN], destination[MAXPATHLEN];
	char	*dir, *base;

	/* get real path */
	snprintf(real_path, sizeof(real_path), ".%s", path);

	/* get the parent directory */
	dir = dirname(real_path);
	base = basename(real_path);
	strlcpy(destination, dir, sizeof(destination));

#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* resolve mac alias */
	wd_apple_resolve_alias_path(destination, destination, sizeof(destination));
#endif
	
	/* create new real path */
	snprintf(real_path, sizeof(real_path), "%s/%s",
		destination,
		base);
	
	/* create the path */
	if(mkdir(real_path, 0755) < 0) {
		wd_log(LOG_WARNING, "Could not create %s: %s", real_path, strerror(errno));
		wd_file_error();

		return;
	}
}



void wd_move_path(char *from, char *to) {
	struct wd_move	*move;
	pthread_t		thread;
	struct stat		sb;
	char			*dir, *base, destination[MAXPATHLEN];

	/* get real paths */
	move = (struct wd_move *) malloc(sizeof(struct wd_move));
	snprintf(move->from, sizeof(move->from), ".%s", from);
	snprintf(move->to, sizeof(move->to), ".%s", to);

	/* get the parent directory */
	dir = dirname(move->to);
	base = basename(move->to);
	strlcpy(destination, dir, sizeof(destination));

#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* resolve mac aliases */
	if(!wd_apple_is_alias(move->from))
		wd_apple_resolve_alias_path(move->from, move->from, sizeof(move->from));

	wd_apple_resolve_alias_path(destination, destination, sizeof(destination));
#endif
	
	/* create new real path */
	snprintf(move->to, sizeof(move->to), "%s/%s",
		destination,
		base);

	/* check for existing file */
	if(stat(move->to, &sb) == 0) {
		wd_reply(521, "File or directory exists");
		
		goto end;
	}
	
	/* move the file/directory */
	if(rename(move->from, move->to) == 0)
		goto end;
	
	if(errno != EXDEV) {
		wd_log(LOG_WARNING, "Could not rename %s to %s: %s",
			move->from, move->to, strerror(errno));
		wd_file_error();
		
		goto end;
	}
	
	/* detach a thread to copy across file systems */
	if(pthread_create(&thread, NULL, wd_copy_thread, move) < 0) {
	   	wd_file_error();
	   	
	   	goto end;
	}
	
	return;

end:
	/* clean up */
	if(move)
		free(move);
}



int wd_delete_path(char *path) {
	char			real_path[MAXPATHLEN];
	struct stat		sb;
	
	/* get real path */
	snprintf(real_path, sizeof(real_path), ".%s", path);

#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* resolve mac alias */
	if(!wd_apple_is_alias(real_path))
		wd_apple_resolve_alias_path(real_path, real_path, sizeof(real_path));
#endif

	if(lstat(real_path, &sb) < 0) {
		wd_log(LOG_WARNING, "Could not open %s: %s", real_path, strerror(errno));
		wd_file_error();

		return -1;
	}
	
	if(S_ISDIR(sb.st_mode)) {
		/* recursively delete this path */
		return wd_delete_paths(real_path);
	} else {
		/* delete the file */
		if(unlink(real_path) < 0) {
			wd_log(LOG_WARNING, "Could not delete %s: %s", real_path, strerror(errno));
			wd_file_error();

			return -1;
		}
	}
	
	return 1;
}



int wd_delete_paths(char *real_path) {
	FTS			*fts;
	FTSENT		*p;
	char		*paths[2];
	bool		error = false;
	int			result = -1;
	
	/* create argument vector */
	paths[0] = real_path;
	paths[1] = NULL;
	
	/* follow symbolic links | don't change directory | don't stat */
	fts = fts_open(paths, FTS_LOGICAL | FTS_NOCHDIR | FTS_NOSTAT, NULL);
	
	if(!fts) {
		wd_log(LOG_WARNING, "Could not open %s: %s", real_path, strerror(errno));
		wd_file_error();
		
		goto end;
	}
	
	/* now traverse the directory */
	while((p = fts_read(fts)) != NULL) {
		switch(p->fts_info) {
			/* pre-order directory, skip */
			case FTS_D:
				break;
				
			/* post-order (empty) directories */
			case FTS_DP:
			case FTS_DNR:
				if(rmdir(p->fts_path) < 0)
					error = true;
				break;
			
			/* catch-all */
			default:
				if(unlink(p->fts_accpath) < 0)
					error = true;
				break;
		}
	}
	
	/* single error message */
	if(error) {
		wd_log(LOG_WARNING, "Could not delete %s: %s", real_path, strerror(errno));
		wd_file_error();
	}
	
	/* success */
	result = 1;
	
end:
	/* clean up */
	if(fts)
		fts_close(fts);
	
	return result;
}



void wd_search(char *path, char *query, bool root) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	struct stat			sb;
	FTS					*fts;
	FTSENT				*p, *chp, *cur;
	char				real_path[MAXPATHLEN], wired_path[MAXPATHLEN], *paths[2];
	off_t				size;
	bool				alias;
	int					type, view_dropboxes;
	
	/* build a custom argv for fts_open() */
	paths[0] = path;
	paths[1] = NULL;
	
	/* follow symbolic links | don't change directory | don't stat */
	fts = fts_open(paths, FTS_LOGICAL | FTS_NOCHDIR | FTS_NOSTAT, wd_name_sort);
	
	if(!fts) {
		wd_log(LOG_WARNING, "Could not open .: %s", strerror(errno));
		wd_file_error();

		goto end;
	}
	
	/* check if we can enter drop boxes */
	view_dropboxes = wd_getpriv(client->login, WD_PRIV_VIEW_DROPBOXES);
	
	/* now traverse the directory */
	while((p = fts_read(fts)) != NULL) {
		/* get children */
		chp = fts_children(fts, 0);
		
		if(chp != NULL) {
			for(cur = chp; cur != NULL; cur = cur->fts_link) {
				/* skip . files */
				if(cur->fts_name[0] == '.') {
					fts_set(fts, cur, FTS_SKIP);
					
					continue;
				}
				
				/* skip very deep levels */
				if(cur->fts_level >= 10) {
					fts_set(fts, cur, FTS_SKIP);
					
					continue;
				}

				/* skip WIRED */
				if(strcmp(cur->fts_name, "WIRED") == 0) {
					fts_set(fts, cur, FTS_SKIP);
					
					continue;
				}
				
				/* get a real access path */
				snprintf(real_path, sizeof(real_path), "%s/%s",
					cur->fts_path,
					cur->fts_name);

#ifdef HAVE_CORESERVICES_CORESERVICES_H
				/* resolve mac aliases */
				alias = wd_apple_is_alias(real_path);
				
				if(alias)
					wd_apple_resolve_alias(real_path, real_path, sizeof(real_path));
#endif

				/* stat */
				if(stat(real_path, &sb) < 0) {
					if(lstat(real_path, &sb) < 0) {
						fts_set(fts, cur, FTS_SKIP);
					
						continue;
					}
				}

#ifdef HAVE_CORESERVICES_CORESERVICES_H
				/* check if the mac alias points to a directory */
				if(alias && S_ISDIR(sb.st_mode))
					wd_search(real_path, query, false);
#endif

				if(strcasestr(cur->fts_name, query)) {
					/* get the file type */
					type = wd_gettype(real_path, &sb);
					
					switch(type) {
						case WD_FILE_TYPE_DIR:
						case WD_FILE_TYPE_UPLOADS:
						case WD_FILE_TYPE_DROPBOX:
							size = wd_count_path(real_path);
							break;
						
						case WD_FILE_TYPE_FILE:
						default:
							size = sb.st_size;
							break;
					}

					/* create display path */
					snprintf(wired_path, sizeof(wired_path), "%s%s%s",
						cur->fts_path,
						cur->fts_path[strlen(cur->fts_path) - 1] == '/'
							? "" /* skip extra '/' */
							: "/",
						cur->fts_name);
					
					/* reply a 420 for each file */
					wd_reply(420, "%s%s%u%s%llu",
							 wired_path,
							 WD_FIELD_SEPARATOR,
							 type,
							 WD_FIELD_SEPARATOR,
							 size);
				}

				/* check if we should enter drop boxes */
				if(wd_gettype(real_path, NULL) == WD_FILE_TYPE_DROPBOX &&
				   view_dropboxes != 1)
					fts_set(fts, cur, FTS_SKIP);
			}
		}
	}

	/* reply end marker */
	if(root)
		wd_reply(421, "Done");

end:
	if(fts)
		fts_close(fts);
}



#pragma mark -

void * wd_copy_thread(void *arg) {
	struct wd_move		*move = (struct wd_move *) arg;
	FTS					*fts = NULL;
	FTSENT				*p;
	struct stat			sb;
	int					offset;
	char				*paths[2], to[MAXPATHLEN];
	
	/* stat the file we should copy */
	if(stat(move->from, &sb) < 0)
		goto end;
	
	if(S_ISDIR(sb.st_mode)) {
		/* create argument vector */
		paths[0] = move->from;
		paths[1] = NULL;
		
		/* follow symbolic links | don't change directory | don't stat */
		fts = fts_open(paths, FTS_LOGICAL | FTS_NOCHDIR | FTS_NOSTAT, NULL);
		
		if(!fts)
			goto end;
		
		/* get offset */
		offset = strlen(move->from);
	
		/* now traverse the directory */
		while((p = fts_read(fts)) != NULL) {
			snprintf(to, sizeof(to), "%s%s", move->to, p->fts_path + offset);

			switch(p->fts_info) {
				/* pre-order directory */
				case FTS_D:
					if(mkdir(to, 0755) < 0)
						goto end;
					break;

				/* post-order directories */
				case FTS_DP:
				case FTS_DNR:
					rmdir(p->fts_path);
					break;
					
				/* catch-all */
				default:
					wd_copy_file(p->fts_path, to);
					break;
			}
		}
	} else {
		wd_copy_file(move->from, move->to);
	}
	
end:
	/* clean up */
	if(fts)
		fts_close(fts);
	
	if(move)
		free(move);
	
	return NULL;
}



void wd_copy_file(char *from, char *to) {
	int			source = -1, destination = -1;
	ssize_t		bytes;
	char		buffer[BUFSIZ];
	
	/* open files */
	if((source = open(from, O_RDONLY, 0)) < 0)
		goto end;

	if((destination = open(to, O_CREAT | O_TRUNC | O_WRONLY, 0644)) < 0)
		goto end;

	/* do copy */
	while((bytes = read(source, buffer, sizeof(buffer))) > 0)
		write(destination, buffer, bytes);
	
	/* unlink source */
	unlink(from);

end:
	/* clean up */
	if(source > 0)
		close(source);
	
	if(destination > 0)
		close(destination);
}



#pragma mark -

void * wd_download_thread(void *arg) {
	struct wd_transfer		*transfer;
	struct timeval			now, last_time;
	FILE					*fp;
	char					buffer[8192];
	long					elapsed;
	unsigned int			limit;
	int						running = 1, bytes, last_bytes = 0, stats_bytes = 0;
	
	/* get transfer */
	transfer = ((struct wd_list_node *) arg)->data;
	
	/* update state */
	transfer->state = WD_XFER_STATE_RUNNING;

	/* log */
	wd_log_l(LOG_INFO, "Sending \"%s\" to %s/%s/%s",
			 transfer->path,
			 transfer->client->nick,
			 transfer->client->login,
			 transfer->client->ip);

	/* open the file */
	fp = fopen(transfer->real_path, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s", transfer->real_path, strerror(errno));
		
		goto end;
	}
	
	/* get limit */
	limit = wd_getpriv(transfer->client->login, WD_PRIV_DOWNLOAD_SPEED);
	
	/* update status */
	pthread_mutex_lock(&wd_status_mutex);
	wd_current_downloads++;
	wd_total_downloads++;
	pthread_mutex_unlock(&wd_status_mutex);
	wd_write_status();
	
	/* update client */
	pthread_mutex_lock(&(transfer->client->transfers_mutex));
	transfer->client->transfers++;
	pthread_mutex_unlock(&(transfer->client->transfers_mutex));
	
	/* seek to requested position */
	fseek(fp, transfer->offset, SEEK_SET);
	transfer->transferred = transfer->offset;
	
	/* start counting time */
	gettimeofday(&last_time, NULL);

	while(running) {
		/* read data */
		bytes = fread(buffer, 1, sizeof(buffer), fp);
	
		if(bytes <= 0) {
			running = 0;
		
			continue;
		}
		
		/* write data */
		if(SSL_write(transfer->ssl, buffer, bytes) <= 0) {
			running = 0;
			
			continue;
		}

		/* update status */
		transfer->transferred += bytes;
		last_bytes += bytes;
		stats_bytes += bytes;
		
		/* update speed */
		while(1) {
			gettimeofday(&now, NULL);
			elapsed = (now.tv_sec - last_time.tv_sec) * 1000 +
					  (now.tv_usec - last_time.tv_usec) / 1000;
			transfer->speed = (double) 1000 * last_bytes / elapsed;
			
			/* throttle bandwidth */
			if((limit > 0 && transfer->speed > limit / transfer->client->transfers) ||
			   (wd_settings.totaldownloadspeed > 0 &&
			   transfer->speed > wd_settings.totaldownloadspeed / wd_current_downloads)) {
				usleep(10000);

				continue;
			}

			break;
		}

		if(elapsed > 60000) {
			/* update time */
			gettimeofday(&last_time, NULL);
			last_bytes = 0;
		}

		if(elapsed > 1000) {
			/* update status */
			pthread_mutex_lock(&wd_status_mutex);
			wd_downloads_traffic += stats_bytes;
			pthread_mutex_unlock(&wd_status_mutex);
			wd_write_status();
			stats_bytes = 0;
		}
	}
	
	/* log */
	wd_log_l(LOG_INFO, "Sent %llu/%llu bytes of \"%s\" to %s/%s/%s",	
			 transfer->transferred - transfer->offset,
			 transfer->size,
			 transfer->path,
			 transfer->client->nick,
			 transfer->client->login,
			 transfer->client->ip);

end:
	/* clean up */
	if(SSL_shutdown(transfer->ssl) == 0)
		SSL_shutdown(transfer->ssl);
	
	SSL_free(transfer->ssl);

	close(transfer->sd);
	
	if(fp)
		fclose(fp);
	
	/* update status */
	pthread_mutex_lock(&wd_status_mutex);
	wd_current_downloads--;
	pthread_mutex_unlock(&wd_status_mutex);
	wd_write_status();

	/* update client */
	pthread_mutex_lock(&(transfer->client->transfers_mutex));
	transfer->client->transfers--;
	pthread_mutex_unlock(&(transfer->client->transfers_mutex));

	/* delete transfer */
	pthread_mutex_lock(&(wd_transfers.mutex));
	wd_list_delete(&wd_transfers, arg);
	pthread_mutex_unlock(&(wd_transfers.mutex));
	wd_update_queue();
	
	/* free transfer */
	free(transfer);
			
	return NULL;
}



void * wd_upload_thread(void *arg) {
	struct wd_transfer		*transfer;
	struct timeval			now, last_time;
	FILE					*fp;
	char					buffer[8192], *path;
	long					elapsed;
	unsigned int			limit;
	int						running = 1, bytes, last_bytes = 0, stats_bytes = 0;

	/* get transfer */
	transfer = ((struct wd_list_node *) arg)->data;
	
	/* update state */
	transfer->state = WD_XFER_STATE_RUNNING;

	/* log */
	wd_log_l(LOG_INFO, "Receiving \"%s\" from %s/%s/%s",
			 transfer->path,
			 transfer->client->nick,
			 transfer->client->login,
			 transfer->client->ip);

	/* open the file */
	fp = fopen(transfer->real_path, "a");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s", transfer->real_path, strerror(errno));
		
		goto end;
	}
	
	/* get limit */
	limit = wd_getpriv(transfer->client->login, WD_PRIV_UPLOAD_SPEED);
	
	/* update status */
	pthread_mutex_lock(&wd_status_mutex);
	wd_current_uploads++;
	wd_total_uploads++;
	pthread_mutex_unlock(&wd_status_mutex);
	wd_write_status();
	
	/* update client */
	pthread_mutex_lock(&(transfer->client->transfers_mutex));
	transfer->client->transfers++;
	pthread_mutex_unlock(&(transfer->client->transfers_mutex));
	
	/* start counting time */
	gettimeofday(&last_time, NULL);

	while(running) {
		/* read data */
		bytes = SSL_read(transfer->ssl, buffer, sizeof(buffer));
	
		if(bytes <= 0) {
			running = 0;
		
			continue;
		}
		
		/* write data */
		if(fwrite(buffer, 1, bytes, fp) <= 0) {
			running = 0;
			
			continue;
		}

		/* update status */
		transfer->transferred += bytes;
		last_bytes += bytes;
		stats_bytes += bytes;
		
		/* update speed */
		while(1) {
			gettimeofday(&now, NULL);
			elapsed = (now.tv_sec - last_time.tv_sec) * 1000 +
					  (now.tv_usec - last_time.tv_usec) / 1000;
			transfer->speed = (double) 1000 * last_bytes / elapsed;
			
			/* throttle bandwidth */
			if((limit > 0 && transfer->speed > limit / transfer->client->transfers) ||
			   (wd_settings.totaluploadspeed > 0 &&
			   transfer->speed > wd_settings.totaluploadspeed / wd_current_uploads)) {
				usleep(10000);

				continue;
			}

			break;
		}

		if(elapsed > 10000) {
			/* update time */
			gettimeofday(&last_time, NULL);
			last_bytes = 0;
		}


		if(elapsed > 1000) {
			/* update status */
			pthread_mutex_lock(&wd_status_mutex);
			wd_uploads_traffic += stats_bytes;
			pthread_mutex_unlock(&wd_status_mutex);
			wd_write_status();
			stats_bytes = 0;
		}
	}
	
	/* log */
	wd_log_l(LOG_INFO, "Received %llu/%llu bytes of \"%s\" from %s/%s/%s",
			 transfer->transferred - transfer->offset,
			 transfer->size,
			 transfer->path,
			 transfer->client->nick,
			 transfer->client->login,
			 transfer->client->ip);
	
	/* move file */
	if(transfer->transferred == transfer->size) {
		path = strdup(transfer->real_path);
		path[strlen(path) - 14] = '\0';
		
		rename(transfer->real_path, path);
		
		free(path);
	}

end:
	/* clean up */
	if(SSL_shutdown(transfer->ssl) == 0)
		SSL_shutdown(transfer->ssl);
	
	SSL_free(transfer->ssl);

	close(transfer->sd);
	
	if(fp)
		fclose(fp);
	
	/* update status */
	pthread_mutex_lock(&wd_status_mutex);
	wd_current_uploads--;
	pthread_mutex_unlock(&wd_status_mutex);
	wd_write_status();

	/* update client */
	pthread_mutex_lock(&(transfer->client->transfers_mutex));
	transfer->client->transfers--;
	pthread_mutex_unlock(&(transfer->client->transfers_mutex));

	/* delete transfer */
	pthread_mutex_lock(&(wd_transfers.mutex));
	wd_list_delete(&wd_transfers, arg);
	pthread_mutex_unlock(&(wd_transfers.mutex));
	wd_update_queue();
	
	/* free transfer */
	free(transfer);
			
	return NULL;
}



void wd_update_queue(void) {
	struct wd_list			*clients;
	struct wd_list_node		*node;
	struct wd_client		*client;

	/* get public chat */
	clients = &(((struct wd_chat *) ((wd_chats.first)->data))->clients);

	/* send SIGUSR2 to all clients */
	pthread_mutex_lock(&(clients->mutex));
	for(node = clients->first; node != NULL; node = node->next) {
		client = node->data;

		if(client->state == WD_CLIENT_STATE_LOGGED_IN)
			pthread_kill(client->thread, SIGUSR1);
	}
	pthread_mutex_unlock(&(clients->mutex));
}



void wd_update_transfers(void) {
	struct wd_list_node		*node;
	struct wd_transfer		*transfer;

	/* remove transfers that have been waiting for more than 10 seconds */
	pthread_mutex_lock(&(wd_transfers.mutex));
	for(node = wd_transfers.first; node != NULL; node = node->next) {
		transfer = node->data;
		
		if(transfer->state == WD_XFER_STATE_WAITING && transfer->queue_time + 10 < time(NULL)) {
			wd_list_delete(&wd_transfers, node);
			free(transfer);
		}
	}
	pthread_mutex_unlock(&(wd_transfers.mutex));
}



void wd_queue_download(char *path, off_t offset) {
	struct wd_client		*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	struct wd_transfer		*transfer;
	struct stat				sb;
	SHA_CTX					c;
	static unsigned char	hex[] = "0123456789abcdef";
	unsigned char			buffer[BUFSIZ], sha[SHA_DIGEST_LENGTH];
	char					real_path[MAXPATHLEN];
	int						i;
	
	/* get real path */
	snprintf(real_path, sizeof(real_path), ".%s", path);

#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* resolve mac alias */
	wd_apple_resolve_alias_path(real_path, real_path, sizeof(real_path));
#endif

	/* stat the actual file */
	if(stat(real_path, &sb) < 0) {
		/* be nice and don't whine about file errors in WIRED directories */
		if(strstr(real_path, "/WIRED/") == NULL) {
			wd_log(LOG_WARNING, "Could not open %s: %s", real_path, strerror(errno));
			wd_file_error();
		}
		
		return;
	}
	
	/* create a transfer */
	transfer = (struct wd_transfer *) malloc(sizeof(struct wd_transfer));
	memset(transfer, 0, sizeof(struct wd_transfer));
	
	/* set values */
	transfer->client		= client;
	transfer->type			= WD_XFER_DOWNLOAD;
	transfer->state			= WD_XFER_STATE_QUEUED;
	transfer->size			= sb.st_size;
	transfer->offset		= offset;
	transfer->transferred	= offset;
	
	/* copy paths */
	strlcpy(transfer->path, path, sizeof(transfer->path));
	strlcpy(transfer->real_path, real_path, sizeof(transfer->real_path));
	
	/* compute random hash for transfer */
	RAND_bytes(buffer, sizeof(buffer));
	SHA1_Init(&c);
	SHA1_Update(&c, buffer, sizeof(buffer));
	SHA1_Final(sha, &c);
	
	for(i = 0; i < SHA_DIGEST_LENGTH; i++) {
		transfer->hash[i+i]		= hex[sha[i] >> 4];
		transfer->hash[i+i+1]	= hex[sha[i] & 0x0F];
	}
	
	transfer->hash[i+i] = '\0';
	
	/* add to list */
	pthread_mutex_lock(&(wd_transfers.mutex));
	wd_list_add(&wd_transfers, transfer);
	pthread_mutex_unlock(&(wd_transfers.mutex));
	
	/* update the queue */
	wd_update_queue();
}



void wd_queue_upload(char *path, off_t size, char *checksum) {
	struct wd_client		*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	struct wd_transfer		*transfer;
	struct stat				sb;
	FILE					*fp;
	SHA_CTX					c;
	static unsigned char	hex[] = "0123456789abcdef";
	unsigned char			buffer[BUFSIZ], sha[SHA_DIGEST_LENGTH], output[SHA_DIGEST_LENGTH * 2 + 1];
	char					real_path[MAXPATHLEN], destination[MAXPATHLEN], *dir, *base;
	size_t					bytes;
	off_t					offset = 0;
	int						i, total = 0;
	
	/* get real path */
	snprintf(real_path, sizeof(real_path), ".%s.WiredTransfer", path);

	/* get the parent directory */
	dir = dirname(real_path);
	base = basename(real_path);
	strlcpy(destination, dir, sizeof(destination));

#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* resolve mac alias */
	wd_apple_resolve_alias_path(destination, destination, sizeof(destination));
#endif
	
	/* create new real path */
	snprintf(real_path, sizeof(real_path), "%s/%s",
		destination,
		base);
	
	/* check for existing file to resume */
	if(stat(real_path, &sb) == 0) {
		fp = fopen(real_path, "r");
		
		if(!fp) {
			wd_log(LOG_WARNING, "Could not open %s: %s", real_path, strerror(errno));
			wd_reply(500, "Command Failed");
			
			return;
		}
		
		/* checksum the existing file */
		SHA1_Init(&c);
	
		if(sb.st_size >= WD_CHECKSUM_SIZE) {
			/* don't read the entire file for checksum, as that will take quite some time */
			while((bytes = fread(buffer, 1, sizeof(buffer), fp))) {
				SHA1_Update(&c, buffer, bytes);
				total += bytes;
				
				if(total >= WD_CHECKSUM_SIZE)
					break;
			}
		}
		
		SHA1_Final(sha, &c);

		fclose(fp);
	
		if(total > 0) {
			/* map into hex characters */
			for(i = 0; i < SHA_DIGEST_LENGTH; i++) {
				output[i+i]		= hex[sha[i] >> 4];
				output[i+i+1]	= hex[sha[i] & 0x0F];
			}
			
			output[i+i] = '\0';

			/* make sure they match */
			if(strcmp(checksum, output) != 0) {
				wd_reply(522, "Checksum mismatch");
				
				return;
			}
		}
			
		/* set new offset */
		offset = sb.st_size;
	}
	
	/* create a transfer */
	transfer = (struct wd_transfer *) malloc(sizeof(struct wd_transfer));
	memset(transfer, 0, sizeof(*transfer));
	
	/* set values */
	transfer->client		= client;
	transfer->type			= WD_XFER_UPLOAD;
	transfer->state			= WD_XFER_STATE_QUEUED;
	transfer->size			= size;
	transfer->offset		= offset;
	transfer->transferred	= offset;
	
	/* copy paths */
	strlcpy(transfer->path, path, sizeof(transfer->path));
	strlcpy(transfer->real_path, real_path, sizeof(transfer->real_path));
	
	/* compute random hash for transfer */
	RAND_bytes(buffer, sizeof(buffer));
	SHA1_Init(&c);
	SHA1_Update(&c, buffer, sizeof(buffer));
	SHA1_Final(sha, &c);
	
	for(i = 0; i < SHA_DIGEST_LENGTH; i++) {
		transfer->hash[i+i]		= hex[sha[i] >> 4];
		transfer->hash[i+i+1]	= hex[sha[i] & 0x0F];
	}
	
	transfer->hash[i+i] = '\0';
	
	/* add to list */
	pthread_mutex_lock(&(wd_transfers.mutex));
	wd_list_add(&wd_transfers, transfer);
	pthread_mutex_unlock(&(wd_transfers.mutex));
	
	/* update the queue */
	wd_update_queue();
}



#pragma mark -

unsigned int wd_gettype(char *path, struct stat *sp) {
	struct stat		sb;
	unsigned int	type = WD_FILE_TYPE_FILE;
	char			*file;

	/* stat the file if we don't have a stat record already*/
	if(!sp) {
		if(stat(path, &sb) < 0) {
			wd_log(LOG_WARNING, "Could not open %s: %s", path, strerror(errno));
			wd_file_error();
			
			goto end;
		}
		
		sp = &sb;
	}

	/* determine file type */
	if(S_ISDIR(sp->st_mode)) {
		path	= wd_getlc(path);
		file	= strrchr(path, '/') + 1;
		
		if(strstr(path, "uploads"))
			type = WD_FILE_TYPE_UPLOADS;
		else if(strstr(file, "drop box"))
			type = WD_FILE_TYPE_DROPBOX;
		else
			type = WD_FILE_TYPE_DIR;
		
		free(path);
	}
	
end:
	return type;
}



char *wd_getlc(char *c) {
	char	*d, *e;
	
	d = e = strdup(c);
	
	while(((*d++) = tolower(*d)))
		;

	return e;
}



int wd_evaluate_path(char *path) {
	if(strstr(path, "../") != NULL)
		return -1;

	if(strstr(path, "/..") != NULL)
		return -1;
	
	if(strcmp(path, "..") == 0)
		return -1;
	
	return 1;
}



void wd_file_error(void) {
	switch(errno) {
		case ENOENT:
			wd_reply(520, "File or Directory Not Found");
			break;
		
		case EEXIST:
			wd_reply(521, "File or Directory Exists");
			break;
		
		default:
			wd_reply(500, "Command Failed");
			break;
	}
}



static int wd_name_sort(const FTSENT **a, const FTSENT **b) {
	return (strcasecmp((*a)->fts_name, (*b)->fts_name));
}
