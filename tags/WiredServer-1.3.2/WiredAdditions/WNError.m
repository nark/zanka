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

#import <WiredNetworking/WNError.h>

@implementation WNError

+ (id)errorWithDomain:(NSString *)domain code:(NSInteger)code argument:(id)argument {
	return [self errorWithDomain:domain code:code userInfo:[NSDictionary dictionaryWithObject:argument forKey:WIArgumentErrorKey]];
}



+ (id)errorWithDomain:(NSString *)domain {
	return [self errorWithDomain:domain code:0 userInfo:NULL];
}



- (id)initWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(NSDictionary *)userInfo {
	NSString		*description;
	wi_pool_t		*pool;
	
	if([domain isEqualToString:WNLibWiredErrorDomain]) {
		pool = wi_pool_init(wi_pool_alloc());
		
		code		= wi_error_code();
		description	= [NSString stringWithUTF8String:wi_string_cstring(wi_error_string())];
		userInfo	= userInfo ? [[userInfo mutableCopy] autorelease] : [NSMutableDictionary dictionary];
		[(NSMutableDictionary *) userInfo setObject:description forKey:NSLocalizedDescriptionKey];

		wi_release(pool);
	}

	return [super initWithDomain:domain code:code userInfo:userInfo];
}



- (id)initWithDomain:(NSString *)domain {
	return [self initWithDomain:domain code:0 userInfo:NULL];
}



#pragma mark -

- (NSString *)localizedDescription {
	if([[self domain] isEqualToString:WNWiredNetworkingErrorDomain]) {
		switch([self code]) {
			case WNAddressLookupFailed:
				return WNLS(@"Address Lookup Failed", @"WNError: WNAddressLookupFailed title");
				break;
				
			case WNAddressNetServiceLookupFailed:
				return WNLS(@"Address Lookup Failed", @"WNError: WNAddressNetServiceLookupFailed title");
				break;
				
			case WNSocketConnectFailed:
				return WNLS(@"Connect Failed", @"WNError: WNSocketConnectFailed title");
				break;
				
			case WNSocketWriteFailed:
				return WNLS(@"Socket Write Failed", @"WNError: WNSocketWriteFailed title");
				break;
				
			case WNSocketReadFailed:
				return WNLS(@"Socket Read Failed", @"WNError: WNSocketReadFailed title");
				break;
				
			default:
				break;
		}
	}
	
	return [super localizedDescription];
}



- (NSString *)localizedFailureReason {
	NSString		*error;
	id				argument;
	
	if([[self domain] isEqualToString:WNWiredNetworkingErrorDomain]) {
		error = [[[self userInfo] objectForKey:WNLibWiredErrorKey] localizedFailureReason];
		argument = [[self userInfo] objectForKey:WIArgumentErrorKey];

		switch([self code]) {
			case WNAddressLookupFailed:
				return [NSSWF:WNLS(@"Could not resolve the address \"%@\": %@.", @"WNError: WNAddressLookupFailed description (hostname, underlying error)"),
					argument, error];
				break;
			
			case WNAddressNetServiceLookupFailed:
				return WNLS(@"Could not retrieve address for server via Bonjour.", @"WNError: WNAddressNetServiceLookupFailed description");
				break;
				
			case WNSocketConnectFailed:
				return [NSSWF:WNLS(@"Could not connect to %@: %@.", @"WNError: WNSocketConnectFailed description (address, underlying error)"),
					argument, error];
				break;
				
			case WNSocketWriteFailed:
				return [NSSWF:WNLS(@"Could not write to %@: %@.", @"WNError: WNSocketWriteFailed description (address, underlying error)"),
					argument, error];
				break;
				
			case WNSocketReadFailed:
				return [NSSWF:WNLS(@"Could not read from %@: %@.", @"WNError: WNSocketReadFailed description (address, underlying error)"),
					argument, error];
				break;
				
			default:
				break;
		}
	}
	else if([[self domain] isEqualToString:WNLibWiredErrorDomain]) {
		return [self localizedDescription];
	}

	return [super localizedFailureReason];
}

@end
