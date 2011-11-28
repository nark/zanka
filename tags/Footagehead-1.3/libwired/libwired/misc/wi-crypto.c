/* $Id$ */

/*
 *  Copyright (c) 2007 Axel Andersson
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

#ifdef WI_CRYPTO

#include <wired/wi-data.h>
#include <wired/wi-crypto.h>
#include <wired/wi-private.h>
#include <wired/wi-string.h>
#include <wired/wi-system.h>

#include <openssl/pem.h>
#include <openssl/rand.h>
#include <openssl/rsa.h>
#include <openssl/x509.h>

struct _wi_rsa {
	wi_runtime_base_t					base;
	
	RSA									*rsa;
	wi_data_t							*public_key;
	wi_data_t							*private_key;
};

static void								_wi_rsa_dealloc(wi_runtime_instance_t *);
static wi_string_t *					_wi_rsa_description(wi_runtime_instance_t *);

static wi_runtime_id_t					_wi_rsa_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_rsa_runtime_class = {
	"wi_rsa_t",
	_wi_rsa_dealloc,
	NULL,
	NULL,
	_wi_rsa_description,
	NULL
};



struct _wi_cipher {
	wi_runtime_base_t					base;
	
	wi_cipher_type_t					type;
	const EVP_CIPHER					*cipher;
	EVP_CIPHER_CTX						encrypt_ctx;
	EVP_CIPHER_CTX						decrypt_ctx;
	wi_data_t							*key;
	wi_data_t							*iv;
};

static void								_wi_cipher_dealloc(wi_runtime_instance_t *);
static wi_string_t *					_wi_cipher_description(wi_runtime_instance_t *);

static const EVP_CIPHER *				_wi_cipher_cipher(wi_cipher_t *);
static void								_wi_cipher_configure_cipher(wi_cipher_t *);

static wi_runtime_id_t					_wi_cipher_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_cipher_runtime_class = {
	"wi_cipher_t",
	_wi_cipher_dealloc,
	NULL,
	NULL,
	_wi_cipher_description,
	NULL
};



void wi_crypto_register(void) {
	_wi_rsa_runtime_id = wi_runtime_register_class(&_wi_rsa_runtime_class);
	_wi_cipher_runtime_id = wi_runtime_register_class(&_wi_cipher_runtime_class);
}



void wi_crypto_initialize(void) {
}



#pragma mark -

wi_runtime_id_t wi_rsa_runtime_id(void) {
	return _wi_rsa_runtime_id;
}



#pragma mark -

wi_rsa_t * wi_rsa_alloc(void) {
	return wi_runtime_create_instance(_wi_rsa_runtime_id, sizeof(wi_rsa_t));
}



wi_rsa_t * wi_rsa_init_with_bits(wi_rsa_t *rsa, wi_uinteger_t size) {
	rsa->rsa = RSA_generate_key(size, RSA_F4, NULL, NULL);
	
	if(!rsa->rsa) {
		wi_release(rsa);
		
		return NULL;
	}
	
	return rsa;
}



wi_rsa_t * wi_rsa_init_with_pem_file(wi_rsa_t *rsa, wi_string_t *path) {
	FILE		*fp;
	
	fp = fopen(wi_string_cstring(path), "r");
	
	if(!fp) {
		wi_error_set_errno(errno);
		
		wi_release(rsa);
		
		return NULL;
	}
	
	rsa->rsa = PEM_read_RSAPrivateKey(fp, NULL, NULL, NULL);
	
	fclose(fp);
	
	if(!rsa->rsa) {
		wi_error_set_openssl_error();
		
		wi_release(rsa);
		
		return NULL;
	}
	
	return rsa;
}



wi_rsa_t * wi_rsa_init_with_private_key(wi_rsa_t *rsa, wi_data_t *data) {
	const unsigned char	*buffer;
	long				length;
	
	buffer = wi_data_bytes(data);
	length = wi_data_length(data);
	
	rsa->rsa = d2i_RSAPrivateKey(NULL, &buffer, length);

	if(!rsa->rsa) {
		wi_error_set_openssl_error();
		
		wi_release(rsa);
		
		return NULL;
	}
	
	rsa->private_key = wi_retain(data);
	
	return rsa;
}



wi_rsa_t * wi_rsa_init_with_public_key(wi_rsa_t *rsa, wi_data_t *data) {
	const unsigned char	*buffer;
	long				length;
	
	buffer = wi_data_bytes(data);
	length = wi_data_length(data);
	
	rsa->rsa = d2i_RSAPublicKey(NULL, (const unsigned char **) &buffer, length);

	if(!rsa->rsa) {
		wi_error_set_openssl_error();
		
		wi_release(rsa);
		
		return NULL;
	}
	
	rsa->public_key = wi_retain(data);
	
	return rsa;
}



static void _wi_rsa_dealloc(wi_runtime_instance_t *instance) {
	wi_rsa_t		*rsa = instance;
	
	RSA_free(rsa->rsa);
	
	wi_release(rsa->public_key);
	wi_release(rsa->private_key);
}



static wi_string_t * _wi_rsa_description(wi_runtime_instance_t *instance) {
	wi_rsa_t		*rsa = instance;
	
	return wi_string_with_format(WI_STR("<%@ %p>{key = %p, bits = %lu}"),
        wi_runtime_class_name(rsa),
		rsa,
		rsa->rsa,
		wi_rsa_bits(rsa));
}



#pragma mark -

wi_data_t * wi_rsa_public_key(wi_rsa_t *rsa) {
	unsigned char	*buffer;
	int				length;

	if(!rsa->public_key) {
		buffer = NULL;
		length = i2d_RSAPublicKey(rsa->rsa, &buffer);
		
		if(length <= 0) {
			wi_error_set_openssl_error();
			
			return NULL;
		}
		
		rsa->public_key = wi_data_init_with_bytes(wi_data_alloc(), buffer, length);

		OPENSSL_free(buffer);
	}
	
	return rsa->public_key;
}



wi_data_t * wi_rsa_private_key(wi_rsa_t *rsa) {
	unsigned char	*buffer;
	int				length;

	if(!rsa->private_key) {
		buffer = NULL;
		length = i2d_RSAPrivateKey(rsa->rsa, &buffer);
		
		if(length <= 0) {
			wi_error_set_openssl_error();
			
			return NULL;
		}
		
		rsa->private_key = wi_data_init_with_bytes(wi_data_alloc(), buffer, length);

		OPENSSL_free(buffer);
	}
	
	return rsa->private_key;
}



wi_uinteger_t wi_rsa_bits(wi_rsa_t *rsa) {
	return RSA_size(rsa->rsa) * 8;
}



#pragma mark -

wi_data_t * wi_rsa_encrypt(wi_rsa_t *rsa, wi_data_t *decrypted_data) {
	const void		*decrypted_buffer;
	void			*encrypted_buffer;
	wi_uinteger_t	decrypted_length, encrypted_length;
	
	decrypted_buffer = wi_data_bytes(decrypted_data);
	decrypted_length = wi_data_length(decrypted_data);
	
	if(!wi_rsa_encrypt_bytes(rsa, decrypted_buffer, decrypted_length, &encrypted_buffer, &encrypted_length))
		return NULL;
	
	return wi_data_with_bytes_no_copy(encrypted_buffer, encrypted_length, true);
}



wi_boolean_t wi_rsa_encrypt_bytes(wi_rsa_t *rsa, const void *decrypted_buffer, wi_uinteger_t decrypted_length, void **out_buffer, wi_uinteger_t *out_length) {
	void		*encrypted_buffer;
	int32_t		encrypted_length;

	encrypted_buffer = wi_malloc(RSA_size(rsa->rsa));
	encrypted_length = RSA_public_encrypt(decrypted_length, decrypted_buffer, encrypted_buffer, rsa->rsa, RSA_PKCS1_PADDING);
	
	if(encrypted_length == -1) {
		wi_error_set_openssl_error();
		
		wi_free(encrypted_buffer);
		
		return false;
	}
	
	*out_buffer = encrypted_buffer;
	*out_length = encrypted_length;

	return true;
}



wi_data_t * wi_rsa_decrypt(wi_rsa_t *rsa, wi_data_t *encrypted_data) {
	const void		*encrypted_buffer;
	void			*decrypted_buffer;
	wi_uinteger_t	encrypted_length, decrypted_length;
	
	encrypted_buffer = wi_data_bytes(encrypted_data);
	encrypted_length = wi_data_length(encrypted_data);
	
	if(!wi_rsa_decrypt_bytes(rsa, encrypted_buffer, encrypted_length, &decrypted_buffer, &decrypted_length))
		return NULL;
	
	return wi_data_with_bytes_no_copy(decrypted_buffer, decrypted_length, true);
}



wi_boolean_t wi_rsa_decrypt_bytes(wi_rsa_t *rsa, const void *encrypted_buffer, wi_uinteger_t encrypted_length, void **out_buffer, wi_uinteger_t *out_length) {
	void		*decrypted_buffer;
	int32_t		decrypted_length;
	
	decrypted_buffer = wi_malloc(RSA_size(rsa->rsa));
	decrypted_length = RSA_private_decrypt(encrypted_length, encrypted_buffer, decrypted_buffer, rsa->rsa, RSA_PKCS1_PADDING);

	if(decrypted_length == -1) {
		wi_error_set_openssl_error();
		
		wi_free(decrypted_buffer);

		return false;
	}
	
	*out_buffer = decrypted_buffer;
	*out_length = decrypted_length;

	return true;
}



#pragma mark -

wi_runtime_id_t wi_cipher_runtime_id(void) {
	return _wi_cipher_runtime_id;
}



#pragma mark -

wi_cipher_t * wi_cipher_alloc(void) {
	return wi_runtime_create_instance(_wi_cipher_runtime_id, sizeof(wi_cipher_t));
}



wi_cipher_t * wi_cipher_init_with_key(wi_cipher_t *cipher, wi_cipher_type_t type, wi_data_t *key, wi_data_t *iv) {
	unsigned char		*key_buffer, *iv_buffer;
	
	cipher->type	= type;
	cipher->cipher	= _wi_cipher_cipher(cipher);
	
	key_buffer		= (unsigned char *) wi_data_bytes(key);
	iv_buffer		= iv ? (unsigned char *) wi_data_bytes(iv) : NULL;
	
	if(EVP_EncryptInit(&cipher->encrypt_ctx, cipher->cipher, NULL, NULL) != 1) {
		wi_error_set_openssl_error();
		
		wi_release(cipher);
		
		return NULL;
	}
	
	if(EVP_DecryptInit(&cipher->decrypt_ctx, cipher->cipher, NULL, NULL) != 1) {
		wi_error_set_openssl_error();
		
		wi_release(cipher);
		
		return NULL;
	}
	
	_wi_cipher_configure_cipher(cipher);

	if(EVP_EncryptInit(&cipher->encrypt_ctx, cipher->cipher, key_buffer, iv_buffer) != 1) {
		wi_error_set_openssl_error();
		
		wi_release(cipher);
		
		return NULL;
	}

	if(EVP_DecryptInit(&cipher->decrypt_ctx, cipher->cipher, key_buffer, iv_buffer) != 1) {
		wi_error_set_openssl_error();
		
		wi_release(cipher);
		
		return NULL;
	}
	
	cipher->key		= wi_retain(key);
	cipher->iv		= wi_retain(iv);

	return cipher;
}



wi_cipher_t * wi_cipher_init_with_random_key(wi_cipher_t *cipher, wi_cipher_type_t type) {
	unsigned char		*key_buffer, *iv_buffer;
	int					key_length, iv_length;
	
	cipher->type	= type;
	cipher->cipher	= _wi_cipher_cipher(cipher);
	
	key_length		= EVP_MAX_KEY_LENGTH;
	key_buffer		= wi_malloc(key_length);
	iv_length		= EVP_CIPHER_iv_length(cipher->cipher);
	iv_buffer		= (iv_length > 0) ? wi_malloc(iv_length) : NULL;
	
	if(RAND_bytes(key_buffer, key_length) <= 0) {
		wi_error_set_openssl_error();
		
		wi_release(cipher);
		
		return NULL;
	}
	
	if(iv_buffer) {
		if(RAND_bytes(iv_buffer, iv_length) <= 0) {
			wi_error_set_openssl_error();
			
			wi_release(cipher);
			
			return NULL;
		}
	}

	if(EVP_EncryptInit_ex(&cipher->encrypt_ctx, cipher->cipher, NULL, NULL, NULL) != 1) {
		wi_error_set_openssl_error();
		
		wi_release(cipher);
		
		return NULL;
	}
	
	if(EVP_DecryptInit_ex(&cipher->decrypt_ctx, cipher->cipher, NULL, NULL, NULL) != 1) {
		wi_error_set_openssl_error();
		
		wi_release(cipher);
		
		return NULL;
	}
	
	_wi_cipher_configure_cipher(cipher);

	if(EVP_EncryptInit_ex(&cipher->encrypt_ctx, cipher->cipher, NULL, key_buffer, iv_buffer) != 1) {
		wi_error_set_openssl_error();
		
		wi_release(cipher);
		
		return NULL;
	}

	if(EVP_DecryptInit_ex(&cipher->decrypt_ctx, cipher->cipher, NULL, key_buffer, iv_buffer) != 1) {
		wi_error_set_openssl_error();
		
		wi_release(cipher);
		
		return NULL;
	}
	
	cipher->key		= wi_data_init_with_bytes_no_copy(wi_data_alloc(), key_buffer, key_length, true);
	cipher->iv		= (iv_length > 0) ? wi_data_init_with_bytes_no_copy(wi_data_alloc(), iv_buffer, iv_length, true) : NULL;

	return cipher;
}



static void _wi_cipher_dealloc(wi_runtime_instance_t *instance) {
	wi_cipher_t		*cipher = instance;
	
	EVP_CIPHER_CTX_cleanup(&cipher->encrypt_ctx);
	EVP_CIPHER_CTX_cleanup(&cipher->decrypt_ctx);
	
	wi_release(cipher->key);
	wi_release(cipher->iv);
}



static wi_string_t * _wi_cipher_description(wi_runtime_instance_t *instance) {
	wi_cipher_t		*cipher = instance;
	
	return wi_string_with_format(WI_STR("<%@ %p>{name = %@, bits = %lu, iv = %@, key = %@}"),
        wi_runtime_class_name(cipher),
		cipher,
		wi_cipher_name(cipher),
		wi_cipher_bits(cipher),
		wi_cipher_iv(cipher),
		wi_cipher_key(cipher));
}



#pragma mark -

static const EVP_CIPHER * _wi_cipher_cipher(wi_cipher_t *cipher) {
	switch(cipher->type) {
		case WI_CIPHER_AES128:		return EVP_aes_128_cbc();
		case WI_CIPHER_AES192:		return EVP_aes_192_cbc();
		case WI_CIPHER_AES256:		return EVP_aes_256_cbc();
		case WI_CIPHER_BF128:		return EVP_bf_cbc();
		case WI_CIPHER_3DES192:		return EVP_des_ede3_cbc();
	}
	
	return NULL;
}



static void _wi_cipher_configure_cipher(wi_cipher_t *cipher) {
	if(cipher->type == WI_CIPHER_BF128) {
		EVP_CIPHER_CTX_set_key_length(&cipher->encrypt_ctx, 16);
		EVP_CIPHER_CTX_set_key_length(&cipher->decrypt_ctx, 16);
	}
}



#pragma mark -

wi_data_t * wi_cipher_key(wi_cipher_t *cipher) {
	return cipher->key;
}



wi_data_t * wi_cipher_iv(wi_cipher_t *cipher) {
	return cipher->iv;
}



wi_cipher_type_t wi_cipher_type(wi_cipher_t *cipher) {
	return cipher->type;
}



wi_string_t * wi_cipher_name(wi_cipher_t *cipher) {
	switch(cipher->type) {
		case WI_CIPHER_AES128:
		case WI_CIPHER_AES192:
		case WI_CIPHER_AES256:
			return WI_STR("AES");

		case WI_CIPHER_BF128:
			return WI_STR("Blowfish");
		
		case WI_CIPHER_3DES192:
			return WI_STR("Triple DES");
	}
	
	return NULL;
}



wi_uinteger_t wi_cipher_bits(wi_cipher_t *cipher) {
	return EVP_CIPHER_key_length(&cipher->encrypt_ctx) * 8;
}



#pragma mark -

wi_data_t * wi_cipher_encrypt(wi_cipher_t *cipher, wi_data_t *decrypted_data) {
	const void		*decrypted_buffer;
	void			*encrypted_buffer;
	wi_uinteger_t	decrypted_length, encrypted_length;
	
	decrypted_buffer = wi_data_bytes(decrypted_data);
	decrypted_length = wi_data_length(decrypted_data);
	
	if(!wi_cipher_encrypt_bytes(cipher, decrypted_buffer, decrypted_length, &encrypted_buffer, &encrypted_length))
		return NULL;
	
	return wi_data_with_bytes_no_copy(encrypted_buffer, encrypted_length, true);
}



wi_boolean_t wi_cipher_encrypt_bytes(wi_cipher_t *cipher, const void *decrypted_buffer, wi_uinteger_t decrypted_length, void **out_buffer, wi_uinteger_t *out_length) {
	void		*encrypted_buffer;
	int			encrypted_length, padded_length;
	
	encrypted_buffer = wi_malloc(decrypted_length + EVP_CIPHER_block_size(cipher->cipher));

	if(EVP_EncryptUpdate(&cipher->encrypt_ctx, encrypted_buffer, &encrypted_length, decrypted_buffer, decrypted_length) != 1) {
		wi_error_set_openssl_error();
		
		wi_free(encrypted_buffer);
		
		return false;
	}
	
	if(EVP_EncryptFinal_ex(&cipher->encrypt_ctx, encrypted_buffer + encrypted_length, &padded_length) != 1) {
		wi_error_set_openssl_error();
		
		wi_free(encrypted_buffer);
		
		return false;
	}

	if(EVP_EncryptInit_ex(&cipher->encrypt_ctx, NULL, NULL, NULL, NULL) != 1) {
		wi_error_set_openssl_error();
		
		wi_free(encrypted_buffer);
		
		return false;
	}

	*out_buffer = encrypted_buffer;
	*out_length = encrypted_length + padded_length;
	
	return true;
}



wi_data_t * wi_cipher_decrypt(wi_cipher_t *cipher, wi_data_t *encrypted_data) {
	const void		*encrypted_buffer;
	void			*decrypted_buffer;
	wi_uinteger_t	encrypted_length, decrypted_length;
	
	encrypted_buffer = wi_data_bytes(encrypted_data);
	encrypted_length = wi_data_length(encrypted_data);
	
	if(!wi_cipher_decrypt_bytes(cipher, encrypted_buffer, encrypted_length, &decrypted_buffer, &decrypted_length))
		return NULL;
	
	return wi_data_with_bytes_no_copy(decrypted_buffer, decrypted_length, true);
}



wi_boolean_t wi_cipher_decrypt_bytes(wi_cipher_t *cipher, const void *encrypted_buffer, wi_uinteger_t encrypted_length, void **out_buffer, wi_uinteger_t *out_length) {
	void		*decrypted_buffer;
	int			decrypted_length, padded_length;
	
	decrypted_buffer = wi_malloc(encrypted_length + EVP_CIPHER_block_size(cipher->cipher));
	
	if(EVP_DecryptUpdate(&cipher->decrypt_ctx, decrypted_buffer, &decrypted_length, encrypted_buffer, encrypted_length) != 1) {
		wi_error_set_openssl_error();
		
		wi_free(decrypted_buffer);
		
		return false;
	}
	
	if(EVP_DecryptFinal_ex(&cipher->decrypt_ctx, decrypted_buffer + decrypted_length, &padded_length) != 1) {
		wi_error_set_openssl_error();
		
		wi_free(decrypted_buffer);
		
		return false;
	}
	
	if(EVP_DecryptInit_ex(&cipher->decrypt_ctx, NULL, NULL, NULL, NULL) != 1) {
		wi_error_set_openssl_error();
		
		wi_free(decrypted_buffer);
		
		return false;
	}
	
	*out_buffer = decrypted_buffer;
	*out_length = decrypted_length + padded_length;
	
	return true;
}

#endif
