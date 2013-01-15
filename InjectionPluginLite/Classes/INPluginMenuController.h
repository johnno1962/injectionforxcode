//
//  INPluginMenuController.h
//  InjectionPluginLite
//
//  Created by John Holdsworth on 15/01/2013.
//
//

#import "INPluginClientController.h"
#import "BundleInjection.h"
#import <WebKit/WebKit.h>

@interface INPluginMenuController : NSObject {

    // as you can see, I'm no fan of @properties
    // particularly in a GC or ARC environment

    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSTextField *urlLabel;
    IBOutlet NSPanel *webPanel;
    IBOutlet WebView *webView;
    IBOutlet NSMenu *subMenu;

    IBOutlet NSTextView *lastTextView;
    IBOutlet INPluginClientController *client;

    Class DVTSourceTextView;
    Class IDEWorkspaceDocument;

    NSArray *serverAddresses;
    NSUserDefaults *defaults;
    int serverSocket;

    NSMutableString *mac;
    time_t installed;
    int licensed;
    int refkey;
}

- (NSUserDefaults *)defaults;
- (NSArray *)serverAddresses;
- (void)error:(NSString *)format, ...;
- (void)setProgress:(NSNumber *)fraction;
- (void)startProgress;

@end
