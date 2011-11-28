/* $Id$ */

/*
 *  Copyright (c) 2005-2006 Axel Andersson
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

#ifdef HAVE_CORESERVICES_CORESERVICES_H
#include <Carbon/Carbon.h>
#endif

#include <sys/param.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mount.h>

#ifdef HAVE_SYS_STATVFS_H
#include <sys/statvfs.h>
#endif

#ifdef HAVE_SYS_STATFS_H
#include <sys/statfs.h>
#endif

#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <dirent.h>

#ifdef HAVE_PATHS_H
#include <paths.h>
#endif

#ifdef WI_SSL
#include <openssl/sha.h>
#endif

#include <wired/wi-array.h>
#include <wired/wi-assert.h>
#include <wired/wi-compat.h>
#include <wired/wi-file.h>
#include <wired/wi-fts.h>
#include <wired/wi-lock.h>
#include <wired/wi-pool.h>
#include <wired/wi-runtime.h>
#include <wired/wi-string.h>

#include "wi-private.h"

#ifndef UINT_MAX
#define UINT_MAX 4294967295U
#endif

#define _WI_FILE_ASSERT_OPEN(file) \
	WI_ASSERT((file)->fd >= 0, "%@ is not open", (file))


struct _wi_file {
	wi_runtime_base_t					base;

	int									fd;
};


static wi_boolean_t						_wi_file_delete_file(wi_string_t *);
static wi_boolean_t						_wi_file_delete_directory(wi_string_t *);

static wi_boolean_t						_wi_file_copy_file(wi_string_t *, wi_string_t *);
static wi_boolean_t						_wi_file_copy_directory(wi_string_t *, wi_string_t *);

static void								_wi_file_dealloc(wi_runtime_instance_t *);
static wi_string_t *					_wi_file_description(wi_runtime_instance_t *);


static wi_runtime_id_t					_wi_file_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_file_runtime_class = {
	"wi_file_t",
	_wi_file_dealloc,
	NULL,
	NULL,
	_wi_file_description,
	NULL
};


void wi_file_register(void) {
	_wi_file_runtime_id = wi_runtime_register_class(&_wi_file_runtime_class);
}



void wi_file_initialize(void) {
}



#pragma mark -

wi_boolean_t wi_file_delete(wi_string_t *path) {
	struct stat		sb;
	wi_boolean_t	result;
	
	if(!wi_file_lstat(path, &sb))
		return false;
	
	if(S_ISDIR(sb.st_mode))
		result = _wi_file_delete_directory(path);
	else
		result = _wi_file_delete_file(path);
	
	if(!result)
		wi_error_set_errno(errno);
	
	return result;
}



static wi_boolean_t _wi_file_delete_file(wi_string_t *path) {
	if(unlink(wi_string_cstring(path)) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return true;
}



static wi_boolean_t _wi_file_delete_directory(wi_string_t *path) {
	WI_FTS			*fts;
	WI_FTSENT		*p;
	char			*paths[2];
	wi_boolean_t	result = true;
	int				err = 0;

	paths[0] = (char *) wi_string_cstring(path);
	paths[1] = NULL;

	fts = wi_fts_open(paths, WI_FTS_LOGICAL | WI_FTS_NOSTAT, NULL);

	if(!fts)
		return false;
	
	while((p = wi_fts_read(fts))) {
		switch(p->fts_info) {
			case WI_FTS_NS:
			case WI_FTS_ERR:
			case WI_FTS_DNR:
				err = p->fts_errno;
				result = false;
				break;

			case WI_FTS_D:
				break;

			case WI_FTS_DC:
			case WI_FTS_DP:
				if(rmdir(p->fts_path) < 0) {
					err = errno;

					result = false;
				}
				break;

			default:
				if(unlink(p->fts_path) < 0) {
					err = errno;

					result = false;
				}
				break;
		}
	}
	
	wi_fts_close(fts);
	
	if(err > 0)
		errno = err;

	return result;
}



wi_boolean_t wi_file_clear(wi_string_t *path) {
	if(truncate(wi_string_cstring(path), 0) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return true;
}



wi_boolean_t wi_file_rename(wi_string_t *path, wi_string_t *newpath) {
	if(rename(wi_string_cstring(path), wi_string_cstring(newpath)) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return true;
}



wi_boolean_t wi_file_copy(wi_string_t *frompath, wi_string_t *topath) {
	struct stat		sb;
	int				err;
	wi_boolean_t	result;
	
	if(!wi_file_lstat(frompath, &sb))
		return false;
	
	if(wi_file_lstat(topath, &sb))
		return false;
	
	if(S_ISDIR(sb.st_mode))
		result = _wi_file_copy_directory(frompath, topath);
	else
		result = _wi_file_copy_file(frompath, topath);
	
	if(!result) {
		err = errno;
		
		wi_file_delete(topath);

		wi_error_set_errno(err);
	}
	
	return result;
}



static wi_boolean_t _wi_file_copy_file(wi_string_t *frompath, wi_string_t *topath) {
	char			buffer[8192];
	int				fromfd = -1, tofd = -1;
	int				rbytes, wbytes;
	wi_boolean_t	result = false;
	
	fromfd = open(wi_string_cstring(frompath), O_RDONLY, 0);
	
	if(fromfd < 0)
		goto end;
	
	tofd = open(wi_string_cstring(topath), O_WRONLY | O_TRUNC | O_CREAT, 0666);
	
	if(tofd < 0)
		goto end;
	
	while((rbytes = read(fromfd, buffer, sizeof(buffer))) > 0) {
		wbytes = write(tofd, buffer, rbytes);
		
		if(rbytes != wbytes || wbytes < 0)
			goto end;
	}
	
	result = true;
	
end:
	if(tofd >= 0)
		close(tofd);

	if(fromfd >= 0)
		close(fromfd);

	return result;
}



static wi_boolean_t _wi_file_copy_directory(wi_string_t *frompath, wi_string_t *topath) {
	WI_FTS			*fts;
	WI_FTSENT		*p;
	wi_string_t		*path, *newpath;
	char			*paths[2];
	uint32_t		pathlength;
	wi_boolean_t	result = true;

	paths[0] = (char *) wi_string_cstring(frompath);;
	paths[1] = NULL;

	fts = wi_fts_open(paths, WI_FTS_LOGICAL | WI_FTS_NOSTAT, NULL);

	if(!fts)
		return false;
	
	pathlength = wi_string_length(frompath);

	while((p = wi_fts_read(fts))) {
		path = wi_string_init_with_cstring(wi_string_alloc(), p->fts_path);
		newpath = wi_string_init_with_cstring(wi_string_alloc(), p->fts_path + pathlength);
		wi_string_insert_string_at_index(newpath, topath, 0);		

		switch(p->fts_info) {
			case WI_FTS_NS:
			case WI_FTS_ERR:
			case WI_FTS_DNR:
				errno = p->fts_errno;
				result = false;
				break;
			
			case WI_FTS_DC:
			case WI_FTS_DP:
				break;
				
			case WI_FTS_D:
				if(!wi_file_create_directory(newpath, 0777))
					result = false;
				break;
			
			default:
				if(!_wi_file_copy_file(path, newpath))
					result = false;
				break;
		}

		wi_release(newpath);
		wi_release(path);
	}

	wi_fts_close(fts);
	
	return result;
}



wi_boolean_t wi_file_create_directory(wi_string_t *path, mode_t mode) {
	if(mkdir(wi_string_cstring(path), mode) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return true;
}



wi_boolean_t wi_file_stat(wi_string_t *path, struct stat *sp) {
	if(stat(wi_string_cstring(path), sp) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return true;
}



wi_boolean_t wi_file_lstat(wi_string_t *path, struct stat *sp) {
	if(lstat(wi_string_cstring(path), sp) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return true;
}



wi_boolean_t wi_file_statfs(wi_string_t *path, wi_file_statfs_t *sfp) {
#ifdef HAVE_STATVFS
	struct statvfs		sfvb;

	if(statvfs(wi_string_cstring(path), &sfvb) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}

	sfp->f_bsize	= sfvb.f_bsize;
	sfp->f_frsize	= sfvb.f_frsize;
	sfp->f_blocks	= sfvb.f_blocks;
	sfp->f_bfree	= sfvb.f_bfree;
	sfp->f_bavail	= sfvb.f_bavail;
	sfp->f_files	= sfvb.f_files;
	sfp->f_ffree	= sfvb.f_ffree;
	sfp->f_favail	= sfvb.f_favail;
	sfp->f_fsid		= sfvb.f_fsid;
	sfp->f_flag		= sfvb.f_flag;
	sfp->f_namemax	= sfvb.f_namemax;
#else
	struct statfs		sfb;

	if(statfs(wi_string_cstring(path), &sfb) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}

	sfp->f_bsize	= sfb.f_iosize;
	sfp->f_frsize	= sfb.f_bsize;
	sfp->f_blocks	= sfb.f_blocks;
	sfp->f_bfree	= sfb.f_bfree;
	sfp->f_bavail	= sfb.f_bavail;
	sfp->f_files	= sfb.f_files;
	sfp->f_ffree	= sfb.f_ffree;
	sfp->f_favail	= sfb.f_ffree;
	sfp->f_fsid		= sfb.f_fsid.val[0];
	sfp->f_flag		= 0;
	sfp->f_namemax	= 0;
#endif
	
	return true;
}



wi_boolean_t wi_file_is_alias(wi_string_t *path) {
#ifdef HAVE_CORESERVICES_CORESERVICES_H
	return wi_file_is_alias_cpath(wi_string_cstring(path));
#else
	return false;
#endif
}



wi_boolean_t wi_file_is_alias_cpath(const char *cpath) {
#ifdef HAVE_CORESERVICES_CORESERVICES_H
	FSRef		fsRef;
	Boolean		isDir, isAlias;

	if(FSPathMakeRef((UInt8 *) cpath, &fsRef, NULL) != noErr)
		return false;

	if(FSIsAliasFile(&fsRef, &isAlias, &isDir) != noErr)
		return false;

	return isAlias;
#else
	return false;
#endif
}



wi_boolean_t wi_file_is_invisible(wi_string_t *path) {
#ifdef HAVE_CORESERVICES_CORESERVICES_H
	return wi_file_is_invisible_cpath(wi_string_cstring(path));
#else
	return false;
#endif
}



wi_boolean_t wi_file_is_invisible_cpath(const char *cpath) {
#ifdef HAVE_CORESERVICES_CORESERVICES_H
	FSRef				fsRef;
	FSCatalogInfo		catalogInfo;

	if(FSPathMakeRef((UInt8 *) cpath, &fsRef, NULL) != noErr)
		return false;

	if(FSGetCatalogInfo(&fsRef, kFSCatInfoFinderInfo, &catalogInfo, NULL, NULL, NULL) != noErr)
		return false;

	return (((FileInfo *) catalogInfo.finderInfo)->finderFlags & kIsInvisible);
#else
	return false;
#endif
}



#pragma mark -

wi_array_t * wi_file_directory_contents_at_path(wi_string_t *path) {
	wi_array_t		*contents;
	wi_string_t		*name;
	DIR				*dir;
	struct dirent	de, *dep;
	
	dir = opendir(wi_string_cstring(path));
	
	if(!dir) {
		wi_error_set_errno(errno);
		
		return NULL;
	}
	
	contents = wi_array_init_with_capacity(wi_array_alloc(), 100);
	
	while(readdir_r(dir, &de, &dep) == 0 && dep) {
		if(strcmp(dep->d_name, ".") != 0 && strcmp(dep->d_name, "..") != 0) {
			name = wi_string_init_with_cstring(wi_string_alloc(), dep->d_name);
			wi_array_add_data(contents, name);
			wi_release(name);
		}
	}

	closedir(dir);
	
	return wi_autorelease(contents);
}



#ifdef WI_SSL
wi_string_t * wi_file_sha1(wi_string_t *path, wi_file_offset_t offset) {
	static unsigned char	hex[] = "0123456789abcdef";
	FILE					*fp;
	SHA_CTX					c;
	char					buffer[WI_FILE_BUFFER_SIZE];
	unsigned char			sha1[SHA_DIGEST_LENGTH];
	char					sha1_hex[sizeof(sha1) * 2 + 1];
	size_t					bytes;
	uint32_t				i;
	wi_boolean_t			all;
	
	fp = fopen(wi_string_cstring(path), "r");
	
	if(!fp) {
		wi_error_set_errno(errno);
		
		return NULL;
	}
	
	all = (offset == 0);
	
	SHA1_Init(&c);

	while((bytes = fread(buffer, 1, sizeof(buffer), fp)) > 0) {
		if(!all)
			bytes = bytes > offset ? offset : bytes;

		SHA1_Update(&c, buffer, bytes);
		
		if(!all) {
			offset -= bytes;
			
			if(offset == 0)
				break;
		}
	}
		
	fclose(fp);

	SHA1_Final(sha1, &c);

	for(i = 0; i < SHA_DIGEST_LENGTH; i++) {
		sha1_hex[i+i]	= hex[sha1[i] >> 4];
		sha1_hex[i+i+1]	= hex[sha1[i] & 0x0F];
	}

	sha1_hex[i+i] = '\0';

	return wi_string_with_cstring(sha1_hex);
}
#endif


#pragma mark -

wi_runtime_id_t wi_file_runtime_id(void) {
	return _wi_file_runtime_id;
}



#pragma mark -

wi_file_t * wi_file_for_reading(wi_string_t *path) {
	return wi_autorelease(wi_file_init_with_path(wi_file_alloc(), path, WI_FILE_READING));
}



wi_file_t * wi_file_for_writing(wi_string_t *path) {
	return wi_autorelease(wi_file_init_with_path(wi_file_alloc(), path, WI_FILE_WRITING));
}



wi_file_t * wi_file_for_updating(wi_string_t *path) {
	return wi_autorelease(wi_file_init_with_path(wi_file_alloc(), path, WI_FILE_READING | WI_FILE_WRITING | WI_FILE_UPDATING));
}



wi_file_t * wi_file_temporary_file(void) {
	return wi_autorelease(wi_file_init_temporary_file(wi_file_alloc()));
}



#pragma mark -

wi_file_t * wi_file_alloc(void) {
	return wi_runtime_create_instance(_wi_file_runtime_id, sizeof(wi_file_t));
}



wi_file_t * wi_file_init_with_path(wi_file_t *file, wi_string_t *path, wi_file_mode_t mode) {
	int		flags;

	if(mode & WI_FILE_WRITING)	
		flags = O_CREAT;
	else
		flags = 0;
	
	if((mode & WI_FILE_READING) && (mode & WI_FILE_WRITING))
		flags |= O_RDWR;
	else if(mode & WI_FILE_READING)
		flags |= O_RDONLY;
	else if(mode & WI_FILE_WRITING)
		flags |= O_WRONLY;
	
	if(mode & WI_FILE_WRITING) {
		if(mode & WI_FILE_UPDATING)
			flags |= O_APPEND;
		else
			flags |= O_TRUNC;
	}
		
	file->fd = open(wi_string_cstring(path), flags, 0666);
	
	if(file->fd < 0) {
		wi_error_set_errno(errno);

		wi_release(file);
		
		return NULL;
	}
	
	return file;
}



wi_file_t * wi_file_init_with_file_descriptor(wi_file_t *file, int fd) {
	file->fd = fd;
	
	return file;
}



wi_file_t * wi_file_init_temporary_file(wi_file_t *file) {
	FILE		*fp;
	
	fp = wi_tmpfile();
	
	if(!fp) {
		wi_error_set_errno(errno);

		wi_release(file);
		
		return NULL;
	}

	return wi_file_init_with_file_descriptor(file, fileno(fp));
}




static void _wi_file_dealloc(wi_runtime_instance_t *instance) {
	wi_file_t		*file = instance;
	
	wi_file_close(file);
}



static wi_string_t * _wi_file_description(wi_runtime_instance_t *instance) {
	wi_file_t		*file = instance;
	
	return wi_string_with_format(WI_STR("<%s %p>{descriptor = %d}"),
	  wi_runtime_class_name(file),
	  file,
	  file->fd);
}



#pragma mark -

int wi_file_descriptor(wi_file_t *file) {
	return file->fd;
}



#pragma mark -

wi_string_t * wi_file_read(wi_file_t *file, size_t length) {
	wi_string_t		*string;
	char			buffer[WI_FILE_BUFFER_SIZE];
	int				bytes = -1;
	
	_WI_FILE_ASSERT_OPEN(file);
	
	string = wi_string_init_with_capacity(wi_string_alloc(), length);
	
	while(length > sizeof(buffer)) {
		bytes = wi_file_read_buffer(file, buffer, sizeof(buffer));
		
		if(bytes <= 0)
			goto end;
		
		wi_string_append_bytes(string, buffer, bytes);
		
		length -= bytes;
	}
	
	if(length > 0) {
		bytes = wi_file_read_buffer(file, buffer, sizeof(buffer));
		
		if(bytes <= 0)
			goto end;
		
		wi_string_append_bytes(string, buffer, bytes);
	}
	
end:
	if(bytes <= 0) {
		wi_release(string);
		
		string = NULL;
	}

	return wi_autorelease(string);
}



wi_string_t * wi_file_read_to_end_of_file(wi_file_t *file) {
	return wi_file_read(file, UINT_MAX);
}



wi_string_t * wi_file_read_line(wi_file_t *file) {
	return wi_file_read_to_string(file, WI_STR("\n"));
}



wi_string_t * wi_file_read_config_line(wi_file_t *file) {
	wi_string_t		*string;
	
	while((string = wi_file_read_line(file))) {
		if(wi_string_length(string) == 0 || wi_string_has_prefix(string, WI_STR("#")))
			continue;

		return string;
	}
	
	return NULL;
}



wi_string_t * wi_file_read_to_string(wi_file_t *file, wi_string_t *separator) {
	wi_string_t		*string;
	uint32_t		index, length;
	
	_WI_FILE_ASSERT_OPEN(file);

	while((string = wi_file_read(file, WI_FILE_BUFFER_SIZE))) {
		length = wi_string_length(string);
		index = wi_string_index_of_string(string, separator, 0);
		
		if(index == WI_NOT_FOUND) {
			if(length < WI_FILE_BUFFER_SIZE)
				return string;
		} else {
			wi_string_delete_characters_from_index(string, index);
			
			wi_file_seek(file, wi_file_offset(file) - length + index + 1);
			
			return string;
		}
	}
	
	return NULL;
}



int32_t wi_file_read_buffer(wi_file_t *file, char *buffer, size_t length) {
	int		bytes;
	
	bytes = read(file->fd, buffer, length);
	
	if(bytes < 0)
		wi_error_set_errno(errno);
	
	return bytes;
}



int32_t wi_file_write(wi_file_t *file, wi_string_t *fmt, ...) {
	wi_string_t		*string;
	int				bytes;
	va_list			ap;
	
	_WI_FILE_ASSERT_OPEN(file);
	
	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);
	
	bytes = wi_file_write_buffer(file, wi_string_cstring(string), wi_string_length(string));
	
	wi_release(string);
	
	return bytes;
}



int32_t wi_file_write_buffer(wi_file_t *file, const char *buffer, size_t length) {
	int		bytes;
	
	bytes = write(file->fd, buffer, length);
	
	if(bytes < 0)
		wi_error_set_errno(errno);
	
	return bytes;
}



#pragma mark -

void wi_file_seek(wi_file_t *file, wi_file_offset_t offset) {
	_WI_FILE_ASSERT_OPEN(file);
	
	lseek(file->fd, (off_t) offset, SEEK_SET);
}



wi_file_offset_t wi_file_seek_to_end_of_file(wi_file_t *file) {
	_WI_FILE_ASSERT_OPEN(file);
	
	return (wi_file_offset_t) lseek(file->fd, 0, SEEK_END);
}



wi_file_offset_t wi_file_offset(wi_file_t *file) {
	return (wi_file_offset_t) lseek(file->fd, 0, SEEK_CUR);
}



#pragma mark -

wi_boolean_t wi_file_truncate(wi_file_t *file, wi_file_offset_t offset) {
	_WI_FILE_ASSERT_OPEN(file);
	
	if(ftruncate(file->fd, offset) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return true;
}



void wi_file_close(wi_file_t *file) {
	if(file->fd >= 0) {
		(void) close(file->fd);
		
		file->fd = -1;
	}
}
