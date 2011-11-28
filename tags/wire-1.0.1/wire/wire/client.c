/* $Id$ */

/*
 *  Copyright (c) 2004 Axel Andersson
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

#include <sys/types.h>
#include <sys/param.h>
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <libgen.h>
#include <openssl/sha.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <readline/readline.h>

#include "client.h"
#include "commands.h"
#include "main.h"
#include "utility.h"


char						wr_host[MAXHOSTNAMELEN];
int							wr_port;
char						wr_server[WR_SERVER_SIZE];
float						wr_protocol;
char						wr_nick[WR_NICK_SIZE];
unsigned int				wr_icon;
char						wr_login[WR_LOGIN_SIZE];
char						wr_password[WR_PASSWORD_SIZE];
char						wr_password_sha[SHA_DIGEST_LENGTH * 2 + 1];
char						wr_topic[WR_TOPIC_SIZE];

unsigned long long			wr_received_bytes;
unsigned long long			wr_transferred_bytes;

int							wr_news_count;
int							wr_news_limit;

wr_ls_state_t				wr_ls_state;
wr_stat_state_t				wr_stat_state;

char						wr_files_cwd[MAXPATHLEN];
char						wr_files_ld[MAXPATHLEN];
wr_list_t					wr_files;

wr_list_t					wr_users;

wr_list_t					wr_transfers;

wr_list_t					wr_ignores;

int							wr_socket = -1;
struct sockaddr_in			wr_addr;

bool						wr_connected;
bool						wr_received;

wr_uid_t					wr_reply_uid;

SSL_CTX						*wr_ssl_ctx;
SSL							*wr_ssl;


void wr_init_ssl(void) {
	/* initiate SSL */
	SSL_load_error_strings();
	SSL_library_init();
}



#pragma mark -

wr_user_t * wr_get_user(wr_uid_t uid) {
	wr_list_node_t	*node;
	wr_user_t		*user, *value = NULL;

	/* find uid on chat */
	WR_LIST_LOCK(wr_users);
	WR_LIST_FOREACH(wr_users, node, user) {
		if(user->uid == uid) {
			value = user;
		
			break;
		}
	}
	WR_LIST_UNLOCK(wr_users);

	return value;
}



wr_user_t * wr_get_user_with_nick(char *nick) {
	wr_list_node_t	*node;
	wr_user_t		*user, *value = NULL;
	char			*name;
	
	/* dequote name */
	name = ((*rl_filename_dequoting_function) (nick, 0));

	/* find nick on chat */
	WR_LIST_LOCK(wr_users);
	WR_LIST_FOREACH(wr_users, node, user) {
		if(strcmp(name, user->nick) == 0) {
			value = user;
		
			break;
		}
	}
	WR_LIST_UNLOCK(wr_users);
	
	/* free nick */
	free(name);

	return value;
}



wr_transfer_t * wr_get_transfer(char *path) {
	wr_list_node_t	*node;
	wr_transfer_t	*transfer, *value = NULL;

	/* find path in transfers */
	WR_LIST_LOCK(wr_transfers);
	WR_LIST_FOREACH(wr_transfers, node, transfer) {
		if(strcmp(transfer->path, path) == 0) {
			value = transfer;
		
			break;
		}
	}
	WR_LIST_UNLOCK(wr_transfers);

	return value;
}



wr_transfer_t * wr_get_transfer_with_sd(int sd) {
	wr_list_node_t	*node;
	wr_transfer_t	*transfer, *value = NULL;

	/* find sd in transfers */
	WR_LIST_LOCK(wr_transfers);
	WR_LIST_FOREACH(wr_transfers, node, transfer) {
		if(transfer->sd == sd) {
			value = transfer;
		
			break;
		}
	}
	WR_LIST_UNLOCK(wr_transfers);

	return value;
}



wr_transfer_t * wr_get_transfer_with_tid(wr_tid_t tid) {
	wr_list_node_t	*node;
	wr_transfer_t	*transfer, *value = NULL;

	/* find sd in transfers */
	WR_LIST_LOCK(wr_transfers);
	WR_LIST_FOREACH(wr_transfers, node, transfer) {
		if(transfer->tid == tid) {
			value = transfer;
		
			break;
		}
	}
	WR_LIST_UNLOCK(wr_transfers);

	return value;
}



bool wr_ignore_nick(char *nick) {
	wr_list_node_t	*node;
	wr_ignore_t		*ignore;
	
	/* loop over ignores */
	WR_LIST_LOCK(wr_ignores);
	WR_LIST_FOREACH(wr_ignores, node, ignore) {
		if(regexec(&(ignore->regex), nick, 0, NULL, 0) == 0)
			return true;
	}
	WR_LIST_UNLOCK(wr_ignores);
	
	return false;
}



#pragma mark -

char * wr_rl_nickname_generator(const char *text, int state) {
	static wr_list_node_t	*node;
	static int				length;
	wr_user_t				*user;

	if(!state) {
		node = wr_users.first;
		length = strlen(text);
	}
	
	for(; node != NULL; ) {
		user = WR_LIST_DATA(node);
		node = WR_LIST_NEXT(node);
		
		if(strncasecmp(user->nick, text, length) == 0)
			return strdup(user->nick);
	}
	
	return NULL;
}



char * wr_rl_filename_generator(const char *text, int state) {
	static wr_list_node_t	*node;
	static char				arg_path[MAXPATHLEN];
	wr_file_t				*file;
	char					*p, *match, *base, *text_copy = NULL, *path = NULL;
	char					real_path[MAXPATHLEN];
	int						length, bytes;

	if(!state) {
		/* re-create list */
		wr_list_free(&wr_files);
		wr_list_create(&wr_files);
		
		/* copy text */
		text_copy = strdup(text);
		
		/* find the path portion of text */
		if((p = strrchr(text_copy, '/'))) {
			*(p + 1) = '\0';

			path = ((*rl_filename_dequoting_function) (text_copy, 0));
		}
		
		/* free copy */
		free(text_copy);
		
		if(!path) {
			/* clear path */
			memset(arg_path, 0, sizeof(arg_path));

			/* default to cwd */
			strlcpy(real_path, wr_files_cwd, sizeof(real_path));
		} else {
			/* save path */
			strlcpy(arg_path, path, sizeof(real_path));

			/* expand path */
			wr_path_expand(real_path, path, sizeof(real_path));
			
			/* free path */
			free(path);
		}
		
		/* list path */
		wr_send_command("LIST %s%s",
			real_path,
			WR_MESSAGE_SEPARATOR);
		
		/* enter loop */
		wr_loop(false, 411, 3.0);
		
		/* set first node */
		node = WR_LIST_FIRST(wr_files);
	}
	
	/* get basename */
	base = basename_np(text);
	length = strlen(base);
		
	/* loop & match */
	for(; node != NULL; ) {
		file = WR_LIST_DATA(node);
		node = WR_LIST_NEXT(node);
		
		/* skip non-folders */
		if(file->type == WR_FILE_FILE && wr_ls_state == WR_LS_COMPLETING_DIRECTORY)
			continue;
		
		if(strncasecmp(file->name, base, length) == 0) {
			/* append / if directory */
			if(file->type != WR_FILE_FILE)
				rl_completion_append_character = '/';
			else
				rl_completion_append_character = ' ';
				
			/* just the filename */
			if(strlen(arg_path) == 0)
				return strdup(file->name);
				
			/* concat path & filename */
			bytes = strlen(arg_path) + strlen(file->name) + 2;
			match = malloc(bytes);
			snprintf(match, bytes, "%s%s", arg_path, file->name);
			
			return match;
		}
	}
	
	return NULL;
}



char * wr_rl_ignore_generator(const char *text, int state) {
	static wr_list_node_t	*node;
	static int				length;
	wr_ignore_t				*ignore;

	if(!state) {
		node = wr_ignores.first;
		length = strlen(text);
	}
	
	for(; node != NULL; ) {
		ignore = WR_LIST_DATA(node);
		node = WR_LIST_NEXT(node);
		
		if(strncasecmp(ignore->string, text, length) == 0)
			return strdup(ignore->string);
	}
	
	return NULL;
}



#pragma mark -

void wr_connect(char *host, int port, char *login, char *password) {
	SHA_CTX					c;
	static unsigned char	hex[] = "0123456789abcdef";
	unsigned char			sha[SHA_DIGEST_LENGTH];
	struct hostent			*hp;
	int						i, on = 1;

	/* disconnect active socket */
	if(wr_socket >= 0)
		wr_close();

	/* reset current working directory */
	strlcpy(wr_files_cwd, "/", sizeof(wr_files_cwd));

	/* copy values */
	wr_port = port;
	
	if(port != 2000)
		snprintf(wr_host, sizeof(wr_host), "%s:%d", host, port);
	else
		strlcpy(wr_host, host, sizeof(wr_host));

	strlcpy(wr_login, login, sizeof(wr_login));
	strlcpy(wr_password, password, sizeof(wr_password));

	/* log */
	wr_printf_prefix("Connecting to %s...\n", wr_host);

	/* create new socket */
	wr_socket = socket(AF_INET, SOCK_STREAM, 0);

	if(wr_socket < 0) {
		wr_printf_prefix("Could not create a socket: %s\n",
			strerror(errno));
		wr_close();

		return;
	}

	/* set socket options */
	if(setsockopt(wr_socket, IPPROTO_TCP, TCP_NODELAY, &on, sizeof(on)) < 0) {
		wr_printf_prefix("Could not set socket options: %s\n",
			strerror(errno));
		wr_close();

		return;
	}

	/* init address */
	memset(&wr_addr, 0, sizeof(wr_addr));
	wr_addr.sin_family	= AF_INET;
	wr_addr.sin_port	= htons(port);

	if(!inet_aton(host, &wr_addr.sin_addr)) {
		hp = gethostbyname(host);

		if(!hp) {
			wr_printf_prefix("Could not resolve hostname %s: %s\n",
				host, hstrerror(h_errno));
			wr_close();

			return;
		}

		memcpy(&wr_addr.sin_addr, hp->h_addr, sizeof(wr_addr.sin_addr));
	}

	/* connect TCP socket */
	if(connect(wr_socket, (struct sockaddr *) &wr_addr, sizeof(wr_addr)) < 0) {
		wr_printf_prefix("Could not connect to %s: %s\n",
			host, strerror(errno));
		wr_close();

		return;
	}

	/* create SSL context */
	wr_ssl_ctx = SSL_CTX_new(TLSv1_client_method());

	if(!wr_ssl_ctx) {
		wr_printf_prefix("Could not create SSL context: %s\n",
			ERR_reason_error_string(ERR_get_error()));
		wr_close();

		return;
	}

	if(SSL_CTX_set_cipher_list(wr_ssl_ctx, "ALL") != 1) {
		wr_printf_prefix("Could not set SSL cipher list: %s\n",
			ERR_reason_error_string(ERR_get_error()));
		wr_close();

		return;
	}

	/* create SSL socket */
	wr_ssl = SSL_new(wr_ssl_ctx);

	if(!wr_ssl) {
		wr_printf_prefix("Could not create SSL socket: %s\n",
			ERR_reason_error_string(ERR_get_error()));
		wr_close();

		return;
	}

	if(SSL_set_fd(wr_ssl, wr_socket) != 1) {
		wr_printf_prefix("Could not set SSL file descriptor: %s\n",
			ERR_reason_error_string(ERR_get_error()));
		wr_close();

		return;
	}

	if(SSL_connect(wr_ssl) != 1) {
		wr_printf_prefix("Could not connect to %s via SSL: %s\n",
			host, ERR_reason_error_string(ERR_get_error()));
		wr_close();

		return;
	}

	/* log */
	wr_printf_prefix("Connected using %s/%s/%u bits, logging in...\n",
		SSL_get_cipher_version(wr_ssl),
		SSL_get_cipher_name(wr_ssl),
		SSL_get_cipher_bits(wr_ssl, NULL));

	/* send initial login */
	wr_send_command("HELLO%s", WR_MESSAGE_SEPARATOR);
	
	/* hash the password */
	memset(wr_password_sha, 0, sizeof(wr_password_sha));
	
	if(strlen(wr_password) > 0) {
		SHA1_Init(&c);
		SHA1_Update(&c, (unsigned char *) wr_password, strlen(wr_password));
		SHA1_Final(sha, &c);
	
		/* map into hexademical characters */
		for(i = 0; i < SHA_DIGEST_LENGTH; i++) {
			wr_password_sha[i+i]	= hex[sha[i] >> 4];
			wr_password_sha[i+i+1]	= hex[sha[i] & 0x0F];
		}
			
		wr_password_sha[i+i] = '\0';
	}
	
	/* set connected */
	wr_connected = true;
}



void wr_close(void) {
	/* close SSL */
	if(wr_ssl) {
		if(SSL_shutdown(wr_ssl) == 0)
			SSL_shutdown(wr_ssl);
		
		SSL_free(wr_ssl);
		wr_ssl = NULL;
	}

	if(wr_ssl_ctx) {
		SSL_CTX_free(wr_ssl_ctx);
		wr_ssl_ctx = NULL;
	}

	/* close TCP */
	if(wr_socket != -1) {
		close(wr_socket);
		wr_socket = -1;
	}
	
	/* clean up */
	if(wr_connected) {
		wr_reply_uid = 0;

		wr_printf_prefix("Connection to %s closed\n",
			wr_host);
		
		wr_list_free(&wr_users);
		wr_list_free(&wr_files);
		wr_list_free(&wr_transfers);
		
		memset(wr_topic, 0, sizeof(wr_topic));
		
		wr_draw_header();
		wr_draw_transfers();
		wr_draw_divider();
	}
	
	wr_connected = false;
	wr_received = false;
}



void wr_close_transfer(wr_transfer_t *transfer) {
	wr_list_node_t	*node;
	
	/* close SSL */
	if(transfer->ssl) {
		if(SSL_shutdown(transfer->ssl) == 0)
			SSL_shutdown(transfer->ssl);
		
		SSL_free(transfer->ssl);
		transfer->ssl = NULL;
	}
	
	/* close TCP */
	if(transfer->sd != -1) {
		close(transfer->sd);
		transfer->sd = -1;
	}
	
	/* close file */
	if(transfer->fp) {
		fclose(transfer->fp);
		transfer->fp = NULL;
	}
	
	/* remove from list */
	node = wr_list_get_node(&wr_transfers, transfer);
	
	if(node)
		wr_list_delete(&wr_transfers, node);
}



#pragma mark -

int wr_parse_message(char *buffer) {
    char        *p, *msg = NULL, *arg = NULL;
    char		**argv;
    int			argc = 0, message, bytes;

	/* convert buffer */
	bytes = strlen(buffer);
	wr_received_bytes += bytes;
	wr_text_convert(wr_conv_from, buffer, &bytes);

	if(wr_debug)
		wr_printf_prefix(">>> %s\n", buffer);

	/* loop over the message */
	for(p = buffer; *buffer && !isspace(*buffer); buffer++)
		;

	/* get message */
	msg = (char *) malloc(buffer - p + 1);
	memcpy(msg, p, buffer - p);
	msg[buffer - p] = '\0';
	message = strtol(msg, NULL, 10);

    /* loop over argument string */
    for(p = ++buffer; *buffer; buffer++)
        ;

    /* get argument */
    arg = (char *) malloc(buffer - p + 1);
    memcpy(arg, p, buffer - p);
    arg[buffer - p] = '\0';

	/* get argument vector */
	wr_argv_create_wired(arg, &argc, &argv);

	/* dispatch message */
	switch(message) {
		case 200:
			wr_msg_200(argc, argv);
			break;

		case 201:
			wr_msg_201(argc, argv);
			break;

		case 300:
			wr_msg_300(argc, argv);
			break;

		case 301:
			wr_msg_301(argc, argv);
			break;

		case 302:
			wr_msg_302(argc, argv);
			break;

		case 303:
			wr_msg_303(argc, argv);
			break;

		case 304:
			wr_msg_304(argc, argv);
			break;

		case 305:
			wr_msg_305(argc, argv);
			break;

		case 308:
			wr_msg_308(argc, argv);
			break;

		case 309:
			wr_msg_309(argc, argv);
			break;

		case 310:
			wr_msg_310(argc, argv);
			break;

		case 311:
			wr_msg_311(argc, argv);
			break;
		
		case 320:
			wr_msg_320(argc, argv);
			break;
		
		case 321:
			wr_msg_321(argc, argv);
			break;

		case 322:
			wr_msg_322(argc, argv);
			break;
		
		case 340:
			break;
			
		case 341:
			wr_msg_341(argc, argv);
			break;
		
		case 400:
			wr_msg_400(argc, argv);
			break;
		
		case 401:
			wr_msg_401(argc, argv);
			break;
		
		case 402:
			wr_msg_402(argc, argv);
			break;
		
		case 410:
			wr_msg_410(argc, argv);
			break;
		
		case 411:
			wr_msg_411(argc, argv);
			break;

		case 500:
		case 501:
		case 502:
		case 503:
			wr_printf_prefix("%s: Command failed\n",
				wr_last_command);
			break;

		case 510:
			wr_printf_prefix("%s: Login failed, wrong login or password\n",
				wr_last_command);
			wr_close();
			break;

		case 511:
			wr_printf_prefix("%s: Login failed, host is banned\n",
				wr_last_command);
			wr_close();
			break;

		case 512:
			wr_printf_prefix("%s: Client not found\n",
				wr_last_command);
			break;

		case 513:
			wr_printf_prefix("%s: Account not found\n",
				wr_last_command);
			break;

		case 514:
			wr_printf_prefix("%s: Account already exists\n",
				wr_last_command);
			break;

		case 515:
			wr_printf_prefix("%s: User cannot be disconnected\n",
				wr_last_command);
			break;

		case 516:
			wr_printf_prefix("%s: Permission denied\n",
				wr_last_command);
			break;

		case 520:
			wr_printf_prefix("%s: File or directory not found\n",
				wr_last_command);
			break;

		case 521:
			wr_printf_prefix("%s: File or directory already exists\n",
				wr_last_command);
			break;

		case 522:
			wr_printf_prefix("%s: Checksum mismatch\n",
				wr_last_command);
			break;

		default:
			break;
	}

	/* clean up */
	if(msg)
		free(msg);

	if(arg)
		free(arg);
	
	if(argc > 0)
		wr_argv_free(argc, argv);
	
	return message;
}



void wr_send_command(char *fmt, ...) {
	char		*buffer;
	va_list		ap;
	int			bytes;

	va_start(ap, fmt);

	bytes = vasprintf(&buffer, fmt, ap);

	if(bytes == -1 || buffer == NULL)
		return;

	if(wr_debug)
		wr_printf_prefix("<<< %s\n", buffer);

	wr_text_convert(wr_conv_to, buffer, &bytes);

	if(wr_ssl) {
		SSL_write(wr_ssl, buffer, bytes);
		wr_transferred_bytes += bytes;
	}

	free(buffer);
	va_end(ap);
}



void wr_send_command_on_ssl(SSL *ssl, char *fmt, ...) {
	char		*buffer;
	va_list		ap;
	int			bytes;

	va_start(ap, fmt);

	bytes = vasprintf(&buffer, fmt, ap);

	if(bytes == -1 || buffer == NULL)
		return;

	if(ssl)
		SSL_write(ssl, buffer, bytes);

	free(buffer);
	va_end(ap);
}



#pragma mark -

void wr_msg_200(int argc, char *argv[]) {
	/* copy values */
	wr_protocol = strtod(argv[1], NULL);
	strlcpy(wr_server, argv[2], sizeof(wr_server));

	/* update divider */
	wr_draw_divider();

	if(!wr_received) {
		/* protocol warning */
		if(wr_protocol > (float) strtod(WR_PROTOCOL_VERSION, NULL)) {
			wr_printf_prefix("The server is using a newer protocol version than this client, protocol errors may occur\n");
		}

		/* continue login */
		wr_send_command("CLIENT %s%s", wr_version_string, WR_MESSAGE_SEPARATOR);
		wr_send_command("NICK %s%s", wr_nick, WR_MESSAGE_SEPARATOR);
		wr_send_command("ICON %u%s", wr_icon, WR_MESSAGE_SEPARATOR);
		wr_send_command("USER %s%s", wr_login, WR_MESSAGE_SEPARATOR);
		wr_send_command("PASS %s%s", wr_password_sha, WR_MESSAGE_SEPARATOR);
		wr_send_command("WHO %u%s", 1, WR_MESSAGE_SEPARATOR);

		/* only do this once */
		wr_received = true;
	}
}



void wr_msg_201(int argc, char *argv[]) {
	/* log */
	wr_printf_prefix("Logged in, welcome to %s\n",
		wr_server);
}



void wr_msg_300(int argc, char *argv[]) {
	wr_user_t	*user;

	/* get user */
	user = wr_get_user(strtoul(argv[1], NULL, 10));
	
	if(user) {
		/* ignore */
		if(wr_ignore_nick(user->nick))
			return;
	
		/* print */
		wr_print_say(user->nick, argv[2]);
	}
}



void wr_msg_301(int argc, char *argv[]) {
	wr_user_t	*user;

	/* get user */
	user = wr_get_user(strtoul(argv[1], NULL, 10));
	
	if(user) {
		/* ignore */
		if(wr_ignore_nick(user->nick))
			return;
	
		/* print */
		wr_print_me(user->nick, argv[2]);
	}
}



void wr_msg_302(int argc, char *argv[]) {
	wr_user_t	*user;

	/* create new user */
	user = (wr_user_t *) malloc(sizeof(wr_user_t));
	memset(user, 0, sizeof(wr_user_t));

	/* set values */
	user->uid = strtoul(argv[1], NULL, 10);
	user->idle = strtoul(argv[2], NULL, 10);
	user->admin = strtoul(argv[3], NULL, 10);
	strlcpy(user->nick, argv[5], sizeof(user->nick));
	strlcpy(user->login, argv[6], sizeof(user->login));
	strlcpy(user->ip, argv[7], sizeof(user->ip));

	/* add to list */
	wr_list_add(&wr_users, (void *) user);
	wr_draw_divider();

	/* print event */
	wr_printf_prefix("%s has joined\n", user->nick);
}



void wr_msg_303(int argc, char *argv[]) {
	wr_list_node_t	*node;
	wr_user_t			*user;

	/* get user */
	user = wr_get_user(strtoul(argv[1], NULL, 10));
	node = wr_list_get_node(&wr_users, user);

	if(user && node) {
		/* print event */
		wr_printf_prefix("%s has left\n", user->nick);
		
		/* delete user */
		wr_list_delete(&wr_users, node);
		wr_draw_divider();
	}
}



void wr_msg_304(int argc, char *argv[]) {
	wr_user_t	*user;

	/* get user */
	user = wr_get_user(strtoul(argv[0], NULL, 10));

	if(user) {
		/* print event */
		if(strcmp(user->nick, argv[4]) != 0) {
			wr_printf_prefix("%s is now known as %s\n",
				user->nick, argv[4]);
			
			strlcpy(user->nick, argv[4], sizeof(user->nick));
		}

		/* set values */
		user->idle = strtoul(argv[1], NULL, 10);
		user->admin = strtoul(argv[2], NULL, 10);
		user->icon = strtoul(argv[3], NULL, 10);
	}
}



void wr_msg_305(int argc, char *argv[]) {
	wr_user_t	*user;

	/* get user */
	user = wr_get_user(strtoul(argv[0], NULL, 10));
	
	if(user) {
		/* ignore */
		if(wr_ignore_nick(user->nick))
			return;
	
		/* print message */
		wr_printf_prefix("Private message from %s:\n", user->nick);
		wr_printf_block("%s", argv[1]);
		
		wr_reply_uid = user->uid;
	}
}



void wr_msg_308(int argc, char *argv[]) {
	struct tm	tm;
	char		*ap, *p, *q;
	char		name[MAXPATHLEN], ftime[26], transferred[16], size[16], speed[16];
	int			i, j, n;

	/* cut version string */
	if((p = strchr(argv[8], ')')) != NULL)
		*(p + 1) = '\0';

	/* print info */
	wr_printf_prefix("User info for %s:\n", argv[4]);
	
	if(wr_protocol >= 1.1)
		wr_printf_block("Status:      %s", argv[15]);
	
	wr_printf_block("Login:       %s", argv[5]);
	wr_printf_block("ID:          %s", argv[0]);
	wr_printf_block("Address:     %s", argv[6]);
	wr_printf_block("Host:        %s", argv[7]);
	wr_printf_block("Client:      %s", argv[8]);
	wr_printf_block("Cipher:      %s/%s bits", argv[9], argv[10]);

	/* print login time */
	wr_iso8601_to_time(argv[11], &tm);
	strftime(ftime, sizeof(ftime), "%a %T %Y", &tm);
	wr_printf_block("Login Time:  %s", ftime);

	/* print idle time */
	wr_iso8601_to_time(argv[12], &tm);
	strftime(ftime, sizeof(ftime), "%a %T %Y", &tm);
	wr_printf_block("Idle Time:   %s", ftime);
	
	/* print transfers */
	for(n = WR_TRANSFER_DOWNLOAD; n <= WR_TRANSFER_UPLOAD; n++) {
		if(n == WR_TRANSFER_DOWNLOAD)
			p = argv[13];
		else
			p = argv[14];
		
		if(strlen(p) > 0) {
			j = 0;
			
			while((ap = strsep(&p, WR_GROUP_SEPARATOR))) {
				q = ap;
				i = 0;
				
				while((ap = strsep(&q, WR_RECORD_SEPARATOR))) {
					switch(i++) {
						case 0:
							strlcpy(name, basename_np(ap), sizeof(name));
							break;
						
						case 1:
							wr_text_format_size(transferred, strtoull(ap, NULL, 10),
												sizeof(transferred));
							break;
						
						case 2:
							wr_text_format_size(size, strtoull(ap, NULL, 10),
												sizeof(size));
							break;
						
						case 3:
							wr_text_format_size(speed, strtoul(ap, NULL, 10),
												sizeof(speed));
							break;
					}
				}
					
				if(j++ == 0) {
					if(n == WR_TRANSFER_DOWNLOAD) {
						wr_printf_block("Downloads:   %s, %s of %s, %s/s",
							name, transferred, size, speed);
					} else {
						wr_printf_block("Uploads:     %s, %s of %s, %s/s",
							name, transferred, size, speed);
					}
				} else {
					wr_printf_block("             %s, %s of %s, %s/s",
						name, transferred, size, speed);
				}
			}
		}
	}
}



void wr_msg_309(int argc, char *argv[]) {
	wr_user_t	*user;

	/* get user */
	user = wr_get_user(strtoul(argv[0], NULL, 10));

	if(user) {
		/* ignore */
		if(wr_ignore_nick(user->nick))
			return;
	
		/* print message */
		wr_printf_prefix("Broadcast message from %s\n:", user->nick);
		wr_printf_block("%s", argv[1]);
	}
}



void wr_msg_310(int argc, char *argv[]) {
	wr_user_t	*user;

	/* create new user */
	user = (wr_user_t *) malloc(sizeof(wr_user_t));
	memset(user, 0, sizeof(wr_user_t));

	/* set values */
	user->uid = strtoul(argv[1], NULL, 10);
	user->idle = strtoul(argv[2], NULL, 10);
	user->admin = strtoul(argv[3], NULL, 10);
	strlcpy(user->nick, argv[5], sizeof(user->nick));
	strlcpy(user->login, argv[6], sizeof(user->login));
	strlcpy(user->ip, argv[7], sizeof(user->ip));

	/* add to list */
	wr_list_add(&wr_users, (void *) user);
}



void wr_msg_311(int argc, char *argv[]) {
	wr_draw_divider();
	wr_cmd_who(0, NULL);
}



void wr_msg_320(int argc, char *argv[]) {
	struct tm		tm;
	char			ftime[26];
	
	if(wr_news_count >= 0) {
		wr_news_count++;
	
		if(wr_news_count > wr_news_limit) {
			wr_printf_prefix("news: Displayed %d %s, use /news -ALL to see more\n",
				wr_news_limit,
				wr_news_limit == 1
					? "entry"
					: "entries");
			
			wr_news_count = -1;
		} else {
			wr_iso8601_to_time(argv[1], &tm);
			strftime(ftime, sizeof(ftime), "%b %e %T %Y", &tm);
		
			wr_printf_prefix("From %s (%s):\n", argv[0], ftime);
			wr_printf_block("%s", argv[2]);
		}
	}
}



void wr_msg_321(int argc, char *argv[]) {
	wr_news_count = 0;
}



void wr_msg_322(int argc, char *argv[]) {
	wr_printf_prefix("News from %s:\n", argv[0]);
	wr_printf_block("%s", argv[2]);
}



void wr_msg_341(int argc, char *argv[]) {
	strlcpy(wr_topic, argv[5], sizeof(wr_topic));
	wr_draw_header();
}



void wr_msg_400(int argc, char *argv[]) {
	wr_transfer_t		*transfer;
	struct sockaddr_in	addr;
	
	/* get transfer */
	transfer = wr_get_transfer(argv[0]);
	
	if(!transfer)
		return;

	/* set state */
	transfer->state = WR_TRANSFER_RUNNING;
	
	/* copy hash */
	strlcpy(transfer->hash, argv[2], sizeof(transfer->hash));
	
	/* open destination file */
	transfer->fp = fopen(transfer->local_path_partial, "a+");
	
	if(!transfer->fp) {
		wr_printf_prefix("Could not open %s: %s\n",
			transfer->local_path_partial, strerror(errno));
		wr_close_transfer(transfer);

		return;
	}
	
	/* seek to destination */
	fseeko(transfer->fp, transfer->offset, SEEK_SET);
	
	/* create new socket */
	transfer->sd = socket(AF_INET, SOCK_STREAM, 0);

	if(transfer->sd < 0) {
		wr_printf_prefix("Could not create a socket: %s\n",
			strerror(errno));
		wr_close_transfer(transfer);

		return;
	}
	
	/* set new port */
	addr = wr_addr;
	addr.sin_port = htons(wr_port + 1);

	/* connect TCP socket */
	if(connect(transfer->sd, (struct sockaddr *) &addr, sizeof(addr)) < 0) {
		wr_printf_prefix("Could not connect to %s: %s\n",
			inet_ntoa(wr_addr.sin_addr), strerror(errno));
		wr_close_transfer(transfer);

		return;
	}

	/* create SSL socket */
	transfer->ssl = SSL_new(wr_ssl_ctx);

	if(!transfer->ssl) {
		wr_printf_prefix("Could not create SSL socket: %s\n",
			ERR_reason_error_string(ERR_get_error()));
		wr_close_transfer(transfer);

		return;
	}

	if(SSL_set_fd(transfer->ssl, transfer->sd) != 1) {
		wr_printf_prefix("Could not set SSL file descriptor: %s\n",
			ERR_reason_error_string(ERR_get_error()));
		wr_close_transfer(transfer);

		return;
	}

	if(SSL_connect(transfer->ssl) != 1) {
		wr_printf_prefix("Could not connect to %s via SSL: %s\n",
			inet_ntoa(wr_addr.sin_addr), ERR_reason_error_string(ERR_get_error()));
		wr_close_transfer(transfer);

		return;
	}

	/* send identify */
	wr_send_command_on_ssl(transfer->ssl, "TRANSFER %s%s",
		transfer->hash,
		WR_MESSAGE_SEPARATOR);
	
	/* set time */
	transfer->start_time = time(NULL);
	
	/* print status */
	wr_printf_prefix("Starting transfer of \"%s\"\n",
		transfer->path);
}



void wr_msg_401(int argc, char *argv[]) {
	wr_transfer_t	*transfer;
	
	/* get transfer */
	transfer = wr_get_transfer(argv[0]);
	
	if(!transfer)
		return;
	
	/* set state */
	transfer->state = WR_TRANSFER_QUEUED;
	
	/* set number in queue */
	transfer->queue = strtoul(argv[1], NULL, 10);
}



void wr_msg_402(int argc, char *argv[]) {
	unsigned long long	size;
	wr_file_type_t		type;

	/* get fields */
	type = strtoul(argv[1], NULL, 10);
	size = strtoull(argv[2], NULL, 10);

	if(wr_stat_state == WR_STAT_FILE) {
		struct tm			tm;
		char				size_string[32];
		char				ftime[26];

		/* get size */
		if(type == WR_FILE_FILE)
			wr_text_format_size(size_string, size, sizeof(size_string));
		else
			wr_text_format_count(size_string, size, sizeof(size_string));
	
		/* print info */
		wr_printf_prefix("File info for %s:\n", basename_np(argv[0]));
		
		wr_printf("   Path:      %s\n", argv[0]);
	
		switch(type) {
			case WR_FILE_FILE:
				wr_printf("   Kind:      File\n");
				break;
	
			case WR_FILE_DIRECTORY:
				wr_printf("   Kind:      Folder\n");
				break;
	
			case WR_FILE_UPLOADS:
				wr_printf("   Kind:      Uploads Folder\n");
				break;
	
			case WR_FILE_DROPBOX:
				wr_printf("   Kind:      Drop Box Folder\n");
				break;
			
			default:
				break;
		}
	
		wr_printf("   Size:      %s\n", size_string);
	
		/* print created time */
		wr_iso8601_to_time(argv[3], &tm);
		strftime(ftime, sizeof(ftime), "%b %e %T %Y", &tm);
		wr_printf("   Created:   %s\n", ftime);
	
		/* print idle time */
		wr_iso8601_to_time(argv[4], &tm);
		strftime(ftime, sizeof(ftime), "%b %e %T %Y", &tm);
		wr_printf("   Modified:  %s\n", ftime);
	
		/* print checksum */
		if(type == WR_FILE_FILE)
			wr_printf("   Checksum:  %s\n", argv[5]);
		
		/* print comment */
		if(wr_protocol >= 1.1)
			wr_printf("   Comment:   %s\n", argv[6]);
	}
	else if(wr_stat_state == WR_STAT_TRANSFER) {
		wr_transfer_t	*transfer;
		wr_list_node_t	*node;

		/* get transfer */
		transfer = wr_get_transfer(argv[0]);
		node = wr_list_get_node(&wr_transfers, transfer);
		
		if(transfer) {
			/* check that it's a file */
			if(type != WR_FILE_FILE) {
				wr_printf_prefix("get: Cannot download directories\n");
				wr_list_delete(&wr_transfers, node);
			
				return;
			}
			
			/* set size */
			transfer->size = size;
			
			/* send get command */
			wr_send_command("GET %s%s%llu%s",
				transfer->path,
				WR_FIELD_SEPARATOR,
				transfer->offset,
				WR_MESSAGE_SEPARATOR);
		}
	}
}



void wr_msg_410(int argc, char *argv[]) {
	wr_file_t		*file;
	
	/* create new file */
	file = (wr_file_t *) malloc(sizeof(wr_file_t));
	memset(file, 0, sizeof(wr_file_t));

	/* set values */
	file->type = strtoul(argv[1], NULL, 10);
	file->size = strtoull(argv[2], NULL, 10);
	strlcpy(file->path, argv[0], sizeof(file->path));
	strlcpy(file->name, basename_np(argv[0]), sizeof(file->name));
	
	/* add to list */
	wr_list_add(&wr_files, file);
}



void wr_msg_411(int argc, char *argv[]) {
	wr_list_node_t	*node;
	wr_file_t		*file;
	unsigned int	length, max_length = 0;
	
	if(wr_ls_state == WR_LS_LISTING) {
		/* find max string length */
		WR_LIST_LOCK(wr_files);
		WR_LIST_FOREACH(wr_files, node, file) {
			length = strlen(file->name);
			max_length = length > max_length ? length : max_length;
		}
	
		/* print files */
		wr_printf_prefix("Listing of %s:\n", wr_files_ld);
		
		WR_LIST_FOREACH(wr_files, node, file)
			wr_print_file(node->data, max_length);
		WR_LIST_UNLOCK(wr_files);
	}
}
