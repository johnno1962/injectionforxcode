//
//  $Id: //depot/injectionforxcode/InjectionPluginLite/Classes/INPluginMenuController.h#1 $
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

#import <WebKit/WebKit.h>

@class INPluginClientController;
@interface INPluginMenuController : NSObject <NSApplicationDelegate>

@property (nonatomic,retain) IBOutlet NSButton *watchButton;
@property (nonatomic,retain) IBOutlet INPluginClientController *client;
@property (nonatomic,retain) NSMutableDictionary<NSString *,NSDate *> *lastInjected;
@property (nonatomic,retain) NSString *lastFile;

- (NSUserDefaults *)defaults;
- (NSArray *)serverAddresses;
- (NSString *)workspacePath;

- (void)error:(NSString *)format, ...;
- (void)enableFileWatcher:(BOOL)enabled;
- (IBAction)watchChanged:sender;

- (void)startProgress;
- (void)setProgress:(NSNumber *)fraction;

- (NSString *)buildDirectory;
- (NSString *)logDirectory;
- (NSString *)xcodeApp;

@end

extern INPluginMenuController *injectionPlugin;
