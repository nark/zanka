/* $Id$ */

/*
 *  Copyright (c) 2008-2009 Axel Andersson
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

#import "QTTrack-SPAdditions.h"

static void										SPXWatchParent(void);
static void *									SPXWatchParentThread(void *);

static void										SPXWatchFiles(NSString *);
static void *									SPXWatchFilesThread(void *);

static void										SPXExport(NSString *, NSString *, NSString *, NSString *, NSString *, NSString *);
static void										SPXLoadTracks(QTMovie *);
static void										SPXSelectTracks(QTMovie *, NSString *, NSString *);

static NSDictionary *							SPXFormatWithName(NSString *, NSString *);

static const char *								SPXErrorString(NSError *);
static void										SPXUsage(void);
static void										SPXCleanUp(void);
static void										SPXSignalTerminate(int);
static void										SPXSignalCrash(int);
static void										SPXExit(int);


static NSString									*SPXTemporaryFilePath;
static pthread_mutex_t							SPXTemporaryFileLock = PTHREAD_MUTEX_INITIALIZER;


@interface SPXMovieDelegate : NSObject

@end


int main(int argc, const char **argv) {
	NSAutoreleasePool		*pool;
	NSString				*audioPattern, *formatName, *inputPath, *outputPath, *spiralPath, *subtitlePattern;
	int						ch;
	
	pool = [[NSAutoreleasePool alloc] init];
	
	SPXWatchParent();
	
	audioPattern = formatName = inputPath = outputPath = spiralPath = subtitlePattern = NULL;
	
	while((ch = getopt(argc, (char * const *) argv, "a:f:i:o:p:s:")) != -1) {
		switch(ch) {
			case 'a':
				audioPattern = [NSString stringWithUTF8String:optarg];
				break;
				
			case 'f':
				formatName = [NSString stringWithUTF8String:optarg];
				break;
				
			case 'i':
				inputPath = [NSString stringWithUTF8String:optarg];
				break;
				
			case 'o':
				outputPath = [NSString stringWithUTF8String:optarg];
				break;
			
			case 'p':
				spiralPath = [NSString stringWithUTF8String:optarg];
				break;
				
			case 's':
				subtitlePattern = [NSString stringWithUTF8String:optarg];
				break;
				
			case 'h':
			case '?':
			default:
				SPXUsage();
				break;
		}
	}
	
	if(!formatName || !spiralPath || !inputPath || !outputPath)
		SPXUsage();
	
	signal(SIGINT, SPXSignalTerminate);
	signal(SIGTERM, SPXSignalTerminate);
	signal(SIGILL, SPXSignalCrash);
    signal(SIGABRT, SPXSignalCrash);
    signal(SIGFPE, SPXSignalCrash);
    signal(SIGBUS, SPXSignalCrash);
    signal(SIGSEGV, SPXSignalCrash);
	
	SPXWatchFiles([outputPath stringByDeletingLastPathComponent]);
	SPXExport(inputPath, outputPath, formatName, spiralPath, audioPattern, subtitlePattern);
	SPXCleanUp();
	
	[pool release];
	
	return 0;
}



#pragma mark -

static void SPXWatchParent(void) {
	pthread_t	thread;
	int			err;
	
	err = pthread_create(&thread, NULL, SPXWatchParentThread, NULL);
	
	if(err != 0) {
		printf("ERROR:%s.\n", strerror(err));
		
		SPXExit(1);
	}
}



static void * SPXWatchParentThread(void *arg) {
	struct kevent	event;
	int				queue;
	
	queue = kqueue();
	
	if(queue >= 0) {
		EV_SET(&event, getppid(), EVFILT_PROC, EV_ADD | EV_ENABLE | EV_CLEAR, NOTE_EXIT, 0, NULL);
		
		if(kevent(queue, &event, 1, &event, 1, NULL) >= 0) {
			SPXCleanUp();
			SPXExit(0);
		}
	}
	
	return NULL;
}



#pragma mark -

static void SPXWatchFiles(NSString *path) {
	pthread_t	thread;
	int			err;
	
	err = pthread_create(&thread, NULL, SPXWatchFilesThread, [path retain]);
	
	if(err != 0) {
		printf("ERROR:%s.\n", strerror(err));
		
		SPXExit(1);
	}
}



static void * SPXWatchFilesThread(void *arg) {
	NSAutoreleasePool	*pool;
	NSArray				*originalFiles;
	NSString			*path = arg, *file;
	struct kevent		event;
	int					queue, fd;
	
	pool = [[NSAutoreleasePool alloc] init];
	
	queue = kqueue();
	
	if(queue >= 0) {
		fd = open([path fileSystemRepresentation], O_EVTONLY, 0);
		
		if(fd >= 0) {
			originalFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
			
			while(YES) {
				EV_SET(&event, fd, EVFILT_VNODE, EV_ADD | EV_ENABLE | EV_CLEAR, NOTE_WRITE, 0, NULL);
				
				if(kevent(queue, &event, 1, &event, 1, NULL) >= 0) {
					for(file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL]) {
						if([file hasPrefix:@".QT-"] && ![originalFiles containsObject:file])
							break;
					}
					
					if(file) {
						pthread_mutex_lock(&SPXTemporaryFileLock);
						SPXTemporaryFilePath = [[path stringByAppendingPathComponent:file] retain];
						pthread_mutex_unlock(&SPXTemporaryFileLock);
						
						break;
					}
				}
			}
		}
	}
	
	[path release];
	[pool release];
	
	return NULL;
}



#pragma mark -

static void SPXExport(NSString *inputPath, NSString *outputPath, NSString *formatName, NSString *spiralPath, NSString *audioPattern, NSString *subtitlePattern) {
	NSDictionary		*format, *attributes;
	NSError				*error;
	QTMovie				*movie;
	SPXMovieDelegate	*delegate;
	const char			*string;
	
	format = SPXFormatWithName(formatName, spiralPath);
	
	if(!format) {
		printf("ERROR:Format not found.\n");
		
		SPXExit(1);
	}
	
	movie = [[QTMovie alloc] initWithFile:inputPath error:&error];
	
	if(!movie) {
		if(error)
			string = SPXErrorString(error);
		else
			string = "Unknown error while opening movie";
		
		printf("ERROR:%s.\n", string);
		
		SPXExit(1);
	}
	
	delegate = [[SPXMovieDelegate alloc] init];
	
	[movie setDelegate:delegate];
	
	SPXLoadTracks(movie);
	SPXSelectTracks(movie, audioPattern, subtitlePattern);
	
	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:YES],
			QTMovieExport,
		[format objectForKey:@"ComponentSubType"],
			QTMovieExportType,
		[format objectForKey:@"ComponentManufacturer"],
			QTMovieExportManufacturer,
		[format objectForKey:@"ComponentSettings"],
			QTMovieExportSettings,
		NULL];
	
	if(![movie writeToFile:outputPath withAttributes:attributes error:&error]) {
		if(error)
			string = SPXErrorString(error);
		else
			string = "Unknown error while exporting movie";
		
		printf("ERROR:%s.\n", string);
		
		SPXExit(1);
	}
	
	printf("COMPLETE\n");
	
	[movie release];
	[delegate release];
}



static void SPXLoadTracks(QTMovie *movie) {
	NSArray				*tracks;
	QTTrack				*track;
	NSTimeInterval		duration, trackDuration;

	printf("STATUS:Loading tracks...\n");

	while([[movie attributeForKey:QTMovieLoadStateAttribute] longValue] != QTMovieLoadStateComplete) {
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
		
		tracks = [movie tracksOfMediaType:QTMediaTypeVideo];
		
		if([tracks count] > 0) {
			track = [tracks objectAtIndex:0];
			
			if(!QTGetTimeInterval([[track attributeForKey:QTTrackRangeAttribute] QTTimeRangeValue].duration, &trackDuration))
				trackDuration = 0.0;
			
			if(!QTGetTimeInterval([[movie attributeForKey:QTMovieDurationAttribute] QTTimeValue], &duration))
				duration = 1.0;
			
			printf("LOADTRACKS:%.2f\n", (trackDuration / duration) * 100.0);
		}
	}
	
	printf("LOADTRACKS:%.2f\n", 100.0);
}



static void SPXSelectTracks(QTMovie *movie, NSString *audioPattern, NSString *subtitlePattern) {
	NSMutableArray		*audioTracks, *subtitleTracks;
	QTTrack				*track;
	NSRange				range;
	NSUInteger			audioTrack, selectedAudioTrack, subtitleTrack, selectedSubtitleTrack;
	
	if([audioPattern length] > 0 || [subtitlePattern length] > 0) {
		audioTracks				= [NSMutableArray array];
		subtitleTracks			= [NSMutableArray array];
		audioTrack				= 0;
		selectedAudioTrack		= NSNotFound;
		subtitleTrack			= 0;
		selectedSubtitleTrack	= NSNotFound;
		
		for(track in [movie tracks]) {
			if([track isAudioTrack]) {
				[audioTracks addObject:track];
				
				if([track isEnabled])
					selectedAudioTrack = audioTrack;
				
				audioTrack++;
			}
			else if([track isSubtitleTrack]) {
				[subtitleTracks addObject:track];
				
				if([track isEnabled])
					selectedSubtitleTrack = subtitleTrack;
				
				subtitleTrack++;
			}
		}
		
		if([audioPattern length] > 0) {
			for(track in audioTracks) {
				range = [[track attributeForKey:QTTrackDisplayNameAttribute] rangeOfString:audioPattern options:NSCaseInsensitiveSearch];
				
				if(range.location != NSNotFound) {
					if(selectedAudioTrack != NSNotFound)
						[[audioTracks objectAtIndex:selectedAudioTrack] setEnabled:NO];
					
					[track setEnabled:YES];

					break;
				}
			}
		}
		
		if([subtitlePattern length] > 0) {
			for(track in subtitleTracks) {
				range = [[track attributeForKey:QTTrackDisplayNameAttribute] rangeOfString:subtitlePattern options:NSCaseInsensitiveSearch];
				
				if(range.location != NSNotFound) {
					if(selectedSubtitleTrack != NSNotFound)
						[[subtitleTracks objectAtIndex:selectedSubtitleTrack] setEnabled:NO];
					
					[track setEnabled:YES];
					
					break;
				}
			}
		}
	}
}



#pragma mark -

static NSDictionary * SPXFormatWithName(NSString *formatName, NSString *spiralPath) {
	NSArray			*formats;
	NSDictionary	*format;
	
	formats = [NSArray arrayWithContentsOfFile:
		[spiralPath stringByAppendingPathComponent:@"Contents/Resources/ExportFormats.plist"]];
	
	for(format in formats) {
		if([formatName isEqualToString:[format objectForKey:@"Name"]])
			return format;
	}
	
	return NULL;
}



#pragma mark -

static const char * SPXErrorString(NSError *error) {
	const char		*string;
	
	string = [[error localizedFailureReason] UTF8String];
	
	if(!string)
		string = [[error localizedDescription] UTF8String];
	
	if(!string)
		string = [[[error userInfo] description] UTF8String];
	
	if(!string)
		string = "Unknown error";
	
	return string;
}



static void SPXUsage(void) {
	fprintf(stderr,
"Usage: SpiralExporter -i inputPath -o outputPath -f formatName -p spiralPath -a audioPattern -s subtitlePattern\n\
\n\
Options:\n\
-i             path to input file\n\
-o             path to output file\n\
-f             format name\n\
-p             path to Spiral\n\
-a             audio track name pattern\n\
-s             subtitle track name pattern\n\
\n\
By Axel Andersson <axel@zankasoftware.com>\n");
	
	SPXExit(2);
}



static void SPXCleanUp(void) {
	pthread_mutex_lock(&SPXTemporaryFileLock);
	
	if(SPXTemporaryFilePath)
		[[NSFileManager defaultManager] removeItemAtPath:SPXTemporaryFilePath error:NULL];
	
	pthread_mutex_unlock(&SPXTemporaryFileLock);
}



static void SPXSignalTerminate(int sigraised) {
	SPXCleanUp();
	SPXExit(0);
}



static void SPXSignalCrash(int sigraised) {
	SPXCleanUp();
	
	signal(sigraised, SIG_DFL);
}



static void SPXExit(int status) {
	sleep(2);
	exit(status);
}



@implementation SPXMovieDelegate

- (BOOL)movie:(QTMovie *)movie shouldContinueOperation:(NSString *)operation withPhase:(QTMovieOperationPhase)phase atPercent:(NSNumber *)percent withAttributes:(NSDictionary *)attributes {
	if(phase == QTMovieOperationBeginPhase)
		printf("STATUS:Exporting movie...\n");
	else
		printf("EXPORT:%.2f\n", [percent doubleValue] * 100.0);
	
	return YES;
}

@end
