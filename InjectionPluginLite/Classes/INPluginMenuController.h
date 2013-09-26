//
//  $Id: //depot/InjectionPluginLite/Classes/INPluginMenuController.h#8 $
//  InjectionPluginLite
//
//  Created by John Holdsworth on 15/01/2013.
//  Copyright (c) 2012 John Holdsworth. All rights reserved.
//
//  Manages interactions with Xcode's product menu and runs TCP server.
//
//  This file is copyright and may not be re-distributed, whole or in part.
//

#import "INPluginClientController.h"
#import "BundleInjection.h"
#import <WebKit/WebKit.h>

@interface INPluginMenuController : NSObject <NSNetServiceDelegate> {

    // as you can see, I'm no fan of @properties
    // particularly in a GC or ARC environment

    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSTextField *urlLabel;
    IBOutlet NSPanel *webPanel;
    IBOutlet WebView *webView;
    IBOutlet NSMenu *subMenu;
    IBOutlet NSMenuItem *subMenuItem, *introItem;

    IBOutlet NSTextView *lastTextView;
    IBOutlet INPluginClientController *client;

    Class DVTSourceTextView;
    Class IDEWorkspaceDocument;

    NSUserDefaults *defaults;
    int serverSocket;

    NSMutableString *mac;
    time_t installed;
    int licensed;
    int refkey;
}

- (NSUserDefaults *)defaults;
- (NSArray *)serverAddresses;
- (NSString *)workspacePath;

- (void)error:(NSString *)format, ...;
- (void)setProgress:(NSNumber *)fraction;
- (void)startProgress;

@end
