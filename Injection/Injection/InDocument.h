//
//  InDocument.h
//  Injection
//
//  Created by John Holdsworth on 15/01/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "InAppDelegate.h"
#import "InDirectory.h"
#import "InImageView.h"

#import <Webkit/Webkit.h>

@interface InDocument : NSDocument {
    IBOutlet NSButton *buildButton, *autoButton;
    IBOutlet NSTextField *label, *appName, *colLabel;
    IBOutlet WebView *webView, *listView;
    IBOutlet NSDrawer *drawer, *list;
    IBOutlet NSTextView *textView;

    IBOutlet NSTextField *val0, *val1, *val2, *val3, *val4;
    IBOutlet NSSlider *slide0, *slide1, *slide2, *slide3, *slide4;
    IBOutlet NSTextField *max0, *max1, *max2, *max3, *max4;
    IBOutlet NSColorWell *well0, *well1, *well2, *well3, *well4;
    IBOutlet InImageView *imageView;

    NSTextField *vals[5];
    NSSlider *sliders[5];
    NSTextField *maxs[5];
    NSColorWell *wells[5];

    char buffer[10*1024*1024];
    FILE *scriptOutput, *fileStream;

    int isDemo, clientSocket, patchNumber, fdin, fdout, fdfile, status;
    OOString projectPath, executablePath, fileFilter, lastScript;
    OODictionary<InDirectory *> includes;
    OOStringArray mdirs, filesChanged;
    FSEventStreamRef fileEvents;
    BOOL reverting, closed;
    InAppDelegate *owner;
    int firstURL, lines;
    OOTask task;
@public
    OOStringDictionary keyFiles;
}

- (void)connected:(int)newConnection binPath:(cOOString)binPath;
- (void)connected:(int)diff;

- (IBAction)openMainProject:sender;
- (IBAction)openBundleProject:sender;
- (IBAction)removeBackups:sender;
- (IBAction)revertProject:sender;
- (IBAction)testProject:sender;
- (IBAction)clearLog:sender;
- (IBAction)reopen:sender;
- (IBAction)cancel:sender;
- (IBAction)panel:sender;

- (IBAction)slid:(NSSlider *)sender;
- (IBAction)maxd:(NSTextField *)sender;
- (void)filesChanged:(NSArray *)changes;
- (IBAction)colorChanged:(NSColorWell *)sender;
- (IBAction)imageChanged:(InImageView *)sender;
- (IBAction)find:(NSString *)sender;

- (void)runScript:(cOOString)script extraArgs:(cOOStringArray)extra;
- (IBAction)startBuild:sender;
- (void)monitorScript;
- (void)mapSimulator;
- (void)listDevice;
- (BOOL)connected;
- (int)flags;

- (void)openURL:(cOOString)file;

@end
