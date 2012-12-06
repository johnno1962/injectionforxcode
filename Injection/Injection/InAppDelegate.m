//
//  InAppDelegate.m
//  Injection
//
//  Created by John Holdsworth on 16/01/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#define INJECTION_NOIMPL

#import "InAppDelegate.h"
#import "InDocument.h"

extern "C" {
    #import "validatereceipt.h"
}

@implementation InAppDelegate

#pragma mark Utilities

static const NSString *kUnlockCommand = @"unlockCommand", *kPlaySound = @"playSound",
    *kInstalled = @"installedV2.x", *kLicensed = @"licensedV1.x", *kConvertAll = @"convertAll";

#ifdef FOR_APP_STORE
#ifdef OPEN_APP_STORE
OOString appHome = @"http://injector.johnholdsworth.com/";
#else
OOString appHome = @"http://injection.johnholdsworth.com/";
#endif
#else
OOString appHome = @"http://injection.johnholdsworth.com/";
#endif

- (void)alert:(NSString *)message {
    NSLog( @"Error: %@", message );
    [[NSAlert alertWithMessageText:INJECTION_APPNAME+OO" Error:"
                     defaultButton:@"OK" alternateButton:nil otherButton:nil
		 informativeTextWithFormat:@"%@", message] runModal];
}

- (void)error:(NSString *)format, ... {
	va_list argp; va_start(argp, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:argp];
	va_end( argp );
    [self performSelectorOnMainThread:@selector(alert:) withObject:message waitUntilDone:NO];
    OO_RELEASE( message );
}

- (OOData)resource:(NSString *)name ofType:(NSString *)type {
	OOData out = OONil; //OOURL( appHome+@"config/"+appVersion+@"/"+name+@"."+type );
	if ( !out || OOString( out, NSISOLatin1StringEncoding )[@"404 Not Found"] != NSNotFound )
		out = OOFile( name, type );
	return out;
}

- (OOString)initResource:(NSString *)name ofType:(NSString *)type force:(BOOL)force {
	OOFile path( scriptRoot+name+@"."+type );

#if defined(DEBUG)
     path = OOFile( name, type ).data();
#else
	if ( force || !path.exists() )
		path = [self resource:name ofType:type];
#endif

	return path.path();
}

- (void)copyTemplate:(NSString *)templ usingFileManager:(NSFileManager *)fileManger {
 	if ( ![fileManger fileExistsAtPath:scriptRoot+templ] )
        [fileManger copyItemAtPath:resourcePath+templ
                            toPath:scriptRoot+templ error:NULL];
}

#pragma mark Initialisation and Exit

- (IBAction)updateScripts:sender {
    BOOL update = sender != nil, first = NO;

    NSFileManager *fileManger = [NSFileManager defaultManager];
    OOString versRoot = appRoot+@"DataV"+appVersion;

 	if ( ![fileManger fileExistsAtPath:versRoot] ) {
		[fileManger createDirectoryAtPath:versRoot 
              withIntermediateDirectories:YES attributes:nil error:NULL];
        OOFile( appRoot+@"Data" ).remove();
        if ( symlink( @"DataV"+appVersion, appRoot+@"Data" ) )
            [self error:@"Could not symlink()"];
        first = YES;
    }

#ifdef OPEN_APP_STORE
    [self initResource:@"common" ofType:@"pm" force:update];
    static NSString *scriptList[] = {@"openProject", @"openBundle", @"prepareBundle",
        @"listDevice", @"openURL", @"revertProject", @"testProject", nil};
    for ( NSString * OO_STRONG *sptr = scriptList ; *sptr ; sptr++ )   
        [self initResource:*sptr ofType:@"pl" force:update];
#else   
    [self initResource:@"injection" ofType:@"dat" force:update];
#endif

    [self copyTemplate:@"OSXBundleTemplate" usingFileManager:fileManger];
    [self copyTemplate:@"iOSBundleTemplate" usingFileManager:fileManger];
    
    [self initResource:@"demo" ofType:@"tgz" force:update];

#ifndef DEBUG
    if ( first )
#endif
        system( "cd '"+scriptRoot+"' && tar xfz demo.tgz && chmod -R +w *Demo" );

    //[self initResource:@"BundleInjection" ofType:@"h" force:update];
    //[self initResource:@"BundleInterface" ofType:@"h" force:update];
    [self initResource:@"welcome" ofType:@"html" force:update];

    static NSString *pngList[] = {@"injection",
        @"green", @"amber", @"red", @"blue", @"grey", nil};
    for ( NSString * OO_STRONG *sptr = pngList ; *sptr ; sptr++ )   
        [self initResource:*sptr ofType:@"png" force:update];
}

#include <sys/ioctl.h>
#include <net/if.h>

- (OOStringArray)startServer {
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
    
    OOStringArray addrs;
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
            OOString addr = inet_ntoa( iaddr->sin_addr );		
            addrs += addr;
        }

    return addrs;
}

static void trapper( int signal ) {
    NSLog( @"SIGPIPE %d", signal );
}

#ifndef FOR_PLUGIN
#ifndef OPEN_APP_STORE
static NSString *global_bundleIdentifier = @"com.johnholdsworth.InjectionII";
#else
static NSString *global_bundleIdentifier = @"com.johnholdsworth.Injection";
#endif
static NSString *global_bundleVersion = @INJECTION_VERSION;
#import "validatereceipt.m"
#endif

- (void)awakeFromNib {
    INLog( @"%@ %@", *defaults, *info );
    appRoot = OOHome()+@"/Library/Application Support/"+info[kCFBundleNameKey]+@"/";
    resourcePath = [[NSBundle mainBundle] resourcePath]+OO"/";
    appPrefix = *info["CFBundleURLTypes"][0]["CFBundleURLSchemes"][0]+
        @":"+getpid()+@":";
    appVersion = info[kCFBundleVersionKey];
    clunk = [NSSound soundNamed:@"clunk"];
    scriptRoot = appRoot+@"Data/";
    signal( SIGPIPE, trapper );

    installed = defaults[kInstalled], now = time(NULL);
    if ( !installed ) {
        defaults[kInstalled] = installed = now;
        defaults.sync();
        [self performSelector:@selector(openDemo:) withObject:self afterDelay:2.];
    }

#if 1
    struct stat st;
    if ( stat( scriptRoot+"..", &st ) == 0 &&
        st.st_ctimespec.tv_sec < installed ) {
        defaults[kInstalled] = installed = st.st_ctimespec.tv_sec;
        defaults.sync();
    }

    INLog( @"TIMES: %d %d", (int)st.st_ctimespec.tv_sec, (int)installed );
#endif

#ifndef FOR_PLUGIN
    OOData addr = OO_BRIDGE(NSData *)copy_mac_address();
    int skip = 2, len = [addr length]-skip;
    unsigned char *bytes = (unsigned char *)[addr bytes]+skip;

    mac.alloc();
    for ( int i=0 ; i<len ; i++ ) {
        [mac appendFormat:@"%02x", 0xff-bytes[i]];
        refkey ^= 365-mac[i*2]<<i*6;
        refkey ^= 365-mac[i*2+1]<<i*6+3;
        //INLog( @"%d", refkey );
    }
    OO_RELEASE(addr);
#endif

#ifdef FOR_APP_STORE
#ifndef DEBUG
    if ( !checkSemaphores( [[[NSBundle mainBundle] bundlePath]
                            stringByAppendingPathComponent:@"Contents/_MASReceipt/receipt"] ) ) {
        NSLog( @"Receipt for Injection did not validate" );
        exit(173);
    }
#endif
    lic.hidden = YES;
    licensed = refkey;
#else
    licensed =  defaults[kLicensed];
    INLog( @"%d %d %d %d", licensed, refkey, (int)installed, (int)time(NULL) ); 
    if ( licensed != refkey ) {
        if ( now < installed + 17*24*60*60+60 )
            licensed = refkey = 1;
        else
            [self license:nil];
    }
#endif
#ifdef OPEN_APP_STORE
    conf.hidden = NO;
#endif

    if ( [*defaults[kUnlockCommand] length] > 1 )
        [unlockCommand setStringValue:*defaults[kUnlockCommand]];
    playSound.state = defaults[kPlaySound];
    convertAll.state = defaults[kConvertAll];

    [self performSelectorInBackground:@selector(updateScripts:) withObject:nil];

    addresses = [self startServer];

	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(getUrl:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];

    docTile = [[NSApplication sharedApplication] dockTile];
    NSImageView *iv = [[NSImageView alloc] init];
    [iv setImage:[[NSApplication sharedApplication] applicationIconImage]];
    [docTile setContentView:iv];

    progressIndicator = [[NSProgressIndicator alloc]
                                              initWithFrame:NSMakeRect(0.0f, 0.0f, docTile.size.width, 10.)];
    [progressIndicator setStyle:NSProgressIndicatorBarStyle];
    [progressIndicator setIndeterminate:NO];
    [iv addSubview:progressIndicator];

    [progressIndicator setBezeled:YES];
    [progressIndicator setMinValue:0];
    [progressIndicator setMaxValue:1];
    [progressIndicator release];

    [self setProgress:[NSNumber numberWithFloat:-1]];
    [NSColor setIgnoresAlpha:NO];
}

- (void)setProgress:(NSNumber *)fraction {
    if ( [fraction floatValue] < 0 )
        [progressIndicator setHidden:YES];
    else {
        [progressIndicator setDoubleValue:[fraction floatValue]];
        [progressIndicator setHidden:NO];
    }
    [docTile display];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [[NSDocumentController sharedDocumentController] 
     closeAllDocumentsWithDelegate:nil didCloseAllSelector:NULL contextInfo:NULL];
    defaults[kUnlockCommand] = unlockCommand.stringValue;
    defaults[kConvertAll] = convertAll.state;
    defaults[kPlaySound] = playSound.state;
    defaults.sync();
}

#pragma mark Licensing

- (IBAction)license:sender {
    OOString url = appHome+"cgi-bin/sale.cgi?vers="+appVersion+
        @"&inst="+(int)installed+@"&ident="+mac+@"&lkey="+licensed;
    webView.customUserAgent = @"040ccedcacacccedcacac";
    [webView.mainFrame loadRequest:OORequest(url)];
    [webView.window makeKeyAndOrderFront:self];
}

- (void)webView:(WebView *)aWebView decidePolicyForNavigationAction:(NSDictionary *)actionInformation
		request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener {
    OOString url = request.URL.absoluteString;
    [urlLabel setStringValue:url];
    if ( !!url[@"^macappstore:|\\.(dmg|html)"] ) {
        [[NSWorkspace sharedWorkspace] openURL:request.URL];
        [listener ignore];
    }
    else
        [listener use];
    return;
}

- (void)webView:(WebView *)aWebView didReceiveTitle:(NSString *)aTitle forFrame:(WebFrame *)frame {
    if ( frame == aWebView.mainFrame )
        aWebView.window.title = aTitle;
}

- (void)webView:(WebView *)aWebView setFrame:(NSRect)frame {
    float chrome = aWebView.window.frame.size.height - aWebView.frame.size.height;
    frame.size.height -= chrome;
    frame.origin.y += chrome;
    [aWebView.window setFrame:frame display:YES animate:YES];
}

- (NSString *)webView:(WebView *)sender runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WebFrame *)frame {
    INLog(@"blah blah blah... %@ %@ %d", prompt, defaultText, refkey );
    if ( OO"license" == prompt ) {
        [webView.window setStyleMask:webView.window.styleMask | NSClosableWindowMask];
        defaults[kLicensed] = licensed = [defaultText intValue];
        defaults.sync();
    }
    return @"";
}

#pragma mark Menu Items

- (InDocument *)activeDoc {
    InDocument *doc = (InDocument *)[[NSApplication sharedApplication] keyWindow].delegate;
    return [doc isKindOfClass:[InDocument class]] ? doc : nil;
}

- (void)getUrl:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    OOString path = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    if ( [path hasPrefix:appPrefix] ) {
        path = [path[OORangeFrom([appPrefix length])]
                stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        [[self activeDoc] openURL:path/*[OORangeFrom(1)]*/];
    }
}

- (IBAction)listDevice:sender {
    [[self activeDoc] listDevice];
}
- (IBAction)build:sender {
    [[self activeDoc] startBuild:nil];
}
- (IBAction)removeBackups:sender {
    [[self activeDoc] removeBackups:nil];
}
- (IBAction)revertProject:sender {
    [[self activeDoc] revertProject:nil];
}
- (IBAction)reopenProject:sender {
    [[self activeDoc] reopen:nil];
}

#pragma mark Servicing and document open

- (void)backgroundConnectionService {

    INLog( @"Waiting for connections..." );
    while ( TRUE ) {
        socklen_t addrLen = sizeof clientAddr;

        int appConnection = accept( serverSocket, (struct sockaddr *)&clientAddr, &addrLen );
        if ( appConnection < 0 )
            continue;

        struct _in_header header;
        char path[PATH_MAX];
        OOPool pool;

        [BundleInjection readHeader:&header forPath:path from:appConnection];

        newDoc = nil;
        if ( header.dataLength == INJECTION_MAGIC )
            [self performSelectorOnMainThread:@selector(open:)
                                   withObject:OOFile(path) waitUntilDone:YES];
        else
            NSLog( @"Bogus connection attempt." );

        int status = newDoc ? 1 : 0;
        write( appConnection, &status, sizeof status );

        if ( newDoc ) {
            [BundleInjection readHeader:&header forPath:path from:appConnection];
            if ( header.dataLength == INJECTION_MAGIC )
                [newDoc connected:appConnection binPath:path];
            else
                NSLog( @"Bogus connection attempt." );
        }
        else
            close( appConnection );
    }
}

- (void)open:(NSURL *)url {
    OOPool pool;
    NSError *error = nil;
    newDoc = [[NSDocumentController sharedDocumentController]
              openDocumentWithContentsOfURL:url display:YES error:&error];
    //if ( error )
    //    [self error:@"Could not open \"%@\" as: %@", url, error.localizedDescription];
}

- (IBAction)openDemo:sender {
    OOFile path = scriptRoot+@"StoryboardDemo/StoryboardDemo.xcodeproj";
    if ( !path.exists() )
        [self performSelector:_cmd withObject:self afterDelay:1.];
    else {
        [self open:path];
        [self open:OOFile(scriptRoot+@"InjectionDemo/InjectionDemo.xcodeproj")];
    }
}

#pragma mark Menu items

- (void)openPath:(NSString *)path {
    [[NSWorkspace sharedWorkspace] openURL:OOFile(path)];
}
- (void)openResource:(const char *)res {
    [self openPath:scriptRoot+"/"+res];
}

- (IBAction)openOSXTemplate:sender {
    [self openResource:"OSXBundleTemplate/InjectionBundle.xcodeproj"];
}
- (IBAction)openiOSTemplate:sender {
    [self openResource:"iOSBundleTemplate/InjectionBundle.xcodeproj"];
}
- (IBAction)openNewProjectScript:sender {
    [self openResource:"openProject.pl"];
}
- (IBAction)openBuildBundleScript:sender {
    [self openResource:"prepareBundle.pl"];
}
- (IBAction)openCloseProjectScript:sender {
    [self openResource:"revertProject.pl"];
}
- (IBAction)openListDeviceScript:sender{
    [self openResource:"listDevice.pl"];
}
- (IBAction)openBundleScript:sender{
    [self openResource:"openBundle.pl"];
}
- (IBAction)openURLScript:sender{
    [self openResource:"openURL.pl"];
}
- (IBAction)openCommonScript:sender {
    [self openResource:"common.pm"];
}
- (IBAction)openCommonCode:sender {
    [self openResource:"BundleInjection.h"];
}
- (IBAction)openInterface:sender {
    [self openResource:"BundleInteface.h"];
}

- (void)openURL:(NSString *)url {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}

- (IBAction)openHelp:sender {
    [self openURL:appHome+@"help.html"];
}

- (IBAction)feedback:sender {
#ifdef FOR_APP_STORE
    [self openURL:@"mailto:injection@johnholdsworth.com?subject=Injection%20Feedback"];
#else
    [self openURL:@"mailto:support@injectionforxcode.com?subject=Injection%20Feedback"];
#endif
}

- (IBAction)find:sender {
    [find.window close];
    [[self activeDoc] find:find.stringValue];;
}

- (IBAction)zap:sender {
    system( "rm -rf ~/Library/Developer/Xcode/DerivedData/*" );
}

@end
