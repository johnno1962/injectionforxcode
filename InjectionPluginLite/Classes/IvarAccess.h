//
//  IvarAccess.h
//  XprobePlugin
//
//  Generic access to get/set ivars - functions so they work with Swift.
//
//  $Id: //depot/XprobePlugin/Classes/IvarAccess.h#43 $
//
//  Source Repo:
//  https://github.com/johnno1962/Xprobe/blob/master/Classes/IvarAccess.h
//
//  Created by John Holdsworth on 16/05/2015.
//  Copyright (c) 2015 John Holdsworth. All rights reserved.
//

/*

 This file has the MIT License (MIT)

 Copyright (c) 2015 John Holdsworth

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.

 */

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreserved-id-macro"
#pragma clang diagnostic ignored "-Wold-style-cast"
#pragma clang diagnostic ignored "-Wcstring-format-directive"
#pragma clang diagnostic ignored "-Wgnu-conditional-omitted-operand"
#pragma clang diagnostic ignored "-Wcast-align"
#pragma clang diagnostic ignored "-Wmissing-noreturn"
#pragma clang diagnostic ignored "-Wunused-exception-parameter"
#pragma clang diagnostic ignored "-Wc11-extensions"
#pragma clang diagnostic ignored "-Wvla-extension"
#pragma clang diagnostic ignored "-Wauto-import"
#pragma clang diagnostic ignored "-Wvla"

#ifndef _IvarAccess_h
#define _IvarAccess_h

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

@interface NSBlock : NSObject
@end

extern const char *ivar_getTypeEncodingSwift( Ivar ivar, Class aClass );
extern id xvalueForPointer( id self, const char *name, void *iptr, const char *type );
extern id xvalueForIvarType( id self, Ivar ivar, const char *type, Class aClass );
extern id xvalueForIvar( id self, Ivar ivar, Class aClass );
extern id xvalueForMethod( id self, Method method );
extern BOOL xvalueUpdateIvar( id self, Ivar ivar, NSString *value );
extern NSString *xlinkForProtocol( NSString *protolName );
extern NSString *utf8String( const char *chars );
extern NSString *xtype( const char *type );

NSString *utf8String( const char *chars ) {
    return chars ? [NSString stringWithUTF8String:chars] : @"";
}

#if 0
static int xstrncmp( const char *str1, const char *str2 ) {
    return strncmp( str1, str2, strlen( str2 ) );
}
#else
#define xstrncmp( _str1, _str2 ) strncmp( _str1, _str2, sizeof _str2 - 1 )
#endif

static const char *isOOType( const char *type ) {
    return strncmp( type, "{OO", 3 ) == 0 ? strstr( type, "\"ref\"" ) : NULL;
}

static BOOL isCFType( const char *type ) {
    return type && strncmp( type, "^{__CF", 6 ) == 0;
}

static BOOL isNewRefType( const char *type ) {
    return type && (xstrncmp( type, "{RetainPtr" ) == 0 ||
                    xstrncmp( type, "{WeakObjCPtr" ) == 0/* ||
                    xstrncmp( type, "{LazyInitialized" ) == 0*/);
}

static BOOL isSwiftObject( const char *type ) {
    return (type[-1] == 'S' && (type[0] == 'a' || type[0] == 'S')) || xstrncmp( type, "{Dictionary}" ) == 0;
}

@interface XprobeSwift : NSObject
+ (NSString *)string:(void *)stringPtr;
+ (NSString *)stringOpt:(void *)stringPtr;
+ (NSString *)array:(void *)arrayPtr;
+ (NSString *)arrayOpt:(void *)arrayPtr;
+ (NSString *)demangle:(NSString *)name;
+ (void)dumpIvars:(id)instance forClass:(Class)aClass into:(NSMutableString *)into;
@end

Class xloadXprobeSwift( const char *ivarName ) {
    static Class xprobeSwift;
    static int triedLoad;
    if ( !xprobeSwift && !(xprobeSwift = objc_getClass("XprobeSwift")) && !triedLoad++ ) {
#ifdef XPROBE_MAGIC
        NSBundle *thisBundle = [NSBundle bundleForClass:[Xprobe class]];
        NSString *bundlePath = [[thisBundle bundlePath] stringByAppendingPathComponent:@"XprobeSwift.loader"];
        if ( ![[NSBundle bundleWithPath:bundlePath] load] )
            NSLog( @"Xprobe: Could not load XprobeSwift bundle for ivar '%s': %@", ivarName, bundlePath );
        xprobeSwift = objc_getClass("XprobeSwift");
#endif
    }
    return xprobeSwift;
}

#pragma mark ivar_getTypeEncoding() for swift

//
// From Jay Freeman's https://www.youtube.com/watch?v=Ii-02vhsdVk
//
// Actual structure is https://github.com/apple/swift/blob/master/include/swift/Runtime/Metadata.h#L1552
//

struct _swift_data {
    unsigned long flags;
    const char *className;
    int fieldcount, flags2;
    const char *ivarNames;
    struct _swift_field **(*get_field_data)();
};

struct _swift_class {
    union {
        Class meta;
        unsigned long flags;
    };
    Class supr;
    void *buckets, *vtable, *pdata;
    int f1, f2; // added for Beta5
    int size, tos, mdsize, eight;
    struct _swift_data *swiftData;
    IMP dispatch[1];
};

struct _swift_field {
    union {
        Class meta;
        unsigned long flags;
    };
    union {
        struct _swift_field *typeInfo;
        const char *typeIdent;
        Class objcClass;
    };
    void *unknown;
    struct _swift_field *optional;
};

struct _swift_class *isSwift( Class aClass ) {
    struct _swift_class *swiftClass = (__bridge struct _swift_class *)aClass;
    return (uintptr_t)swiftClass->pdata & 0x1 ? swiftClass : NULL;
}

static const char *strfmt( NSString *fmt, ... ) NS_FORMAT_FUNCTION(1,2);
static const char *strfmt( NSString *fmt, ... ) {
    va_list argp;
    va_start(argp, fmt);
    return [[[NSString alloc] initWithFormat:fmt arguments:argp] UTF8String];
}

static const char *typeInfoForClass( Class aClass, const char *optionals ) {
    return strfmt( @"@\"%@\"%s", NSStringFromClass( aClass ), optionals );
}

static const char *skipSwift( const char *typeIdent ) {
    while ( isalpha( *typeIdent ) )
        typeIdent++;
    while ( isnumber( *typeIdent ) )
        typeIdent++;
    return typeIdent;
}

struct _swift_data3 {
    int className;
    int fieldcount, flags2;
    int ivarNames;
    int get_field_data;
};

struct _swift_field3 {
//    union {
//        Class meta;
//        unsigned long flags;
        int typeIdent;
//    };
//    union {
//        struct _swift_field *typeInfo;
//        Class objcClass;
//    };
//    void *unknown;
//    struct _swift_field *optional;
};

// Swift3 pointers to some metadata are relative
static const char *swift3Relative( void *ptrPtr ) {
    intptr_t offset = *(int *)ptrPtr;
    return offset < 0 ? (const char *)((intptr_t)ptrPtr + offset) : (const char *)offset;
}

const char *ivar_getTypeEncodingSwift3( Ivar ivar, Class aClass ) {
    struct _swift_class *swiftClass = isSwift( aClass );
    struct _swift_data3 *swiftData = (struct _swift_data3 *)swift3Relative( &swiftClass->swiftData );
    const char *nameptr = swift3Relative( &swiftData->ivarNames );
    const char *name = ivar_getName(ivar);
    int ivarIndex;

    for ( ivarIndex=0 ; ivarIndex < swiftData->fieldcount ; ivarIndex++ )
        if ( strcmp( name, nameptr ) == 0 )
            break;
        else
            nameptr += strlen(nameptr)+1;

    if ( ivarIndex >= swiftData->fieldcount )
        return NULL;

    struct _swift_field **(*get_field_data)() =
        (struct _swift_field **(*)())swift3Relative( &swiftData->get_field_data );
    struct _swift_field *field0 = get_field_data()[ivarIndex], *field = field0;
    struct _swift_field3 *typeInfo = (struct _swift_field3 *)swift3Relative( &field->typeInfo );
    char optionals[100] = "", *optr = optionals;

    if ( field->flags == 0x2 )
        return "e";

    // unwrap any optionals
    while ( field->flags == 0x2 || field->flags == 0x3 ) {
        if ( field->optional && field->optional->flags != 0x3 ) {
            field = field->optional;
            typeInfo = (struct _swift_field3 *)swift3Relative( &field->typeInfo );
            *optr++ = '?';
            *optr = '\000';
        }
        else
            return strfmt( @"%s%s", swift3Relative( &typeInfo->typeIdent ), optionals );
    }

    //    printf( "%s %lu\n", name, field->flags );

    if ( field->flags == 0x1 ) { // rawtype
        const char *typeIdent = swift3Relative( &typeInfo->typeIdent );
        if ( typeIdent[0] == 'V' ) {
            if ( (typeIdent[1] == 'S' && (typeIdent[2] == 'C' || typeIdent[2] == 's')) || typeIdent[1] == 's' )
                return strfmt( @"{%@}%s#%s", utf8String( skipSwift( typeIdent ) ), optionals, typeIdent );
            else
                return strfmt( @"{%@}%s#%s", utf8String( skipSwift( skipSwift( typeIdent ) ) ), optionals, typeIdent );
        }
        else
            return strfmt( @"%s%s", typeIdent, optionals )+1;
    }
    else if ( field->flags == 0xa ) // function
        return strfmt( @"^{Block}%s", optionals );
    else if ( field->flags == 0xc ) // protocol
        return strfmt( @"@\"<%@>\"%s", utf8String( field->optional->typeIdent ), optionals );
    else if ( field->flags == 0xe ) // objc class
        return typeInfoForClass( field->objcClass, optionals );
    else if ( field->flags == 0x10 ) // pointer
        return strfmt( @"^{%@}%s", utf8String( skipSwift( field->typeIdent ?: "??" ) ), optionals );
//    else if ( (field->flags & 0xff) == 0x55 || (field->flags & 0xffff) == 0x8948 ) // enum?
//        return strfmt( @"e%s", optionals );
    else if ( field->flags < 0x100 || field->flags & 0x3 ) // unknown/bad isa
        return strfmt( @"?FLAGS#%lx(%p)%s", field->flags, (void *)field, optionals );
    else // swift class
        return typeInfoForClass( (__bridge Class)field, optionals );
}

// returned type string has "autorelease" scope
const char *ivar_getTypeEncodingSwift( Ivar ivar, Class aClass ) {
    struct _swift_class *swiftClass = isSwift( aClass );
    if ( !swiftClass )
        return ivar_getTypeEncoding( ivar );

    const char *name = ivar_getName(ivar);
    BOOL useProperties = 01;
    if ( useProperties ) {
        objc_property_t prop = class_getProperty( aClass, name );
        if ( prop != NULL ) {
            const char *attrs = property_getAttributes( prop );
            if ( attrs ) {
                //NSLog( @"%s %s", name, attrs );
                return attrs+1;
            }
        }
    }

    // Swift 3.0+ uses relative pointers to reduce relocations
    if ( (intptr_t)swiftClass->swiftData < 0 )
        return ivar_getTypeEncodingSwift3(ivar, aClass);

    struct _swift_data *swiftData = swiftClass->swiftData;
    const char *nameptr = swiftData->ivarNames;
    int ivarIndex;

    for ( ivarIndex=0 ; ivarIndex < swiftData->fieldcount ; ivarIndex++ )
        if ( strcmp( name, nameptr ) == 0 )
            break;
        else
            nameptr += strlen(nameptr)+1;

    if ( ivarIndex >= swiftData->fieldcount )
        return NULL;

    struct _swift_field *field0 = swiftData->get_field_data()[ivarIndex], *field = field0;
    char optionals[100] = "", *optr = optionals;

    // unwrap any optionals
    while ( field->flags == 0x2 || field->flags == 0x3 ) {
        if ( field->optional && field->optional->flags != 0x3 ) {
            field = field->optional;
            *optr++ = '?';
            *optr = '\000';
        }
        else
            return strfmt( @"%s%s", field->typeInfo->typeIdent, optionals );
    }

//    printf( "%s %lu\n", name, field->flags );

    if ( field->flags == 0x1 ) { // rawtype
        const char *typeIdent = field->typeInfo->typeIdent;
        if ( typeIdent[0] == 'V' ) {
            if ( (typeIdent[1] == 'S' && (typeIdent[2] == 'C' || typeIdent[2] == 's')) || typeIdent[1] == 's' )
                return strfmt( @"{%@}%s#%s", utf8String( skipSwift( typeIdent ) ), optionals, typeIdent );
            else
                return strfmt( @"{%@}%s#%s", utf8String( skipSwift( skipSwift( typeIdent ) ) ), optionals, typeIdent );
        }
        else
            return strfmt( @"%s%s", field->typeInfo->typeIdent, optionals )+1;
    }
    else if ( field->flags == 0xa ) // function
        return strfmt( @"^{Block}%s", optionals );
    else if ( field->flags == 0xc ) // protocol
        return strfmt( @"@\"<%@>\"%s", utf8String( field->optional->typeIdent ), optionals );
    else if ( field->flags == 0xe ) // objc class
        return typeInfoForClass( field->objcClass, optionals );
    else if ( field->flags == 0x10 ) // pointer
        return strfmt( @"^{%@}%s", utf8String( skipSwift( field->typeIdent ?: "??" ) ), optionals );
    else if ( (field->flags & 0xff) == 0x55 || (field->flags & 0xffff) == 0x8948 ) // enum?
        return strfmt( @"e%s", optionals );
    else if ( field->flags < 0x100 || field->flags & 0x3 ) // unknown/bad isa
        return strfmt( @"?FLAGS#%lx(%p)%s", field->flags, (void *)field, optionals );
    else // swift class
        return typeInfoForClass( (__bridge Class)field, optionals );
}

#pragma mark generic ivar/method access

static NSString *trapped = @"#INVALID", *notype = @"#TYPE";

static jmp_buf jmp_env;

static void handler( int sig ) {
    longjmp( jmp_env, sig );
}

static int xprotect( void (^blockToProtect)() ) {
    void (*savetrap)(int) = signal( SIGTRAP, handler );
    void (*savesegv)(int) = signal( SIGSEGV, handler );
    void (*savebus )(int) = signal( SIGBUS,  handler );

    int signum;
    switch ( signum = setjmp( jmp_env ) ) {
        case 0:
            blockToProtect();
            break;
        default:
#ifdef XPROBE_MAGIC
            if ( [Xprobe respondsToSelector:@selector(writeString:)] )
                [Xprobe writeString:[NSString stringWithFormat:@"SIGNAL: %d", signum]];
            else
#endif
                NSLog( @"SIGNAL: %d", signum );
    }

    signal( SIGBUS,  savebus  );
    signal( SIGSEGV, savesegv );
    signal( SIGTRAP, savetrap );
    return signum;
}

id xvalueForPointer( id self, const char *name, void *iptr, const char *type ) {
    if ( !type )
        return notype;
    switch ( type[0] ) {
        case 'V':
        case 'v': return @"void";

        case 'b': // for now, for swift
        case 'B': return @(*(bool *)iptr);// ? @"true" : @"false";

        case 'c': return @(*(char *)iptr);
        case 'C': return [NSString stringWithFormat:@"0x%x", *(unsigned char *)iptr];

        case 's': return @(*(short *)iptr);

        case 'a':
        case 'S':
            if ( type[-1] == 'S' ) {
                const char *suffix = strchr( name, '.' );
                const char *mname = suffix ? strndup( name, suffix-name ) : name;
                Method m = class_getInstanceMethod( object_getClass( self ), sel_registerName( mname ) );
                if ( m && method_getTypeEncoding( m )[0] == '@' ) {
                    id (*imp)( id, SEL ) = (id (*)( id, SEL ))method_getImplementation( m );
                    return imp ? imp( self, method_getName( m ) ) : @"nomethod";
                }
                else
                    switch ( type[0] ) {
                        case 'a':
                            return type[1] != '?' ?
                            [xloadXprobeSwift( name ) array:iptr] ?: @"unavailable" :
                            [xloadXprobeSwift( name ) arrayOpt:iptr] ?: @"unavailable";
                        case 'S':
                            return type[1] != '?' ?
                            [xloadXprobeSwift( name ) string:iptr] ?: @"unavailable" :
                            [xloadXprobeSwift( name ) stringOpt:iptr] ?: @"unavailable";
                    }
            }

            return [NSString stringWithFormat:@"0x%x", *(unsigned short *)iptr];

        case 'O':
        case 'e': return @(*(unsigned *)iptr);

        case 'f': return @(*(float *)iptr);
        case 'd': return @(*(double *)iptr);

        case 'I': return [NSString stringWithFormat:@"0x%x", *(unsigned *)iptr];
        case 'i':
#ifdef __LP64__
            if ( !isSwift( [self class] ) )
#endif
                return @(*(int *)iptr);

#ifndef __LP64__
        case 'q': return @(*(long long *)iptr);
#else
        case 'q':
#endif
        case 'l': return @(*(long *)iptr);
#ifndef __LP64__
        case 'Q': return @(*(unsigned long long *)iptr);
#else
        case 'Q':
#endif
        case 'L': return @(*(unsigned long *)iptr);

        case '@': {
            const char *suffix = strchr( name, '.' );
            const char *mname = suffix ? strndup( name, suffix-name ) : name;
            Method m = class_getInstanceMethod( object_getClass( self ), sel_registerName( mname ) );
            if ( m && method_getTypeEncoding( m )[0] == '@' ) {
                id (*imp)( id, SEL ) = (id (*)( id, SEL ))method_getImplementation( m );
                if ( imp )
                    return imp( self, method_getName( m ) );
            }

            __block id out = trapped;

            xprotect( ^{
                uintptr_t uptr = *(uintptr_t *)iptr;
                if ( !uptr )
                    out = nil;
                else if ( uptr & 0xffffffff ) {
                    id obj = *(const id *)iptr;
#ifdef XPROBE_MAGIC
                    //[obj description];
#endif
                    out = obj;
                }
            } );

            return out;
        }
        case ':': return [NSString stringWithFormat:@"@selector(%@)",
                          NSStringFromSelector( *(SEL *)iptr )];
        case '#': {
            Class aClass = *(const Class *)iptr;
            return aClass ? [NSString stringWithFormat:@"[%@ class]",
                             NSStringFromClass( aClass )] : @"Nil";
        }
        case '^':
            if ( isCFType( type ) ) {
                char buff[100];
                strcpy(buff, "@\"NS" );
                strcat(buff,type+6);
                strcpy(strchr(buff,'='),"\"");
                return xvalueForPointer( self, name, iptr, buff );
            }
            return [NSValue valueWithPointer:*(void **)iptr];

        case '{': case '(': @try {
            if ( isNewRefType( type ) )
                return *(const id *)iptr;
            else if ( xstrncmp( type+1, "Int8" ) == 0 )
                return @(*(char *)iptr);
            else if ( xstrncmp( type+1, "Int16" ) == 0 )
                return @(*(short *)iptr);
            else if ( xstrncmp( type+1, "Int32" ) == 0 )
                return @(*(int *)iptr);
            if ( xstrncmp( type+1, "UInt8" ) == 0 )
                return @(*(unsigned char *)iptr);
            else if ( xstrncmp( type+1, "UInt16" ) == 0 )
                return @(*(unsigned short *)iptr);
            else if ( xstrncmp( type+1, "UInt32" ) == 0 )
                return @(*(unsigned int *)iptr);
            else if ( xstrncmp( type, "{Dictionary}" ) == 0 ) {
                const char *suffix = strchr( name, '.' );
                const char *mname = suffix ? strndup( name, suffix-name ) : name;
                Method m = class_getInstanceMethod( object_getClass( self ), sel_registerName( mname ) );
                if ( m && method_getTypeEncoding( m )[0] == '@' ) {
                    id (*imp)( id, SEL ) = (id (*)( id, SEL ))method_getImplementation( m );
                    return imp ? imp( self, method_getName( m ) ) : @"unavailable";
                }
                else
                    return @"unavailable";
            }

            const char *ooType = isOOType( type );
            if ( ooType )
                return xvalueForPointer( self, name, iptr, ooType+5 );
            else if ( type[1] == '?' )
                return xvalueForPointer( self, name, iptr, "I" );

            // remove names for valueWithBytes:objCType:
            char cleanType[1000], *tptr = cleanType;
            while ( *type ) {
                if ( *type == ',' )
                    break;
                if ( *type == '"' ) {
                    while ( *++type != '"' )
                        ;
                    type++;
                }
                else
                    *tptr++ = *type++;
            }
            *tptr = '\000';

            // for incomplete Swift encodings
            if ( strchr( cleanType, '=' ) )
                ;
            else if ( xstrncmp( cleanType, "{CGFloat" ) == 0 )
                return @(*(CGFloat *)iptr);
            else if ( xstrncmp( cleanType, "{CGPoint" ) == 0 )
                strcpy( cleanType, @encode(CGPoint) );
            else if ( xstrncmp( cleanType, "{CGSize" ) == 0 )
                strcpy( cleanType, @encode(CGSize) );
            else if ( xstrncmp( cleanType, "{CGRect" ) == 0 )
                strcpy( cleanType, @encode(CGRect) );
#if TARGET_OS_IPHONE
            else if ( xstrncmp( cleanType, "{UIOffset" ) == 0 )
                strcpy( cleanType, @encode(UIOffset) );
            else if ( xstrncmp( cleanType, "{UIEdgeInsets" ) == 0 )
                strcpy( cleanType, @encode(UIEdgeInsets) );
#else
            else if ( xstrncmp( cleanType, "{NSPoint" ) == 0 )
                strcpy( cleanType, @encode(NSPoint) );
            else if ( xstrncmp( cleanType, "{NSSize" ) == 0 )
                strcpy( cleanType, @encode(NSSize) );
            else if ( xstrncmp( cleanType, "{NSRect" ) == 0 )
                strcpy( cleanType, @encode(NSRect) );
#endif
            else if ( xstrncmp( cleanType, "{CGAffineTransform" ) == 0 )
                strcpy( cleanType, @encode(CGAffineTransform) );

            return [NSValue valueWithBytes:iptr objCType:cleanType];
        }
        @catch ( NSException *e ) {
            return @"raised exception";
        }
        case '*': {
            const char *ptr = *(const char **)iptr;
            return ptr ? utf8String( ptr ) : @"NULL";
        }
#if 0
        case 'b':
            return [NSString stringWithFormat:@"0x%08x", *(int *)iptr];
#endif
        default:
            return @"unknown";
    }
}

id xvalueForIvarType( id self, Ivar ivar, const char *type, Class aClass ) {
    void *iptr = (char *)(__bridge void *)self + ivar_getOffset(ivar);
    return xvalueForPointer( self, ivar_getName( ivar ), iptr, type );
}

id xvalueForIvar( id self, Ivar ivar, Class aClass ) {
    const char *type = ivar_getTypeEncodingSwift(ivar, aClass);
    //NSLog( @"%@ %p %p %s %s %s", aClass, ivar, isSwift(aClass), ivar_getName(ivar), ivar_getTypeEncoding(ivar), type );
    return xvalueForIvarType( self, ivar, type, aClass );
}

static NSString *invocationException;

id xvalueForMethod( id self, Method method ) {
    @try {
        const char *type = method_getTypeEncoding(method);
        NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:type];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
        [invocation setSelector:method_getName(method)];
        [invocation invokeWithTarget:self];

        NSUInteger size = 0, align;
        const char *returnType = [sig methodReturnType];
        NSGetSizeAndAlignment( returnType, &size, &align );

        char buffer[size];
        if ( returnType[0] != 'v' )
            [invocation getReturnValue:buffer];
        return xvalueForPointer( self, sel_getName( method_getName( method ) ), buffer, returnType );
    }
    @catch ( NSException *e ) {
        NSLog( @"Xprobe: exception on invoke: %@", e );
        return invocationException = [e description];
    }
}

BOOL xvalueUpdateIvar( id self, Ivar ivar, NSString *value ) {
    char *iptr = (char *)(__bridge void *)self + ivar_getOffset(ivar);
    const char *type = ivar_getTypeEncodingSwift( ivar, [self class] );
    switch ( type[0] ) {
        case 'b': // Swift
        case 'B': *(bool *)iptr = [value boolValue]; break;
        case 'c': *(char *)iptr = [value intValue]; break;
        case 'C': *(unsigned char *)iptr = [value intValue]; break;
        case 's': *(short *)iptr = [value intValue]; break;
        case 'S': *(unsigned short *)iptr = [value intValue]; break;
        case 'e':
        case 'i': *(int *)iptr = [value intValue]; break;
        case 'I': *(unsigned *)iptr = [value intValue]; break;
        case 'f': *(float *)iptr = [value floatValue]; break;
        case 'd': *(double *)iptr = [value doubleValue]; break;
#ifndef __LP64__
        case 'q': *(long long *)iptr = [value longLongValue]; break;
#else
        case 'q':
#endif
        case 'l': *(long *)iptr = (long)[value longLongValue]; break;
#ifndef __LP64__
        case 'Q': *(unsigned long long *)iptr = [value longLongValue]; break;
#else
        case 'Q':
#endif
        case 'L': *(unsigned long *)iptr = (unsigned long)[value longLongValue]; break;
        case ':': *(SEL *)iptr = NSSelectorFromString(value); break;
        default:
            NSLog( @"Xprobe: update of unknown type: %s", type );
            return FALSE;
    }

    return TRUE;
}

#pragma mark HTML representation of type

NSString *xlinkForProtocol( NSString *protolName ) {
    NSString *protocolName = NSStringFromProtocol (NSProtocolFromString( protolName ) );
    return [NSString stringWithFormat:@"<a href=\\'#\\' onclick=\\'this.id=\"%@\"; "
            "sendClient( \"protocol:\", \"%@\" ); event.cancelBubble = true; return false;\\'>%@</a>",
            protolName, protolName, [protocolName isEqualToString:@"nil"] ? protolName : protocolName];
}


static NSString *xtypeStar( const char *type, const char *star ) {
    if ( type[-1] == '@' ) {
        if ( type[0] != '"' )
            return @"id";
        else if ( type[1] == '<' )
            type++;
    }
    if ( type[-1] == '^' && type[0] != '{' )
        return [xtype( type ) stringByAppendingString:@" *"];

    const char *end = ++type;
    if ( *end == '?' )
        end = end+strlen(end);
    else
        while ( isalnum(*end) || *end == '_' || *end == ',' || *end == '.' || *end < 0 )
            end++;
    NSString *typeName = [[NSString alloc] initWithBytes:type length:end-type encoding:NSUTF8StringEncoding];
    Class theClass = NSClassFromString( typeName );
    if ( theClass )
        typeName = [[xloadXprobeSwift( type ) demangle:typeName]
                    stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"] ?: NSStringFromClass( theClass );
    if ( type[-1] == '<' )
        return [NSString stringWithFormat:@"id&lt;%@&gt;", xlinkForProtocol( typeName )];
    else
        return [NSString stringWithFormat:@"<span onclick=\\'this.id=\"%@\"; "
                "sendClient( \"class:\", \"%@\" ); event.cancelBubble=true;\\'>%@</span>%s",
                typeName, typeName, typeName, star];
}

static NSString *xtype_( const char *type ) {
    if ( !type )
        return @"notype";
    switch ( type[0] ) {
        case 'V': return @"oneway void";
        case 'v': return @"void";
        case 'a': return @"Array&lt;?&gt;";
        case 'b': return @"Bool";
        case 'B': return @"bool";
        case 'c': return @"char";
        case 'C': return @"unsigned char";
        case 's': return @"short";
        case 'S': return type[-1] == 'S' ? @"String" : @"unsigned short";
        case 'e': return @"Enum";
        case 'O': return [NSString stringWithFormat:@"enum %s", type+1];
        case 'i': return type[-1] == 'S' ? @"Int" : @"int";
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
        case '@': return xtypeStar( type+1, " *" );
        case '^': return xtypeStar( type+1, " *" );
        case '{': return xtypeStar( type, "" );
        case '[': {
            int dim = atoi( type+1 );
            while ( isnumber( *++type ) )
                ;
            return [NSString stringWithFormat:@"%@[%d]", xtype( type ), dim];
        }
        case 'r':
            return [@"const " stringByAppendingString:xtype( type+1 )];
        case '*': return @"char *";
        default:
            return utf8String( type ); //@"id";
    }
}

NSString *xtype( const char *type ) {
    NSString *typeStr = xtype_( type );
    return [NSString stringWithFormat:@"<span class=\\'%@\\' title=\\'%s\\'>%@</span>",
            [typeStr hasSuffix:@"*"] ? @"classStyle" : @"typeStyle", type, typeStr];
}

#endif
#pragma clang diagnostic pop
