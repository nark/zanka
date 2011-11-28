#import <Cocoa/Cocoa.h>

@class WCAccount, WCClient;

@interface WCServer : NSObject {
	unsigned int			_type;
	WCClient				*_client;
	WCAccount				*_account;
	NSString				*_name;
	NSURL					*_url;
}


- (void)					setType:(unsigned int)value;
- (unsigned int)			type;

- (void)					setClient:(WCClient *)value;
- (WCClient *)				client;

- (void)					setAccount:(WCAccount *)value;
- (WCAccount *)				account;

- (void)					setName:(NSString *)value;
- (NSString *)				name;

- (void)					setURL:(NSURL *)value;
- (NSURL *)					URL;

@end
