//
//  $Id: //depot/InjectionPluginLite/Classes/INPluginClientController.m#33 $
//  InjectionPluginLite
//
//  Created by John Holdsworth on 15/01/2013.
//  Copyright (c) 2012 John Holdsworth. All rights reserved.
//
//  Manages interaction with client application and runs UNIX scripts.
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

#define INJECTION_NOIMPL

#import "INPluginClientController.h"
#import "INPluginMenuController.h"

static NSString *kINUnlockCommand = @"INUnlockCommand", *kINSilent = @"INSilent",
    *kINStoryBoard = @"INStoryboard", *kINOrderFront = @"INOrderFront", *colorFormat = @"%f,%f,%f,%f"/*,
    *pluginAppResources = @"/Applications/Injection Plugin.app/Contents/Resources"*/;

@interface INPluginClientController() {

    IBOutlet NSTextField *colorLabel, *mainSourceLabel, *msgField, *unlockField;
    IBOutlet NSButton *silentButton, *frontButton, *storyButton;
    IBOutlet INPluginMenuController *menuController;
    IBOutlet NSTextView *consoleTextView;

    IBOutlet NSView *vals, *sliders, *maxs, *wells;
    IBOutlet NSImageView *imageWell;

    int clientSocket, patchNumber, fdin, fdout, fdfile, lines, status, lastFlags;
    NSMutableString *output;
    char buffer[1024*1024];
    FILE *scriptOutput;
    BOOL autoOpened;
}

@property (nonatomic,retain) IBOutlet NSPanel *consolePanel;
@property (nonatomic,retain) IBOutlet NSPanel *paramsPanel;
@property (nonatomic,retain) IBOutlet NSPanel *alertPanel;
@property (nonatomic,retain) IBOutlet NSPanel *errorPanel;
@property (nonatomic,retain) NSDockTile *docTile;

@property (nonatomic,retain) NSString *resourcePath;
@property (nonatomic,retain) NSString *mainFilePath;
@property (nonatomic,retain) NSString *executablePath;
@property (nonatomic,retain) NSString *productPath;
@property (nonatomic,retain) NSString *deviceRoot;
@property (nonatomic,retain) NSString *identity;
@property (nonatomic,retain) NSString *arch;

@end

#define RESOURCES_LINK "/tmp/injectionforxcode"

@implementation INPluginClientController

- (void)awakeFromNib {
    NSUserDefaults *defaults = menuController.defaults;
    if ( [defaults valueForKey:kINUnlockCommand] )
        unlockField.stringValue = [defaults valueForKey:kINUnlockCommand];
    if ( [defaults valueForKey:kINSilent] )
        silentButton.state = [defaults boolForKey:kINSilent];
    frontButton.state = [defaults boolForKey:kINOrderFront];
    storyButton.state = [defaults boolForKey:kINStoryBoard];

    self.scriptPath = [[NSBundle bundleForClass:[self class]] resourcePath];
//    if ( [[self implementionInDirectory:pluginAppResources]
//          isEqualTo:[self implementionInDirectory:self.scriptPath]] )
//        self.resourcePath = pluginAppResources;
//    else
//        self.resourcePath = self.scriptPath;
    self.resourcePath = @RESOURCES_LINK;

    unlink( RESOURCES_LINK );
    symlink( [self.scriptPath UTF8String], RESOURCES_LINK );

    self.docTile = [[NSApplication sharedApplication] dockTile];
    [self logRTF:@"{\\rtf1\\ansi\\def0}\n"];
}

- (NSString *)implementionInDirectory:(NSString *)dir {
    return [NSString stringWithContentsOfURL:[[NSURL fileURLWithPath:dir]
                                              URLByAppendingPathComponent:@"BundleInjection.h"]
                             encoding:NSUTF8StringEncoding error:NULL];
}

- (IBAction)unlockChanged:(NSTextField *)sender  {
    [menuController.defaults setValue:unlockField.stringValue forKey:kINUnlockCommand];
}

- (IBAction)silentChanged:(NSButton *)sender {
    [menuController.defaults setBool:silentButton.state forKey:kINSilent];
}

- (IBAction)frontChanged:(NSButton *)sender {
    [menuController.defaults setBool:frontButton.state forKey:kINOrderFront];
}

- (IBAction)storyChanged:(NSButton *)sender {
    [menuController.defaults setBool:storyButton.state forKey:kINStoryBoard];
    if ( storyButton.state )
        [self alert:@"It's fair to say storyboard injection has it's limitations (requires project patching.) If you're not using it you should leave this option off."];
}

- (void)alert:(NSString *)msg {
    [[NSAlert alertWithMessageText:@"Injection Plugin:"
                     defaultButton:@"OK" alternateButton:nil otherButton:nil
         informativeTextWithFormat:@"%@", msg] runModal];
    return;
    msgField.stringValue = msg;
    [self.alertPanel orderFront:self];
}

#pragma mark - Misc

- (void)logRTF:(NSString *)rtf {
    if ( !output )
        output = [NSMutableString new];
    [output appendFormat:@"{%@\\line}\n", rtf];
}

- (void)completeRTF:(NSString *)out {
    NSString *rtf = out ? out : output;
    if ( ![rtf length] )
        return;

    @try {
        const char *wrapped = [[NSString stringWithFormat:@"{%@\\line}\n", rtf] UTF8String];
        NSAttributedString *as2 = [[NSAttributedString alloc]
                                   initWithRTF:[NSData dataWithBytesNoCopy:(void *)wrapped
                                                                    length:strlen(wrapped)
                                                              freeWhenDone:NO]
                                   documentAttributes:nil];
        if ( !as2 ) {
            NSLog( @"-[InPluginDocument<%p> pasteRTF:] Could not convert '%@'", self, rtf );
            [consoleTextView insertText:rtf];
        }
        else
            [consoleTextView insertText:as2];

        if ( !out )
            [output setString:@""];
    }
    @catch ( NSException *e ) {
        NSLog( @"-[InPluginDocument<%p> pasteRTF:] exception '%@' converting '%@': %@",
              self, [e reason], rtf, [e callStackSymbols] );
    }
}

- (void)scriptText:(NSString *)text {
    [self performSelectorOnMainThread:@selector(logRTF:) withObject:text waitUntilDone:YES];
}

- (NSColor *)parseColor:(NSString *)info {
    if ( !info )
        return nil;
    float r, g, b, a;
    sscanf( [info UTF8String], [colorFormat UTF8String], &r, &g, &b, &a );
    return [NSColor colorWithDeviceRed:r green:g blue:b alpha:a];
}

- (NSString *)formatColor:(NSColor *)color {
    CGFloat r=1., g=1., b=1., a=1.;
    @try {
        color = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
        [color getRed:&r green:&g blue:&b alpha:&a];
    }
    @catch (NSException *e) {
        NSLog( @"Color Exception: %@", [e description] );
    }
    return [NSString stringWithFormat:colorFormat, r, g, b, a];
}

#pragma mark - Accept connection

- (void)setConnection:(int)appConnection {
    struct _in_header header;
    char path[PATH_MAX];

    [BundleInjection readHeader:&header forPath:path from:appConnection];

    if ( header.dataLength == INJECTION_MAGIC )
        [mainSourceLabel
         performSelectorOnMainThread:@selector(setStringValue:)
         withObject:self.mainFilePath = [NSString stringWithUTF8String:path]
         waitUntilDone:NO];
    else {
        self.identity = [NSString stringWithUTF8String:path];

        path[0] = '@';
        path[header.dataLength+1] = '\000';
        read( appConnection, path+1, header.dataLength );
        self.productPath = [NSString stringWithUTF8String:path+1];

        if ( self.connected && menuController.workspacePath )
            [self runScript:@"injectStoryboard.pl" withArg:self.productPath];

        close( appConnection );
        return;
    }

    status = (storyButton.state ? INJECTION_STORYBOARD : 1);// | INJECTION_DEVICEIOS8;
    write( appConnection, &status, sizeof status );

    [BundleInjection readHeader:&header forPath:path from:appConnection];
    self.executablePath = [NSString stringWithUTF8String:path];

    if ( header.dataLength )
        self.deviceRoot = self.executablePath;
    else
        do {
            [BundleInjection readHeader:&header forPath:path from:appConnection];
            self.deviceRoot = [NSString stringWithUTF8String:path];
        } while ( header.dataLength == 0 );

    read( appConnection, path, header.dataLength );
    self.arch = [NSString stringWithUTF8String:path];

    [self scriptText:[NSString stringWithFormat:@"Connection from: %@ %@ (%d)",
                      self.executablePath, self.arch, appConnection]];

    clientSocket = appConnection;

    [self.docTile
     performSelectorOnMainThread:@selector(setBadgeLabel:)
     withObject:@"1" waitUntilDone:NO];

    for ( NSSlider *slider in [sliders subviews] )
        [self slid:slider];
    for ( NSColorWell *well in [wells subviews] )
        [self colorChanged:well];

    [menuController enableFileWatcher:YES];

    [self performSelectorInBackground:@selector(connectionMonitor) withObject:nil];
}

- (void)connectionMonitor {
    int loaded;

    while( read( clientSocket, &loaded, sizeof loaded ) == sizeof loaded )
        if ( !fdout )
            [self performSelectorOnMainThread:@selector(completed:)
                                   withObject:loaded ? nil :
             @"\n\n{\\colortbl;\\red0\\green0\\blue0;\\red255\\green100\\blue100;}\\cb2"
             "*** Bundle load failed ***\\line Consult the Xcode console." waitUntilDone:NO];
        else {
            [BundleInjection writeBytes:loaded withPath:NULL from:clientSocket to:fdout];
            close( fdout );
            fdout = 0;
        }

    if ( !clientSocket )
        return;

    [self scriptText:[@"Disconnected from: " stringByAppendingString:self.executablePath]];
    close( clientSocket );
    clientSocket = 0;
    patchNumber = 1;

    [menuController enableFileWatcher:NO];

    [self.docTile
     performSelectorOnMainThread:@selector(setBadgeLabel:)
     withObject:nil waitUntilDone:NO];
}

- (void)connectionKeepalive {
    if ( clientSocket && !scriptOutput ) {
        [BundleInjection writeBytes:INJECTION_MAGIC withPath:"" from:0 to:clientSocket];
        [self performSelector:@selector(connectionKeepalive) withObject:nil afterDelay:10.];
    }
}

- (void)completed:error {
    if ( error ) {
        [self logRTF:error];
        if ( !self.consolePanel.isVisible )
            autoOpened = YES;
        [self.consolePanel orderFront:self];
        //        [self.errorPanel orderFront:self];
    }
    else {
        [self logRTF:@"\\line Bundle loaded successfully.\\line"];
        if ( autoOpened )
            [self.consolePanel orderOut:self];
        [self.alertPanel orderOut:self];
        [self.errorPanel orderOut:self];
        [self mapSimulator];
        autoOpened = NO;
    }

    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(connectionKeepalive) object:nil];
    [self connectionKeepalive];
    [self completeRTF:nil];
}

- (void)mapSimulator {
    if ( frontButton.state &&
        ([self.executablePath rangeOfString:@"/iPhone Simulator/"].location != NSNotFound ||
         [self.executablePath rangeOfString:@"/CoreSimulator/"].location != NSNotFound) )
        [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:
            [NSString stringWithFormat:@"%@/Contents/Developer/Applications/iOS Simulator.app",
             [NSBundle mainBundle].bundlePath]]];
}

- (BOOL)connected {
    return clientSocket > 0;
}

#pragma mark - Run script

- (void)runScript:(NSString *)script withArg:(NSString *)selectedFile {
    [menuController startProgress];
    if ( ![selectedFile length] )
        [self.consolePanel orderFront:self];

    int flags = (silentButton.state ? 0 : INJECTION_NOTSILENT) |
                (frontButton.state ? INJECTION_ORDERFRONT : 0) |
                (storyButton.state ? INJECTION_STORYBOARD : 0);
    if ( flags != lastFlags )
        flags |= INJECTION_FLAGCHANGE;
    lastFlags = flags & ~INJECTION_FLAGCHANGE;

    NSString *command = [NSString stringWithFormat:@"\"%@/%@\" "
                         "\"%@\" \"%@\" \"%@\" \"%@\" \"%@\" %d %d \"%@\" \"%@\" \"%@\" \"%@\" \"%@\" \"%@\" 2>&1",
                         self.scriptPath, script, self.resourcePath, menuController.workspacePath,
                         self.deviceRoot, //self.mainFilePath ? self.mainFilePath : @"",
                         self.executablePath ? self.executablePath : @"", self.arch, ++patchNumber, flags,
                         [unlockField.stringValue stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""],
                         [[menuController serverAddresses] componentsJoinedByString:@" "],
                         selectedFile, [NSBundle mainBundle].bundlePath,
                         [menuController buildDirectory] ?: @"", [menuController logDirectory]];
    [self exec:command];
}

- (void)exec:(NSString *)command {
    int length = consoleTextView.string.length;
    if ( length > 100000 )
        [self clearConsole:nil];
    else
        [consoleTextView setSelectedRange:NSMakeRange(length, 0)];

    INLog( @"Running: %@", command );
    if ( scriptOutput ) {
        [self performSelector:_cmd withObject:command afterDelay:.5];
        return;
    }

    lines = 0, status = 0;
    scriptOutput = (FILE *)1;
    if ( (scriptOutput = popen( [command UTF8String], "r")) == NULL )
        [menuController error:@"Could not run script: %@", command];
    else
        [self performSelectorInBackground:@selector(monitorScript) withObject:nil];
}

- (void)monitorScript {
    char *file = &buffer[1];

    while ( scriptOutput && fgets( buffer, sizeof buffer-1, scriptOutput ) ) {
        [menuController performSelectorOnMainThread:@selector(setProgress:)
                                withObject:[NSNumber numberWithFloat:lines++/50.]
                             waitUntilDone:NO];

        //INLog( @"%lu %s", strlen( buffer ), buffer );
        buffer[strlen(buffer)-1] = '\000';

        switch ( buffer[0] ) {
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
                    case '<':
                    case '/':
                    case '@':
                    case '!':
                        if ( self.connected ) {
                            if ( self.withReset )
                                [BundleInjection writeBytes:INJECTION_MAGIC
                                                   withPath:"~" from:0 to:clientSocket];
                            [BundleInjection writeBytes:INJECTION_MAGIC
                                               withPath:file from:0 to:clientSocket];
                            self.withReset = NO;
                        }
                        else
                            [self scriptText:@"\\line Application no longer running/connected."];
                        break;
                    default:
                        [self scriptText:[NSString stringWithUTF8String:buffer]];
                        break;
                }
                break;
            case '%': {
                NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:NSUTF8StringEncoding], NSCharacterEncodingDocumentAttribute, nil];
                NSAttributedString *as2 = [[NSAttributedString alloc]
                                           initWithHTML:[NSData dataWithBytes:file length:strlen(file)]
                                           options:attr documentAttributes:nil];
                [consoleTextView performSelectorOnMainThread:@selector(insertText:) withObject:as2 waitUntilDone:YES];
                break;
            }
           case '?':
                NSLog( @"Error from script: %s", file );
                [menuController error:@"%s", file];
                break;
            default:
                [self scriptText:[NSString stringWithUTF8String:buffer]];
                break;
        }
    }

    [menuController performSelectorOnMainThread:@selector(setProgress:)
                            withObject:[NSNumber numberWithFloat:-1.] waitUntilDone:NO];

    status = pclose( scriptOutput )>>8;
    if ( status )
        NSLog( @"Status: %d", status );
    //[NSThread sleepForTimeInterval:.5];

    if ( status != 0 && scriptOutput )
        [self performSelectorOnMainThread:@selector(completed:)
                               withObject:@"\n\n{\\colortbl;\\red0\\green0\\blue0;\\red255\\green100\\blue100;}\\cb2"
         "*** Bundle build failed ***" waitUntilDone:NO];
    
    [self performSelectorOnMainThread:@selector(completeRTF:) withObject:nil waitUntilDone:NO];
    scriptOutput = NULL;
}

#pragma mark - Tunable Parameters

- (IBAction)slid:(NSSlider *)sender {
    if ( !clientSocket ) return;
    int tag = [sender tag];
    NSTextField *val = [vals viewWithTag:tag];
    [val setStringValue:[NSString stringWithFormat:@"%.3f", sender.floatValue]];
    NSString *file = [NSString stringWithFormat:@"%d%@", tag, [val stringValue]];
    dispatch_async( dispatch_get_main_queue(), ^{
        [BundleInjection writeBytes:INJECTION_MAGIC withPath:[file UTF8String] from:0 to:clientSocket];
    } );
}

- (IBAction)maxChanged:(NSTextField *)sender {
    [[sliders viewWithTag:sender.tag] setMaxValue:sender.stringValue.floatValue];
}

- (IBAction)colorChanged:(NSColorWell *)sender {
    if ( !clientSocket ) return;
    NSString *col = [self formatColor:sender.color], *file = [NSString stringWithFormat:@"%d%@", (int)[sender tag], col];
    colorLabel.stringValue = [NSString stringWithFormat:@"Color changed: rgba = {%@}", col];
    dispatch_async( dispatch_get_main_queue(), ^{
        [BundleInjection writeBytes:INJECTION_MAGIC withPath:[file UTF8String] from:0 to:clientSocket];
    } );
}

- (IBAction)imageChanged:(NSImageView *)sender {
    if ( !clientSocket ) return;
    [BundleInjection writeBytes:INJECTION_MAGIC withPath:"#" from:0 to:clientSocket];

    NSArray *reps = [[sender image] representations];
    NSData *data = [[reps objectAtIndex:0] representationUsingType:NSPNGFileType properties:@{}];

    int len = data.length;
    if ( write( clientSocket, &len, sizeof len ) != sizeof len ||
        write( clientSocket, data.bytes, len ) != len )
        NSLog( @"Image write error: %s", strerror( errno ) );

    [self mapSimulator];
}

- (void)openResource:(const char *)res {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%s", self.scriptPath, res]]];
}

- (IBAction)openOSXTemplate:sender {
    [self openResource:"OSXBundleTemplate/InjectionBundle.xcodeproj"];
}
- (IBAction)openiOSTemplate:sender {
    [self openResource:"iOSBundleTemplate/InjectionBundle.xcodeproj"];
}
- (IBAction)openPatchProject:sender {
    [self openResource:"patchProject.pl"];
}
- (IBAction)openRevertProject:sender {
    [self openResource:"revertProject.pl"];
}
- (IBAction)openInjectSource:sender {
    [self openResource:"injectSource.pl"];
}
- (IBAction)openOpenBundle:sender{
    [self openResource:"openBundle.pl"];
}
- (IBAction)openCommonCode:sender {
    [self openResource:"common.pm"];
}
- (IBAction)openBundleInjection:sender {
    [self openResource:"BundleInjection.h"];
}
- (IBAction)openBundleInterface:sender {
    [self openResource:"BundleInterface.h"];
}

#pragma mark Console

- (void)clearConsole: (id)sender {
    consoleTextView.string = @"";
}
@end
