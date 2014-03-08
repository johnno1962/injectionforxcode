//
//  Xtrace.mm
//  Xtrace
//
//  Created by John Holdsworth on 28/02/2014.
//  Copyright (c) 2014 John Holdsworth. All rights reserved.
//
//  Repo: https://github.com/johnno1962/Xtrace
//
//  $Id: //depot/Xtrace/Xray/Xtrace.mm#52 $
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  Your milage will vary.. This is definitely a case of:
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#ifdef DEBUG

#import "Xtrace.h"
#import <map>

@implementation NSObject(Xtrace)

+ (void)notrace {
    [Xtrace dontTrace:self];
}

+ (void)xtrace {
    [Xtrace traceClass:self];
}

- (void)xtrace {
    [Xtrace traceInstance:self];
}

- (void)untrace {
    [Xtrace untrace:self];
}

@end

@implementation Xtrace

static BOOL includeProperties, hideReturns, showArguments = YES, describeValues, logToDelegate;
static id delegate;

+ (void)setDelegate:aDelegate {
    delegate = aDelegate;
    logToDelegate = [delegate respondsToSelector:@selector(xtraceLog:)];
}

+ (void)hideReturns:(BOOL)hide {
    hideReturns = hide;
}

+ (void)includeProperties:(BOOL)include {
    includeProperties = include;
}

+ (void)showArguments:(BOOL)show {
    showArguments = show;
}

+ (void)describeValues:(BOOL)desc {
    describeValues = desc;
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

static std::map<Class,std::map<SEL,struct _xtrace_info> > originals;
static std::map<Class,BOOL> tracedClasses, excludedClasses;
static std::map<XTRACE_UNSAFE id,BOOL> tracedInstances;
static BOOL tracingInstances;
static int indent;

+ (void)dontTrace:(Class)aClass {
    Class metaClass = object_getClass(aClass);
    excludedClasses[metaClass] = 1;
    excludedClasses[aClass] = 1;
}

+ (void)traceClass:(Class)aClass {
    [self traceClass:aClass levels:99];
}

+ (void)traceClass:(Class)aClass levels:(int)levels {
    Class metaClass = object_getClass(aClass);
    [self traceClass:metaClass mtype:"+" levels:levels];
    [self traceClass:aClass mtype:"" levels:levels];
}

+ (void)traceInstance:(id)instance {
    [self traceClass:[instance class]];
    tracedInstances[instance] = 1;
    tracingInstances = YES;
}

+ (void)untrace:(id)instance {
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

+ (VIMP)forClass:(Class)aClass intercept:(SEL)sel callback:(SEL)callback {
    int depth = [self depth:aClass];
    return [self intercept:aClass method:class_getInstanceMethod(aClass, sel) mtype:NULL depth:depth] ?
        (VIMP)[delegate methodForSelector:callback] : NULL;
}

+ (int)depth:(Class)aClass {
    int depth = 0;
    for ( Class nsObject = [NSObject class], nsObjectMeta = object_getClass( nsObject ) ;
         aClass && aClass != nsObject && aClass != nsObjectMeta ; aClass = class_getSuperclass( aClass ) )
        depth++;
    return depth;
}

+ (void)traceClass:(Class)aClass mtype:(const char *)mtype levels:(int)levels {
    tracedClasses[aClass] = 0;

    // yes, this is a hack
    if ( !excludeMethods )
        [self excludeMethods:@XTRACE_EXCLUSIONS];

    int depth = [self depth:aClass];
    for ( int l=0 ; l<levels ; l++ ) {

        if ( !tracedClasses[aClass] && excludedClasses.find(aClass) == excludedClasses.end() ) {
            unsigned mc = 0;
            const char *className = class_getName(aClass);
            Method *methods = class_copyMethodList(aClass, &mc);

           for( int i=0; methods && i<mc; i++ ) {
                const char *type = method_getTypeEncoding(methods[i]);
                const char *name = sel_getName(method_getName(methods[i]));
                NSString *nameStr = [NSString stringWithUTF8String:name];

               if ( ((includeMethods && ![self string:nameStr matches:includeMethods]) ||
                      (excludeMethods && [self string:nameStr matches:excludeMethods])) )
                   ;//NSLog( @"Xtrace: filters exclude: %s[%s %s] %s", mtype, className, name, type );

                else if ( (excludeTypes && [self string:[NSString stringWithUTF8String:type] matches:excludeTypes]) )
                    NSLog( @"Xtrace: type filter excludes: %s[%s %s] %s", mtype, className, name, type );

                else if ( name[0] == '.' || // [nameStr hasPrefix:@"init"] || //
                         [nameStr isEqualToString:@"retain"] || [nameStr isEqualToString:@"release"] ||
                         [nameStr isEqualToString:@"dealloc"] || [nameStr hasPrefix:@"_dealloc"] ||
                         [nameStr isEqualToString:@"description"] )
                    ; // best avoided

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && !defined(INJECTION_AUTOLOAD)
                else if ( aClass == [UIView class] && [nameStr isEqualToString:@"drawRect:"] )
                    ; // no idea why this is a problem...
#endif

                else if (includeProperties || !class_getProperty( aClass, name ))
                    [self intercept:aClass method:methods[i] mtype:mtype depth:depth];
            }

            tracedClasses[aClass] = 1;
            free( methods );
        }

        aClass = class_getSuperclass(aClass);
        if ( !--depth ) // don't trace NSObject
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

// delegate implements as instance method
+ (void)xtraceLog:(NSString *)trace {
    printf( "| %s\n", [trace UTF8String] );
}

static BOOL describing;

#define APPEND_TYPE( _enc, _fmt, _type ) case _enc: [args appendFormat:_fmt, va_arg(*argp,_type)]; return YES;

static BOOL formatValue( const char *type, void *valptr, va_list *argp, NSMutableString *args ) {
    switch ( type[0] == 'r' ? type[1] : type[0] ) {
        case 'V': case 'v':
            return NO;

        // warnings here are necessary evil
        // but how does one suppress them??
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wall"
        APPEND_TYPE( 'B', @"%d", BOOL )
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
            id obj = va_arg(*argp,id);
            if ( describeValues ) {
                describing = YES;
                [args appendString:obj?[obj description]:@"<nil>"];
                describing = NO;
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
    return YES;
}

struct _xtrace_depth {
    int depth; XTRACE_UNSAFE id obj; SEL sel;
};

static id nullImpl( id obj, SEL sel, ... ) {
    return nil;
}

// find struct _original implmentation for message and log call
static struct _xtrace_info &findOriginal( struct _xtrace_depth *info, SEL sel, ... ) {
    va_list argp; va_start(argp, sel);
    Class aClass = object_getClass( info->obj );

    while ( aClass && (originals[aClass].find(sel) == originals[aClass].end() ||
                       originals[aClass][sel].depth != info->depth) )
        aClass = class_getSuperclass( aClass );

    struct _xtrace_info &orig = originals[aClass][sel];

    if ( !aClass ) {
        NSLog( @"Xtrace: could not find original implementation for %s", sel_getName(info->sel) );
        orig.original = (VIMP)nullImpl;
    }

    aClass = object_getClass( info->obj );
    if ( (orig.logged = !describing && orig.mtype &&
          (!tracingInstances ? tracedClasses[aClass] :
           tracedInstances.find(info->obj) != tracedInstances.end())) ) {
        NSMutableString *args = [NSMutableString string];

        [args appendFormat:@"%*s%s[<%s %p>", indent++, "",
         orig.mtype, class_getName(aClass), info->obj];

        if ( !showArguments )
            [args appendFormat:@" %s", orig.name];
        else {
            const char *frame = (char *)(void *)&info+sizeof info;
            void *valptr = &sel;

            for ( struct _xtrace_arg *aptr = orig.args ; *aptr->name ; aptr++ ) {
                [args appendFormat:@" %.*s", (int)(aptr[1].name-aptr->name), aptr->name];
                if ( !aptr->type )
                    break;

                valptr = (void *)(frame+aptr[1].stackOffset);
                formatValue( aptr->type, valptr, &argp, args );
            }
        }

        // add custom filtering of logging here..
        [args appendFormat:@"] %.50s %p", orig.type, orig.original];
        [logToDelegate ? delegate : [Xtrace class] xtraceLog:args];
    }

    orig.stats.callCount++;
    orig.stats.entered = [NSDate timeIntervalSinceReferenceDate];
    orig.lastObj = info->obj;

    return orig;
}

// log returning value
static void returning( struct _xtrace_info &orig, ... ) {
    va_list argp; va_start(argp, orig);
    indent && indent--;

    if ( orig.logged && !hideReturns ) {
        NSMutableString *val = [NSMutableString string];
        [val appendFormat:@"%*s-> ", indent, ""];
        if ( formatValue(orig.type, NULL, &argp, val) ) {
            [val appendFormat:@" (%s)", orig.name];
            [logToDelegate ? delegate : [Xtrace class] xtraceLog:val];
        }
    }

    orig.stats.elapsed = [NSDate timeIntervalSinceReferenceDate] - orig.stats.entered;
}

#define ARG_SIZE sizeof(id) + sizeof(SEL) + sizeof(void *)*9 // something may be aligned
#define ARG_DEFS void *a0, void *a1, void *a2, void *a3, void *a4, void *a5, void *a6, void *a7, void *a8, void *a9
#define ARG_COPY a0, a1, a2, a3, a4, a5, a6, a7, a8, a9

// replacement implmentations "swizzled" onto class
// "_depth" is number of levels down from NSObject
// (used to detect calls to super)
template <typename _type, int _depth>
static void vintercept( id obj, SEL sel, ARG_DEFS ) {
    struct _xtrace_depth info = { _depth, obj, sel };
    struct _xtrace_info &orig = findOriginal( &info, sel, ARG_COPY );

    if ( orig.before && !orig.callingBack ) {
        orig.callingBack = YES;
        orig.before( delegate, sel, obj, ARG_COPY );
        orig.callingBack = NO;
    }

    orig.original( obj, sel, ARG_COPY );

    if ( orig.after && !orig.callingBack ) {
        orig.callingBack = YES;
        orig.after( delegate, sel, obj, ARG_COPY );
        orig.callingBack = NO;
    }

    returning( orig );
}

template <typename _type, int _depth>
static _type XTRACE_RETAINED intercept( id obj, SEL sel, ARG_DEFS ) {
    struct _xtrace_depth info = { _depth, obj, sel };
    struct _xtrace_info &orig = findOriginal( &info, sel, ARG_COPY );

    if ( orig.before && !orig.callingBack ) {
        orig.callingBack = YES;
        orig.before( delegate, sel, obj, ARG_COPY );
        orig.callingBack = NO;
    }

    _type (*impl)( id obj, SEL sel, ... ) = (_type (*)( id obj, SEL sel, ... ))orig.original;
    _type out = impl( obj, sel, ARG_COPY );

    if ( orig.after && !orig.callingBack ) {
        orig.callingBack = YES;
        impl = (_type (*)( id obj, SEL sel, ... ))orig.after;
        out = impl( delegate, sel, out, obj, ARG_COPY );
        orig.callingBack = NO;
    }

    returning( orig, out );
    return out;
}

+ (BOOL)intercept:(Class)aClass method:(Method)method mtype:(const char *)mtype depth:(int)depth {
    SEL sel = method_getName(method);
    const char *name = sel_getName(sel);
    const char *className = class_getName(aClass);
    const char *type = method_getTypeEncoding(method);

    IMP newImpl = NULL;
    switch ( type[0] == 'r' ? type[1] : type[0] ) {

#define IMPL_COUNT 5
#define IMPLS( _func, _type ) \
switch ( depth%IMPL_COUNT ) { \
    case 0: newImpl = (IMP)_func<_type,0>; break; \
    case 1: newImpl = (IMP)_func<_type,1>; break; \
    case 2: newImpl = (IMP)_func<_type,2>; break; \
    case 3: newImpl = (IMP)_func<_type,3>; break; \
    case 4: newImpl = (IMP)_func<_type,4>; break; \
}
        case 'V':
        case 'v': IMPLS( vintercept, void ); break;

        case 'B': IMPLS( intercept, bool ); break;
        case 'C':
        case 'c': IMPLS( intercept, char ); break;
        case 'S':
        case 's': IMPLS( intercept, short ); break;
        case 'I':
        case 'i': IMPLS( intercept, int ); break;
        case 'Q':
        case 'q':
#ifndef __LP64__
            IMPLS( intercept, long long ); break;
#endif
        case 'L':
        case 'l': IMPLS( intercept, long ); break;
        case 'f': IMPLS( intercept, float ); break;
        case 'd': IMPLS( intercept, double ); break;
        case '#':
        case '@': IMPLS( intercept, id ) break;
        case '^': IMPLS( intercept, void * ); break;
        case ':': IMPLS( intercept, SEL ); break;
        case '*': IMPLS( intercept, char * ); break;
        case '{':
            if ( strncmp(type,"{_NSRange=",10) == 0 )
                IMPLS( intercept, NSRange )
#ifndef __IPHONE_OS_VERSION_MIN_REQUIRED
            else if ( strncmp(type,"{_NSRect=",9) == 0 )
                IMPLS( intercept, NSRect )
            else if ( strncmp(type,"{_NSPoint=",10) == 0 )
                IMPLS( intercept, NSPoint )
            else if ( strncmp(type,"{_NSSize=",9) == 0 )
                IMPLS( intercept, NSSize )
#endif
            else if ( strncmp(type,"{CGRect=",8) == 0 )
                IMPLS( intercept, CGRect )
            else if ( strncmp(type,"{CGPoint=",9) == 0 )
                IMPLS( intercept, CGPoint )
            else if ( strncmp(type,"{CGSize=",8) == 0 )
                IMPLS( intercept, CGSize )
            else if ( strncmp(type,"{CGAffineTransform=",19) == 0 )
                IMPLS( intercept, CGAffineTransform )
            break;
        default:
            NSLog(@"Xtrace: Unsupported return type: %s for: %s[%s %s]", type, mtype, className, name);
    }

    const char *frameSize = type+1;
    while ( !isdigit(*frameSize) )
        frameSize++;

    if ( atoi(frameSize) > ARG_SIZE )
        NSLog( @"Xtrace: Stack frame too large to trace method: %s[%s %s]", mtype, className, name );

    else if ( newImpl ) {

        struct _xtrace_info &orig = originals[aClass][sel];

        orig.name = name;
        orig.type = type;
        orig.method = method;
        orig.depth = depth%IMPL_COUNT;
        if ( mtype )
            orig.mtype = mtype;

        [self extractSelector:name into:orig.args];
        [self extractOffsets:type into:orig.args];

        IMP impl = method_getImplementation(method);
        if ( impl != newImpl ) {
            orig.original = (VIMP)impl;
            method_setImplementation(method,newImpl);
            //NSLog( @"%d %s%s %s %s", depth, mtype, className, name, type );
        }

        return YES;
    }

    return NO;
}

// break up selector by argument
+ (int)extractSelector:(const char *)name into:(struct _xtrace_arg *)args {

    for ( int i=0 ; i<XTRACE_ARGS_SUPPORTED ; i++ ) {
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

+ (int)extractOffsets:(const char *)type into:(struct _xtrace_arg *)args {
    int frameLen = -1;

    for ( int i=0 ; i<XTRACE_ARGS_SUPPORTED ; i++ ) {
        args->type = type;
        while ( !isdigit(*type) )
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

+ (int)extractOffsets:(const char *)type into:(struct _xtrace_arg *)args {
    NSUInteger size, align, offset = 0;

    type = NSGetSizeAndAlignment( type, &size, &align );

    for ( int i=0 ; i<XTRACE_ARGS_SUPPORTED ; i++ ) {
        while ( isdigit(*type) )
            type++;
        args->type = type;
        type = NSGetSizeAndAlignment( type, &size, &align );
        if ( !*type )
            return i;
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

#endif
@end
#endif
