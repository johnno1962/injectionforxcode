//
//  $Id: //depot/InjectionPluginLite/Classes/INPluginMenuController.m#57 $
//  InjectionPluginLite
//
//  Created by John Holdsworth on 15/01/2013.
//  Copyright (c) 2012 John Holdsworth. All rights reserved.
//
//  Manages interactions with Xcode's product menu and runs TCP server.
//
//  This file is copyright and may not be re-distributed, whole or in part.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "INPluginMenuController.h"
#import "INPluginClientController.h"
#import "FileWatcher.h"

#define MIN_CHANGE_INTERVAL 1.5

static NSString *kINShortcut = @"INShortcut", *kINFileWatch = @"INFileWatch";

@interface DBGLLDBSession : NSObject
- (void)requestPause;
- (void)requestContinue;
- (void)evaluateExpression:(id)a0 threadID:(unsigned long)a1 stackFrameID:(unsigned long)a2 queue:(id)a3 completionHandler:(id)a4;
- (void)executeConsoleCommand:(id)a0 threadID:(unsigned long)a1 stackFrameID:(unsigned long)a2 ;
@end

static INPluginMenuController *injectionPlugin;

@interface INPluginMenuController()  <NSNetServiceDelegate> {

    IBOutlet NSTextField *urlLabel, *shortcut;
    IBOutlet NSMenuItem *subMenuItem, *introItem, *injectAndReset;
    IBOutlet NSButton *watchButton;
    IBOutlet WebView *webView;
    NSMenuItem *menuItem;

    Class IDEWorkspaceWindowController;
    Class DVTSourceTextView;
    Class IDEWorkspaceDocument;
    Class IDEConsoleTextView;

    int serverSocket;

    NSTimeInterval lastChanged;
    int skipLastSaved;
    time_t installed;
    int licensed;
    int refkey;
}

@property (nonatomic,retain) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic,retain) IBOutlet INPluginClientController *client;
@property (nonatomic,retain) IBOutlet NSPanel *webPanel;
@property (nonatomic,retain) IBOutlet NSMenu *subMenu;
@property (nonatomic,retain) NSUserDefaults *defaults;
@property (nonatomic,retain) NSMutableString *mac;
@property (nonatomic,retain) NSString *bonjourName;

@property (nonatomic,retain) NSWindow *lastKeyWindow;
@property (nonatomic,retain) FileWatcher *fileWatcher;
@property (nonatomic,retain) NSString *lastFile;
@property (nonatomic) BOOL hasSaved;
@property (nonatomic) int continues;

@end

@implementation INPluginMenuController

#pragma mark - Plugin Initialization

+ (void)pluginDidLoad:(NSBundle *)plugin {
    if ([[NSBundle mainBundle].infoDictionary[@"CFBundleName"] isEqual:@"Xcode"]) {
        static dispatch_once_t onceToken;
        dispatch_once( &onceToken, ^{
            injectionPlugin = [[self alloc] init];
            //NSLog( @"Preparing Injection: %@", injectionPlugin );
            dispatch_async( dispatch_get_main_queue(), ^{
                [injectionPlugin applicationDidFinishLaunching:nil];
            } );
        } );
    }
}

+ (void)evalCode:(NSString *)code {
    if( !injectionPlugin.client.connected )
        [injectionPlugin error:@"Injection has not connected, please restart app"];
    else
        [injectionPlugin.client runScript:@"evalCode.pl" withArg:code];
}

+ (BOOL)loadXprobe:(NSString *)resourcePath {
    if ( injectionPlugin.client.connected ) {
        [injectionPlugin.client runScript:@"xprobeLoad.pl" withArg:resourcePath];
        return YES;
    }
    else
        return NO;
}

+ (BOOL)loadRemote:(NSString *)resourcePath {
    return [self loadXprobe:resourcePath];
}

- (void)error:(NSString *)format, ... {
    va_list argp;
    va_start(argp, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:argp];
    [self.client performSelectorOnMainThread:@selector(alert:) withObject:message waitUntilDone:NO];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSMenu *productMenu = [[[NSApp mainMenu] itemWithTitle:@"Product"] submenu];
    if ( !productMenu ) {
        [self performSelector:@selector(applicationDidFinishLaunching:) withObject:notification afterDelay:1.0];
        return;
    }

    IDEWorkspaceWindowController = NSClassFromString(@"IDEWorkspaceWindowController");
    IDEWorkspaceDocument = NSClassFromString(@"IDEWorkspaceDocument");
    DVTSourceTextView = NSClassFromString(@"DVTSourceTextView");
    IDEConsoleTextView = NSClassFromString(@"IDEConsoleTextView");

    if ( ![NSBundle loadNibNamed:@"INPluginMenuController" owner:self] )
        if ( [[NSAlert alertWithMessageText:@"Injection Plugin:"
                              defaultButton:@"OK" alternateButton:@"Goto GitHub" otherButton:nil
                  informativeTextWithFormat:@"Could not load interface nib. If problems persist, "
               "please download from GitHub, build clean then rebuild from the sources. "
               "This will install the plugin."] runModal] == NSAlertAlternateReturn )
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/johnno1962/injectionforxcode"]];

    self.defaults = [NSUserDefaults standardUserDefaults];

    NSString *currentShortcut = [self.defaults valueForKey:kINShortcut] ?: shortcut.stringValue;
    [shortcut setStringValue:currentShortcut];

    if ( [self.defaults valueForKey:kINFileWatch] )
        watchButton.state = [self.defaults boolForKey:kINFileWatch];

    [productMenu addItem:[NSMenuItem separatorItem]];

    struct { const char *item,  *key; SEL action; } items[] = {
        {"Injection Plugin", "", NULL},
        {"Inject Source", [currentShortcut UTF8String], @selector(injectSource:)}
    };

    for ( int i=0 ; i<sizeof items/sizeof items[0] ; i++ ) {
        menuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithUTF8String:items[i].item]
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
                                             selector:@selector(workspaceDidChange:)
                                                 name:NSWindowDidBecomeKeyNotification object:nil];

    [injectAndReset setKeyEquivalent:currentShortcut];

    self.progressIndicator.frame = NSMakeRect(60, 20, 200, 10);
    webView.drawsBackground = NO;
    [self setProgress:@-1];
    [self startServer];
}

- (IBAction)shortcutChanged:sender {
    [self.defaults setValue:shortcut.stringValue forKey:kINShortcut];
    [self.defaults synchronize];
    [menuItem setKeyEquivalent:shortcut.stringValue];
    [injectAndReset setKeyEquivalent:shortcut.stringValue];
}

- (IBAction)watchChanged:sender {
    [self.defaults setBool:watchButton.state forKey:kINFileWatch];
    [self.defaults synchronize];
    if ( self.client.connected )
        [self enableFileWatcher:YES];
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

- (void)workspaceDidChange:(NSNotification *)notification {
    NSWindow *object = [notification object];
    NSWindowController *currentWindowController = [object windowController];
    if ( [currentWindowController isKindOfClass:IDEWorkspaceWindowController] &&
        [[currentWindowController document] fileURL] )
        self.lastKeyWindow = object;
}

- (NSWindowController *)lastController {
    return [self.lastKeyWindow windowController];
}

- (id)lastEditor {
    return [[self lastController] valueForKeyPath:@"editorArea.lastActiveEditorContext.editor"];
}

- (NSTextView *)lastTextView {
    id currentEditor = [self lastEditor];
    if ( [currentEditor respondsToSelector:@selector(textView)] )
        return [currentEditor textView];
    else
        return nil;
}

- (NSString *)lastFileSaving:(BOOL)save {
    NSDocument *doc = [[self lastEditor] document];
    if ( save ) {
        if ( [doc isDocumentEdited] ) {
            self.hasSaved = FALSE;
            skipLastSaved = 1;
            [doc saveDocumentWithDelegate:self
                          didSaveSelector:@selector(document:didSave:contextInfo:)
                              contextInfo:NULL];
        }
        else
            self.hasSaved = TRUE;
        [self setupLicensing];
    }
    return [[doc fileURL] path];
}

- (void)document:(NSDocument *)doc didSave:(BOOL)didSave contextInfo:(void  *)contextInfo {
    self.hasSaved = TRUE;
}

- (BOOL)lastFileContains:(NSString *)string {
    NSURL *url = [NSURL fileURLWithPath:[self lastFileSaving:NO]];
    NSString *source = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:NULL];
    return [source rangeOfString:string].location != NSNotFound;
}

- (NSString *)buildDirectory {
    return [self.lastTextView valueForKeyPath:@"window.delegate.workspace.executionEnvironment.workspaceArena.buildFolderPath.pathString"];
}

- (NSString *)logDirectory {
    return [self.lastController valueForKeyPath:@"workspace.executionEnvironment.logStore.rootDirectoryPath"];
}

- (NSString *)workspacePath {
    return [[[[self debugController] document] fileURL] path];
//    id delegate = [[NSApp keyWindow] delegate];
//    if ( ![delegate respondsToSelector:@selector(document)] )
//        delegate = [[self.lastTextView window] delegate];
//    if ( ![delegate respondsToSelector:@selector(document)] )
//        delegate = [self.lastKeyWindow delegate];
//    NSDocument *workspace = [delegate document];
//    return [workspace isKindOfClass:IDEWorkspaceDocument] ?
//        [[workspace fileURL] path] : nil;
}

- (BOOL)validateMenuItem:(NSMenuItem *)aMenuItem {
    SEL action = [aMenuItem action];
    if ( action == @selector(injectSource:) ) {
//        NSString *workspace = [self workspacePath];
//        NSRange range = [workspace rangeOfString:@"([^/]+)(?=\\.(?:xcodeproj|xcworkspace))"
//                                         options:NSRegularExpressionSearch];
//
//        if ( workspace && range.location != NSNotFound )
//            subMenuItem.title = [workspace substringWithRange:range];
//        else
            subMenuItem.title = @"Injection Plugin";
    }
    if ( action == @selector(patchProject:) || action == @selector(revertProject:) )
        return [self workspacePath] != nil;
    else if ( [aMenuItem action] == @selector(listDevice:) )
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

- (DBGLLDBSession *)sessionForController:(NSWindowController *)controller {
    return [controller valueForKeyPath:@"workspace"
            ".executionEnvironment.selectedLaunchSession.currentDebugSession"];
}

- (NSWindowController *)debugController {
    NSWindowController *controller = [self lastController];
    if ( [self sessionForController:controller] )
        return controller;

    for ( NSWindow *win in [NSApp windows] ) {
        controller = [win windowController];
        if ( [controller isKindOfClass:IDEWorkspaceWindowController] &&
            [self sessionForController:controller] )
            return controller;
    }

    return [self lastController];
}

- (DBGLLDBSession *)session {
    return [self sessionForController:[self debugController]];
}

- (IBAction)injectSource:(id)sender {
    if ( [sender isKindOfClass:[NSMenuItem class]] || [sender isKindOfClass:[NSButton class]] )
        self.lastFile = [self lastFileSaving:YES];

    DBGLLDBSession *session = [self session];
    //NSLog( @"injectSource: %@ %@", sender, session );
    if ( !session && !sender ) {
        return;
    }
    else if ( !session ) {
        [self.client alert:@"No project is running."];
        return;
    }
    else if ( !self.lastFile ) {
//        [self.client alert:@"No source file is selected. "
//         "Make sure that text is selected and the cursor is inside the file you have edited."];
        return;
    }
    else if ( [self.lastFile rangeOfString:@"\\.(mm?|swift|storyboard)$"
                                   options:NSRegularExpressionSearch].location == NSNotFound )
        [self.client alert:@"Only class implementations (.m, .mm, .swift or .storyboard files) can be injected."];
    else if ( [self.lastFile rangeOfString:@"/main\\.mm?$"
                                   options:NSRegularExpressionSearch].location != NSNotFound )
        [self.client alert:@"You can not inject main.m"];
    else if ( !self.hasSaved ) {
        [self performSelector:@selector(injectSource:) withObject:self afterDelay:.01];
        return;
    }
    else if ( ![self workspacePath] )
        [self.client alert:@"No project selected. Make sure the project you are working on is the \"Key Window\"."];
    else if ( !self.client.connected ) {

        // "unpatched" injection
        if ( sender ) {
            self.lastKeyWindow = [self.lastTextView window];
            [session requestPause];
            [self performSelector:@selector(loadBundle:) withObject:session afterDelay:.005];
        }
        else
            [self performSelector:@selector(injectSource:) withObject:nil afterDelay:.1];
    }
    else {
        [self.client runScript:@"injectSource.pl" withArg:self.lastFile];
        self.lastFile = nil;
        [self enableFileWatcher:YES];
    }
}

- (void)loadBundle:(DBGLLDBSession *)session {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0), ^{
        NSString *loader = [NSString stringWithFormat:@"expr -l objc++ -O -- "
                            "(void)[[NSClassFromString(@\"NSBundle\")  bundleWithPath:"
                            "@\"%@/InjectionLoader.bundle\"] load]\r", self.client.scriptPath];
        [session executeConsoleCommand:loader threadID:1 stackFrameID:0];
        dispatch_async(dispatch_get_main_queue(), ^{
            [session requestContinue];
            [self injectSource:nil];
        });
    });
}

- (IBAction)injectWithReset:(id)sender {
    self.client.withReset = YES;
    [self injectSource:sender];
}

- (void)enableFileWatcher:(BOOL)enabled {
    if ( enabled && watchButton.state ) {
        if ( !self.fileWatcher ) {
            static NSRegularExpression *regexp;
            if ( !regexp )
                regexp = [[NSRegularExpression alloc] initWithPattern:@"^(.+?/([^/]+))/(([^/]*)\\.(xcodeproj|xcworkspace|(idea/misc.xml)))" options:0 error:nil];

            NSString *workspacePath = [self workspacePath];
            NSRange range = [regexp rangeOfFirstMatchInString:workspacePath options:0
                                                        range:NSMakeRange( 0, workspacePath.length )];

            NSString *projectRoot = [[workspacePath substringWithRange:range] stringByDeletingLastPathComponent];
            [self.fileWatcher = [[FileWatcher alloc] initWithRoot:projectRoot plugin:^( NSArray *filesChanged ) {
                NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
                if ( --skipLastSaved < 0 && now - lastChanged > MIN_CHANGE_INTERVAL ) {
                    self.lastFile = filesChanged[0];
                    self.hasSaved = YES;
                    [self injectSource:self];
                    lastChanged = now;
                }
            }] release];
        }
    }
    else
        self.fileWatcher = nil;
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
    //INLog( @"%@ %@", [INJECTION_BRIDGE(NSData *)copy_mac_address() description], _bonjourName);
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
    else if ( fcntl(serverSocket, F_SETFD, FD_CLOEXEC) < 0 )
        [self error:@"Could not set close exec: %s", strerror( errno )];
    else if ( setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof optval) < 0 )
        [self error:@"Could not set socket option: %s", strerror( errno )];
    else if ( setsockopt( serverSocket, IPPROTO_TCP, TCP_NODELAY, (void *)&optval, sizeof(optval)) < 0 )
        [self error:@"Could not set socket option: %s", strerror( errno )];
    else if ( bind( serverSocket, (struct sockaddr *)&serverAddr, sizeof serverAddr ) < 0 )
        [self error:@"Could not bind service socket: %s. "
         "Kill any \"ibtoold\" processes and restart.", strerror( errno )];
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

    INLog( @"Injection: Waiting for connections..." );
    while ( TRUE ) {
        struct sockaddr_in clientAddr;
        socklen_t addrLen = sizeof clientAddr;

        int appConnection = accept( serverSocket, (struct sockaddr *)&clientAddr, &addrLen );
        if ( appConnection > 0 ) {
            NSLog( @"Injection: Connection from %s:%d",
                  inet_ntoa( clientAddr.sin_addr ), clientAddr.sin_port );
            [self.client setConnection:appConnection];
        }
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
    if ( refkey || stat( "/Applications/Objective-C++.app/Contents/Resources/InjectionPluginLite", &tstat ) == 0 )
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
