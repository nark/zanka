# config.m4

AC_DEFUN([_WI_MSG_LIB_ERROR], [
	AC_MSG_ERROR([could not locate $1

If you installed $1 into a non-standard directory, please run:

    env CPPFLAGS="-I/path/to/include" LDFLAGS="-L/path/to/lib" ./configure])
])


AC_DEFUN([WI_INCLUDE_WARNING_FLAG], [
	OLD_CFLAGS="$CFLAGS"
	CFLAGS="$CFLAGS $1"

	AC_COMPILE_IFELSE([
		int main(void) {
			return 0;
		}
	], [
		WARNFLAGS="$WARNFLAGS $1"
	], [
		CFLAGS="$OLD_CFLAGS"
	])
])


AC_DEFUN([WI_INCLUDE_EXTRA_INCLUDE_PATHS], [
	if test -d /usr/local/include; then
		CPPFLAGS="$CPPFLAGS -I/usr/local/include"
	fi
])


AC_DEFUN([WI_INCLUDE_EXTRA_LIBRARY_PATHS], [
	if test -d /usr/local/lib; then
		LDFLAGS="$LDFLAGS -L/usr/local/lib"
	fi
])


AC_DEFUN([WI_INCLUDE_EXTRA_SSL_PATHS], [
	if test "$_wi_ssl_paths_added" != yes ; then
		if test -d /usr/local/ssl/include; then
			CPPFLAGS="$CPPFLAGS -I/usr/local/ssl/include"
		fi

		if test -d /usr/kerberos/include; then
			CPPFLAGS="$CPPFLAGS -I/usr/kerberos/include"
		fi

		if test -d /usr/local/ssl/lib; then
			LDFLAGS="$LDFLAGS -L/usr/local/ssl/lib"
		fi
	fi

	_wi_ssl_paths_added=yes
])


AC_DEFUN([WI_CHECK_LIBWIRED], [
	if ! test -f "$srcdir/libwired/configure"; then
		AC_MSG_ERROR([could not locate libwired

You need to download a version of libwired and place it in the same directory as this configure script])
fi
])


AC_DEFUN([WI_INCLUDE_LIBWIRED_LIBRARIES], [
	WI_INCLUDE_MATH_LIBRARY
	WI_INCLUDE_SOCKET_LIBRARY
	WI_INCLUDE_NSL_LIBRARY
	WI_INCLUDE_RESOLV_LIBRARY
	WI_INCLUDE_CORESERVICES_FRAMEWORK
])


AC_DEFUN([WI_INCLUDE_OPENSSL_LIBRARIES], [
	WI_INCLUDE_CRYPTO_LIBRARY
	WI_INCLUDE_SSL_LIBRARY
])



AC_DEFUN([WI_INCLUDE_P7_LIBRARIES], [
	WI_INCLUDE_CRYPTO_LIBRARY
	WI_INCLUDE_LIBXML2_LIBRARY
	WI_INCLUDE_ZLIB_LIBRARY
])


AC_DEFUN([WI_INCLUDE_MATH_LIBRARY], [
	AC_CHECK_FUNC([pow], [], [
		AC_CHECK_LIB([m], [sqrt], [
			LIBS="$LIBS -lm"
		])
	])
])


AC_DEFUN([WI_INCLUDE_SOCKET_LIBRARY], [
	AC_CHECK_FUNC(setsockopt, [], [
		AC_CHECK_LIB([socket], [setsockopt], [
			LIBS="$LIBS -lsocket"
		])
	])
])


AC_DEFUN([WI_INCLUDE_NSL_LIBRARY], [
	AC_CHECK_FUNC([gethostent], [], [
		AC_CHECK_LIB([nsl], [gethostent], [
			LIBS="$LIBS -lnsl"
		])
	])
])


AC_DEFUN([WI_INCLUDE_RESOLV_LIBRARY], [
	AC_CHECK_FUNC([inet_aton], [], [
		AC_CHECK_LIB([resolv], [inet_aton], [
			LIBS="$LIBS -lresolv"
		])
	])
])


AC_DEFUN([WI_INCLUDE_CRYPTO_LIBRARY], [
	WI_INCLUDE_EXTRA_SSL_PATHS

	AC_CHECK_HEADERS([openssl/sha.h], [
		AC_CHECK_LIB([crypto], [MD5_Init], [
			LIBS="$LIBS -lcrypto"
		], [
			_WI_MSG_LIB_ERROR([OpenSSL])
		])
	], [
		_WI_MSG_LIB_ERROR([OpenSSL])
	])
])


AC_DEFUN([WI_INCLUDE_SSL_LIBRARY], [
	WI_INCLUDE_EXTRA_SSL_PATHS

	AC_CHECK_HEADERS([openssl/ssl.h], [
		AC_CHECK_LIB([ssl], [SSL_library_init], [
			LIBS="$LIBS -lssl"
		], [
			_WI_MSG_LIB_ERROR([OpenSSL])
		])
	], [
		_WI_MSG_LIB_ERROR([OpenSSL])
	])
])


AC_DEFUN([WI_INCLUDE_CORESERVICES_FRAMEWORK], [
	AC_CHECK_HEADERS([CoreServices/CoreServices.h], [
		LIBS="$LIBS -framework CoreServices -framework Carbon"
	])
])


AC_DEFUN([_WI_PTHREAD_TEST_INCLUDES], [
	#include <pthread.h>
	#include <errno.h>

	void * thread(void *arg) {
		return NULL;
	}
])


AC_DEFUN([_WI_PTHREAD_TEST_FUNCTION], [
	pthread_t tid;

	if(pthread_create(&tid, 0, thread, NULL) < 0)
		return errno;

	return 0;
])


AC_DEFUN([_WI_PTHREAD_TEST_PROGRAM], [
	_WI_PTHREAD_TEST_INCLUDES

	int main(void) {
		_WI_PTHREAD_TEST_FUNCTION
	}
])


AC_DEFUN([_WI_PTHREAD_TRY], [
	if test "$_wi_pthreads_found" != yes ; then
		OLD_LIBS="$LIBS"
		LIBS="$1 $LIBS"

		AC_RUN_IFELSE([AC_LANG_SOURCE([_WI_PTHREAD_TEST_PROGRAM])], [
			_wi_pthreads_test=yes
		], [
			_wi_pthreads_test=no
		], [
			AC_LINK_IFELSE([AC_LANG_PROGRAM([_WI_PTHREAD_TEST_INCLUDES], [_WI_PTHREAD_TEST_FUNCTION])], [
				_wi_pthreads_test=yes
			], [
				_wi_pthreads_test=no
			])
		])

		LIBS="$OLD_LIBS"

		if test "$_wi_pthreads_test" = yes ; then
			_wi_pthreads_found=yes
			_wi_pthreads_libs="$1"
		fi
	fi
])


AC_DEFUN([WI_INCLUDE_PTHREADS], [
	case $host in
		*-solaris*)
			AC_DEFINE([_POSIX_PTHREAD_SEMANTICS], [], [Define on Solaris to get sigwait() to work using pthreads semantics.])
			;;
	esac
	
	AC_CHECK_HEADERS([pthread.h], [
		AC_MSG_CHECKING([for pthreads])

		_WI_PTHREAD_TRY([])
		_WI_PTHREAD_TRY([-pthread])
		_WI_PTHREAD_TRY([-lpthread])

		if test "$_wi_pthreads_found" = yes ; then
			AC_MSG_RESULT([yes])
			LIBS="$_wi_pthreads_libs $LIBS"
		else
			AC_MSG_RESULT([no])
			AC_MSG_ERROR([could not locate pthreads])
		fi
	], [
		AC_MSG_ERROR([could not locate pthreads])
	])
])


AC_DEFUN([WI_INCLUDE_ICONV_LIBRARY], [
	AC_CHECK_HEADERS([iconv.h], [
		AC_CHECK_LIB([iconv], [iconv], [
			LIBS="$LIBS -liconv"
		], [
			AC_CHECK_LIB([iconv], [libiconv], [
				LIBS="$LIBS -liconv"
			], [
				AC_CHECK_FUNC([iconv], [], [
					_WI_MSG_LIB_ERROR([iconv])
				])
			])
		])
	], [
		_WI_MSG_LIB_ERROR([iconv])
	])

	AC_MSG_CHECKING([if iconv understands Unicode])
	AC_RUN_IFELSE([
		#include <iconv.h>
		int main(void) {
			iconv_t conv = iconv_open("UTF-8", "UTF-16");
			if(conv == (iconv_t) -1)
				return 1;
			return 0;
		}
	], [
		AC_MSG_RESULT([yes])
	], [
		AC_MSG_ERROR([no])
	])
])


AC_DEFUN([WI_INCLUDE_TERMCAP_LIBRARY], [
	AC_CHECK_HEADERS([term.h], [
		AC_CHECK_FUNC([tgoto], [], [
			AC_CHECK_LIB([termcap], [tgoto], [
				LIBS="$LIBS -ltermcap"
			], [
				AC_CHECK_LIB([ncurses], [tgoto], [
					LIBS="$LIBS -lncurses"
				], [
					AC_CHECK_LIB([curses], [tgoto], [
						LIBS="$LIBS -lcurses"
					])
				])
			])
		])
	])
])


AC_DEFUN([WI_INCLUDE_READLINE_LIBRARY], [
	AC_CHECK_HEADERS([readline/readline.h], [
		AC_CHECK_LIB([readline], [rl_initialize], [
			LIBS="$LIBS -lreadline"

			AC_MSG_CHECKING([for GNU readline])
			AC_RUN_IFELSE([
				#include <stdio.h>
				#include <readline/readline.h>
				int main(void) {
					return rl_gnu_readline_p ? 0 : 1;
				}
			], [
				AC_MSG_RESULT([yes])
			], [
				AC_MSG_RESULT([no])
				_WI_MSG_LIB_ERROR([GNU readline])
			])

			AC_MSG_CHECKING([for rl_completion_matches])
			AC_RUN_IFELSE([
				#include <stdio.h>
				#include <readline/readline.h>
				char * generator(const char *, int);
				char * generator(const char *text, int state) {
					return NULL;
				}
				int main(void) {
					(void) rl_completion_matches("", generator);

					return 0;
				}
			], [
				AC_DEFINE([HAVE_RL_COMPLETION_MATCHES], [1], [Define to 1 if you have the `rl_completion_matches' function, and to 0 otherwise.])
				AC_MSG_RESULT([yes])

			], [
				AC_MSG_RESULT([no])
			])

			AC_CHECK_DECLS([rl_completion_display_matches_hook], [], [], [
				#include <stdio.h>
				#include <readline/readline.h>
			])
		], [
			_WI_MSG_LIB_ERROR([readline])
		])
	], [
		_WI_MSG_LIB_ERROR([readline])
	])
])


AC_DEFUN([WI_INCLUDE_LIBXML2_LIBRARY], [
	if test -d /usr/include/libxml2; then
		CPPFLAGS="$CPPFLAGS -I/usr/include/libxml2"
	fi

	if test -d /usr/local/include/libxml2; then
		CPPFLAGS="$CPPFLAGS -I/usr/local/include/libxml2"
	fi

	AC_CHECK_HEADERS([libxml/parser.h], [
		AC_CHECK_LIB([xml2], [xmlParseFile], [
			LIBS="$LIBS -lxml2"
		], [
			_WI_MSG_LIB_ERROR([libxml2])
		])
	], [
		_WI_MSG_LIB_ERROR([libxml2])
	])
])


AC_DEFUN([WI_INCLUDE_ZLIB_LIBRARY], [
	AC_CHECK_HEADERS([zlib.h], [
		AC_CHECK_LIB([z], [deflate], [
			LIBS="$LIBS -lz"
		], [
			_WI_MSG_LIB_ERROR([zlib])
		])
	], [
		_WI_MSG_LIB_ERROR([zlib])
	])
])
