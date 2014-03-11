//
//  $Id: //depot/InjectionPluginLite/Classes/INPluginMenuController.h#12 $
//  InjectionPluginLite
//
//  Created by John Holdsworth on 15/01/2013.
//  Copyright (c) 2012 John Holdsworth. All rights reserved.
//
//  Manages interactions with Xcode's product menu and runs TCP server.
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

#import "INPluginClientController.h"
#import "BundleInjection.h"
#import <WebKit/WebKit.h>

@interface INPluginMenuController : NSObject <NSNetServiceDelegate> {

    //IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSTextField *urlLabel;
    //IBOutlet NSPanel *webPanel;
    IBOutlet WebView *webView;
    //IBOutlet NSMenu *subMenu;
    IBOutlet NSMenuItem *subMenuItem, *introItem;

    //IBOutlet NSTextView *lastTextView;
    //IBOutlet INPluginClientController *client;

    Class DVTSourceTextView;
    Class IDEWorkspaceDocument;
    Class IDEConsoleTextView;

    //NSUserDefaults *defaults;
    int serverSocket;

    //NSMutableString *mac;
    time_t installed;
    int licensed;
    int refkey;
}

@property (nonatomic,retain) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic,retain) IBOutlet INPluginClientController *client;
@property (nonatomic,retain) IBOutlet NSPanel *webPanel;
@property (nonatomic,retain) IBOutlet NSMenu *subMenu;
@property (nonatomic,retain) NSTextView *lastTextView;
@property (nonatomic,retain) NSUserDefaults *defaults;
@property (nonatomic,retain) NSMutableString *mac;
@property (nonatomic,retain) NSString *bonjourName;

@property (nonatomic,retain) NSButton *pauseResume;
@property (nonatomic,retain) NSTextView *debugger;
@property (nonatomic,retain) NSString *lastFile;
@property (nonatomic,retain) NSWindow *lastWin;

- (NSUserDefaults *)defaults;
- (NSArray *)serverAddresses;
- (NSString *)workspacePath;

- (void)error:(NSString *)format, ...;
- (void)setProgress:(NSNumber *)fraction;
- (void)startProgress;

@end
