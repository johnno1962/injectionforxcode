//
//  Xtrace.mm
//  Xtrace
//
//  Created by John Holdsworth on 28/02/2014.
//  Copyright (c) 2014 John Holdsworth. All rights reserved.
//
//  Repo: https://github.com/johnno1962/Xtrace
//
//  $Id: //depot/Xtrace/Xtrace.mm#4 $
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  Your milage will vary.. This is definitely a case of:
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

#import "Xtrace.h"
#import <map>

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>
#endif

@implementation NSObject(Xtrace)

+ (void)xdump {
    [Xtrace dumpClass:self];
}

+ (void)beforeSelector:(SEL)sel callBlock:callback {
    [Xtrace forClass:self before:sel callbackBlock:callback];
}

+ (void)afterSelector:(SEL)sel callBlock:callback {
    [Xtrace forClass:self after:sel callbackBlock:callback];
}

+ (void)notrace {
    [Xtrace dontTrace:self];
}

+ (void)xtrace {
    [Xtrace traceClass:self];
}

- (void)xtrace {
    [Xtrace traceInstance:self];
}

- (void)notrace {
    [Xtrace notrace:self];
}

@end

@implementation Xtrace

// Not sure this is even C..
static struct { BOOL showCaller = YES, showActual = YES, showReturns = YES, showArguments = YES,
    showSignature = NO, includeProperties = NO, describeValues = NO, logToDelegate; } params;
static int indentScale = 2;
static id delegate;

template <class _M,typename _K>
static inline bool exists( const _M &map, const _K &key ) {
    return map.find(key) != map.end();
}

+ (void)setDelegate:aDelegate {
    delegate = aDelegate;
    params.logToDelegate = [delegate respondsToSelector:@selector(xtrace:forInstance:indent:)];
}

// callback delegate can implement as instance method
+ (void)xtrace:(NSString *)trace forInstance:(void *)obj indent:(int)indent {
    printf( "| %s\n", [trace UTF8String] );
}

+ (void)showCaller:(BOOL)show {
    params.showCaller = show;
}

+ (void)showActual:(BOOL)show {
    params.showActual = show;
}

+ (void)showReturns:(BOOL)hide {
    params.showReturns = hide;
}

+ (void)includeProperties:(BOOL)include {
    params.includeProperties = include;
}

+ (void)showArguments:(BOOL)show {
    params.showArguments = show;
}

+ (void)describeValues:(BOOL)desc {
    params.describeValues = desc;
}

static std::map<XTRACE_UNSAFE Class,std::map<SEL,struct _xtrace_info> > originals;
static std::map<XTRACE_UNSAFE Class,const char *> tracedClasses; // trace color
static std::map<XTRACE_UNSAFE Class,BOOL> swizzledClasses, excludedClasses;
static std::map<XTRACE_UNSAFE Class,int> tracingInstances;
static std::map<XTRACE_UNSAFE id,BOOL> tracedInstances;
static std::map<SEL,const char *> selectorColors;

+ (void)dontTrace:(Class)aClass {
    Class metaClass = object_getClass(aClass);
    excludedClasses[metaClass] = 1;
    excludedClasses[aClass] = 1;
}

+ (void)traceBundle:(NSBundle *)theBundle {
    unsigned nc;
    Class *classes = objc_copyClassList( &nc );
    for ( unsigned i =0 ; i < nc ; i++ ) {
        Class aClass = classes[i];
        NSString *className = NSStringFromClass(aClass);
        if ( ![className hasPrefix:@"_T"] && [NSBundle bundleForClass:aClass] == theBundle ) {
            [self traceClass: aClass levels: 1];
        }
    }
}

+ (void)traceClass:(Class)aClass {
    [self traceClass:aClass levels:99];
}

+ (void)traceClass:(Class)aClass levels:(int)levels {
    if ( aClass == [NSObject class] ) {
        NSLog( @"Tracing NSObject will not trace all classes" );
        return;
    }
#ifdef __arm64__
    #warning Xtrace will not work on an ARM64 build. Rebuild for $(ARCHS_STANDARD_32_BIT).
    NSLog( @"Xtrace will not work on an ARM64 build. Rebuild for $(ARCHS_STANDARD_32_BIT)." );
#else
    Class metaClass = object_getClass(aClass);
    [self traceClass:metaClass mtype:"+" levels:levels];
    [self traceClass:aClass mtype:"" levels:levels];
#endif
}

+ (void)traceInstance:(id)instance class:(Class)aClass {
    [self traceClass:aClass levels:1];
    tracedInstances[instance] = YES;
    tracingInstances[aClass]++;
}

+ (void)traceInstance:(id)instance {
    Class aClass = [instance class];
    [self traceClass:aClass];
    tracedInstances[instance] = YES;
    tracingInstances[aClass]++;
}

+ (void)notrace:(id)instance {
    auto i = tracedInstances.find(instance);
    if ( i != tracedInstances.end() )
        tracedInstances.erase(i);

}

+ (void)forClass:(Class)aClass before:(SEL)sel callback:(SEL)callback {
    if ( !(originals[aClass][sel].before = [self forClass:aClass intercept:sel callback:callback]) )
        NSLog( @"Xtrace: ** Could not setup before callback for: [%s %s]", class_getName(aClass), sel_getName(sel) );
}

+ (void)forClass:(Class)aClass replace:(SEL)sel callback:(SEL)callback {
    if ( !(originals[aClass][sel].original = [self forClass:aClass intercept:sel callback:callback]) )
        NSLog( @"Xtrace: ** Could not setup replace callback for: [%s %s]", class_getName(aClass), sel_getName(sel) );
}

+ (void)forClass:(Class)aClass after:(SEL)sel callback:(SEL)callback {
    if ( !(originals[aClass][sel].after = [self forClass:aClass intercept:sel callback:callback]) )
        NSLog( @"Xtrace: ** Could not setup after callback for: [%s %s]", class_getName(aClass), sel_getName(sel) );
}

+ (void)forClass:(Class)aClass before:(SEL)sel callbackBlock:callback {
    [self intercept:aClass method:class_getInstanceMethod(aClass, sel) mtype:NULL
              depth:[self depth:aClass]]->beforeBlock = XTRACE_BRIDGE(XTRACE_BIMP)CFRetain( XTRACE_BRIDGE(CFTypeRef)callback );
}

+ (void)forClass:(Class)aClass after:(SEL)sel callbackBlock:callback {
    [self intercept:aClass method:class_getInstanceMethod(aClass, sel) mtype:NULL
              depth:[self depth:aClass]]->afterBlock = XTRACE_BRIDGE(XTRACE_BIMP)CFRetain( XTRACE_BRIDGE(CFTypeRef)callback );
}

+ (XTRACE_VIMP)forClass:(Class)aClass intercept:(SEL)sel callback:(SEL)callback {
    return [self intercept:aClass method:class_getInstanceMethod(aClass, sel) mtype:NULL
                     depth:[self depth:aClass]] ? (XTRACE_VIMP)[delegate methodForSelector:callback] : NULL;
}

+ (int)depth:(Class)aClass {
    int depth = 0;
    for ( Class nsObject = [NSObject class], nsObjectMeta = object_getClass( nsObject ) ;
         aClass && aClass != nsObject && aClass != nsObjectMeta ; aClass = class_getSuperclass( aClass ) )
        depth++;
    return depth;
}

static NSRegularExpression *includeMethods, *excludeMethods, *excludeTypes;

+ (BOOL)includeMethods:(NSString *)pattern {
    return (includeMethods = [self getRegexp:pattern]) != NULL;
}

+ (BOOL)excludeMethods:(NSString *)pattern {
    return (excludeMethods = [self getRegexp:pattern]) != NULL;
}

+ (BOOL)excludeTypes:(NSString *)pattern {
    return (excludeTypes = [self getRegexp:pattern]) != NULL;
}

+ (NSRegularExpression *)getRegexp:(NSString *)pattern {
    if ( !pattern )
        return nil;
    NSError *error = nil;
    NSRegularExpression *regexp = [[NSRegularExpression alloc] initWithPattern:pattern options:0 error:&error];
    if ( error )
        NSLog( @"Xtrace: Filter compilation error: %@, in pattern: \"%@\"", [error localizedDescription], pattern );
    return regexp;
}

static const char *noColor = "", *traceColor = noColor;

+ (void)useColor:(const char *)color {
    if ( !color ) color = noColor;
    traceColor = color;
}

+ (void)useColor:(const char *)color forSelector:(SEL)sel {
    if ( !color ) color = noColor;
    selectorColors[sel] = color;
}

+ (void)useColor:(const char *)color forClass:(Class)aClass {
    if ( !color ) color = noColor;
    Class metaClass = object_getClass(aClass);
    tracedClasses[metaClass] = color;
    tracedClasses[aClass] = color;
}

+ (void)traceClass:(Class)aClass mtype:(const char *)mtype levels:(int)levels {

    if ( !tracedClasses[aClass] )
        tracedClasses[aClass] = traceColor;
    swizzledClasses[aClass] = NO;

    // yes, this is a hack
    if ( !excludeMethods )
        [self excludeMethods:@XTRACE_EXCLUSIONS];

    Class nsObject = [NSObject class], nsObjectMeta = object_getClass( nsObject );
    NSMutableString *nameStr = [NSMutableString new];
    int depth = [self depth:aClass];

    for ( int l=0 ; l<levels ; l++ ) {

        if ( !swizzledClasses[aClass] && !exists( excludedClasses, aClass ) ) {
            unsigned mc = 0;
            const char *className = class_getName(aClass);
            Method *methods = class_copyMethodList(aClass, &mc);

           for( unsigned i=0; methods && i<mc; i++ ) {
                const char *type = method_getTypeEncoding(methods[i]);
                const char *name = sel_getName(method_getName(methods[i]));
                [nameStr appendFormat:@"%s", name];

                if ( ((includeMethods && ![self string:nameStr matches:includeMethods]) ||
                      (excludeMethods && [self string:nameStr matches:excludeMethods])) )
                   ;//NSLog( @"Xtrace: filters exclude: %s[%s %s] %s", mtype, className, name, type );

                else if ( (excludeTypes && [self string:[NSString stringWithUTF8String:type] matches:excludeTypes]) )
                    NSLog( @"Xtrace: type filter excludes: %s[%s %s] %s", mtype, className, name, type );

                else if ( name[0] == '.' ||
                         [nameStr isEqualToString:@"_isDeallocating"] || [nameStr isEqualToString:@"_tryRetain"] ||
                         [nameStr isEqualToString:@"description"] || [nameStr hasPrefix:@"_description"] ||
                         [nameStr isEqualToString:@"retain"] || [nameStr isEqualToString:@"release"] /*||
                         [nameStr isEqualToString:@"dealloc"] || [nameStr hasPrefix:@"_dealloc"]*/ )
                    ; // best avoided

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
                else if ( aClass == [UIView class] && [nameStr isEqualToString:@"drawRect:"] )
                    ; // no idea why this is a problem...
#endif

                else if (params.includeProperties || !class_getProperty( aClass, name ))
                    [self intercept:aClass method:methods[i] mtype:mtype depth:depth];

               [nameStr setString:@""];
            }

            swizzledClasses[aClass] = YES;
            free( methods );
        }

        aClass = class_getSuperclass(aClass);
        if ( !--depth || aClass == nsObject || aClass == nsObjectMeta ) // don't trace NSObject
            break;
    }
}

+ (void)traceClassPattern:(NSString *)pattern excluding:(NSString *)exclusions {
    NSRegularExpression *include = [self getRegexp:pattern], *exclude = [self getRegexp:exclusions];
    unsigned ccount;
    Class *classes = objc_copyClassList( &ccount );
    for ( unsigned i=0 ; i<ccount ; i++ ) {
        NSString *className = [NSString stringWithUTF8String:class_getName(classes[i])];
        if ( [self string:className matches:include] && (!exclude || ![self string:className matches:exclude]) )
            [self traceClass:classes[i]];
    }
    free( classes );
}

+ (BOOL)string:(NSString *)name matches:(NSRegularExpression *)regexp {
    return [regexp rangeOfFirstMatchInString:name options:0 range:NSMakeRange(0, [name length])].location != NSNotFound;
}

+ (struct _xtrace_info *)infoFor:(Class)aClass sel:(SEL)sel {
    return &originals[aClass][sel];
}

#import <dlfcn.h>

+ (const char *)callerFor:(void *)caller {
    static std::map<void *,const char *> callers;

    if ( !exists( callers, caller ) ) {
        Dl_info info;
        if ( dladdr(caller, &info) && info.dli_sname )
            callers[caller] = strdup(info.dli_sname);
    }

    return callers[caller];
}

+ (const char *)callerFor:(Class)aClass sel:(SEL)sel {
    return [self callerFor:originals[aClass][sel].caller];
}

// should really be per-thread but can deadlock
static struct { int indent;  BOOL describing; } state;

#define APPEND_TYPE( _enc, _fmt, _type ) case _enc: [args appendFormat:_fmt, va_arg(*argp,_type)]; return YES;

static BOOL formatValue( const char *type, void *valptr, va_list *argp, NSMutableString *args ) {
    switch ( type[0] == 'r' ? type[1] : type[0] ) {
        case 'V': case 'v':
            return NO;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wvarargs"
        // warnings here are necessary evil
        APPEND_TYPE( 'B', @"%d", bool )
        APPEND_TYPE( 'c', @"%d", char )
        APPEND_TYPE( 'C', @"%d", unsigned char )
        APPEND_TYPE( 's', @"%d", short )
        APPEND_TYPE( 'S', @"%d", unsigned short )
        APPEND_TYPE( 'i', @"%d", int )
        APPEND_TYPE( 'I', @"%u", unsigned )
        APPEND_TYPE( 'f', @"%f", float )
#pragma clang diagnostic pop
        APPEND_TYPE( 'd', @"%f", double )
        APPEND_TYPE( '^', @"%p", void * )
        APPEND_TYPE( '*', @"\"%.100s\"", char * )
#ifndef __LP64__
        APPEND_TYPE( 'q', @"%lldLL", long long )
#else
        case 'q':
#endif
        APPEND_TYPE( 'l', @"%ldL", long )
#ifndef __LP64__
        APPEND_TYPE( 'Q', @"%lluLL", unsigned long long )
#else
        case 'Q':
#endif
        APPEND_TYPE( 'L', @"%luL", unsigned long )
        case ':':
            [args appendFormat:@"@selector(%s)", sel_getName(va_arg(*argp,SEL))];
            return YES;
        case '#': case '@': {
            XTRACE_UNSAFE id obj = va_arg(*argp,XTRACE_UNSAFE id);
            if ( [obj isKindOfClass:[NSString class]] )
                [args appendFormat:@"@\"%@\"", obj];
            else if ( params.describeValues ) {
                state.describing = YES;
                [args appendString:obj?[obj description]:@"<nil>"];
                state.describing = NO;
            }
            else
                [args appendFormat:@"<%s %p>", class_getName(object_getClass(obj)), obj];
            return YES;
        }
        case '{':
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
            if ( strncmp(type,"{CGRect=",8) == 0 )
                [args appendString:NSStringFromCGRect( va_arg(*argp,CGRect) )];
            else if ( strncmp(type,"{CGPoint=",9) == 0 )
                [args appendString:NSStringFromCGPoint( va_arg(*argp,CGPoint) )];
            else if ( strncmp(type,"{CGSize=",8) == 0 )
                [args appendString:NSStringFromCGSize( va_arg(*argp,CGSize) )];
            else if ( strncmp(type,"{CGAffineTransform=",19) == 0 )
                [args appendString:NSStringFromCGAffineTransform( va_arg(*argp,CGAffineTransform) )];
            else if ( strncmp(type,"{UIEdgeInsets=",14) == 0 )
                [args appendString:NSStringFromUIEdgeInsets( va_arg(*argp,UIEdgeInsets) )];
            else if ( strncmp(type,"{UIOffset=",10) == 0 )
                [args appendString:NSStringFromUIOffset( va_arg(*argp,UIOffset) )];
#else
            if ( strncmp(type,"{_NSRect=",9) == 0 || strncmp(type,"{CGRect=",8) == 0 )
                [args appendString:NSStringFromRect( va_arg(*argp,NSRect) )];
            else if ( strncmp(type,"{_NSPoint=",10) == 0 || strncmp(type,"{CGPoint=",9) == 0 )
                [args appendString:NSStringFromPoint( va_arg(*argp,NSPoint) )];
            else if ( strncmp(type,"{_NSSize=",9) == 0 || strncmp(type,"{CGSize=",8) == 0 )
                [args appendString:NSStringFromSize( va_arg(*argp,NSSize) )];
#endif
            else if ( strncmp(type,"{_NSRange=",10) == 0 )
                [args appendString:NSStringFromRange( va_arg(*argp,NSRange) )];
            else
                break;
            return YES;
    }

    [args appendFormat:@"<?? %.50s>", type];
    return NO;
}

struct _xtrace_depth {
    XTRACE_UNSAFE id obj; SEL sel; int depth;
};

static id nullImpl( XTRACE_UNSAFE __unused id obj, __unused SEL sel, ... ) {
    return nil;
}

// find original implmentation for message and log call
static struct _xtrace_info &findOriginal( struct _xtrace_depth *info, SEL sel, ... ) {
    va_list argp; va_start(argp, sel);
    Class aClass = object_getClass( info->obj );
    const char *className = class_getName( aClass );

    while ( aClass && (!exists( originals[aClass], sel ) ||
                       originals[aClass][sel].depth != info->depth) )
        aClass = class_getSuperclass( aClass );

    struct _xtrace_info &orig = originals[aClass][sel];
    orig.lastObj = XTRACE_BRIDGE(void*)info->obj;
    orig.caller = __builtin_return_address(1);

    if ( !aClass ) {
        NSLog( @"Xtrace: could not find original implementation for [%s %s]", className, sel_getName(sel) );
        orig.original = (XTRACE_VIMP)nullImpl;
    }

    static char KVO_prefix[] = "NSKVONotifying_";
    while ( aClass && strncmp( class_getName(aClass), KVO_prefix, sizeof(KVO_prefix)-1 ) == 0 )
        aClass = class_getSuperclass(aClass);

    Class implementingClass = aClass;
    aClass = object_getClass( info->obj );

    // add custom filtering of logging here..
    if ( !state.describing && orig.mtype &&
        (exists( tracingInstances, aClass ) ?
         exists( tracedInstances, info->obj ) :
         tracedClasses[aClass] != nil) )
        orig.color = exists( selectorColors, sel ) ?
                selectorColors[sel] : tracedClasses[aClass];
    else
        orig.color = NULL;

    if ( orig.color ) {
        NSMutableString *args = [NSMutableString string];

        const char *symbol;
        if ( params.showCaller && state.indent == 0 &&
            (symbol = [Xtrace callerFor:orig.caller]) && symbol[0] != '<' ) {
            [args appendFormat:@"From: %s", symbol];
            [params.logToDelegate ? delegate : [Xtrace class] xtrace:args forInstance:orig.lastObj indent:-2];
            [args setString:@""];
        }

        if ( orig.color && orig.color[0] )
            [args appendFormat:@"%s", orig.color];

        if ( orig.mtype[0] == '+' )
            [args appendFormat:@"%*s%s[%s",
             state.indent++*indentScale, "", orig.mtype, className];
        else
            [args appendFormat:@"%*s%s[<%s %p>",
             state.indent++*indentScale, "", orig.mtype, className, info->obj];

        if ( params.showActual && implementingClass != aClass )
            [args appendFormat:@"/%s", class_getName(implementingClass)];

        if ( !params.showArguments )
            [args appendFormat:@" %s", orig.name];
        else {
            const char *frame = (char *)(void *)&info+sizeof info;
            void *valptr = NULL;

            BOOL typesKnown = YES;
            for ( struct _xtrace_arg *aptr = orig.args ; *aptr->name ; aptr++ ) {
                [args appendFormat:@" %.*s", (int)(aptr[1].name-aptr->name), aptr->name];
                if ( !aptr->type )
                    break;

                valptr = (void *)(frame+aptr[1].stackOffset);
                typesKnown = typesKnown &&
                    formatValue( aptr->type, valptr, &argp, args );
            }
        }

        [args appendString:@"]"];
        if ( params.showSignature )
            [args appendFormat:@" %.100s %p", orig.type, orig.original];
        if ( orig.color && orig.color[0] )
            [args appendString:@"\033[;"];
        [params.logToDelegate ? delegate : [Xtrace class] xtrace:args forInstance:orig.lastObj indent:state.indent];
    }

    orig.stats.entered = [NSDate timeIntervalSinceReferenceDate];
    orig.stats.callCount++;
    return orig;
}

// log returning value
static void returning( struct _xtrace_info *orig, ... ) {
    va_list argp; va_start(argp, orig);
    if ( state.indent > 0 )
        state.indent--;

    orig->stats.elapsed += [NSDate timeIntervalSinceReferenceDate] - orig->stats.entered;

    if ( orig->color && params.showReturns ) {
        NSMutableString *val = [NSMutableString string];
        [val appendFormat:@"%s%*s-> ", orig->color, state.indent*indentScale, ""];
        if ( formatValue(orig->type, NULL, &argp, val) ) {
            [val appendFormat:@" (%s)", orig->name];
            if ( orig->color && orig->color[0] )
                [val appendString:@"\033[;"];
            [params.logToDelegate ? delegate : [Xtrace class] xtrace:val forInstance:orig->lastObj indent:-1];
        }
    }
}

#define ARG_SIZE (sizeof(id) + sizeof(SEL) + sizeof(void *)*9) // approximate to say the least..
#ifndef __LP64__
#define ARG_DEFS void *a0, void *a1, void *a2, void *a3, void *a4, void *a5, void *a6, void *a7, void *a8, void *a9
#define ARG_COPY a0, a1, a2, a3, a4, a5, a6, a7, a8, a9
#else
#define ARG_DEFS void *a0, void *a1, void *a2, void *a3, void *a4, void *a5, void *a6, void *a7, void *a8, void *a9, double d0, double d1, double d2, double d3, double d4, double d5, double d6, double d7
#define ARG_COPY a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, d0, d1, d2, d3, d4, d5, d6, d7
#endif

// replacement implmentations "swizzled" onto class
// "_depth" is number of levels down from NSObject
// (used to detect calls to super)
template <typename _type, int _depth>
static void xtrace( XTRACE_UNSAFE id obj, SEL sel, ARG_DEFS ) {
    struct _xtrace_depth info = { obj, sel, _depth };
    struct _xtrace_info &orig = findOriginal( &info, sel, ARG_COPY );

    if ( !orig.callingBack ) {
        if ( orig.before ) {
            orig.callingBack = YES;
            orig.before( delegate, sel, obj, ARG_COPY );
            orig.callingBack = NO;
        }
        if ( orig.beforeBlock ) {
            orig.callingBack = YES;
            orig.beforeBlock( obj, sel, ARG_COPY );
            orig.callingBack = NO;
        }
    }

    orig.original( obj, sel, ARG_COPY );

    if ( !orig.callingBack ) {
        if ( orig.after ) {
            orig.callingBack = YES;
            orig.after( delegate, sel, obj, ARG_COPY );
            orig.callingBack = NO;
        }
        if ( orig.afterBlock ) {
            orig.callingBack = YES;
            orig.afterBlock( obj, sel, ARG_COPY );
            orig.callingBack = NO;
        }
    }

    returning( &orig );
}

template <typename _type, int _depth>
static _type XTRACE_RETAINED xtrace_t( XTRACE_UNSAFE id obj, SEL sel, ARG_DEFS ) {
    struct _xtrace_depth info = { obj, sel, _depth };
    struct _xtrace_info &orig = findOriginal( &info, sel, ARG_COPY );

    if ( !orig.callingBack ) {
        if ( orig.before ) {
            orig.callingBack = YES;
            orig.before( delegate, sel, obj, ARG_COPY );
            orig.callingBack = NO;
        }
        if ( orig.beforeBlock ) {
            orig.callingBack = YES;
            orig.beforeBlock( obj, sel, ARG_COPY );
            orig.callingBack = NO;
        }
    }

    typedef _type (*TIMP)( XTRACE_UNSAFE id obj, SEL sel, ... );
    TIMP impl = (TIMP)orig.original;
    _type out = impl( obj, sel, ARG_COPY );

    if ( !orig.callingBack ) {
        if ( orig.after ) {
            orig.callingBack = YES;
            impl = (TIMP)orig.after;
            out = impl( delegate, sel, out, obj, ARG_COPY );
            orig.callingBack = NO;
        }
        if ( orig.afterBlock ) {
            typedef _type (^BTIMP)( XTRACE_UNSAFE id obj, SEL sel, _type out, ... );
            orig.callingBack = YES;
            BTIMP timpl = (BTIMP)orig.afterBlock;
            out = timpl( obj, sel, out, ARG_COPY );
            orig.callingBack = NO;
        }
    }

    returning( &orig, out );
    return out;
}

+ (struct _xtrace_info *)intercept:(Class)aClass method:(Method)method mtype:(const char *)mtype depth:(int)depth {
    if ( !method )
        NSLog( @"Xtrace: unknown method" );

    SEL sel = method_getName(method);
    const char *name = sel_getName(sel);
    const char *className = class_getName(aClass);
    const char *type = method_getTypeEncoding(method);
    if ( !type )
        return NULL;

    IMP newImpl = NULL;
    switch ( type[0] == 'r' ? type[1] : type[0] ) {

#define IMPL_COUNT 10
#define IMPLS( _func, _type ) \
switch ( depth%IMPL_COUNT ) { \
    case 0: newImpl = (IMP)_func<_type,0>; break; \
    case 1: newImpl = (IMP)_func<_type,1>; break; \
    case 2: newImpl = (IMP)_func<_type,2>; break; \
    case 3: newImpl = (IMP)_func<_type,3>; break; \
    case 4: newImpl = (IMP)_func<_type,4>; break; \
    case 5: newImpl = (IMP)_func<_type,5>; break; \
    case 6: newImpl = (IMP)_func<_type,6>; break; \
    case 7: newImpl = (IMP)_func<_type,7>; break; \
    case 8: newImpl = (IMP)_func<_type,8>; break; \
    case 9: newImpl = (IMP)_func<_type,9>; break; \
}
        case 'V':
        case 'v': IMPLS( xtrace, void ); break;

        case 'B': IMPLS( xtrace_t, bool ); break;
        case 'C':
        case 'c': IMPLS( xtrace_t, char ); break;
        case 'S':
        case 's': IMPLS( xtrace_t, short ); break;
        case 'I':
        case 'i': IMPLS( xtrace_t, int ); break;
        case 'Q':
        case 'q':
#ifndef __LP64__
            IMPLS( xtrace_t, long long ); break;
#endif
        case 'L':
        case 'l': IMPLS( xtrace_t, long ); break;
        case 'f': IMPLS( xtrace_t, float ); break;
        case 'd': IMPLS( xtrace_t, double ); break;
        case '#':
        case '@': IMPLS( xtrace_t, id ) break;
        case '^': IMPLS( xtrace_t, void * ); break;
        case ':': IMPLS( xtrace_t, SEL ); break;
        case '*': IMPLS( xtrace_t, char * ); break;
        case '{':
            if ( strncmp(type,"{_NSRange=",10) == 0 )
                IMPLS( xtrace_t, NSRange )
#ifndef __IPHONE_OS_VERSION_MIN_REQUIRED
            else if ( strncmp(type,"{_NSRect=",9) == 0 )
                IMPLS( xtrace_t, NSRect )
            else if ( strncmp(type,"{_NSPoint=",10) == 0 )
                IMPLS( xtrace_t, NSPoint )
            else if ( strncmp(type,"{_NSSize=",9) == 0 )
                IMPLS( xtrace_t, NSSize )
#endif
            else if ( strncmp(type,"{CGRect=",8) == 0 )
                IMPLS( xtrace_t, CGRect )
            else if ( strncmp(type,"{CGPoint=",9) == 0 )
                IMPLS( xtrace_t, CGPoint )
            else if ( strncmp(type,"{CGSize=",8) == 0 )
                IMPLS( xtrace_t, CGSize )
            else if ( strncmp(type,"{CGAffineTransform=",19) == 0 )
                IMPLS( xtrace_t, CGAffineTransform )
            break;
        default:
            NSLog(@"Xtrace: Unsupported return type: %s for: %s[%s %s]", type, mtype, className, name);
    }

    const char *frameSize = type+1;
    while ( !isdigit(*frameSize) )
        frameSize++;

    if ( atoi(frameSize) > (int)ARG_SIZE )
        NSLog( @"Xtrace: Stack frame too large to trace method: %s[%s %s]", mtype, className, name );

    else if ( newImpl ) {

        struct _xtrace_info &orig = originals[aClass][sel];

        orig.name = name;
        orig.type = type;
        orig.method = method;
        orig.depth = depth%IMPL_COUNT;
        if ( mtype )
            orig.mtype = mtype;

        [self extractSelector:name into:orig.args maxargs:XTRACE_ARGS_SUPPORTED];
        [self extractOffsets:type into:orig.args maxargs:XTRACE_ARGS_SUPPORTED];

        IMP impl = method_getImplementation(method);
        if ( impl != newImpl ) {
            orig.original = (XTRACE_VIMP)impl;
            method_setImplementation(method,newImpl);
            //NSLog( @"%d %s%s %s %s", depth, mtype, className, name, type );
        }

        return &orig;
    }

    return NULL;
}

// break up selector by argument
+ (int)extractSelector:(const char *)name into:(struct _xtrace_arg *)args maxargs:(int)maxargs {

    for ( int i=0 ; i<maxargs ; i++ ) {
        args->name = name;
        const char *next = index( name, ':' );
        if ( next ) {
            name = next+1;
            args++;
        }
        else {
            args[1].name = name+strlen(name);
            return i;
        }
    }

    return -1;
}

// parse method encoding for call stack offsets (replaced by varargs)

#if 1 // original version using information in method type encoding

+ (int)originalExtractOffsets:(const char *)type into:(struct _xtrace_arg *)args maxargs:(int)maxargs {
    int frameLen = -1;

    for ( int i=0 ; i<maxargs ; i++ ) {
        args->type = type;
        while ( !isdigit(*type) || type[1] == ',' )
            type++;
        args->stackOffset = -atoi(type);
        if ( i==0 )
            frameLen = args->stackOffset;
        while ( isdigit(*type) )
            type++;
        if ( i>2 )
            args++;
        else
            args->type = NULL;
        if ( !*type ) {
            args->stackOffset = frameLen;
            return i;
        }
    }

    return -1;
}

#else // alternate "NSGetSizeAndAlignment()" version

+ (int)extractOffsets:(const char *)type into:(struct _xtrace_arg *)args maxargs:(int)maxargs {
    NSUInteger size, align, offset = 0;

    type = NSGetSizeAndAlignment( type, &size, &align );

    for ( int i=0 ; i<maxargs ; i++ ) {
        while ( isdigit(*type) )
            type++;
        args->type = type;
        type = NSGetSizeAndAlignment( type, &size, &align );
        if ( !*type ) {
            args->type = NULL;
            return i;
        }
        offset -= size;
        offset &= ~(align-1 | sizeof(void *)-1);
        args[1].stackOffset = (int)offset;
        if ( i>1 )
            args++;
        else
            args->type = NULL;
    }

    return -1;
}

#endif // Extract types using NSMethodSignature - can give unsuppported type error

+ (int)extractOffsets:(const char *)type into:(struct _xtrace_arg *)args maxargs:(int)maxargs {
    @try {
        NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:type];
        int acount = (int)[sig numberOfArguments];

        for ( int i=2 ; i<acount ; i++ )
            args[i-2].type = [sig getArgumentTypeAtIndex:i];

        return acount-2;
    }
    @catch ( NSException *e ) {
        NSLog( @"Xtrace: exception %@ on signature: %s", e, type );
        [self originalExtractOffsets:type into:args maxargs:maxargs];
    }
}

+ (void)dumpClass:(Class)aClass {
    NSMutableString *str = [NSMutableString string];
    [str appendFormat:@"@interface %s : %s {\n", class_getName(aClass), class_getName(class_getSuperclass(aClass))];

    unsigned c;
    Ivar *ivars = class_copyIvarList(aClass, &c);
    for ( unsigned i=0 ; i<c ; i++ ) {
        const char *type = ivar_getTypeEncoding(ivars[i]);
        [str appendFormat:@"    %@ %s; // %s\n", [self xtype:type], ivar_getName(ivars[i]), type];
    }
    free( ivars );
    [str appendString:@"}\n\n"];

    objc_property_t *props = class_copyPropertyList(aClass, &c);
    for ( unsigned i=0 ; i<c ; i++ ) {
        const char *attrs = property_getAttributes(props[i]);
        [str appendFormat:@"@property () %@ %s; // %s\n", [self xtype:attrs+1], property_getName(props[i]), attrs];
    }
    free( props );

    [self dumpMethodType:"+" forClass:object_getClass(aClass) into:str];
    [self dumpMethodType:"-" forClass:aClass into:str];
    printf( "%s\n@end\n\n", [str UTF8String] );
}

+ (void)dumpMethodType:(const char *)mtype forClass:(Class)aClass into:(NSMutableString *)str {
    [str appendString:@"\n"];
    unsigned mc;
    Method *methods = class_copyMethodList(aClass, &mc);
    for ( unsigned i=0 ; i<mc ; i++ ) {
        const char *name = sel_getName(method_getName(methods[i]));
        const char *type = method_getTypeEncoding(methods[i]);
        [str appendFormat:@"%s (%@)", mtype, [self xtype:type]];

#define MAXARGS 99
        struct _xtrace_arg args[MAXARGS+1];
        [self extractSelector:name into:args maxargs:MAXARGS];
        [self extractOffsets:type into:args maxargs:MAXARGS];

        for ( int a=0 ; a<MAXARGS ; a++ ) {
            if ( !args[a].name[0] )
                break;
            [str appendFormat:@"%.*s", (int)(args[a+1].name-args[a].name), args[a].name];
            if ( !args[a].type )
                break;
            [str appendFormat:@"(%@)a%d ", [self xtype:args[a].type], a];
        }

        [str appendFormat:@"; // %s\n", type];
    }

    free( methods );
}

+ (NSString *)xtype:(const char *)type {
    switch ( type[0] ) {
        case 'V': return @"oneway void";
        case 'v': return @"void";
        case 'B': return @"bool";
        case 'c': return @"char";
        case 'C': return @"unsigned char";
        case 's': return @"short";
        case 'S': return @"unsigned short";
        case 'i': return @"int";
        case 'I': return @"unsigned";
        case 'f': return @"float";
        case 'd': return @"double";
#ifndef __LP64__
        case 'q': return @"long long";
#else
        case 'q':
#endif
        case 'l': return @"long";
#ifndef __LP64__
        case 'Q': return @"unsigned long long";
#else
        case 'Q':
#endif
        case 'L': return @"unsigned long";
        case ':': return @"SEL";
        case '#': return @"Class";
        case '@': return [self xtype:type+1 star:" *"];
        case '^': return [self xtype:type+1 star:" *"];
        case '{': return [self xtype:type star:""];
        case 'r':
            return [@"const " stringByAppendingString:[self xtype:type+1]];
        case '*': return @"char *";
        default:
            return @"id";
    }
}

+ (NSString *)xtype:(const char *)type star:(const char *)star {
    if ( type[-1] == '@' ) {
        if ( type[0] != '"' )
            return @"id";
        else if ( type[1] == '<' )
            type++;
    }
    if ( type[-1] == '^' && type[0] != '{' )
        return [[self xtype:type] stringByAppendingString:@" *"];

    const char *end = ++type;
    while ( isalpha(*end) || *end == '_' || *end == ',' )
        end++;
    if ( type[-1] == '<' )
        return [NSString stringWithFormat:@"id<%.*s>", (int)(end-type), type];
    else
        return [NSString stringWithFormat:@"%.*s%s", (int)(end-type), type, star];
}

+ (NSArray *)profile {
    NSMutableArray *profile = [NSMutableArray array];

    for ( auto &byClass : originals )
        for ( auto &bySel : byClass.second ) {
            Xtrace *trace = [Xtrace new];
            trace->aClass = byClass.first;
            trace->info = &bySel.second;
            trace->callCount = trace->info->stats.callCount;
            trace->elapsed = trace->info->stats.elapsed;
            trace->info->stats.callCount = 0;
            trace->info->stats.elapsed = 0;
            [profile addObject:trace];
        }

    [profile sortUsingSelector:@selector(compareElapsed:)];
    return profile;
}

+ (void)dumpProfile:(unsigned)count dp:(int)decimalPlaces {
    NSArray *profile = [self profile];
    for ( unsigned i=0 ; i<count && i<[profile count] ; i++ ) {
        Xtrace *trace = [profile objectAtIndex:i];
        if ( !trace->info->color )
            trace->info->color = noColor;
        printf( "%s%.*f/%-4d %s[%s %s]%s\n",
               trace->info->color, decimalPlaces, trace->elapsed, trace->callCount,
               trace->info->mtype, class_getName(trace->aClass), trace->info->name,
               trace->info->color[0] ? "\033[;" : "" );
    }
}

- (NSComparisonResult)compareElapsed:(Xtrace *)other {
    return self->elapsed > other->elapsed ? NSOrderedAscending : self->elapsed == other->elapsed ? NSOrderedSame : NSOrderedDescending;
}

@end
#endif
