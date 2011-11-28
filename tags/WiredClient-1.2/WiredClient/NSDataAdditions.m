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

#import "NSDataAdditions.h"

@implementation NSData(WCChecksumming)

- (NSString *)SHA1 {
	SHA_CTX					c;
	static unsigned char	hex[] = "0123456789abcdef";
	unsigned char			sha[SHA_DIGEST_LENGTH], password[SHA_DIGEST_LENGTH * 2 + 1];
	int						i;

	// --- calculate the checksum
	SHA1_Init(&c);
	SHA1_Update(&c, (unsigned char *) [self bytes], [self length]);
	SHA1_Final(sha, &c);

	// --- map into hexademical characters
	for(i = 0; i < SHA_DIGEST_LENGTH; i++) {
		password[i+i]	= hex[sha[i] >> 4];
		password[i+i+1]	= hex[sha[i] & 0x0F];
	}
		
	// --- terminate
	password[i+i] = '\0';
	
	// --- return an autoreleased NSString of it
	return [NSString stringWithCString:(char *) password];
}

@end



@implementation NSData(WCBase64Encoding)

+ (NSData *)dataWithBase64EncodedString:(NSString *)string {
    NSMutableData			*mutableData;
	NSData					*data;
	const unsigned char		*bytes;
	unsigned char			ch, inbuffer[3], outbuffer[4];
	int						i, length, chars, textpos = 0, bufferpos = 0;
	BOOL					ignore, stop, end = NO;

	data = [string dataUsingEncoding:NSASCIIStringEncoding];
	bytes = [data bytes];
	length = [data length];
	mutableData = [NSMutableData dataWithCapacity:length];
	
	while(textpos < length) {
		ignore = NO;
		ch = bytes[textpos++];
		
		if((ch >= 'A') && (ch <= 'Z'))
			ch = ch - 'A';
		else if((ch >= 'a') && (ch <= 'z'))
			ch = ch - 'a' + 26;
		else if ((ch >= '0') && (ch <= '9'))
			ch = ch - '0' + 52;
		else if (ch == '+')
			ch = 62;
		else if (ch == '=')
			end = YES;
		else if (ch == '/')
			ch = 63;
		else
			ignore = YES; 
				 
		if (!ignore) {
			chars = 3;
			stop = NO;
			
			if(end) {
				if(bufferpos == 0)
					break;
				
				if((chars == 1) || (chars == 2))
					chars = 1;
				else
					chars = 2;
				
				bufferpos = 3;
				stop = YES;
			}
			
			inbuffer[bufferpos++] = ch;
			
			if(bufferpos == 4) {
				bufferpos = 0;
				outbuffer[0] = (inbuffer [0] << 2) | ((inbuffer [1] & 0x30) >> 4);
				outbuffer[1] = ((inbuffer [1] & 0x0F) << 4) | ((inbuffer [2] & 0x3C) >> 2);
				outbuffer[2] = ((inbuffer [2] & 0x03) << 6) | (inbuffer [3] & 0x3F);
				
				for(i = 0; i < chars; i++) 
					[mutableData appendBytes:&outbuffer[i] length:1];
			}
			
			if(stop)
				break;
		}
	}

	return [NSData dataWithData:mutableData];
}



- (NSString *)base64EncodedString {
    NSMutableString			*string;
    const unsigned char		*bytes;
    int						i, copy, length, textpos = 0;
    unsigned char			inbuffer[3], outbuffer[4];
	static char				encodingTable[64] = {
		'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
		'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
		'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
		'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/'
	};

	length = [self length];
	bytes = [self bytes];
	string = [NSMutableString stringWithCapacity:length];
	
	while (length - textpos > 0) {
		for(i = 0; i < 3; i++) {
             if (textpos + i < length)
                inbuffer[i] = bytes[textpos + i];
            else
                inbuffer[i] = 0;
        }

		outbuffer [0] = (inbuffer [0] & 0xFC) >> 2;
		outbuffer [1] = ((inbuffer [0] & 0x03) << 4) | ((inbuffer [1] & 0xF0) >> 4);
		outbuffer [2] = ((inbuffer [1] & 0x0F) << 2) | ((inbuffer [2] & 0xC0) >> 6);
		outbuffer [3] = inbuffer [2] & 0x3F;
		
		if(length - textpos == 1)
			copy = 2;
		else if(length - textpos == 2)
			copy = 3;
		else
			copy = 4;
        
		for(i = 0; i < copy; i++)
			[string appendFormat:@"%c", encodingTable[outbuffer[i]]];

		for(i = copy; i < 4; i++)
			[string appendFormat:@"%c", '='];

		textpos += 3;
	}
        
	return [NSString stringWithString:string];
}

@end
