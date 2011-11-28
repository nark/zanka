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

#import "NSNumberAdditions.h"

@implementation NSNumber(WCBandwidthFormatting)

- (NSString *)bandwidth {
	unsigned int	speed;
	
	speed = [self unsignedIntValue];
	
	if(speed > 0) {
		if(speed <= 3600)
			return NSLocalizedString(@"28.8k Modem", "Bandwidth");
		else if(speed <= 4200)
			return NSLocalizedString(@"33.6k Modem", "Bandwidth");
		else if(speed <= 7000)
			return NSLocalizedString(@"56k Modem", "Bandwidth");
		else if(speed <= 8000)
			return NSLocalizedString(@"64k ISDN", "Bandwidth");
		else if(speed <= 16000)
			return NSLocalizedString(@"128k ISDN/DSL", "Bandwidth");
		else if(speed <= 32000)
			return NSLocalizedString(@"256k DSL/Cable", "Bandwidth");
		else if(speed <= 48000)
			return NSLocalizedString(@"384k DSL/Cable", "Bandwidth");
		else if(speed <= 64000)
			return NSLocalizedString(@"512k DSL/Cable", "Bandwidth");
		else if(speed <= 96000)
			return NSLocalizedString(@"768k DSL/Cable", "Bandwidth");
		else if(speed <= 128000)
			return NSLocalizedString(@"1M DSL/Cable", "Bandwidth");
		else if(speed <= 256000)
			return NSLocalizedString(@"2M DSL/Cable", "Bandwidth");
		else if(speed <= 1280000)
			return NSLocalizedString(@"10M LAN", "Bandwidth");
		else if(speed <= 12800000)
			return NSLocalizedString(@"100M LAN", "Bandwidth");
	}
	
	return NSLocalizedString(@"Unknown", "Bandwidth");
}

@end
