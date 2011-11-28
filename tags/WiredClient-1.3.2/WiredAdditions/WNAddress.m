/* $Id$ */

/*
 *  Copyright (c) 2006-2007 Axel Andersson
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

#import <WiredNetworking/WNAddress.h>
#import <WiredNetworking/WNError.h>

@implementation WNAddress

+ (WNAddress *)addressWithString:(NSString *)address error:(WNError **)error {
	return [[[self alloc] initWithString:address error:error] autorelease];
}



+ (WNAddress *)addressWithNetService:(NSNetService *)netService error:(WNError **)error {
	return [[[self alloc] initWithNetService:netService error:error] autorelease];
}



- (id)initWithString:(NSString *)address error:(WNError **)error {
	wi_pool_t		*pool;

	self = [super init];
	
	pool = wi_pool_init(wi_pool_alloc());
	_address = wi_retain(wi_host_address(wi_host_with_string(wi_string_with_cstring([address UTF8String]))));
	wi_release(pool);
	
	if(!_address) {
		if(error) {
			*error = [WNError errorWithDomain:WNWiredNetworkingErrorDomain
										 code:WNAddressLookupFailed
									 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
										 [WNError errorWithDomain:WNLibWiredErrorDomain],	WNLibWiredErrorKey,
										 address,											WIArgumentErrorKey,
										 NULL]];
		}
		
		[self release];
		
		return NULL;
	}
	
	return self;
}



- (id)initWithNetService:(NSNetService *)netService error:(WNError **)error {
	NSArray		*addresses;
	NSData		*data;
	wi_pool_t	*pool;
	
	self = [super init];
	
	addresses = [netService addresses];
	
	if([addresses count] == 0) {
		if(error) {
			*error = [WNError errorWithDomain:WNWiredNetworkingErrorDomain
										 code:WNAddressNetServiceLookupFailed];
		}
		
		[self release];
		
		return NULL;
	}
	
	data = [addresses objectAtIndex:0];
	
	pool = wi_pool_init(wi_pool_alloc());
	_address = wi_address_init_with_sa(wi_address_alloc(), (struct sockaddr *) [data bytes]);
	wi_release(pool);
	
	return self;
}



- (void)dealloc {
	wi_pool_t	*pool;

	pool = wi_pool_init(wi_pool_alloc());
	wi_release(_address);
	wi_release(pool);
	
	[super dealloc];
}



#pragma mark -

- (void)setPort:(NSUInteger)port {
	wi_address_set_port(_address, port);
}



- (NSUInteger)port {
	return wi_address_port(_address);
}



#pragma mark -

- (WNAddressFamily)family {
	return (WNAddressFamily) wi_address_family(_address);
}



- (NSString *)string {
	NSString	*string;
	wi_pool_t	*pool;
	
	pool = wi_pool_init(wi_pool_alloc());
	string = [NSString stringWithUTF8String:wi_string_cstring(wi_address_string(_address))];
	wi_release(pool);
	
	return string;
}



- (NSString *)hostname {
	NSString	*string;
	wi_pool_t	*pool;
	
	pool = wi_pool_init(wi_pool_alloc());
	string = [NSString stringWithUTF8String:wi_string_cstring(wi_address_hostname(_address))];
	wi_release(pool);
	
	return string;
}

@end



@implementation WNAddress(WISocketAdditions)

- (wi_address_t *)address {
	return _address;
}

@end
