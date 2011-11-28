/* $Id$ */

/*
 *  Copyright (c) 2003-2005 Axel Andersson
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

#import "NSBitmapImageRep-FHAdditions.h"

@interface NSBitmapImageRep(FHPrivate)

static void _FHJPEGErrorHandler(j_common_ptr);

struct FHJPEGError {
	struct jpeg_error_mgr	error_mgr;
	jmp_buf					jmp_buffer;
};

@end



@implementation NSBitmapImageRep(FHAdditions)

- (id)initWithJPEGFile:(NSString *)path preferredSize:(NSSize)size {
	FILE							*fp = NULL;
	struct FHJPEGError				error;
	struct jpeg_decompress_struct	jinfo;
	unsigned char					*pixels = NULL, **lines = NULL;
	float							scale;
	unsigned int					y, width, height, samplesPerPixel, bitsPerPixel;
	J_COLOR_SPACE					colorSpace;
	
	fp = fopen([path UTF8String], "r");
	
	if(!fp) {
		NSLog(@"*** %@: %@: %s", [self class], path, strerror(errno));
		
		goto err;
	}

	jinfo.err = jpeg_std_error(&error.error_mgr);
	error.error_mgr.error_exit = _FHJPEGErrorHandler;
	
	if(setjmp(error.jmp_buffer) != 0)
		goto err;
	
	jpeg_create_decompress(&jinfo);
	jpeg_stdio_src(&jinfo, fp);
	jpeg_read_header(&jinfo, TRUE);
	
	colorSpace = jinfo.out_color_space;
	
	if(colorSpace != JCS_RGB && colorSpace != JCS_GRAYSCALE && colorSpace != JCS_CMYK)
		goto err;
	
	scale = ((float) jinfo.image_width / (float) jinfo.image_height) > (size.width / size.height)
		? size.width / (float) jinfo.image_width
		: size.height / (float) jinfo.image_height;

	if(scale < 1.0) {
		jinfo.scale_num			= 1;
		jinfo.scale_denom		= (unsigned int) (1.0f / scale);
	}
	
	jinfo.do_fancy_upsampling	= NO;
	jinfo.do_block_smoothing	= NO;
	jinfo.dct_method			= JDCT_IFAST;
	jinfo.out_color_space		= JCS_RGB;
	
	jpeg_calc_output_dimensions(&jinfo);
	
	width = jinfo.output_width;
	height = jinfo.output_height;
	samplesPerPixel = jinfo.output_components;
	bitsPerPixel = samplesPerPixel * 8;
	pixels = (unsigned char *) malloc(jinfo.output_width * jinfo.output_height * samplesPerPixel);
	lines = (unsigned char **) malloc(jinfo.output_height * sizeof(unsigned char *));

	jpeg_start_decompress(&jinfo);

	for (y = 0; y < jinfo.output_height; y++)
		lines[y] = pixels + (y * samplesPerPixel * jinfo.output_width);
	
	while (jinfo.output_scanline < jinfo.output_height)
		jpeg_read_scanlines(&jinfo, &lines[jinfo.output_scanline], jinfo.rec_outbuf_height);
	
	jpeg_finish_decompress(&jinfo);
	
	self = [self initWithBitmapDataPlanes:NULL
							   pixelsWide:width
							   pixelsHigh:height
							bitsPerSample:8
						  samplesPerPixel:samplesPerPixel
								 hasAlpha:NO
								 isPlanar:NO
						   colorSpaceName:NSCalibratedRGBColorSpace
							  bytesPerRow:width * samplesPerPixel
							 bitsPerPixel:bitsPerPixel];
	
	memcpy([self bitmapData], pixels, width * height * samplesPerPixel);

	goto end;

err:
	[self release];
	self = NULL;

end:

	if(fp)
		fclose(fp);
	
	if(pixels)
		free(pixels);
	
	if(lines)
		free(lines);
	
	return self;
}



static void _FHJPEGErrorHandler(j_common_ptr info) {
	struct FHJPEGError		*error;
	
	error = (struct FHJPEGError *) info->err;
	longjmp(error->jmp_buffer, 1);
}

@end
