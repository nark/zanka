/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
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

#import <WiredAdditions/NSData-WIAdditions.h>

@implementation NSData(WIDataChecksum)

+ (NSData *)dataWithBase64EncodedString:(NSString *)string {
	NSMutableData			*mutableData;
	NSData					*data;
	const unsigned char		*buffer;
	unsigned char			ch, inbuffer[4], outbuffer[3];
	NSUInteger				i, length, count, position, offset;
	BOOL					ignore, stop, end;
	
	data = [string dataUsingEncoding:NSASCIIStringEncoding];
	length = [data length];
	position = offset = 0;
	buffer = [data bytes];
	mutableData = [NSMutableData dataWithCapacity:length];
	
	while(position < length) {
		ignore = end = NO;
		ch = buffer[position++];
		
		if(ch >= 'A' && ch <= 'Z')
			ch = ch - 'A';
		else if(ch >= 'a' && ch <= 'z')
			ch = ch - 'a' + 26;
		else if(ch >= '0' && ch <= '9')
			ch = ch - '0' + 52;
		else if(ch == '+')
			ch = 62;
		else if(ch == '=')
			end = YES;
		else if(ch == '/')
			ch = 63;
		else
			ignore = YES;
		
		if(!ignore) {
			count = 3;
			stop = NO;
			
			if(end) {
				if(offset == 0)
					break;
				else if(offset == 1 || offset == 2)
					count = 1;
				else
					count = 2;
				
				offset = 3;
				stop = YES;
			}
			
			inbuffer[offset++] = ch;
			
			if(offset == 4) {
				outbuffer[0] =  (inbuffer[0]         << 2) | ((inbuffer[1] & 0x30) >> 4);
				outbuffer[1] = ((inbuffer[1] & 0x0F) << 4) | ((inbuffer[2] & 0x3C) >> 2);
				outbuffer[2] = ((inbuffer[2] & 0x03) << 6) |  (inbuffer[3] & 0x3F);
				
				for(i = 0; i < count; i++)
					[mutableData appendBytes:&outbuffer[i] length:1];

				offset = 0;
			}
			
			if(stop)
				break;
		}
	}
	
	return mutableData;
}



- (NSString *)base64EncodedString {
	NSMutableString			*string;
	const unsigned char		*buffer;
	unsigned char			inbuffer[3], outbuffer[4];
	NSUInteger				i, count, length, position, remaining;
	static char				table[] =
		"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	
	length = [self length];
	buffer = [self bytes];
	position = 0;
	string = [NSMutableString stringWithCapacity:(NSUInteger) (length * (4.0f / 3.0f)) + 4];
	
	while(position < length) {
		for(i = 0; i < 3; i++) {
			if(position + i < length)
				inbuffer[i] = buffer[position + i];
			else
				inbuffer[i] = '\0';
		}
		
		outbuffer[0] =  (inbuffer[0] & 0xFC) >> 2;
		outbuffer[1] = ((inbuffer[0] & 0x03) << 4) | ((inbuffer[1] & 0xF0) >> 4);
		outbuffer[2] = ((inbuffer[1] & 0x0F) << 2) | ((inbuffer[2] & 0xC0) >> 6);
		outbuffer[3] =   inbuffer[2] & 0x3F;
		
		remaining = length - position;
		
		if(remaining == 1)
			count = 2;
		else if(remaining == 2)
			count = 3;
		else
			count = 4;
		
		for(i = 0; i < count; i++)
			[string appendFormat:@"%c", table[outbuffer[i]]];
		
		for(i = count; i < 4; i++)
			[string appendFormat:@"%c", '='];
		
		position += 3;
	}
	
	return string;
}



#pragma mark -

- (NSString *)SHA1 {
	SHA_CTX					c;
	static unsigned char	hex[] = "0123456789abcdef";
	unsigned char			sha[SHA_DIGEST_LENGTH], text[SHA_DIGEST_LENGTH * 2 + 1];
	NSUInteger				i;

	SHA1_Init(&c);
	SHA1_Update(&c, (unsigned char *) [self bytes], [self length]);
	SHA1_Final(sha, &c);

	for(i = 0; i < SHA_DIGEST_LENGTH; i++) {
		text[i+i]	= hex[sha[i] >> 4];
		text[i+i+1]	= hex[sha[i] & 0x0F];
	}

	text[i+i] = '\0';

	return [NSString stringWithCString:(char *) text];
}

@end
