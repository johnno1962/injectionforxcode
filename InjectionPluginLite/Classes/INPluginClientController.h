//
//  $Id: //depot/InjectionPluginLite/Classes/INPluginClientController.h#13 $
//  InjectionPluginLite
//
//  Created by John Holdsworth on 15/01/2013.
//  Copyright (c) 2012 John Holdsworth. All rights reserved.
//
//  Manages interaction with client application and runs UNIX scripts.
//
//  This file is copyright and may not be re-distributed, whole or in part.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import <Cocoa/Cocoa.h>
#import "Xtrace.h"

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

- (IBAction)clearConsole: (id)sender;

@end
