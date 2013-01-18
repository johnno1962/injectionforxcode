//
//  INPluginMenuController.h
//  InjectionPluginLite
//
//  Created by John Holdsworth on 15/01/2013.
//
//

#import <Cocoa/Cocoa.h>

@class INPluginMenuController;

@interface INPluginClientController : NSObject {

	IBOutlet NSPanel *consolePanel, *paramsPanel, *alertPanel, *errorPanel;
    IBOutlet NSTextField *colorLabel, *mainSourceLabel, *msgField, *unlockField;
    IBOutlet INPluginMenuController *menuController;
    IBOutlet NSButton *silentButton, *frontButton;
    IBOutlet NSTextView *consoleTextView;

    IBOutlet NSView *vals, *sliders, *maxs, *wells;
    IBOutlet NSImageView *imageWell;

    NSString *scriptPath, *resourcePath, *mainFilePath, *executablePath;
    int clientSocket, patchNumber, fdin, fdout, fdfile, lines, status;
    char buffer[1024*1024];
    NSDockTile *docTile;
    FILE *scriptOutput;
}

- (void)alert:(NSString *)msg;
- (void)setConnection:(int)clientConnection;
- (void)runScript:(NSString *)script withArg:(NSString *)selectedFile;
- (BOOL)connected;

@end
