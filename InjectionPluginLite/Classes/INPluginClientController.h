//
//  $Id: //depot/InjectionPluginLite/Classes/INPluginClientController.h#11 $
//  InjectionPluginLite
//
//  Created by John Holdsworth on 15/01/2013.
//  Copyright (c) 2012 John Holdsworth. All rights reserved.
//
//  Manages interaction with client application and runs UNIX scripts.
//
//  This file is copyright and may not be re-distributed, whole or in part.
//

#import <Cocoa/Cocoa.h>

@class INPluginMenuController;

@interface INPluginClientController : NSObject {

	//IBOutlet NSPanel *consolePanel, *paramsPanel, *alertPanel, *errorPanel;
    IBOutlet NSTextField *colorLabel, *mainSourceLabel, *msgField, *unlockField;
    IBOutlet NSButton *silentButton, *frontButton, *storyButton;
    IBOutlet INPluginMenuController *menuController;
    IBOutlet NSTextView *consoleTextView;

    IBOutlet NSView *vals, *sliders, *maxs, *wells;
    IBOutlet NSImageView *imageWell;

    //NSString *scriptPath, *resourcePath, *mainFilePath, *executablePath, *productPath, *identity;
    int clientSocket, patchNumber, fdin, fdout, fdfile, lines, status;
    char buffer[1024*1024];
    //NSDockTile *docTile;
    FILE *scriptOutput;
    BOOL autoOpened;
}

@property (nonatomic,retain) IBOutlet NSPanel *consolePanel;
@property (nonatomic,retain) IBOutlet NSPanel *paramsPanel;
@property (nonatomic,retain) IBOutlet NSPanel *alertPanel;
@property (nonatomic,retain) IBOutlet NSPanel *errorPanel;
@property (nonatomic,retain) NSDockTile *docTile;

@property (nonatomic,retain) NSString *scriptPath;
@property (nonatomic,retain) NSString *resourcePath;
@property (nonatomic,retain) NSString *mainFilePath;
@property (nonatomic,retain) NSString *executablePath;
@property (nonatomic,retain) NSString *productPath;
@property (nonatomic,retain) NSString *identity;
@property (nonatomic,retain) NSString *arch;

- (void)alert:(NSString *)msg;
- (void)setConnection:(int)clientConnection;
- (void)runScript:(NSString *)script withArg:(NSString *)selectedFile;
- (BOOL)connected;

@end
