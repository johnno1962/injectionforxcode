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
    IBOutlet NSTextView *consoleTextView;

    IBOutlet NSTextField *val0, *val1, *val2, *val3, *val4;
    IBOutlet NSSlider *slide0, *slide1, *slide2, *slide3, *slide4;
    IBOutlet NSTextField *max0, *max1, *max2, *max3, *max4;
    IBOutlet NSColorWell *well0, *well1, *well2, *well3, *well4;
    IBOutlet NSImageView *imageWell;
    IBOutlet NSButton *silentButton;

    NSTextField *vals[5];
    NSSlider *sliders[5];
    NSTextField *maxs[5];
    NSColorWell *wells[5];

    NSString *resourcePath, *mainFilePath, *executablePath;
    int clientSocket, patchNumber, fdin, fdout, fdfile, lines, status;
    char buffer[10*1024*1024];
    NSDockTile *docTile;
    FILE *scriptOutput;
}

- (void)alert:(NSString *)msg;
- (void)setConnection:(int)clientConnection;
- (void)runScript:(NSString *)script withArg:(NSString *)selectedFile;
- (BOOL)connected;

@end
