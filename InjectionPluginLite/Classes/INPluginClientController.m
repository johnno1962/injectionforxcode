//
//  INPluginMenuController.m
//  InjectionPluginLite
//
//  Created by John Holdsworth on 15/01/2013.
//
//

#define INJECTION_NOIMPL

#import "INPluginClientController.h"
#import "INPluginMenuController.h"

static NSString *kINUnlockCommand = @"INUnlockCommand", *kINSilent = @"INSilent",
    *kINOrderFront = @"INOrderFront", *colorFormat = @"%f,%f,%f,%f";

@implementation INPluginClientController

- (id)valueForkey:(NSString *)key index:(int)index {
    return [self valueForKey:[NSString stringWithFormat:@"%@%d", key, index]];
}

- (void)awakeFromNib {
    resourcePath = [[NSBundle bundleForClass:[self class]] resourcePath];
    for ( int i=0 ; i<sizeof vals/sizeof *vals ; i++ ) {
        vals[i]    = [self valueForkey:@"val"   index:i];
        sliders[i] = [self valueForkey:@"slide" index:i];
        maxs[i]    = [self valueForkey:@"max"   index:i];
        wells[i]   = [self valueForkey:@"well"  index:i];
    }
    [self logRTF:@"{\\rtf1\\ansi\\def0}\n"];

    NSUserDefaults *defaults = menuController.defaults;
    if ( [defaults valueForKey:kINUnlockCommand] )
        unlockField.stringValue = [defaults valueForKey:kINUnlockCommand];
    silentButton.state = [defaults boolForKey:kINSilent];
    frontButton.state = [defaults boolForKey:kINOrderFront];
    docTile = [[NSApplication sharedApplication] dockTile];
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

- (void)alert:(NSString *)msg {
    msgField.stringValue = msg;
    [alertPanel orderFront:self];
}

#pragma mark - Misc

- (void)logRTF:(NSString *)rtf {
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
         withObject:mainFilePath = [NSString stringWithUTF8String:path]
         waitUntilDone:NO];
    else
        NSLog( @"Bogus connection attempt." );

    status = 1;
    write( appConnection, &status, sizeof status );

    [BundleInjection readHeader:&header forPath:path from:appConnection];
    if ( header.dataLength == INJECTION_MAGIC )
        executablePath = [NSString stringWithUTF8String:path];
    else
        NSLog( @"Bogus connection attempt." );

    [self scriptText:[NSString stringWithFormat:@"Connection from: %@ (%d)",
                      executablePath, appConnection]];

    clientSocket = appConnection;

    [docTile
     performSelectorOnMainThread:@selector(setBadgeLabel:)
     withObject:@"1" waitUntilDone:NO];

    for ( int i=0 ; i<sizeof vals/sizeof *vals ; i++ ) {
        [self slid:sliders[i]];
        [self colorChanged:wells[i]];
    }

    [self performSelectorInBackground:@selector(connectionMonitor) withObject:nil];
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

    [self scriptText:[@"Disconnected from: " stringByAppendingString:executablePath]];
    close( clientSocket );
    clientSocket = 0;
    patchNumber = 1;

    [docTile
     performSelectorOnMainThread:@selector(setBadgeLabel:)
     withObject:nil waitUntilDone:NO];
}

- (void)completed:success {
    if ( success ) {
        [self logRTF:@"\\line Bundle loaded successfully.\\line"];
        [consolePanel orderOut:self];
        [errorPanel orderOut:self];
        [self mapSimulator];
    }
    else {
        [self logRTF:@"\n\n{\\colortbl;\\red0\\green0\\blue0;\\red255\\green100\\blue100;}\\cb2"
         "*** Bundle load failed ***\\line Consult the Xcode console."];
        [consolePanel orderFront:self];
        [errorPanel orderFront:self];
    }
}

- (void)mapSimulator {
    if ( frontButton.state && [executablePath rangeOfString:@"/iPhone Simulator/"].location != NSNotFound )
        [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:@"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Applications/iPhone Simulator.app"]];
}

- (BOOL)connected {
    return clientSocket > 0;
}

#pragma mark - Run script

- (void)runScript:(NSString *)script withArg:(NSString *)selectedFile {
   [menuController startProgress];
    NSString *command = [NSString stringWithFormat:@"\"%@/%@\" "
                         "\"%@\" \"%@\" \"%@\" %d %d \"%@\" \"%@\" \"%@\"",
                         resourcePath, script, resourcePath,
                         mainFilePath ? mainFilePath : @"", executablePath ? executablePath : @"",
                         ++patchNumber, silentButton.state ? 0 : 1<<2 | frontButton.state ? 0 : 1<<3,
                         [unlockField.stringValue stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""],
                         [[menuController serverAddresses] componentsJoinedByString:@" "],
                         selectedFile];
    [self exec:command];
}

- (void)exec:(NSString *)command {
    int length = consoleTextView.string.length;
    if ( length > 100000 )
        consoleTextView.string = @"";
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
                        if ( clientSocket )
                            [BundleInjection writeBytes:INJECTION_MAGIC
                                               withPath:file from:0 to:clientSocket];
                        else
                            [self scriptText:@"\\line Application no longer running/connected."];
                        break;
                    default:
                        [self scriptText:[NSString stringWithUTF8String:buffer]];
                        break;
                }
                break;
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
        [self performSelectorOnMainThread:@selector(completed:) withObject:nil waitUntilDone:NO];
    
    scriptOutput = NULL;
}

#pragma mark - Tunable Parameters

- (IBAction)slid:(NSSlider *)sender {
    if ( !clientSocket ) return;
    int tag = [sender tag];
    [vals[tag] setStringValue:[NSString stringWithFormat:@"%.3f", sender.floatValue]];
    NSString *file = [NSString stringWithFormat:@"%d%@", tag, vals[tag].stringValue];
    [BundleInjection writeBytes:INJECTION_MAGIC withPath:[file UTF8String] from:0 to:clientSocket];
}

- (IBAction)maxChanged:(NSTextField *)sender {
    [sliders[sender.tag] setMaxValue:sender.stringValue.floatValue];
}

- (IBAction)colorChanged:(NSColorWell *)sender {
    if ( !clientSocket ) return;
    NSString *col = [self formatColor:sender.color], *file = [NSString stringWithFormat:@"%d%@", (int)[sender tag], col];
    colorLabel.stringValue = [NSString stringWithFormat:@"Color changed: rgba = {%@}", col];
    [BundleInjection writeBytes:INJECTION_MAGIC withPath:[file UTF8String] from:0 to:clientSocket];
}

- (IBAction)imageChanged:(NSImageView *)sender {
    if ( !clientSocket ) return;
    [BundleInjection writeBytes:INJECTION_MAGIC withPath:"#" from:0 to:clientSocket];

    NSArray *reps = [[sender image] representations];
    NSData *data = [[reps objectAtIndex:0] representationUsingType:NSPNGFileType properties:nil];

    int len = data.length;
    if ( write( clientSocket, &len, sizeof len ) != sizeof len ||
        write( clientSocket, data.bytes, len ) != len )
        NSLog( @"Image write error: %s", strerror( errno ) );

    [self mapSimulator];
}

- (void)openResource:(const char *)res {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%s", resourcePath, res]]];
}

- (IBAction)openOSXTemplate:sender {
    [self openResource:"OSXBundleTemplate/InjectionBundle.xcodeproj"];
}
- (IBAction)openiOSTemplate:sender {
    [self openResource:"iOSBundleTemplate/InjectionBundle.xcodeproj"];
}
- (IBAction)openPatchMain:sender {
    [self openResource:"patchMain.pl"];
}
- (IBAction)openPatchPch:sender {
    [self openResource:"patchPch.pl"];
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
    [self openResource:"BundleInteface.h"];
}

@end
