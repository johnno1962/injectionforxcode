//
//  InInjectionPlugin.m
//  InjectionPlugin
//
//  Created by John Holdsworth on 19/09/2012.
//
//

#define INJECTION_NOIMPL

#import "InInjectionPlugin.h"
#import "InPluginDocument.h"

static NSString *kConvert = @"INConvertAll", *kUnlock = @"INUnlockCommand", *kInPlace = @"INInPlace";

InInjectionPlugin *inInjectionPlugin;

@implementation InInjectionPlugin

@synthesize parameters, console, alert, error, menu, status, textView;

#pragma mark - Plugin Initialization

+ (void)pluginDidLoad:(NSBundle *)plugin {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		inInjectionPlugin = [[self alloc] init];
        NSLog( @"Loading InInjectionPlugin: %p", inInjectionPlugin );
	});
}

static OOString installer = @"/Applications/Injection Plugin.app/Contents/";
#import "BundleInterface.h"

#ifndef WEB_PLUGIN
#ifdef INJECTION_UNSIGNED
NSString *global_bundleVersion = @"X.X";
static int checkSemaphores( NSString *str ) { return 1; }
#else
static NSString *global_bundleIdentifier = @INJECTION_PLUGIN;
static NSString *global_bundleVersion = @INJECTION_VERSION;
#import "../../Injection/Injection/validatereceipt.m"
#endif
#else
// Returns a CFData object, containing the machine's GUID.
CFDataRef copy_mac_address(void)
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
#endif

- (id)init {
	if (self = [super init]) {

#ifndef WEB_PLUGIN
        if ( !checkSemaphores( installer+@"/_MASReceipt/receipt" ) )
            switch ( [[NSAlert alertWithMessageText:INJECTION_APPNAME+OO" Error:"
                                      defaultButton:@"OK" alternateButton:@"Remove" otherButton:@"Update"
                          informativeTextWithFormat:@"Using the %s Plugin requires version %@ of the application "
                       "\"%s Plugin\" to have been installed from the Mac App Store onto this machine.",
                       INJECTION_APPNAME, global_bundleVersion, INJECTION_APPNAME] runModal] ) {
                case NSAlertAlternateReturn:
                    system( "\\rm -r ~/Library/Application\\ Support/Developer/Shared/Xcode/Plug-ins/InjectionPlugin.xcplugin" );
                    break;
                case NSAlertOtherReturn:
                    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://injection.johnholdsworth.com/plugin.html"]];
                    break;
            }
        else
#endif
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching:)
                                                         name:NSApplicationDidFinishLaunchingNotification object:nil];

        IDEWorkspaceDocument = NSClassFromString(@"IDEWorkspaceDocument");
        DVTSourceTextView = NSClassFromString(@"DVTSourceTextView");
	}
	return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    if ( ![NSBundle loadNibNamed:@"InInjectionPlugin" owner:self] )
        [self alert:@"InInjectionPlugin: Could not load interface."];

	NSMenuItem *editMenuItem = [[NSApp mainMenu] itemWithTitle:@"Product"];
	if (editMenuItem) {
		[[editMenuItem submenu] addItem:[NSMenuItem separatorItem]];

        static struct { NSString *item,  *key; SEL action; } items[] = {
            {@"Injection", @"", NULL},
            {@"Inject Source", @"=", @selector(inject:)}
        };

        for ( int i=0 ; i<sizeof items/sizeof items[0] ; i++ ) {
            NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:items[i].item
                                                               action:items[i].action
                                                        keyEquivalent:items[i].key] autorelease];
            if ( i==0 )
                [subMenu = menuItem setSubmenu:menu];
            else
                [menuItem setTarget:self];
            [[editMenuItem submenu] addItem:menuItem];
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(selectionDidChange:)
                                                     name:NSTextViewDidChangeSelectionNotification object:nil];
	}
    else
        [self alert:@"InInjectionPlugin: Could not locate Product Menu."];
}

- (void)awakeFromNib {
    appRoot = [[NSBundle bundleForClass:[self class]] resourcePath]+OO"/";
    appPrefix = @"file://"; //*info["CFBundleURLTypes"][0]["CFBundleURLSchemes"][0]+@":"+getpid()+@":";
    appVersion = INJECTION_VERSION; //info[kCFBundleVersionKey];
    //clunk = [NSSound soundNamed:@"clunk"];
    scriptRoot = appRoot; //+@"Data/";
    addresses = [self startServer];
    //[NSColor setIgnoresAlpha:NO];
    //resourcePath = installer+@"Resources/";
    //if ( !OOFile(resourcePath).exists() )
        resourcePath = appRoot;

    if ( !!defaults[kUnlock] )
        unlockCommand.stringValue = defaults[kUnlock];
    convertAll.state = defaults[kConvert];
    inPlace.state = defaults[kInPlace];

    progressIndicator = [[NSProgressIndicator alloc]
                         initWithFrame:NSMakeRect(60, 20, 200, 10)];
    [progressIndicator setStyle:NSProgressIndicatorBarStyle];
    [progressIndicator setIndeterminate:NO];
    [progressIndicator setBezeled:YES];
    [progressIndicator setMinValue:0];
    [progressIndicator setMaxValue:1];
    webView.drawsBackground = NO;
    [self setProgress:@-1];
}

#pragma mark - Text Selection Handling

- (void)selectionDidChange:(NSNotification *)notification {
    id object = [notification object];
	if ([object isKindOfClass:DVTSourceTextView] &&
        [object isKindOfClass:[NSTextView class]] &&
        [[object delegate] respondsToSelector:@selector(document)])
        self.textView = object;
}

- (NSDocument *)lastSelected {
    return [(id)[textView delegate] document];
}

- (NSString *)xcodeProjPath:(NSDocument *)doc {
    OOString path = [[doc fileURL] path], ext = [path pathExtension];
    if ( ext == @"xcodeproj" )
        return path;
    else if ( OO [path lastPathComponent] == @"project.xcworkspace" )
        return [path stringByDeletingLastPathComponent];
    else if ( ext == @"xcworkspace" ) // CocoaPods
        return [[path stringByDeletingPathExtension] stringByAppendingString:@".xcodeproj"];
    else
        return nil;
}

- (NSString *)projectPath {
    id delegate = [[NSApp keyWindow] delegate];
    if ( ![delegate respondsToSelector:@selector(document)] )
        delegate = [[textView window] delegate];
    NSDocument *workspace = [delegate document];
    return [workspace isKindOfClass:IDEWorkspaceDocument] ?
        [self xcodeProjPath:workspace] : nil;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    NSString *projectPath = [self projectPath];
    if ([menuItem tag] == 1)
        return TRUE;
    else if ([menuItem action] == @selector(inject:)) {
        if ( projectPath )
            subMenu.title = [[projectPath lastPathComponent] stringByDeletingPathExtension];
        else
            subMenu.title = @"Injection";
        INLog( @"%@ %@ %@ %@ %@", [textView window], [NSApp keyWindow],
              projectPath, *projects[projectPath], *projects );
        return
            !!OOString(self.lastSelected.fileURL.path)[@"\\.mm?$"] &&
            [projects[projectPath] connected];
    }
    else if ( [menuItem tag] == 3 )
        return !!projects[projectPath];
    else
        return projectPath != nil;
}

#pragma mark - Actions

- (void)alert:(NSString *)msg {
    msgField.stringValue = msg;
    [alert orderFront:self];
}

- (void)buildError {
    [error orderFront:self];
}

- (void)startProgress {
    NSView *scrollView = [[textView superview] superview];
    [scrollView addSubview:progressIndicator];
}

- (BOOL)isOpen:(cOOString)project {
    OOArray<NSDocument *> docs = [[NSDocumentController sharedDocumentController] documents];
    for ( int i=0 ; i<docs ; i++ )
        if ( [docs[i] isKindOfClass:IDEWorkspaceDocument] &&
            [self xcodeProjPath:docs[i]] == project )
            return YES;
    return NO;
}

static const NSString *kInstalled = @"INInstalled", *kLicensed = @"INLicensed2.x";

- (void)setDelegates {
    installed = defaults[kInstalled], now = time(NULL);
    if ( !installed ) {
        defaults[kInstalled] = installed = now;
        defaults.sync();
        //[self performSelector:@selector(openDemo:) withObject:self afterDelay:2.];
    }

    struct stat st;
    if ( stat( "/Applications/Injection Plugin.app/Contents/", &st ) == 0 &&
        st.st_ctimespec.tv_sec < installed ) {
        defaults[kInstalled] = installed = st.st_ctimespec.tv_sec;
        defaults.sync();
    }
    INLog( @"TIMES: %d %d", (int)st.st_ctimespec.tv_sec, (int)installed );

    OOData addr = OO_BRIDGE(NSData *)copy_mac_address();
    int skip = 2, len = [addr length]-skip;
    unsigned char *bytes = (unsigned char *)[addr bytes]+skip;

    mac.alloc();
    for ( int i=0 ; i<len ; i++ ) {
        //bytes[i]++;
        [mac appendFormat:@"%02x", 0xff-bytes[i]];
        refkey ^= 365-mac[i*2]<<i*6;
        refkey ^= 365-mac[i*2+1]<<i*6+3;
        //INLog( @"%d", refkey );
    }
    OO_RELEASE(addr);

    licensed =  defaults[kLicensed];
    INLog( @"%d %d %d %d", licensed, refkey, (int)installed, (int)time(NULL) );
    if ( licensed != refkey ) {
        if ( now < installed + 17*24*60*60+60 )
            licensed = refkey = 1;
        else
            [self license:nil];
    }
}

- (IBAction)license:sender {
    if ( !refkey )
        [self setDelegates];
    [super license:sender];
}

- (NSString *)webView:(WebView *)sender runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WebFrame *)frame {
    INLog(@"License install... %@ %@ %d", prompt, defaultText, refkey );
    if ( OO"license" == prompt ) {
        [webView.window setStyleMask:webView.window.styleMask | NSClosableWindowMask];
        defaults[kLicensed] = licensed = [defaultText intValue];
        defaults.sync();
    }
    return @"";
}

- (void)open:(NSURL *)url {
#ifdef WEB_PLUGIN
    if ( !refkey )
        [self setDelegates];
#endif
    if ( !url )
        NSLog( @"-[InInjectionPlugin<%p> open:] NO URL %@", self, self.textView );
    else if ( ![self isOpen:url.path] )
        [self alert:OOFormat(@"Connection from app at %s with unopened project: %@",
                             inet_ntoa(clientAddr.sin_addr), url.path)];
    else if ( !(newDoc = projects[url.path]) )
        newDoc = projects[url.path] = [[InPluginDocument alloc]
                                       initWithContentsOfURL:url
                                       ofType:@"xcodeproj" error:NULL];
    if ( newDoc == OONull ) { /////
        ~projects[url.path];
        newDoc = nil;
    }
}

- (IBAction)convert:sender {
    NSString *projectPath = [self projectPath];
    [console orderFront:sender];
    if ( !projects[projectPath] )
        [self open:OOFile(projectPath)];
    else
        [projects[projectPath] reopen:sender];
}

- (IBAction)revert:sender {
    NSString *projectPath = [self projectPath];
    [self open:OOFile(projectPath)];
    [projects[projectPath] revertProject:sender];
    ~projects[projectPath];/////////// close];
    newDoc = nil;
}

- (IBAction)inject:sender {
    NSString *projectPath = [self projectPath];
    if ( !(lastFile = [[self.lastSelected fileURL] path]) )
        return;
    INLog( @"inject: %@ %@ %@", [sender title], projectPath, *lastFile );
    [self open:OOFile(projectPath)];
    [self.lastSelected saveDocument:sender];
    [projects[projectPath] filesChanged:@[lastFile]];
    ~lastFile;
}

- (InPluginDocument *)relatedProject {
    NSString *projectPath = [self projectPath];
    if ( projectPath )
        [self open:OOFile(projectPath)];
    return projects[projectPath];
}

- (IBAction)shadow:sender {
    NSString *file = [[self.lastSelected fileURL] path];
    if ( file )
        [[self relatedProject] runScript:@"openShadow.pl"
                               extraArgs:@[file]];
}

- (IBAction)bundle:sender {
    [error orderOut:sender];
    [[self relatedProject] openBundleProject:sender];
}

- (IBAction)listDevice:sender {
    [error orderOut:sender];
    [[self relatedProject] listDevice];
    [status orderFront:self];
}

- (IBAction)status:sender {
    [self relatedProject];
    [status orderFront:sender];
}

- (void)special:(NSString *)key {
    InDocument *proj = [self relatedProject];
    if ( !proj )
        return;
    else if ( !proj->keyFiles[key] )
        [self performSelector:_cmd withObject:key afterDelay:1.];
    else
        [[NSWorkspace sharedWorkspace] openURL:OOFile(proj->keyFiles[key])];
}

- (IBAction)main:(id)sender {
    [self special:@"MAIN"];
}

- (IBAction)pch:(id)sender {
    [self special:@"PCH"];
}

- (IBAction)intro:(id)sender {
    [webView.mainFrame loadRequest:OORequest(appHome+@"plugintro.html")];
    [webView.window orderFront:self];
}

#pragma mark - Parameters

- (IBAction)slid:(NSSlider *)sender {
    [[self relatedProject] slid:sender];
}

- (IBAction)maxd:(NSTextField *)sender {
    [[self relatedProject] maxd:sender];
}

- (IBAction)colorChanged:(NSColorWell *)sender {
    [[self relatedProject] colorChanged:sender];
}

- (IBAction)imageChanged:(InImageView *)sender {
    [[self relatedProject] imageChanged:sender];
}

- (IBAction)unlockChanged:(NSTextField *)sender  {
    defaults[kUnlock] = unlockCommand.stringValue;
}

- (IBAction)convertChanged:(NSButton *)sender {
    defaults[kConvert] = convertAll.state;
}

- (IBAction)inplaceChanged:(NSButton *)sender {
    defaults[kInPlace] = inPlace.state;
}

- (BOOL)windowShouldClose:(id)sender {
    [sender orderOut:sender];
    return NO;
}

- (void)webView:(WebView *)aWebView decidePolicyForNavigationAction:(NSDictionary *)actionInformation
		request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener {
    if ( aWebView == webView ) {
        OOString url = request.URL.absoluteString;
        [urlLabel setStringValue:url];
        if ( !!url[@"^macappstore:|\\.(dmg|zip)"] ) {
            [[NSWorkspace sharedWorkspace] openURL:request.URL];
            [listener ignore];
        }
        else
            [listener use];
        return;
    }

    OOString path = request.URL.absoluteString;
    if ( ![path hasPrefix:appPrefix] ) {
        [listener use];
        return;
    }

    INLog( @"Clicked link: %@", *path );
    path = [path[OORangeFrom([appPrefix length])]
            stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [[self relatedProject] openURL:path];
    [listener ignore];
}

#pragma mark -

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

@end
