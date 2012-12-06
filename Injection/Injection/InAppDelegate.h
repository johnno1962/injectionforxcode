//
//  InAppDelegate.h
//  Injection
//
//  Created by John Holdsworth on 16/01/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Webkit/WebView.h>

#import "BundleInjection.h"
#import "objcpp.h"

@class InDocument;

@interface InAppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSMenuItem *lic, *conf;
    IBOutlet NSWindow *licensing;
    IBOutlet WebView *webView;
    InDocument *newDoc;

    struct sockaddr_in clientAddr;
    time_t installed, now;
    NSDockTile *docTile;
    int serverSocket;
    OOInfo info;

@public
    IBOutlet NSTextField *unlockCommand, *urlLabel, *find;
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSButton *playSound, *convertAll;

    OOString resourcePath, appRoot, appPrefix, appVersion, scriptRoot, mac;
    int refkey, licensed, connected;
    OOReference<NSSound *> clunk;
    OOStringArray addresses;
    OODefaults defaults;
}

extern OOString appHome;

- (void)error:(NSString *)format, ...;
- (void)setProgress:(NSNumber *)fraction;
- (OOStringArray)startServer;

- (IBAction)license:sender;
- (IBAction)openDemo:sender;
- (IBAction)openOSXTemplate:sender;
- (IBAction)openiOSTemplate:sender;

- (IBAction)openNewProjectScript:sender;
- (IBAction)openBuildBundleScript:sender;
- (IBAction)openCloseProjectScript:sender;
- (IBAction)openListDeviceScript:sender;
- (IBAction)openBundleScript:sender;
- (IBAction)openURLScript:sender;
- (IBAction)openCommonScript:sender;
- (IBAction)openCommonCode:sender;
- (IBAction)openInterface:sender;

- (void)openPath:(NSString *)path;

- (IBAction)removeBackups:sender;
- (IBAction)revertProject:sender;
- (IBAction)reopenProject:sender;
- (IBAction)updateScripts:sender;
- (IBAction)listDevice:sender;
- (IBAction)openHelp:sender;
- (IBAction)feedback:sender;
- (IBAction)build:sender;
- (IBAction)find:sender;
- (IBAction)zap:sender;

@end
