//
//  Xtrace.h
//  Xtrace
//
//  Created by John Holdsworth on 28/02/2014.
//  Copyright (c) 2014 John Holdsworth. All rights reserved.
//
//  Repo: https://github.com/johnno1962/Xtrace
//
//  $Id: //depot/Xtrace/Xray/Xtrace.h#40 $
//
//  Class to intercept messages sent to a class or object.
//  Swizzles generic logging implemntation in place of the
//  original which is called after logging the message.
//
//  Implemented as category  on NSObject so message the
//  class or instance you want to log for example:
//
//  Log all messages of the navigation controller class
//  and it's superclasses:
//  [UINavigationController xtrace]
//
//  Log all messages sent to objects instance1/2
//  [instance1 xtrace];
//  [instance2 xtrace];
//
//  Instance tracing takes priority.
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

#ifdef DEBUG
#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#ifdef __clang__
#if __has_feature(objc_arc)
#define XTRACE_ISARC
#endif
#endif

#ifdef XTRACE_ISARC
#define XTRACE_UNSAFE __unsafe_unretained
#define XTRACE_BRIDGE(_type) (__bridge _type)
#define XTRACE_RETAINED __attribute((ns_returns_retained))
#else
#define XTRACE_UNSAFE
#define XTRACE_BRIDGE(_type) (_type)
#define XTRACE_RETAINED
#endif

#define XTRACE_EXCLUSIONS "^(initWithCoder:|_UIAppearance_|"\
    "_(initializeFor|performUpdatesForPossibleChangesOf)Idiom:|"\
    "timeIntervalSinceReferenceDate)|(WithObjects(AndKeys)?|Format):$"

// for use with "XcodeColours" plugin
// https://github.com/robbiehanson/XcodeColors

#define XTRACE_FG "\033[fg"
#define XTRACE_BG "\033[bg"

#define XTRACE_RED   XTRACE_FG"255,0,0;"
#define XTRACE_GREEN XTRACE_FG"0,255,0;"
#define XTRACE_BLUE  XTRACE_FG"0,0,255;"

// internal information
#define XTRACE_ARGS_SUPPORTED 16

typedef void (*XTRACE_VIMP)( XTRACE_UNSAFE id obj, SEL sel, ... );
typedef void (^XTRACE_BIMP)( XTRACE_UNSAFE id obj, SEL sel, ... );

struct _xtrace_arg {
    const char *name, *type;
    int stackOffset;
};

// information about original implementations
struct _xtrace_info {
    int depth;
    void *caller;
    void *lastObj;
    const char *color;

    XTRACE_VIMP before, original, after;
    XTRACE_UNSAFE XTRACE_BIMP beforeBlock, afterBlock;

    Method method;
    const char *name, *type, *mtype;
    struct _xtrace_arg args[XTRACE_ARGS_SUPPORTED+1];

    struct _stats {
        NSTimeInterval entered, elapsed;
        unsigned callCount;
    } stats;
    BOOL callingBack;
};

@interface NSObject(Xtrace)

// dump class
+ (void)xdump;

// intercept before method is called
+ (void)beforeSelector:(SEL)sel callBlock:callback;

// after intercept block replaces return value
+ (void)afterSelector:(SEL)sel callBlock:callback;

// avoid a class
+ (void)notrace;

// trace class or..
+ (void)xtrace;

// trace instance
- (void)xtrace;

// stop tacing ""
- (void)notrace;

@end

// logging delegate
@protocol XtraceDelegate
- (void)xtrace:(NSString *)trace forInstance:(void *)obj indent:(int)indent;
@end

// implementing class
@interface Xtrace : NSObject {
@public
    Class aClass;
    struct _xtrace_info *info;
    NSTimeInterval elapsed;
    int callCount;
}

// delegate for callbacks
+ (void)setDelegate:delegate;

// show caller on entry
+ (void)showCaller:(BOOL)show;

// show class implementing
+ (void)showActual:(BOOL)show;

// show log of return values
+ (void)showReturns:(BOOL)show;

// attempt log of call arguments
+ (void)showArguments:(BOOL)show;

// log values's "description"
+ (void)describeValues:(BOOL)desc;

// property methods filtered out by default
+ (void)includeProperties:(BOOL)include;

// include/exclude methods matching pattern
+ (BOOL)includeMethods:(NSString *)pattern;
+ (BOOL)excludeMethods:(NSString *)pattern;
+ (BOOL)excludeTypes:(NSString *)pattern;

// color subsequent traces
+ (void)useColor:(const char *)color;

// finer grain control of color
+ (void)useColor:(const char *)color forSelector:(SEL)sel;
+ (void)useColor:(const char *)color forClass:(Class)aClass;

// don't trace this class e.g. [UIView notrace]
+ (void)dontTrace:(Class)aClass;

// trace classes in Bundle
+ (void)traceBundle:(NSBundle *)theBundle;

// trace class down to NSObject
+ (void)traceClass:(Class)aClass;

// trace class down to "levels" of superclases
+ (void)traceClass:(Class)aClass levels:(int)levels;

// "kitchen sink" trace all classes matching pattern
+ (void)traceClassPattern:(NSString *)pattern excluding:(NSString *)exclusions;

// trace instance but only for methods in aClass
+ (void)traceInstance:(id)instance class:(Class)aClass;

// trace all messages sent to an instance
+ (void)traceInstance:(id)instance;

// stop tracing messages to instance
+ (void)notrace:(id)instance;

// dump runtime class info
+ (void)dumpClass:(Class)aClass;

// before, replacement and after callbacks to delegate
+ (void)forClass:(Class)aClass before:(SEL)sel callback:(SEL)callback;
+ (void)forClass:(Class)aClass replace:(SEL)sel callback:(SEL)callback;
+ (void)forClass:(Class)aClass after:(SEL)sel callback:(SEL)callback;

// block based callbacks as an alternative
+ (void)forClass:(Class)aClass before:(SEL)sel callbackBlock:callback;
+ (void)forClass:(Class)aClass after:(SEL)sel callbackBlock:callback;

// get parsed argument info and recorded stats
+ (struct _xtrace_info *)infoFor:(Class)aClass sel:(SEL)sel;

// name the caller of the specified method
+ (const char *)callerFor:(Class)aClass sel:(SEL)sel;

// simple profiling interface
+ (NSArray *)profile;
+ (void)dumpProfile:(unsigned)count dp:(int)decimalPlaces;

@end
#endif
#endif
