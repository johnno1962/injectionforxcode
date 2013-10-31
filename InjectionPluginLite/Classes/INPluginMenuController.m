//
//  $Id: //depot/InjectionPluginLite/Classes/INPluginMenuController.m#31 $
//  InjectionPluginLite
//
//  Created by John Holdsworth on 15/01/2013.
//  Copyright (c) 2012 John Holdsworth. All rights reserved.
//
//  Manages interactions with Xcode's product menu and runs TCP server.
//
//  This file is copyright and may not be re-distributed, whole or in part.
//

#import "INPluginMenuController.h"
#import "INPluginClientController.h"

@implementation INPluginMenuController

#pragma mark - Plugin Initialization

+ (void)pluginDidLoad:(NSBundle *)plugin {

    static INPluginMenuController *injectionPlugin;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		injectionPlugin = [[self alloc] init];
        //NSLog( @"Preparing Injection: %@", injectionPlugin );
        [[NSNotificationCenter defaultCenter] addObserver:injectionPlugin
                                                 selector:@selector(applicationDidFinishLaunching:)
                                                     name:NSApplicationDidFinishLaunchingNotification object:nil];
	});
}

- (void)error:(NSString *)format, ... {
    va_list argp;
    va_start(argp, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:argp];
    [self.client performSelectorOnMainThread:@selector(alert:) withObject:message waitUntilDone:NO];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    IDEWorkspaceDocument = NSClassFromString(@"IDEWorkspaceDocument");
    DVTSourceTextView = NSClassFromString(@"DVTSourceTextView");
    self.defaults = [NSUserDefaults standardUserDefaults];

    if ( ![NSBundle loadNibNamed:@"INPluginMenuController" owner:self] )
        NSLog( @"INPluginMenuController: Could not load interface." );

	NSMenu *productMenu = [[[NSApp mainMenu] itemWithTitle:@"Product"] submenu];
	if (productMenu) {
		[productMenu addItem:[NSMenuItem separatorItem]];

        struct { char *item,  *key; SEL action; } items[] = {
            {"Injection Plugin", "", NULL},
            {"Inject Source", "=", @selector(injectSource:)}
        };

        for ( int i=0 ; i<sizeof items/sizeof items[0] ; i++ ) {
            NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithUTF8String:items[i].item]
                                                              action:items[i].action
                                                       keyEquivalent:[NSString stringWithUTF8String:items[i].key]];
            [menuItem setKeyEquivalentModifierMask:NSControlKeyMask];
            if ( i==0 )
                [subMenuItem = menuItem setSubmenu:self.subMenu];
            else
                [menuItem setTarget:self];
            [productMenu addItem:menuItem];
        }

        introItem.title = [NSString stringWithFormat:@"Injection v%s Intro", INJECTION_VERSION];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(selectionDidChange:)
                                                     name:NSTextViewDidChangeSelectionNotification object:nil];
	}
    else
        [self error:@"InInjectionPlugin: Could not locate Product Menu."];

    self.progressIndicator.frame = NSMakeRect(60, 20, 200, 10);
    webView.drawsBackground = NO;
    [self setProgress:@-1];
    [self startServer];
}

- (void)setProgress:(NSNumber *)fraction {
    if ( [fraction floatValue] < 0 )
        [self.progressIndicator setHidden:YES];
    else {
        [self.progressIndicator setDoubleValue:[fraction floatValue]];
        [self.progressIndicator setHidden:NO];
    }
}

- (void)startProgress {
    NSView *scrollView = [[self.lastTextView superview] superview];
    [scrollView addSubview:self.progressIndicator];
}

#pragma mark - Text Selection Handling

- (void)selectionDidChange:(NSNotification *)notification {
    id object = [notification object];
	if ([object isKindOfClass:DVTSourceTextView] &&
        [object isKindOfClass:[NSTextView class]] &&
        [[object delegate] respondsToSelector:@selector(document)])
        self.lastTextView = object;
}

- (NSString *)lastFileSaving:(BOOL)save {
    NSDocument *doc = [(id)[self.lastTextView delegate] document];
    if ( save ) {
        [doc saveDocument:self];
        [self setupLicensing];
    }
    return [[doc fileURL] path];
}

- (BOOL)lastFileContains:(NSString *)string {
    NSURL *url = [NSURL fileURLWithPath:[self lastFileSaving:NO]];
    NSString *source = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:NULL];
    return [source rangeOfString:string].location != NSNotFound;
}

- (NSString *)workspacePath {
    id delegate = [[NSApp keyWindow] delegate];
    if ( ![delegate respondsToSelector:@selector(document)] )
        delegate = [[self.lastTextView window] delegate];
    NSDocument *workspace = [delegate document];
    return [workspace isKindOfClass:IDEWorkspaceDocument] ?
        [[workspace fileURL] path] : nil;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = [menuItem action];
    if ( action == @selector(injectSource:) ) {
        NSString *workspace = [self workspacePath];
        NSRange range = [workspace rangeOfString:@"([^/]+)(?=\\.(?:xcodeproj|xcworkspace))"
                                         options:NSRegularExpressionSearch];

        if ( workspace && range.location != NSNotFound )
            subMenuItem.title = [workspace substringWithRange:range];
        else
            subMenuItem.title = @"Injection Plugin";
    }
    if ( action == @selector(patchProject:) || action == @selector(revertProject:) )
        return [self workspacePath] != nil;
    else if ( [menuItem action] == @selector(openBundle:) || [menuItem action] == @selector(listDevice:) )
        return self.client.connected;
    else
        return YES;
}

#pragma mark - Actions

static NSString *kAppHome = @"http://injection.johnholdsworth.com/",
    *kInstalled = @"INInstalled", *kLicensed = @"INLicensed2.x";

- (IBAction)viewIntro:sender{
    NSURL *url = [NSURL URLWithString:[kAppHome stringByAppendingString:@"pluginlite.html"]];
    [webView.mainFrame loadRequest:[NSURLRequest requestWithURL:url]];
    [webView.window orderFront:self];
}
- (void)openURL:(NSString *)url {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}
- (IBAction)support:sender {
    [self openURL:@"mailto:injection@johnholdsworth.com?subject=Injection%20Feedback"];
}
                  
- (IBAction)listDevice:sender {
    [self.client runScript:@"listDevice.pl" withArg:@""];
}
- (IBAction)patchProject:sender {
    [self.client runScript:@"patchProject.pl" withArg:@""];
}
- (IBAction)revertProject:sender {
    [self.client runScript:@"revertProject.pl" withArg:@""];
}
- (IBAction)openBundle:sender {
    [self.client runScript:@"openBundle.pl" withArg:[self lastFileSaving:YES]];
}
- (IBAction)injectSource:(id)sender {
    NSString *lastFile = [self lastFileSaving:YES];
    if ( ![self workspacePath] )
        [self.client alert:@"No project is open. Make sure the project you are working on is the \"Key Window\"."];
    else if ( !self.client.connected )
        [self.client alert:@"No  application has connected to injection. "
         "Patch the project and make sure DEBUG is #defined then run project again."];
    else if ( !lastFile )
        [self.client alert:@"No source file is selected. "
         "Make sure that text is selected and the cursor is inside the file you have edited."];
    else if ( [lastFile rangeOfString:@"\\.mm?$"
                                options:NSRegularExpressionSearch].location == NSNotFound )
        [self.client alert:@"Only class implementations (.m or .mm files) can be injected. "
         "Make sure that text is selected and the cursor is inside the file you have edited."];
    else
        [self.client runScript:@"injectSource.pl" withArg:lastFile];
}

#pragma mark - Injection Service

static CFDataRef copy_mac_address(void)
{
	kern_return_t			 kernResult;
	mach_port_t			   master_port;
	CFMutableDictionaryRef	matchingDict;
	io_iterator_t			 iterator;
	io_object_t			   service;
	CFDataRef				 macAddress = nil;

	kernResult = IOMasterPort(MACH_PORT_NULL, &master_port);
	if (kernResult != KERN_SUCCESS) {
		printf("IOMasterPort returned %d\n", kernResult);
		return nil;
	}

	matchingDict = IOBSDNameMatching(master_port, 0, "en0");
	if(!matchingDict) {
		printf("IOBSDNameMatching returned empty dictionary\n");
		return nil;
	}

	kernResult = IOServiceGetMatchingServices(master_port, matchingDict, &iterator);
	if (kernResult != KERN_SUCCESS) {
		printf("IOServiceGetMatchingServices returned %d\n", kernResult);
		return nil;
	}

	while((service = IOIteratorNext(iterator)) != 0)
	{
		io_object_t		parentService;

		kernResult = IORegistryEntryGetParentEntry(service, kIOServicePlane, &parentService);
		if(kernResult == KERN_SUCCESS)
		{
			if(macAddress) CFRelease(macAddress);
			macAddress = (CFDataRef)IORegistryEntryCreateCFProperty(parentService, CFSTR("IOMACAddress"), kCFAllocatorDefault, 0);
			IOObjectRelease(parentService);
		}
		else {
			printf("IORegistryEntryGetParentEntry returned %d\n", kernResult);
		}

		IOObjectRelease(service);
	}

	return macAddress;
}

- (NSString *)bonjourName {
    if ( !_bonjourName )
        self.bonjourName = [NSString stringWithFormat:@"_IN_%@._tcp.",
                       [[[INJECTION_BRIDGE(NSData *)copy_mac_address() description]
                         substringWithRange:NSMakeRange(5, 9)]
                        stringByReplacingOccurrencesOfString:@" " withString:@""]];
    INLog( @"%@ %@", [INJECTION_BRIDGE(NSData *)copy_mac_address() description], _bonjourName);
    return _bonjourName;
}

#include <sys/ioctl.h>
#include <net/if.h>

- (void)startServer {
    struct sockaddr_in serverAddr;

    serverAddr.sin_family = AF_INET;
    serverAddr.sin_addr.s_addr = INADDR_ANY;
    serverAddr.sin_port = htons(INJECTION_PORT);

    int optval = 1;
    if ( (serverSocket = socket(AF_INET, SOCK_STREAM, 0)) < 0 )
        [self error:@"Could not open service socket: %s", strerror( errno )];
    else if ( setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof optval) < 0 )
        [self error:@"Could not set socket option: %s", strerror( errno )];
    else if ( setsockopt( serverSocket, IPPROTO_TCP, TCP_NODELAY, (void *)&optval, sizeof(optval)) < 0 )
        [self error:@"Could not set socket option: %s", strerror( errno )];
    else if ( bind( serverSocket, (struct sockaddr *)&serverAddr, sizeof serverAddr ) < 0 )
        [self error:@"Could not bind service socket: %s", strerror( errno )];
    else if ( listen( serverSocket, 5 ) < 0 )
        [self error:@"Service socket would not listen: %s", strerror( errno )];
    else
        [self performSelectorInBackground:@selector(backgroundConnectionService) withObject:nil];
}

- (void)backgroundConnectionService {

    NSNetService *netService = [[NSNetService alloc] initWithDomain:@"" type:[self bonjourName]
                                                               name:@"" port:INJECTION_PORT];
    netService.delegate = self;
    [netService publish];

    INLog( @"Waiting for connections..." );
    while ( TRUE ) {
        struct sockaddr_in clientAddr;
        socklen_t addrLen = sizeof clientAddr;

        int appConnection = accept( serverSocket, (struct sockaddr *)&clientAddr, &addrLen );
        if ( appConnection > 0 )
            [self.client setConnection:appConnection];
        else
            [NSThread sleepForTimeInterval:.5];
    }
}

-(void)netService:(NSNetService *)aNetService didNotPublish:(NSDictionary *)dict {
    NSLog(@"%s failed to publish: %@", INJECTION_APPNAME, dict);
}

- (NSArray *)serverAddresses {
    NSMutableArray *addrs = [NSMutableArray arrayWithObject:[self bonjourName]];
    char buffer[1024];
    struct ifconf ifc;
    ifc.ifc_len = sizeof buffer;
    ifc.ifc_buf = buffer;

    if (ioctl(serverSocket, SIOCGIFCONF, &ifc) < 0)
        [self error:@"ioctl error %s", strerror( errno )];
    else
        for ( char *ptr = buffer; ptr < buffer + ifc.ifc_len; ) {
            struct ifreq *ifr = (struct ifreq *)ptr;
            int len = MAX(sizeof(struct sockaddr), ifr->ifr_addr.sa_len);
            ptr += sizeof(ifr->ifr_name) + len;	// for next one in buffer

            if (ifr->ifr_addr.sa_family != AF_INET)
                continue;	// ignore if not desired address family

            struct sockaddr_in *iaddr = (struct sockaddr_in *)&ifr->ifr_addr;
            [addrs addObject:[NSString stringWithUTF8String:inet_ntoa( iaddr->sin_addr )]];
        }
    
    return addrs;
}

- (BOOL)windowShouldClose:(id)sender {
    [sender orderOut:sender];
    return NO;
}

#pragma mark - Licensing Code

- (IBAction)license:sender{
    [self setupLicensing];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@cgi-bin/sale.cgi?vers=%s&inst=%d&ident=%@&lkey=%d",
                                       kAppHome, INJECTION_VERSION, (int)installed, self.mac, licensed]];
    webView.customUserAgent = @"040ccedcacacccedcacac";
    [webView.mainFrame loadRequest:[NSURLRequest requestWithURL:url]];
    [webView.window makeKeyAndOrderFront:self];
}

- (void)setupLicensing {
    struct stat tstat;
    if ( refkey || stat( "/Applications/Injection Plugin.app/Contents/Resources/InjectionPluginLite", &tstat ) == 0 )
        return;
    time_t now = time(NULL);
    installed = [self.defaults integerForKey:kInstalled];
    if ( !installed ) {
        [self.defaults setInteger:installed = now forKey:kInstalled];
        [self.defaults synchronize];
        //[self performSelector:@selector(openDemo:) withObject:self afterDelay:2.];
    }

    NSData *addr = INJECTION_BRIDGE(NSData *)copy_mac_address();
    int skip = 2, len = [addr length]-skip;
    unsigned char *bytes = (unsigned char *)[addr bytes]+skip;

    self.mac = [NSMutableString string];
    for ( int i=0 ; i<len ; i++ ) {
        [self.mac appendFormat:@"%02x", 0xff-bytes[i]];
        refkey ^= (365-[self.mac characterAtIndex:i*2])<<i*6;
        refkey ^= (365-[self.mac characterAtIndex:i*2+1])<<(i*6+3);
    }
    CFRelease( INJECTION_BRIDGE(CFDataRef)addr );

    licensed =  [self.defaults integerForKey:kLicensed];
    if ( licensed != refkey ) {
        // was 17 day eval period
        if ( now < installed + 17*24*60*60+60 )
            licensed = refkey = 1;
        else
            [self license:nil];
    }
}

#pragma mark - WebView delegates

- (NSString *)webView:(WebView *)sender runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt
          defaultText:(NSString *)defaultText initiatedByFrame:(WebFrame *)frame {
    INLog(@"License install... %@ %@ %d", prompt, defaultText, refkey );
    if ( [@"license" isEqualToString:prompt] ) {
        [webView.window setStyleMask:webView.window.styleMask | NSClosableWindowMask];
        [self.defaults setInteger:licensed = [defaultText intValue] forKey:kLicensed];
        [self.defaults synchronize];
    }
    return @"";
}

- (void)webView:(WebView *)aWebView decidePolicyForNavigationAction:(NSDictionary *)actionInformation
		request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener  {
    NSString *url = request.URL.absoluteString;
    if ( aWebView == webView ) {
        urlLabel.stringValue = url;
        if ( [url rangeOfString:@"^macappstore:|\\.(dmg|zip)" options:NSRegularExpressionSearch].location != NSNotFound ) {
            [[NSWorkspace sharedWorkspace] openURL:request.URL];
            [listener ignore];
            return;
        }
    }

    [listener use];
}

- (void)webView:(WebView *)aWebView didReceiveTitle:(NSString *)aTitle forFrame:(WebFrame *)frame {
    if ( frame == webView.mainFrame )
        self.webPanel.title = aTitle;
}

#pragma mark -

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
#ifndef INJECTION_ISARC
	[super dealloc];
#endif
}

@end
