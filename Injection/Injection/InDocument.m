//
//  InDocument.m
//  Injection
//
//  Created by John Holdsworth on 15/01/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "InDocument.h"

@implementation InDocument

static const NSString *kExecPaths = @"IN_binaries", *kParams = @"IN_paramValues", *kColors = @"IN_wellColors";
static char colorFormat[] = {"%f,%f,%f,%f"};

static InDocument *welcomeDoc;

+ (BOOL)autosavesInPlace {
    return NO;
}

- (BOOL)isDocumentEdited {
    return NO;
}

- (NSString *)displayName {
    return !self.fileURL ? @"Welcome to Injection" : [super displayName];
}

- (NSString *)windowNibName {
    return !self.fileURL ? @"InWelcome" : @"InDocument";
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper ofType:(NSString *)typeName error:(NSError **)outError {
    return YES;
}

- (void)setState:(NSString *)image {
    [buildButton performSelectorOnMainThread:@selector(setImage:)
                                  withObject:[NSImage imageNamed:clientSocket ?
                                                          image : @"grey.png"] waitUntilDone:NO];
}

- (void)connected:(int)diff {
    owner->connected += diff;
    [[[NSApplication sharedApplication] dockTile] 
     performSelectorOnMainThread:@selector(setBadgeLabel:)
     withObject:owner->connected ?
     (scriptOutput&&0?OO"Build: ":OO"")+owner->connected : OOString( OONil ) waitUntilDone:NO];
}

- (void)pasteRTF:(NSString *)rtf {
#if 0
    NSAttributedString *as2 = [[NSAttributedString alloc]
                               initWithRTF:(OO"{"+rtf+"\\line}").utf8Data() documentAttributes:nil];
    [textView insertText:as2];
    OO_RELEASE( as2 );
#else
    NSString *save = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
    [[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObjects:NSPasteboardTypeString, NSPasteboardTypeRTF, nil] owner:self];
    [[NSPasteboard generalPasteboard] setString:OO"{"+rtf+"\\line}" forType:NSPasteboardTypeRTF];
    [textView setSelectedRange:NSMakeRange(textView.string.length, 0)];
    [textView pasteAsRichText:self];
    [[NSPasteboard generalPasteboard] setString:save forType:NSPasteboardTypeString];
#endif
}

- (void)scriptText:(cOOString)text {
    [self performSelectorOnMainThread:@selector(pasteRTF:) withObject:text waitUntilDone:YES];
}

#ifndef FOR_PLUGIN
#define HELPER
#endif

#ifdef HELPER
- (int)localConnect {
    static struct sockaddr_in localAddr, loaderAddr;
    if ( !localAddr.sin_family  ) {
        localAddr.sin_family = loaderAddr.sin_family = AF_INET;
        loaderAddr.sin_addr.s_addr = loaderAddr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        localAddr.sin_port = 0; loaderAddr.sin_port = htons(INJECTION_PORT+1);
    }

restart:
    int loaderSocket, retry = 0, optval = 1;
retry:
    if ( (loaderSocket = socket(AF_INET, SOCK_STREAM, 0)) < 0 )
        [owner error:@"Could not open socket for help: %s", strerror( errno )];
	else if ( bind( loaderSocket, (struct sockaddr *)&localAddr, sizeof localAddr ) < 0 )
		[owner error:@"Could not bind helper socket: %s", strerror( errno )];
    else if ( setsockopt( loaderSocket, IPPROTO_TCP, TCP_NODELAY, (void *)&optval, sizeof(optval)) < 0 )
        [owner error:@"Could not set TCP_NODELAY: %s", strerror( errno )];
    else while ( retry<5 && connect( loaderSocket, (struct sockaddr *)&loaderAddr, sizeof loaderAddr ) < 0 ) {
        [NSThread sleepForTimeInterval:.1];
        close( loaderSocket );
        retry++;
        goto retry;
    }

    const char *key = [owner->mac UTF8String];
    if ( write(loaderSocket, key, strlen(key)) < 0 ) {
        [[NSWorkspace sharedWorkspace] openURL:OOURL(@"http://injection.johnholdsworth.com/helper.html")];
        if ( [[NSAlert alertWithMessageText:@"Injection Helper Not Running"
                         defaultButton:@"It's running now" alternateButton:@"Quit" otherButton:nil
             informativeTextWithFormat:@"%@", @"In order for Injection to work it needs a small helper application "
               "running outside the sanddbox to be able to use \"xcodebuild\".  See the opened web page for details "
               "on how to download it and start it running."] runModal] == NSAlertAlternateReturn )
            exit(0);
        close( loaderSocket );
        goto restart;
    }

    write(loaderSocket, "\n", 1);
    return loaderSocket;
}


- (FILE *)hopen:(const char *)command {
    int procSocket = [self localConnect];
    INLog( @"procSocket: %d", procSocket );
    write(procSocket, command, strlen(command));
    write(procSocket, "\n", 1);
    return fdopen( procSocket, "r" );
}
#endif

- (void)runCommand:(NSString *)command {
    if ( owner->licensed != owner->refkey ) {
        [self scriptText:@"This copy of Injection is not curently licensed."];
        [owner license:nil];
        return;
    }

    INLog( @"Running: %@", command );
    if ( scriptOutput ) {
        [self performSelector:_cmd withObject:command afterDelay:.5];
        return;
    }

    scriptOutput = (FILE *)1;
    if ( fileEvents )
        FSEventStreamStop( fileEvents );

    lines = 0, status = 0;
#ifndef HELPER
    if ( (scriptOutput = popen( [command UTF8String], "r" )) == NULL )
#else
    if ( (scriptOutput = [self hopen:[command UTF8String]]) == NULL )
#endif
        [owner error:@"Could not run script: %@", command];
    else
        [self performSelectorInBackground:@selector(monitorScript) withObject:nil];
    [self connected:0];
}

- (int)flags {
    return isDemo ? 1<<0 : 0;
}

- (void)runScript:(cOOString)script extraArgs:(cOOStringArray)extra {
#ifdef DEBUG
    OOString scriptDir = owner->resourcePath;
#else
    OOString scriptDir = owner->scriptRoot;
#endif
    int flags = [self flags];
    if (owner->convertAll.state || isDemo)
        flags |= 1<<1;

    OOString unlock = owner->unlockCommand.stringValue;
#ifndef OPEN_APP_STORE
    unlock[@"\""] = @"\\\"";
#endif

    lastScript = script;
    OOString command = 
#ifdef OPEN_APP_STORE
        "/usr/bin/perl -w -I'/Applications/Injector.app/Contents/Resources/en.lproj/.' -I'"+scriptDir+"' '"+scriptDir+script+"' '"+
#else
        "'"+owner->resourcePath+"runner' '"+scriptDir+"injection.dat' \"'"+
#endif
        owner->resourcePath+"' '"+owner->appVersion+"' '"+owner->appPrefix+"' '"+
        owner->scriptRoot+"' '"+projectPath+"' '"+(executablePath||"")+"' "+
        patchNumber+" '"+unlock+"' "+flags+" '' '' '' '' "+(extra+'\'')/" "+
#ifdef OPEN_APP_STORE
        " 2>&1";
#else
        " 2>&1\" \""+script+"\"";
#endif

    [self runCommand:command];
}

- (NSColor *)parseColor:(cOOString)info {
    if ( !info )
        return nil;
    CGFloat r, g, b, a;
    sscanf( info, colorFormat, &r, &g, &b, &a );
    return [NSColor colorWithDeviceRed:r green:g blue:b alpha:a];
}

- (NSString *)formatColor:(NSColor *)color {
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    return OOFormat( OOString(colorFormat), r, g, b, a );
}

- owner {
    return [NSApplication sharedApplication].delegate;
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
    if ( aController )
        [super windowControllerDidLoadNib:aController];

    owner = [self owner];

    projectPath = self.fileURL.path;
    if ( !projectPath ) {
        NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:appHome+"welcome.html"]];
        [[NSURLCache sharedURLCache] removeCachedResponseForRequest:req];
        [[webView mainFrame] loadRequest:req];
        welcomeDoc = self;
        return;
    }

    if ( !(isDemo = projectPath & @"/((Injection|Storyboard)Demo|UICatalog|(iOS|OSX)GLEssentials)\\.xcodeproj") )
        [welcomeDoc close];
    else if ( projectPath & @"/InjectionDemo.xcodeproj" ) {
        [list close];
        [drawer openOnEdge:NSMinYEdge];
    }

    INLog( @"windowControllerDidLoadNib: %@", *projectPath );
    if( aController ) {
        for ( int i=0 ; i<sizeof vals/sizeof *vals ; i++ ) {
            vals[i]    = [self valueForKey:OO"val"+i];
            sliders[i] = [self valueForKey:OO"slide"+i];
            maxs[i]    = [self valueForKey:OO"max"+i];
            wells[i]   = [self valueForKey:OO"well"+i];
        }

        OOStringArray params = owner->defaults[kParams][projectPath];
        OOStringArray colors = owner->defaults[kColors][projectPath];
        for ( int i=0, p=0 ; params && i<sizeof vals/sizeof *vals ; i++ ) {
            [maxs[i] setStringValue:*params[p++]];
            [sliders[i] setMaxValue:[maxs[i] doubleValue]];
            [sliders[i] setFloatValue:[*params[p++] doubleValue]];
            NSColor *col = i<colors ? [self parseColor:colors[i]] : nil;
            if ( col )
                [wells[i] setColor:col];
        }

        executablePath = owner->defaults[kExecPaths][projectPath];
        autoButton.state = !owner->defaults[projectPath];
        [self setState:@"grey.png"];
    }

    fileFilter = @"\\.(mm?|xib|nib|storyboard)$";
    [self runScript:"openProject.pl" extraArgs:owner->addresses];
}

- (IBAction)panel:sender {
    if ( drawer.state == NSDrawerOpenState ) {
        [drawer close];
        [list openOnEdge:NSMinYEdge];
    }
    else if ( list.state == NSDrawerOpenState ) {
        [list close];
    }
    else {
        [drawer openOnEdge:NSMinYEdge];
        [list close];
    }
}

- (IBAction)find:(NSString *)what {
    [drawer close];
    [list openOnEdge:NSMinYEdge];
    [listView searchFor:what direction:YES caseSensitive:NO wrap:YES];
}

- (void)connected:(int)appConnection binPath:(cOOString)binPath {
#ifndef FOR_PLUGIN
    owner->defaults[kExecPaths][projectPath] =
#endif
    executablePath = binPath;
    INLog( @"Connected: %d binPath: %@", appConnection, *executablePath );
    appName.stringValue = *(executablePath & "[^/]+$")[0];
    [self scriptText:"Connection from: "+executablePath];
    clientSocket = appConnection;

    ~filesChanged;
    //patchNumber = 0;
    [self setState:@"green.png"];

    [self performSelectorInBackground:@selector(connectionMonitor) withObject:nil];
    [self connected:+1];

    [NSThread sleepForTimeInterval:.1];

    reverting = TRUE;
    for ( int i=0 ; i<sizeof vals/sizeof *vals ; i++ ) {
        [self slid:sliders[i]];
        [self colorChanged:wells[i]];
    }
    reverting = FALSE;
}

- (void)connectionMonitor {
    int loaded;

    while( read( clientSocket, &loaded, sizeof loaded ) == sizeof loaded )
        if ( !fdout )
            [self performSelectorOnMainThread:@selector(completed:)
                                   withObject:loaded ? self : nil waitUntilDone:NO];
        else {
            [BundleInjection writeBytes:loaded withPath:NULL from:clientSocket to:fdout];
            close( fdout );
            fdout = 0;
        }

    if ( !clientSocket )
        return;

    [self scriptText:"Disconnected from: "+executablePath];
    [self setState:@"grey.png"];
    close( clientSocket );
    clientSocket = 0;

    [self connected:-1];
}

- (BOOL)connected {
    return clientSocket > 0;
}

- (void)mapSimulator {
    if ( executablePath & @"/iPhone Simulator/" )
        [owner openPath:@"/Developer/Platforms/iPhoneSimulator.platform/Developer/Applications/iPhone Simulator.app"];
}

- (void)completed:success {
    if ( success ) {
        [self setState:@"green.png"];
        [self scriptText:@"\\line Bundle loaded successfully.\\line"];
        [self mapSimulator];
        ~filesChanged;////
    }
    else {
        [self setState:@"red.png"];
        [self scriptText:@"\n\n{\\colortbl;\\red0\\green0\\blue0;\\red255\\green100\\blue100;}\\cb2"
            "*** Bundle load failed ***\\line Consult the Xcode console."];
        [self scriptText:@""];

        if ( [self connected] ) {
            [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
            [textView.window makeKeyAndOrderFront:self];
        }

        if ( owner->playSound.state )
            [owner->clunk play];
    }
}

static void fileCallback( ConstFSEventStreamRef streamRef,
                         void *clientCallBackInfo,
                         size_t numEvents, void *eventPaths,
                         const FSEventStreamEventFlags eventFlags[],
                         const FSEventStreamEventId eventIds[] ) {
    InDocument *self = OO_BRIDGE(InDocument *)clientCallBackInfo;
    [self performSelectorOnMainThread:@selector(filesChanged:)
                           withObject:OO_BRIDGE(id)eventPaths waitUntilDone:NO];
}

- (void)stopFilter {
    if ( fileEvents ) {
        FSEventStreamStop( fileEvents );
        FSEventStreamInvalidate( fileEvents );
        FSEventStreamRelease( fileEvents );
        fileEvents = NULL;
    }
}

- (void)startFilter:(NSArray *)dirs {
    [self stopFilter];

    static struct FSEventStreamContext context;
    context.info = OO_BRIDGE(void *)self;

    fileEvents = FSEventStreamCreate( kCFAllocatorDefault, fileCallback, &context, 
                                     OO_BRIDGE(CFArrayRef)dirs,
                                     kFSEventStreamEventIdSinceNow, .1, 
                                     kFSEventStreamCreateFlagUseCFTypes);
    FSEventStreamScheduleWithRunLoop(fileEvents, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
}

- (void)filesChanged:(NSArray *)changes {
    NSInteger already = [filesChanged count];
    if ( scriptOutput )
        return;

    INLog(  @"filesChanged: %@ - %@", changes, *includes );

#if !defined(HELPER) && !defined(FOR_PLUGIN)
    for ( NSString *dir in changes )
        for ( NSString *_file in &[includes[dir] changed] ) {
#else
        for ( NSString *_file in changes ) {
#endif
            INLog( @"%@ has changed", _file );
            OOString file = _file;

            if ( !!fileFilter && !!file[fileFilter] && !file[@"/BundleContents\\.m$"] ) {
                [self scriptText:"Change to: "+file];
                //if ( (int)filesChanged[file] == NSNotFound )
                filesChanged += file;
            }
            else if ( imageView && file == imageView->imageFile.path() )
                [self imageChanged:imageView];
        }

    if ( [filesChanged count] - already > 0 ) {
        [self setState:@"blue.png"];
        if ( (!autoButton || autoButton.state) && clientSocket )
            [self startBuild:nil];
    }
}

- (void)montorFiles {
    char buff[PATH_MAX];
    while( fgets(buff, sizeof buff, fileStream) ) {
        buff[strlen(buff)-1] = '\000';
        [self filesChanged:OOStringArray(OOString(buff),nil)];
    }
    fclose( fileStream );
    fileStream = NULL;
}

- (void)monitorScript {
    char *file = &buffer[1];
    OOPool pool;

    while ( scriptOutput && fgets( buffer, sizeof buffer-1, scriptOutput ) ) {
        [owner performSelectorOnMainThread:@selector(setProgress:)
                                withObject:[NSNumber numberWithFloat:lines++/50.]
                             waitUntilDone:NO];

        //INLog( @"%lu %s", strlen( buffer ), buffer );
        buffer[strlen(buffer)-1] = '\000';

        switch ( buffer[0] ) {
            case '#':
                switch ( buffer[1] ) {
#ifndef HELPER
                   case '/':
                        ~mdirs;
                        INLog( @"Include: %s", file );
                        OO_RELEASE( includes[file] = [[InDirectory alloc] initPath:file] );
                        break;
                    case '!':
                        INLog( @"Monitor: %s", buffer+2 );
                        mdirs += OOString( buffer+2 );
                        break;
                    case '#':
                        fileFilter = buffer+2;
                        INLog( @"Filter: %@", *fileFilter );
                        [self performSelectorOnMainThread:@selector(startFilter:)
                                               withObject:mdirs waitUntilDone:YES];
                        break;
#else
                    case '/':
                        if ( !fileStream )
                            fileStream = fdopen( fdfile = [self localConnect], "r");
                        break;
                    case '#':
                        fileFilter = buffer+2;
                        [self performSelectorInBackground:@selector(montorFiles) withObject:nil];
                    case '!':
                        buffer[strlen(buffer)] = '\n';
                        write(fdfile, buffer, strlen(buffer));
                        break;
#endif
                    default:
                        [self scriptText:buffer];
                        break;
                }
                break;
            case '<': {
                if ( (fdin = open( file, O_RDONLY )) < 0 )
                    NSLog( @"Could not open input file: \"%s\" as: %s", file, strerror( errno ) );
                if ( fdout ) {
                    struct stat fdinfo;
                    if ( fstat( fdin, &fdinfo ) != 0 )
                        NSLog( @"Could not stat \"%s\" as: %s", file, strerror( errno ) );
                    [BundleInjection writeBytes:fdinfo.st_size withPath:NULL from:fdin to:fdout];
                    close( fdout );
                    fdin = fdout = 0;
                }
            }
                break;
            case '>':
                while ( fdout )
                    [NSThread sleepForTimeInterval:.5];
                if ( (fdout = open( file, O_CREAT|O_TRUNC|O_WRONLY, 0644 )) < 0 )
                    NSLog( @"Could not open output file: \"%s\" as: %s", file, strerror( errno ) );
                break;
            case '!':
                switch ( buffer[1] ) {
                    case '>':
                        if ( fdin ) {
                            struct stat fdinfo;
                            fstat( fdin, &fdinfo );
                            [BundleInjection writeBytes:S_ISDIR( fdinfo.st_mode ) ? 
                                       INJECTION_MKDIR : fdinfo.st_size withPath:file from:fdin to:clientSocket];
                            close( fdin );
                            fdin = 0;
                            break;
                        }
                    case ':': {
                        OOStringVars( name, value ) = OOString( buffer+2 )[@"([^=]+)=(.*)"];
                        keyFiles[name] = value;
                        break;
                    }
                    case '<':
                    case '/':
                        if ( clientSocket )
                            [BundleInjection writeBytes:INJECTION_MAGIC
                                               withPath:file from:0 to:clientSocket];
                        else
                            [self scriptText:@"\\line Application no longer running/connected."];
                        break;
                    default:
                        [self scriptText:buffer];
                        break;
                }
                break;
            case '%': {
                OOString html = file+1;
                switch ( *file ) {
                case '!':
                    [listView  performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:)
                                                withObject:html waitUntilDone:NO];
                    INLog( @"%s", file );
                    break;
                case '2':
                    [self performSelectorOnMainThread:@selector(loadHTML:)
                                           withObject:"<html><body><style> body, table { "
                                                        "font: 10pt Arial;'; } </style>"+html
                                        waitUntilDone:NO];
                   break;
                case '1': {
                    OOStringDict attr;
                    attr[NSCharacterEncodingDocumentAttribute] =
                    [NSNumber numberWithInt:NSUTF8StringEncoding];
                    NSAttributedString *as2 = [[NSAttributedString alloc]
                                               initWithHTML:html.utf8Data() options:attr documentAttributes:nil];
                    [textView performSelectorOnMainThread:@selector(insertText:) withObject:as2 waitUntilDone:YES];
                    OO_RELEASE( as2 );
                    break;
                }
                }
                break;
            }
            case '?':
                NSLog( @"Error from script: %s", file );
                [owner error:@"%s", file];
                break;
            case '_':
                if ( strcmp(buffer, "__FAILED__") == 0 ) {
                    status = 1;
                    break;
                }
            default:
                [self scriptText:buffer];
                break;
        }
    }

    [owner performSelectorOnMainThread:@selector(setProgress:)
                            withObject:[NSNumber numberWithFloat:-1.] waitUntilDone:NO];

#ifndef FOR_PLUGIN
#ifndef HELPER
    status = pclose( scriptOutput )>>8;
#else
    fclose( scriptOutput );
#endif
#else
    status = task.wait()>>8;
    fclose( scriptOutput );
#endif
    if ( status )
        NSLog( @"Status: %d", status );
    [NSThread sleepForTimeInterval:.5];
    [self connected:0];

    if ( status != 0 && scriptOutput )
        [self performSelectorOnMainThread:@selector(completed:) withObject:nil waitUntilDone:NO];
    if ( !reverting && fileEvents )
        FSEventStreamStart( fileEvents );

    scriptOutput = NULL;
}

- (void)loadHTML:(NSString *)html {
    [[listView mainFrame] loadHTMLString:html baseURL:nil];
}

- (IBAction)openMainProject:sender {
    [owner openPath:projectPath];
    OOString docPath = !isDemo ? nil :
        projectPath & @"InjectionDemo" ? @"InjectionDemo/InjectionDemo/INRoseView.m" :
        projectPath & @"StoryboardDemo" ? @"StoryboardDemo/StoryboardDemo/"
                                            "en.lproj/MainStoryboard_iPad.storyboard" : nil;
    if ( docPath )
        [owner performSelector:@selector(openPath:)
                    withObject:owner->scriptRoot+docPath
                    afterDelay:3.];
}

- (IBAction)openBundleProject:sender {
    [self runScript:@"openBundle.pl" extraArgs:nil];
}

- (IBAction)startBuild:sender {
    patchNumber++;
    [self setState:@"amber.png"];
    [self runScript:"prepareBundle.pl" extraArgs:filesChanged];
}

- (IBAction)clearLog:sender {
    [textView setString:@""];
}

- (IBAction)reopen:sender {
    [self windowControllerDidLoadNib:nil];
}

- (void)listDevice {
    [self runScript:@"listDevice.pl" extraArgs:nil];
}

- (void)openURL:(cOOString)file {
    //reverting = TRUE;
    [self runScript:@"openURL.pl" extraArgs:[NSArray arrayWithObjects:file,
                                             owner->unlockCommand.stringValue, nil]];
}

- (IBAction)removeBackups:sender {
    system( "find '"+projectPath+"/..' -name '*.save' -exec rm {} \\;" );
}

- (IBAction)revertProject:sender {
    reverting = TRUE;
    [self runScript:@"revertProject.pl" extraArgs:nil];
}

- (IBAction)testProject:sender {
    [self runScript:@"testProject.pl" extraArgs:nil];
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame {
    NSLog( @"welcome page load failed: %@", error.localizedDescription );
    NSURL *url = [NSURL fileURLWithPath:owner->scriptRoot+"welcome.html"];
    [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:url]];
    webView = nil;
}

- (void)webView:(WebView *)aWebView decidePolicyForNavigationAction:(NSDictionary *)actionInformation
		request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener {
    if ( !firstURL++ ) {
        [listener use];
        return;
    }
    [listener ignore];
    [[NSWorkspace sharedWorkspace] openURL:request.URL];
}

- (IBAction)slid:(NSSlider *)sender {
    if ( !clientSocket ) return;
    int tag = [sender tag];
    [vals[tag] setStringValue:OOFmt( @"%.3f", sender.floatValue )];
    OOString file = OOFmt( @"%d%@", tag, vals[tag].stringValue );
    [BundleInjection writeBytes:INJECTION_MAGIC withPath:file from:0 to:clientSocket];
}

- (IBAction)maxd:(NSTextField *)sender {
    [sliders[sender.tag] setMaxValue:sender.stringValue.floatValue];
}

- (IBAction)colorChanged:(NSColorWell *)sender {
    if ( !clientSocket ) return;
    OOString col = [self formatColor:sender.color], file = OOFmt( @"%d%@", (int)[sender tag], *col );
    if ( !reverting )
        colLabel.stringValue = OOFmt( @"Color changed: rgba = {%@}", *col );
    [BundleInjection writeBytes:INJECTION_MAGIC withPath:file from:0 to:clientSocket];
}

- (IBAction)imageChanged:(InImageView *)sender {
    if ( !clientSocket ) return;
    [BundleInjection writeBytes:INJECTION_MAGIC withPath:"#" from:0 to:clientSocket];

    NSData *data = sender->imageFile.data();
    BOOL readable = data != nil;
    if ( !readable ) {
        OOArray<NSBitmapImageRep *> reps = [[sender image] representations];
        data = [reps[0] representationUsingType:NSPNGFileType properties:nil];
    }

    int len = data.length;
    if ( write( clientSocket, &len, sizeof len ) != sizeof len ||
            write( clientSocket, data.bytes, len ) != len )
        NSLog( @"Image write error: %s", strerror( errno ) );

    OOString path = sender->imageFile.canonize().directory()+"/";
    colLabel.stringValue = sender->imageFile.path();

#ifndef HELPER
    if ( !includes[path] ) {
        OO_RELEASE( includes[path] = [[InDirectory alloc] initPath:path] );
        [self startFilter:mdirs |= OOStringArray( path, nil )];
        FSEventStreamStart( fileEvents );
    }
#else
    if ( readable ) {
        const char *extra = path;
        write(fdfile, "#!", 2);
        write(fdfile, extra, strlen(extra));
        write(fdfile, "\n##\n", 4);
    }
#endif

    [self mapSimulator];
}

- (IBAction)cancel:sender {
    if ( scriptOutput ) {
#ifndef HELPER
        system( "kill -9 `/bin/ps uxww | grep '"+owner->appPrefix+
                "' | grep -v grep | /usr/bin/awk '{print $2}'`" );
        pclose( scriptOutput );
#else
        fclose( scriptOutput );
#endif
        scriptOutput = NULL;
    }
}

- (void)close {
    INLog( @"Closing %@", *projectPath );

    if ( welcomeDoc == self )
        welcomeDoc = nil;

    if ( !!projectPath && !closed++ ) {
        if ( autoButton.state )
            ~owner->defaults[projectPath];
        else
            owner->defaults[projectPath] = YES;

        OOStringArray params, colors;
        for ( int i=0 ; i<sizeof vals/sizeof *vals ; i++ ) {
            params += maxs[i].stringValue;
            params += sliders[i].stringValue;
            colors += [self formatColor:wells[i].color];;
        }
#ifndef FOR_PLUGIN
        // to sort out in objstr.h one day..
        owner->defaults[kParams][projectPath] = params;
        owner->defaults[kParams][projectPath] = params;
        owner->defaults[kColors][projectPath] = colors;
        owner->defaults[kColors][projectPath] = colors;
#endif
        [self cancel:self];
    }

    [self stopFilter];
    if ( fileStream ) {
        close( fdfile );
        fclose( fileStream );
        fileStream = NULL;
    }

    if ( clientSocket ) {
        [BundleInjection writeBytes:INJECTION_CLOSE withPath:"" from:0 to:clientSocket];

        int ctmp = clientSocket;
        clientSocket = 0;
        close( ctmp );
        [self connected:-1];
    }

    [super close];
}

@end
