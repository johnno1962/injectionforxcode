//
//  InInjectionPlugin.h
//  InjectionPlugin
//
//  Created by John Holdsworth on 19/09/2012.
//
//

#import "InPluginDocument.h"

@interface InInjectionPlugin : InAppDelegate {
    IBOutlet NSTextField *val0, *val1, *val2, *val3, *val4;
    IBOutlet NSSlider *slide0, *slide1, *slide2, *slide3, *slide4;
    IBOutlet NSTextField *max0, *max1, *max2, *max3, *max4;
    IBOutlet NSColorWell *well0, *well1, *well2, *well3, *well4;
    IBOutlet InImageView *imageView;

    IBOutlet NSTextField *msgField, *errField;
    IBOutlet NSMenu *menu;

    Class DVTSourceTextView, IDEWorkspaceDocument;
	NSPanel *console, *parameters, *alert, *error, *status;
    OODictionary<InPluginDocument *> projects;
    NSTextView *textView;
    NSMenuItem *subMenu;
@public
    IBOutlet NSTextField *colLabel, *projLabel;
    IBOutlet NSTextView *consoleView;
    IBOutlet WebView *statusWeb;
    IBOutlet NSButton *inPlace;
    OOString lastFile;
}

@property (nonatomic, retain) IBOutlet NSMenu *menu;
@property (nonatomic, retain) IBOutlet NSPanel *alert;
@property (nonatomic, retain) IBOutlet NSPanel *error;
@property (nonatomic, retain) IBOutlet NSPanel *status;
@property (nonatomic, retain) IBOutlet NSPanel *console;
@property (nonatomic, retain) IBOutlet NSPanel *parameters;
@property (nonatomic, retain) NSTextView *textView;

- (void)alert:(NSString *)msg;

- (void)buildError;
- (void)startProgress;

- (IBAction)convert:sender;
- (IBAction)revert:sender;
- (IBAction)inject:sender;
- (IBAction)bundle:sender;
- (IBAction)shadow:sender;

- (IBAction)slid:(NSSlider *)sender;
- (IBAction)maxd:(NSTextField *)sender;
- (IBAction)colorChanged:(NSColorWell *)sender;
- (IBAction)imageChanged:(InImageView *)sender;

- (IBAction)unlockChanged:(NSTextField *)sender;
- (IBAction)convertChanged:(NSButton *)sender;
- (IBAction)inplaceChanged:(NSButton *)sender;

@end

extern InInjectionPlugin *inInjectionPlugin;
