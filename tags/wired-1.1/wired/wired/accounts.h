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

#ifndef WD_ACCOUNTS_H
#define WD_ACCOUNTS_H 1

#include "server.h"


enum {
	WD_USER_NAME							= 0,
	WD_USER_PASSWORD,
	WD_USER_GROUP,
	WD_USER_GET_USER_INFO,
	WD_USER_BROADCAST,
	WD_USER_POST_NEWS,
	WD_USER_CLEAR_NEWS,
	WD_USER_DOWNLOAD,
	WD_USER_UPLOAD,
	WD_USER_UPLOAD_ANYWHERE,
	WD_USER_CREATE_FOLDERS,
	WD_USER_MOVE_FILES,
	WD_USER_DELETE_FILES,
	WD_USER_VIEW_DROPBOXES,
	WD_USER_CREATE_ACCOUNTS,
	WD_USER_EDIT_ACCOUNTS,
	WD_USER_DELETE_ACCOUNTS,
	WD_USER_ELEVATE_PRIVILEGES,
	WD_USER_KICK_USERS,
	WD_USER_BAN_USERS,
	WD_USER_CANNOT_BE_KICKED,
	WD_USER_DOWNLOAD_SPEED,
	WD_USER_UPLOAD_SPEED,
	WD_USER_LAST
};

enum {
	WD_GROUP_NAME							= 0,
	WD_GROUP_GET_USER_INFO,
	WD_GROUP_BROADCAST,
	WD_GROUP_POST_NEWS,
	WD_GROUP_CLEAR_NEWS,
	WD_GROUP_DOWNLOAD,
	WD_GROUP_UPLOAD,
	WD_GROUP_UPLOAD_ANYWHERE,
	WD_GROUP_CREATE_FOLDERS,
	WD_GROUP_MOVE_FILES,
	WD_GROUP_DELETE_FILES,
	WD_GROUP_VIEW_DROPBOXES,
	WD_GROUP_CREATE_ACCOUNTS,
	WD_GROUP_EDIT_ACCOUNTS,
	WD_GROUP_DELETE_ACCOUNTS,
	WD_GROUP_ELEVATE_PRIVILEGES,
	WD_GROUP_KICK_USERS,
	WD_GROUP_BAN_USERS,
	WD_GROUP_CANNOT_BE_KICKED,
	WD_GROUP_DOWNLOAD_SPEED,
	WD_GROUP_UPLOAD_SPEED,
	WD_GROUP_LAST
};

enum {
	WD_PRIV_NONE							= -1,
	WD_PRIV_GET_USER_INFO					= 0,
	WD_PRIV_BROADCAST,
	WD_PRIV_POST_NEWS,
	WD_PRIV_CLEAR_NEWS,
	WD_PRIV_DOWNLOAD,
	WD_PRIV_UPLOAD,
	WD_PRIV_UPLOAD_ANYWHERE,
	WD_PRIV_CREATE_FOLDERS,
	WD_PRIV_MOVE_FILES,
	WD_PRIV_DELETE_FILES,
	WD_PRIV_VIEW_DROPBOXES,
	WD_PRIV_CREATE_ACCOUNTS,
	WD_PRIV_EDIT_ACCOUNTS,
	WD_PRIV_DELETE_ACCOUNTS,
	WD_PRIV_ELEVATE_PRIVILEGES,
	WD_PRIV_KICK_USERS,
	WD_PRIV_BAN_USERS,
	WD_PRIV_CANNOT_BE_KICKED,
	WD_PRIV_DOWNLOAD_SPEED,
	WD_PRIV_UPLOAD_SPEED,
	WD_PRIV_LAST
};


int										wd_check_login(char *, char *);

char *									wd_getuser(char *);
char *									wd_getuserfield(char *, int);
char *									wd_getgroup(char *);
char *									wd_getgroupfield(char *, int);
int										wd_getpriv(char *, int);

int										wd_create_user(char **);
int										wd_edit_user(char **);
int										wd_delete_user(char *);
int										wd_create_group(char **);
int										wd_edit_group(char **);
int										wd_delete_group(char *);
void									wd_clear_group(char *);

void									wd_list_users(void);
void									wd_list_groups(void);
void									wd_list_privileges(struct wd_client *);

#endif /* WD_ACCOUNTS_H */
