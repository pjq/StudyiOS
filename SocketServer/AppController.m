#import "AppController.h"
#import "AsyncSocket.h"

#define FORMAT(format, args...) [NSString stringWithFormat:format, args]

@interface AppController (PrivateAPI)
- (void)logError:(NSString *)msg;
- (void)logInfo:(NSString *)msg;
- (void)logMessage:(NSString *)msg;
@end


@implementation AppController

- (id)init
{
	if(self = [super init])
	{
		listenSocket = [[AsyncSocket alloc] initWithDelegate:self];
		connectedSockets = [[NSMutableArray alloc] initWithCapacity:1];
		
		isRunning = NO;
	}
	return self;
}

- (void)awakeFromNib
{
	[logView setString:@""];
}

- (void)scrollToBottom
{
	NSScrollView *scrollView = [logView enclosingScrollView];
	NSPoint newScrollOrigin;
	
	if ([[scrollView documentView] isFlipped])
		newScrollOrigin = NSMakePoint(0.0, NSMaxY([[scrollView documentView] frame]));
	else
		newScrollOrigin = NSMakePoint(0.0, 0.0);
	
	[[scrollView documentView] scrollPoint:newScrollOrigin];
}

- (void)logError:(NSString *)msg
{
	NSString *paragraph = [NSString stringWithFormat:@"%@\n", msg];
	
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:1];
	[attributes setObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
	
	NSAttributedString *as = [[NSAttributedString alloc] initWithString:paragraph attributes:attributes];
	[as autorelease];
	
	[[logView textStorage] appendAttributedString:as];
	[self scrollToBottom];
}

- (void)logInfo:(NSString *)msg
{
	NSString *paragraph = [NSString stringWithFormat:@"%@\n", msg];
	
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:1];
	[attributes setObject:[NSColor purpleColor] forKey:NSForegroundColorAttributeName];
	
	NSAttributedString *as = [[NSAttributedString alloc] initWithString:paragraph attributes:attributes];
	[as autorelease];
	
	[[logView textStorage] appendAttributedString:as];
	[self scrollToBottom];
}

- (void)logMessage:(NSString *)msg
{
	NSString *paragraph = [NSString stringWithFormat:@"%@\n", msg];
	
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:1];
	[attributes setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
	
	NSAttributedString *as = [[NSAttributedString alloc] initWithString:paragraph attributes:attributes];
	[as autorelease];
	
	[[logView textStorage] appendAttributedString:as];
	[self scrollToBottom];
}

- (IBAction)startStop:(id)sender
{
	if(!isRunning)
	{
		int port = [portField intValue];
		
		if(port < 0 || port > 65535)
		{
			port = 0;
		}
		
		NSError *error = nil;
		if(![listenSocket acceptOnPort:port error:&error])
		{
			[self logError:FORMAT(@"Error starting server: %@", error)];
			return;
		}
		
		[self logInfo:FORMAT(@"Echo server started on port %hu", [listenSocket localPort])];
		isRunning = YES;
		
		[portField setEnabled:NO];
		[startStopButton setTitle:@"Stop"];
	}
	else
	{
		// Stop accepting connections
		[listenSocket disconnect];
			
		// Stop any client connections
		int i;
		for(i = 0; i < [connectedSockets count]; i++)
		{
			// Call disconnect on the socket,
			// which will invoke the onSocketDidDisconnect: method,
			// which will remove the socket from the list.
			[[connectedSockets objectAtIndex:i] disconnect];
		}
		
		[self logInfo:@"Stopped Echo server"];
		isRunning = false;
		
		[portField setEnabled:YES];
		[startStopButton setTitle:@"Start"];
	}
}

- (void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket
{
	[connectedSockets addObject:newSocket];
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	[self logInfo:FORMAT(@"Accepted client %@:%hu", host, port)];
	
	NSString *welcomeMsg = @"Welcome to the AsyncSocket Echo Server\r\n";
	NSData *welcomeData = [welcomeMsg dataUsingEncoding:NSUTF8StringEncoding];
	
	[sock writeData:welcomeData withTimeout:-1 tag:0];
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	NSData *strData = [data subdataWithRange:NSMakeRange(0, [data length] - 2)];
	NSString *msg = [[[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding] autorelease];
	if(msg)
	{
		[self logMessage:msg];
	}
	else
	{
		[self logError:@"Error converting received data into UTF-8 String"];
	}
	
	// Even if we were unable to write the incoming data to the log,
	// we're still going to echo it back to the client.
	[sock writeData:data withTimeout:-1 tag:0];
}

- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	[sock readDataToData:[AsyncSocket CRLFData] withTimeout:-1 tag:0];
}

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
	[self logInfo:FORMAT(@"Client Disconnected: %@:%hu", [sock connectedHost], [sock connectedPort])];
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
	[connectedSockets removeObject:sock];
}

@end
