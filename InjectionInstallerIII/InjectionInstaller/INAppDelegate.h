//
//  INAppDelegate.h
//  InjectionInstaller
//
//  Created by John Holdsworth on 20/09/2012.
//  Copyright (c) 2012 John Holdsworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface INAppDelegate : NSObject <NSApplicationDelegate,NSURLDownloadDelegate> {
    IBOutlet NSWindow *window, *disclaimer;
    IBOutlet WebView *webView;
    IBOutlet NSBox *box, *rbox;

    WebDownload *loader;
    NSString *file, *dest;
}

- (IBAction)install:sender;
- (IBAction)remove:sender;
- (IBAction)help:sender;

@end
