//
//  $Id: //depot/InjectionPluginLite/Classes/BundleInterface.h#15 $
//  Injection
//
//  Created by John Holdsworth on 16/01/2012.
//  Copyright (c) 2012 John Holdsworth. All rights reserved.
//
//  Interface to Code Injection system. Added to program's .pch preprocessor file.
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

#ifdef __OBJC__

#ifndef INJECTION_PLUGIN
#define INJECTION_PLUGIN "com.johnholdsworth.InjectionPlugin"
#define INJECTION_VERSION "5.1"

// scope macros
#ifdef INJECTION_ENABLED
#define _instatic
#else
#define _instatic static
#endif

#define _inglobal

#define _inval( _val... ) = _val

#ifdef INJECTION_ENABLED
#import <Foundation/Foundation.h>

// global variable interface to control panel

#define INJECTION_PARAMETERS 5
extern float INParameters[INJECTION_PARAMETERS];
extern id INDelegates[INJECTION_PARAMETERS];

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
@class UIColor;
extern UIColor *INColors[INJECTION_PARAMETERS];
#else
@class NSColor;
extern NSColor *INColors[INJECTION_PARAMETERS];
#endif

extern id INColorTargets[INJECTION_PARAMETERS];
extern SEL INColorActions[INJECTION_PARAMETERS];
extern id INColorDelegate;
extern id INImageTarget; // action is setImage:

extern NSString *kINNotification; // bundle loaded

// object interface to control panel

@interface NSObject(INParameters)
+ (float *)inParameters;
+ (float)inParameter:(int)tag;
+ (void)inSetDelegate:(id)delegate forParameter:(int)tag;
+ (void)inSetTarget:(id)target action:(SEL)action forColor:(int)tag;
+ (void)inSetImageTarget:(id)target;
@end

@interface NSObject(INParameterDelegate)
- (void)inParameter:(int)tag hasChanged:(float)value;
- (void)inColor:(int)tag hasChanged:(id)value;
- (void)injectionBundleLoaded:(NSNotification *)notification;
@end

// macro interface to control panel

#define INPARAM( _which, _dflt ) \
    INParameters[_which]
#define INJECTION_DELEGATE( _who, _which ) \
    INDelegates[_which] = _who;
#define INJECTION_DELEGATE_ALL( _who ) \
    INDelegates[0] = INDelegates[1] = INDelegates[2] = INDelegates[3] = INDelegates[4] = _who;
#define INJECTION_NOTIFY( _who ) [[NSNotificationCenter defaultCenter] \
    addObserver:_who selector:@selector(injectionBundleLoaded:) name:kINNotification object:nil]

#define INJECTION_BINDCOLOR( _who, _which ) \
    INColorTargets[_which] = _who; INColorActions[_which] = NULL;
#define INJECTION_BACKGROUND( _who, _which ) \
    INColorTargets[_which] = _who; INColorActions[_which] = @selector(setBackgroundColor:)
#define INJECTION_BINDIMAGE( _who ) \
    INImageTarget = _who
#else
#define INPARAM( _which, _dflt ) _dflt
#define INJECTION_DELEGATE( _who, _which )
#define INJECTION_DELEGATE_ALL( _who )
#define INJECTION_NOTIFY( _who )
#define INJECTION_BINDCOLOR( _who, _which )
#define INJECTION_BACKGROUND( _who, _which )
#define INJECTION_BINDIMAGE( _who )
#endif

// ARC dependencies

#ifdef __clang__
#if __has_feature(objc_arc)
#define INJECTION_ISARC 
#endif
#endif

#ifdef INJECTION_ISARC
#define INJECTION_BRIDGE(_type) (__bridge _type)
#define INJECTION_UNSAFE __unsafe_unretained
#define INJECTION_WEAK __weak
#else
#define INJECTION_BRIDGE(_type) (_type)
#define INJECTION_UNSAFE
#define INJECTION_WEAK
#endif

#endif
#endif
