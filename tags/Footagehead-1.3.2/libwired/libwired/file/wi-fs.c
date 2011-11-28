/* $Id$ */

/*
 *  Copyright (c) 2005-2009 Axel Andersson
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

#define _DARWIN_USE_64_BIT_INODE

#ifdef HAVE_CARBON_CARBON_H
#include <Carbon/Carbon.h>
#endif

#include <sys/param.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mount.h>

#ifdef HAVE_SYS_ATTR_H
#include <sys/attr.h>
#endif

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

#include <wired/wi-array.h>
#include <wired/wi-assert.h>
#include <wired/wi-byteorder.h>
#include <wired/wi-compat.h>
#include <wired/wi-digest.h>
#include <wired/wi-fts.h>
#include <wired/wi-lock.h>
#include <wired/wi-fs.h>
#include <wired/wi-pool.h>
#include <wired/wi-private.h>
#include <wired/wi-runtime.h>
#include <wired/wi-string.h>

static wi_boolean_t						_wi_fs_delete_file(wi_string_t *);
static wi_boolean_t						_wi_fs_delete_directory(wi_string_t *);

static wi_boolean_t						_wi_fs_copy_file(wi_string_t *, wi_string_t *);
static wi_boolean_t						_wi_fs_copy_directory(wi_string_t *, wi_string_t *);

static wi_boolean_t						_wi_fs_stat_path(wi_string_t *, wi_fs_stat_t *, wi_boolean_t);

#ifdef HAVE_CARBON_CARBON_H
static int16_t							_wi_fs_finder_flags(const char *);
#endif



wi_string_t * wi_fs_temporary_path_with_template(wi_string_t *template) {
	char		path[WI_PATH_SIZE];
	
	wi_strlcpy(path, wi_string_cstring(template), sizeof(path));
	
	if(!mktemp(path))
		return NULL;
	
	return wi_string_with_cstring(path);
}



#pragma mark -

wi_boolean_t wi_fs_create_directory(wi_string_t *path, uint32_t mode) {
	if(mkdir(wi_string_cstring(path), mode) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return true;
}



wi_boolean_t wi_fs_change_directory(wi_string_t *path) {
	if(chdir(wi_string_cstring(path)) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return true;
}



#pragma mark -

wi_boolean_t wi_fs_delete_path(wi_string_t *path) {
	wi_fs_stat_t	sb;
	wi_boolean_t	result;
	
	if(!wi_fs_lstat_path(path, &sb))
		return false;
	
	if(S_ISDIR(sb.mode))
		result = _wi_fs_delete_directory(path);
	else
		result = _wi_fs_delete_file(path);
	
	if(!result)
		wi_error_set_errno(errno);
	
	return result;
}



static wi_boolean_t _wi_fs_delete_file(wi_string_t *path) {
	if(unlink(wi_string_cstring(path)) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return true;
}



static wi_boolean_t _wi_fs_delete_directory(wi_string_t *path) {
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



wi_boolean_t wi_fs_clear_path(wi_string_t *path) {
	if(truncate(wi_string_cstring(path), 0) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return true;
}



wi_boolean_t wi_fs_rename_path(wi_string_t *path, wi_string_t *newpath) {
	if(rename(wi_string_cstring(path), wi_string_cstring(newpath)) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return true;
}



wi_boolean_t wi_fs_symlink_path(wi_string_t *frompath, wi_string_t *topath) {
	if(symlink(wi_string_cstring(frompath), wi_string_cstring(topath)) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return true;
}



wi_boolean_t wi_fs_copy_path(wi_string_t *frompath, wi_string_t *topath) {
	wi_fs_stat_t	sb;
	int				err;
	wi_boolean_t	result;
	
	if(!wi_fs_lstat_path(frompath, &sb))
		return false;
	
	if(wi_fs_path_exists(topath, NULL)) {
		wi_error_set_errno(EEXIST);
		
		return false;
	}
	
	if(S_ISDIR(sb.mode))
		result = _wi_fs_copy_directory(frompath, topath);
	else
		result = _wi_fs_copy_file(frompath, topath);
	
	if(!result) {
		err = errno;
		
		wi_fs_delete_path(topath);

		wi_error_set_errno(err);
	}
	
	return result;
}



static wi_boolean_t _wi_fs_copy_file(wi_string_t *frompath, wi_string_t *topath) {
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



static wi_boolean_t _wi_fs_copy_directory(wi_string_t *frompath, wi_string_t *topath) {
	WI_FTS			*fts;
	WI_FTSENT		*p;
	wi_string_t		*path, *newpath;
	char			*paths[2];
	wi_uinteger_t	pathlength;
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
				if(!wi_fs_create_directory(newpath, 0777))
					result = false;
				break;
			
			default:
				if(!_wi_fs_copy_file(path, newpath))
					result = false;
				break;
		}

		wi_release(newpath);
		wi_release(path);
	}

	wi_fts_close(fts);
	
	return result;
}



wi_boolean_t wi_fs_set_mode_for_path(wi_string_t *path, uint32_t mode) {
	if(chmod(wi_string_cstring(path), mode) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return true;
}



#pragma mark -

static wi_boolean_t _wi_fs_stat_path(wi_string_t *path, wi_fs_stat_t *sp, wi_boolean_t link) {
#if defined(HAVE_STAT64) && !defined(_DARWIN_FEATURE_64_BIT_INODE)
	struct stat64		sb;
	
	if((link && lstat64(wi_string_cstring(path), &sb) < 0) ||
	   (!link && stat64(wi_string_cstring(path), &sb) < 0)) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	sp->dev			= sb.st_dev;
	sp->ino			= sb.st_ino;
	sp->mode		= sb.st_mode;
	sp->nlink		= sb.st_nlink;
	sp->uid			= sb.st_uid;
	sp->gid			= sb.st_gid;
	sp->rdev		= sb.st_rdev;
	sp->atime		= sb.st_atime;
	sp->mtime		= sb.st_mtime;
	sp->ctime		= sb.st_ctime;

#ifdef HAVE_STRUCT_STAT64_ST_BIRTHTIME
	sp->birthtime	= sb.st_birthtime;
#else
	sp->birthtime	= sb.st_ctime;
#endif
	
	sp->size		= sb.st_size;
	sp->blocks		= sb.st_blocks;
	sp->blksize		= sb.st_blksize;
	
	return true;
#else
	struct stat		sb;
	
	if((link && lstat(wi_string_cstring(path), &sb) < 0) ||
	   (!link && stat(wi_string_cstring(path), &sb) < 0)) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	sp->dev			= sb.st_dev;
	sp->ino			= sb.st_ino;
	sp->mode		= sb.st_mode;
	sp->nlink		= sb.st_nlink;
	sp->uid			= sb.st_uid;
	sp->gid			= sb.st_gid;
	sp->rdev		= sb.st_rdev;
	sp->atime		= sb.st_atime;
	sp->mtime		= sb.st_mtime;
	sp->ctime		= sb.st_ctime;
	
#ifdef HAVE_STRUCT_STAT_ST_BIRTHTIME
	sp->birthtime	= sb.st_birthtime;
#else
	sp->birthtime	= sb.st_ctime;
#endif
	
	sp->size		= sb.st_size;
	sp->blocks		= sb.st_blocks;
	sp->blksize		= sb.st_blksize;
	
	return true;
#endif
}



wi_boolean_t wi_fs_stat_path(wi_string_t *path, wi_fs_stat_t *sp) {
	return _wi_fs_stat_path(path, sp, false);
}



wi_boolean_t wi_fs_lstat_path(wi_string_t *path, wi_fs_stat_t *sp) {
	return _wi_fs_stat_path(path, sp, true);
}



wi_boolean_t wi_fs_statfs_path(wi_string_t *path, wi_fs_statfs_t *sfp) {
#ifdef HAVE_STATVFS
	struct statvfs		sfvb;

	if(statvfs(wi_string_cstring(path), &sfvb) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}

	sfp->bsize		= sfvb.f_bsize;
	sfp->frsize		= sfvb.f_frsize;
	sfp->blocks		= sfvb.f_blocks;
	sfp->bfree		= sfvb.f_bfree;
	sfp->bavail		= sfvb.f_bavail;
	sfp->files		= sfvb.f_files;
	sfp->ffree		= sfvb.f_ffree;
	sfp->favail		= sfvb.f_favail;
	sfp->fsid		= sfvb.f_fsid;
	sfp->flag		= sfvb.f_flag;
	sfp->namemax	= sfvb.f_namemax;
#else
	struct statfs		sfb;

	if(statfs(wi_string_cstring(path), &sfb) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}

	sfp->bsize		= sfb.f_iosize;
	sfp->frsize		= sfb.f_bsize;
	sfp->blocks		= sfb.f_blocks;
	sfp->bfree		= sfb.f_bfree;
	sfp->bavail		= sfb.f_bavail;
	sfp->files		= sfb.f_files;
	sfp->ffree		= sfb.f_ffree;
	sfp->favail		= sfb.f_ffree;
	sfp->fsid		= sfb.f_fsid.val[0];
	sfp->flag		= 0;
	sfp->namemax	= 0;
#endif
	
	return true;
}



wi_boolean_t wi_fs_path_exists(wi_string_t *path, wi_boolean_t *is_directory) {
	wi_fs_stat_t	sb;
	
	if(!wi_fs_stat_path(path, &sb))
		return false;
		
	if(is_directory)
		*is_directory = S_ISDIR(sb.mode);
	
	return true;
}



wi_boolean_t wi_fs_path_is_alias(wi_string_t *path) {
	return wi_fs_cpath_is_alias(wi_string_cstring(path));
}



wi_boolean_t wi_fs_cpath_is_alias(const char *cpath) {
#ifdef HAVE_CARBON_CARBON_H
	return (_wi_fs_finder_flags(cpath) & kIsAlias);
#else
	wi_error_set_libwired_error(WI_ERROR_FILE_NOCARBON);
	
	return false;
#endif
}



wi_boolean_t wi_fs_path_is_invisible(wi_string_t *path) {
	return wi_fs_cpath_is_invisible(wi_string_cstring(path));
}



wi_boolean_t wi_fs_cpath_is_invisible(const char *cpath) {
#ifdef HAVE_CARBON_CARBON_H
	return (_wi_fs_finder_flags(cpath) & kIsInvisible);
#else
	wi_error_set_libwired_error(WI_ERROR_FILE_NOCARBON);
	
	return false;
#endif
}



#ifdef HAVE_CARBON_CARBON_H

static int16_t _wi_fs_finder_flags(const char *cpath) {
	struct attrlist		attrs;
	char				finderinfo[32];
	
	attrs.bitmapcount	= ATTR_BIT_MAP_COUNT;
	attrs.reserved		= 0;
	attrs.commonattr	= ATTR_CMN_FNDRINFO;
	attrs.volattr		= 0;
	attrs.dirattr		= 0;
	attrs.fileattr		= 0;
	attrs.forkattr		= 0;
	
	if(getattrlist(cpath, &attrs, &finderinfo, sizeof(finderinfo), FSOPT_NOFOLLOW) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return wi_read_swap_big_to_host_int16(finderinfo, 12);
}

#endif



#pragma mark -

wi_boolean_t wi_fs_set_finder_comment_for_path(wi_string_t *path, wi_string_t *comment) {
#ifdef HAVE_CARBON_CARBON_H
    FSRef			fileRef;
    AEDesc			fileDesc, commentDesc, builtEvent, replyEvent;
	OSType			finderSignature = 'MACS';
    OSErr			err;
    const char		*event =
        "'----': 'obj '{ "
        "  form: enum(prop), "
        "  seld: type(comt), "
        "  want: type(prop), "
        "  from: 'obj '{ "
        "      form: enum(indx), "
        "      want: type(file), "
        "      seld: @,"
        "      from: null() "
        "              }"
        "             }, "
        "data: @";
	
    err = FSPathMakeRef((UInt8 *) wi_string_cstring(path), &fileRef, NULL);
	
	if(err != noErr) {
		wi_error_set_carbon_error(err);
	
		return false;
	}

    AEInitializeDesc(&fileDesc);

    err = AECoercePtr(typeFSRef, &fileRef, sizeof(fileRef), typeAlias, &fileDesc);
    
	if(err != noErr) {
		wi_error_set_carbon_error(err);
	
		return false;
    }

	err = AECreateDesc(typeUTF8Text, wi_string_cstring(comment), wi_string_length(comment), &commentDesc);
	
	if(err != noErr) {
		wi_error_set_carbon_error(err);
	
		return false;
	}
	
    AEInitializeDesc(&builtEvent);
    AEInitializeDesc(&replyEvent);
	
    err = AEBuildAppleEvent(kAECoreSuite,
							kAESetData,
                            typeApplSignature,
							&finderSignature,
							sizeof(finderSignature),
                            kAutoGenerateReturnID,
							kAnyTransactionID,
                            &builtEvent,
							NULL,
                            event,
                            &fileDesc,
							&commentDesc);

    AEDisposeDesc(&fileDesc);
    AEDisposeDesc(&commentDesc);

    if(err != noErr) {
		wi_error_set_carbon_error(err);

		return false;
    }
    
    err = AESendMessage(&builtEvent, &replyEvent, kAENoReply, kAEDefaultTimeout);

    AEDisposeDesc(&builtEvent);
    AEDisposeDesc(&replyEvent);

    if(err != noErr) {
		wi_error_set_carbon_error(err);

		return false;
    }
	
	return true;
#else
	wi_error_set_libwired_error(WI_ERROR_FILE_NOCARBON);
	
	return false;
#endif
}



wi_string_t * wi_fs_finder_comment_for_path(wi_string_t *path) {
#if defined(HAVE_CARBON_CARBON_H) && defined(HAVE_MDITEMCREATE)
	MDItemRef		item;
	CFStringRef		cfPath, cfComment = NULL;
	wi_string_t		*comment = NULL;
	char			buffer[1024];
	
	cfPath = CFStringCreateWithCString(NULL, wi_string_cstring(path), kCFStringEncodingUTF8);
	item = MDItemCreate(NULL, cfPath);
	
	if(!item) {
		wi_error_set_carbon_error(0);
		
		goto end;
	}
	
	cfComment = MDItemCopyAttribute(item, kMDItemFinderComment);
	
	if(!cfComment)
		goto end;
	
	if(!CFStringGetCString(cfComment, buffer, sizeof(buffer), kCFStringEncodingUTF8)) {
		wi_error_set_carbon_error(0);
		
		goto end;
	}
	
	comment = wi_string_with_cstring(buffer);
	
end:
	if(cfPath)
		CFRelease(cfPath);
	
	if(cfComment)
		CFRelease(cfComment);
	
	if(item)
		CFRelease(item);
	
	return comment;
#else
	wi_error_set_libwired_error(WI_ERROR_FILE_NOCARBON);
	
	return NULL;
#endif
}



#pragma mark -

wi_array_t * wi_fs_directory_contents_at_path(wi_string_t *path) {
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



wi_fsenumerator_t * wi_fs_enumerator_at_path(wi_string_t *path) {
	return wi_autorelease(wi_fsenumerator_init_with_path(wi_fsenumerator_alloc(), path));
}



#pragma mark -

#ifdef WI_DIGESTS

wi_string_t * wi_fs_sha1_for_path(wi_string_t *path, wi_file_offset_t offset) {
	static unsigned char	hex[] = "0123456789abcdef";
	FILE					*fp;
	wi_sha1_ctx_t			c;
	char					buffer[WI_FILE_BUFFER_SIZE];
	unsigned char			sha1[WI_SHA1_DIGEST_LENGTH];
	char					sha1_hex[sizeof(sha1) * 2 + 1];
	size_t					bytes;
	wi_uinteger_t			i;
	wi_boolean_t			all;
	
	fp = fopen(wi_string_cstring(path), "r");
	
	if(!fp) {
		wi_error_set_errno(errno);
		
		return NULL;
	}
	
	all = (offset == 0);
	
	wi_sha1_init(&c);

	while((bytes = fread(buffer, 1, sizeof(buffer), fp)) > 0) {
		if(!all)
			bytes = bytes > offset ? offset : bytes;

		wi_sha1_update(&c, buffer, bytes);
		
		if(!all) {
			offset -= bytes;
			
			if(offset == 0)
				break;
		}
	}
		
	fclose(fp);

	wi_sha1_final(sha1, &c);

	for(i = 0; i < WI_SHA1_DIGEST_LENGTH; i++) {
		sha1_hex[i + i]		= hex[sha1[i] >> 4];
		sha1_hex[i + i + 1]	= hex[sha1[i] & 0x0F];
	}

	sha1_hex[i + i] = '\0';

	return wi_string_with_cstring(sha1_hex);
}

#endif
