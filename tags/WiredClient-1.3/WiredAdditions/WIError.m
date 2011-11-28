/* $Id$ */

/*
 *  Copyright (c) 2006 Axel Andersson
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

#import <WiredAdditions/WIError.h>

@implementation WIError

+ (id)errorWithDomain:(NSString *)domain code:(int)code argument:(id)argument {
	return [self errorWithDomain:domain code:code userInfo:[NSDictionary dictionaryWithObject:argument forKey:WIArgumentErrorKey]];
}



+ (id)errorWithDomain:(NSString *)domain {
	return [self errorWithDomain:domain code:0 userInfo:NULL];
}



- (id)initWithDomain:(NSString *)domain code:(int)code userInfo:(NSDictionary *)userInfo {
	NSString		*description;
	wi_pool_t		*pool;
	
	if([domain isEqualToString:WILibWiredErrorDomain]) {
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
	if([[self domain] isEqualToString:WIWiredAdditionsErrorDomain]) {
		switch([self code]) {
			case WIAddressLookupFailed:
				return WILS(@"Address Lookup Failed", @"WIError: WIAddressLookupFailed title");
				break;
				
			case WIAddressNetServiceLookupFailed:
				return WILS(@"Address Lookup Failed", @"WIError: WIAddressNetServiceLookupFailed title");
				break;
				
			case WISocketConnectFailed:
				return WILS(@"Connect Failed", @"WIError: WISocketConnectFailed title");
				break;
				
			case WISocketWriteFailed:
				return WILS(@"Socket Write Failed", @"WIError: WISocketWriteFailed title");
				break;
				
			case WISocketReadFailed:
				return WILS(@"Socket Read Failed", @"WIError: WISocketReadFailed title");
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
	
	if([[self domain] isEqualToString:WIWiredAdditionsErrorDomain]) {
		error = [[[self userInfo] objectForKey:WILibWiredErrorKey] localizedFailureReason];
		argument = [[self userInfo] objectForKey:WIArgumentErrorKey];

		switch([self code]) {
			case WIAddressLookupFailed:
				return [NSSWF:WILS(@"Could not resolve the address \"%@\": %@.", @"WIError: WIAddressLookupFailed description (hostname, underlying error)"),
					argument, error];
				break;
			
			case WIAddressNetServiceLookupFailed:
				return WILS(@"Could not retrieve address for server via Bonjour.", @"WIError: WIAddressNetServiceLookupFailed description");
				break;
				
			case WISocketConnectFailed:
				return [NSSWF:WILS(@"Could not connect to %@: %@.", @"WIError: WISocketConnectFailed description (address, underlying error)"),
					argument, error];
				break;
				
			case WISocketWriteFailed:
				return [NSSWF:WILS(@"Could not write to %@: %@.", @"WIError: WISocketWriteFailed description (address, underlying error)"),
					argument, error];
				break;
				
			case WISocketReadFailed:
				return [NSSWF:WILS(@"Could not read from %@: %@.", @"WIError: WISocketReadFailed description (address, underlying error)"),
					argument, error];
				break;
				
			default:
				break;
		}
	}
	else if([[self domain] isEqualToString:WILibWiredErrorDomain]) {
		return [self localizedDescription];
	}

	return [[self superclass] instancesRespondToSelector:_cmd] ? [(id) super localizedFailureReason] : NULL;
}



#pragma mark -

- (NSAlert *)alert {
	return [NSAlert alertWithMessageText:[self localizedDescription]
						   defaultButton:WILS(@"OK", @"WIError: OK button")
						 alternateButton:NULL
							 otherButton:NULL
			   informativeTextWithFormat:@"%@", [self localizedFailureReason]];
}

@end
