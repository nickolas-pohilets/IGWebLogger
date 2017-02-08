//
//  IGWebLogger.m
//  IGWebLogger
//
//  Created by Francis Chong on 13年3月4日.
//  Copyright (c) 2013年 Ignition Soft. All rights reserved.
//

#import "IGWebLogger.h"
#import "WebSocket.h"
#import "HTTPServer.h"
#import "IGWebLoggerURLConnection.h"

@implementation IGWebLogger

static IGWebLogger *sharedInstance;

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
		sharedInstance = [[IGWebLogger alloc] init];
    });
}

+ (IGWebLogger *)sharedInstance
{
	return sharedInstance;
}

- (id)init
{
	if (sharedInstance != nil)
	{
		return nil;
	}
	
	if ((self = [super init]))
	{
        self.webSockets = [NSMutableArray array];
	}

	return self;
}

#pragma mark - Public

- (void)addWebSocket:(WebSocket*)webSocket
{
    dispatch_sync([DDLog loggingQueue], ^{
        [self.webSockets addObject:webSocket];
    });
}

- (void)removeWebSocket:(WebSocket*)webSocket
{
    dispatch_sync([DDLog loggingQueue], ^{
        [self.webSockets removeObject:webSocket];
    });
}

+ (HTTPServer*) httpServer {
    return [self httpServerWithPort:8888];
}

+ (HTTPServer*) httpServerWithPort:(UInt16)port {
    HTTPServer* httpServer = [[HTTPServer alloc] init];
    [httpServer setConnectionClass:[IGWebLoggerURLConnection class]];
    [httpServer setType:@"_http._tcp."];

    [httpServer setPort:port];
    
    NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"IGWebLogger.bundle"];
    [httpServer setDocumentRoot:webPath];
    return httpServer;
}

#pragma mark - DDLogger

- (void)logMessage:(DDLogMessage *)logMessage
{
	if ([self.webSockets count] > 0)
	{
        NSString *logMsg = [self formatLogMessage:logMessage];
        if (logMsg)
        {
            [self.webSockets enumerateObjectsUsingBlock:^(WebSocket* socket, NSUInteger idx, BOOL *stop) {
                [socket sendMessage:logMsg];
            }];
        }
	}
}

- (NSString *)loggerName
{
	return @"hk.ignition.logger.IGWebLogger";
}

// a DDLogFormatter that format the log in JSON

#pragma mark - DDLogFormatter

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage {
    NSString* logLevel = @"verbose";
    if (logMessage->_flag & DDLogFlagError) {
        logLevel = @"error";
    } else if (logMessage->_flag & DDLogFlagWarning) {
        logLevel = @"warn";
    } else if (logMessage->_flag & DDLogFlagInfo) {
        logLevel = @"info";
    } else {
        logLevel = @"verbose";
    }
    
    NSDictionary* data = @{
        @"message": logMessage->_message ?: @"",
        @"level": logLevel,
        @"file": logMessage->_file ?: @"",
        @"function": logMessage->_function ?: @"",
        @"line": @(logMessage->_line)
    };
    
    NSError* error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:data
                                                       options:0
                                                         error:&error];
    NSString* jsonStr = [[NSString alloc] initWithData:jsonData
                                              encoding:NSUTF8StringEncoding];
    return jsonStr;
}

@end
