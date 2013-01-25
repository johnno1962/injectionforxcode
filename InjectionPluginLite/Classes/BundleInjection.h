//
//  $Id: //depot/InjectionPluginLite/Classes/BundleInjection.h#16 $
//  Injection
//
//  Created by John Holdsworth on 16/01/2012.
//  Copyright (c) 2012 John Holdsworth. All rights reserved.
//
//  Client application interface to Code Injection system.
//  Added to program's main.m to connect to the Injection app.
//
//  This file is copyright and may not be re-distributed, whole or in part.
//

#import "BundleInterface.h"

#define INJECTION_PORT 31442
#define INJECTION_MAGIC -INJECTION_PORT*INJECTION_PORT
#define INJECTION_APPNAME "Injection"
#define INJECTION_MKDIR -1
#define INJECTION_NOFILE -2
#define INJECTION_CLOSE -3

#ifdef DEBUG
#define INLog NSLog
#else
#define INLog if(0) NSLog
#endif

struct _in_header { int pathLength, dataLength; };

@interface BundleInjection : NSObject
+ (BOOL)readHeader:(struct _in_header *)header forPath:(char *)path from:(int)fdin;
+ (BOOL)writeBytes:(off_t)bytes withPath:(const char *)path from:(int)fdin to:(int)fdout;
#ifdef INJECTION_BUNDLE
+ (void)loadedClass:(Class)newClass notify:(BOOL)notify;
+ (void)loadedNotify:(BOOL)notify;
#endif
@end


#import <netinet/tcp.h>
#import <arpa/inet.h>
#import <sys/stat.h>
#import <unistd.h>
#import <fcntl.h>

#ifndef INJECTION_NOIMPL

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
@implementation UIAlertView(Injection)
- (void)injectionDismiss {
    [self dismissWithClickedButtonIndex:0 animated:YES];
}
@end
#endif

@interface BundleInjection(Private)
- (void)bundleLoader;
- (void)loadBundle;
@end

@implementation BundleInjection

+ (BOOL)readHeader:(struct _in_header *)header forPath:(char *)path from:(int)fdin {
    return read( fdin, header, sizeof *header ) == sizeof *header &&
        read( fdin, path, header->pathLength ) == header->pathLength;
}

+ (BOOL)writeBytes:(off_t)bytes withPath:(const char *)path from:(int)fdin to:(int)fdout {
    BOOL ok = 1;
    if ( path ) {
        struct _in_header header;
        header.pathLength = (int)strlen( path )+1;
        header.dataLength = (int)bytes;
        ok = ok && write( fdout, &header, sizeof header ) == sizeof header &&
            write( fdout, path, header.pathLength ) == header.pathLength;
    }

    char buffer[1024];
    while ( ok && bytes > 0 && fdin ) {
        ssize_t rc = read( fdin, buffer, bytes < sizeof buffer ? (int)bytes : (int)sizeof buffer );
        ok = ok && rc > 0 && fdout > 0 ? write( fdout, buffer, rc ) == rc : TRUE;
        bytes -= rc;
    }

    return ok;
}

#ifdef INJECTION_ENABLED

+ (void)load {
#ifndef INJECTION_ISARC
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
#else
    @autoreleasepool {
#endif

        [self performSelectorInBackground:@selector(bundleLoader) withObject:nil];

#ifndef INJECTION_ISARC
        [pool release];
#else
    }
#endif
}

NSString *kINNotification = @"INJECTION_BUNDLE_NOTIFICATION";
float INParameters[INJECTION_PARAMETERS] = {1,1,1,1,1};
id INDelegates[INJECTION_PARAMETERS];

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
UIColor *INColors[INJECTION_PARAMETERS];
#else
NSColor *INColors[INJECTION_PARAMETERS];
#endif
id INColorTargets[INJECTION_PARAMETERS];
SEL INColorActions[INJECTION_PARAMETERS];
id INImageTarget;

static char path[PATH_MAX], *file = &path[1];
static int status, sbInjection;

#import <dirent.h>

+ (void)listDirectory:(const char *)start ending:(char *)end into:(NSMutableString *)listing {
    struct dirent *ent;
    struct stat st;

    //INLog( @"List: %s", file );
    DIR *d = opendir( file );
    if ( !d )
        perror( file );
    else {
        *end++ = '/';
        while ( (ent = readdir( d )) ) {
            strcpy( end, ent->d_name );
            lstat( file, &st );

            if ( S_ISDIR( st.st_mode ) && !S_ISLNK( st.st_mode ) && ent->d_name[0] != '.' ) 
                [self listDirectory:start ending:end + strlen(end) into:listing];
            else if ( strcmp( ent->d_name, ".." ) != 0 )
                [listing appendFormat:@"%d\t%d\t%s\n", (int)st.st_size, st.st_mode, start];
        }
        closedir( d );
    }
}


+ (int)connectTo:(const char *)ipAddress {
    struct sockaddr_in loaderAddr;
    int loaderSocket;

    loaderAddr.sin_family = AF_INET;
	inet_aton( ipAddress, &loaderAddr.sin_addr );
	loaderAddr.sin_port = htons(INJECTION_PORT);

    int optval = 1;
    if ( (loaderSocket = socket(AF_INET, SOCK_STREAM, 0)) < 0 )
        NSLog( @"Could not open socket for injection: %s", strerror( errno ) );
    else if ( setsockopt( loaderSocket, IPPROTO_TCP, TCP_NODELAY, (void *)&optval, sizeof(optval)) < 0 )
        NSLog( @"Could not set TCP_NODELAY: %s", strerror( errno ) );
    else if ( connect( loaderSocket, (struct sockaddr *)&loaderAddr, sizeof loaderAddr ) >= 0 )
        return loaderSocket;

    close( loaderSocket );
    return 0;
}

#import <objc/runtime.h>
#import <sys/sysctl.h>

+ (void)bundleLoader {
#ifndef INJECTION_ISARC
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
#else
    @autoreleasepool {
#endif

        static char machine[64];
        size_t size = sizeof machine;
        sysctlbyname("hw.machine", machine, &size, NULL, 0);
        machine[size] = '\000';
        
        const char *localOnly[] = {"127.0.0.1", NULL},
            **addrSwitch = strcmp( machine, "x86_64" ) == 0 ? localOnly : _inIPAddresses;

        int i;
        for ( i=0 ; i<100 ; i++ ) {
            int loaderSocket = 0;

            const char **addrPtr;
            for ( addrPtr = addrSwitch ; *addrPtr;  addrPtr++ )
                if ( (loaderSocket = [self connectTo:*addrPtr]) )
                    break;

            if ( !loaderSocket ) {
                [NSThread sleepForTimeInterval:1.];
                continue;
            }

            [self writeBytes:INJECTION_MAGIC withPath:_inMainFilePath from:0 to:loaderSocket];

            read( loaderSocket, &status, sizeof status );
            if ( !status ) {
                NSLog( @"Unable to locate main file \"%s\", re-patch it in Xcode and rebuild your application.",
                      _inMainFilePath );
                return;
            }

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
            if ( (sbInjection = status == 2) )
                method_exchangeImplementations(
                   class_getInstanceMethod([UINib class], @selector(instantiateWithOwner:options:)),
                   class_getInstanceMethod([UINib class], @selector(inInstantiateWithOwner:options:)));
#endif

            NSString *executablePath = [[NSBundle mainBundle] executablePath];
            [executablePath getCString:path maxLength:sizeof path encoding:NSUTF8StringEncoding];
            [self writeBytes:INJECTION_MAGIC withPath:path from:0 to:loaderSocket];

            INLog( @"Connected to \"%s\" application, ready to load code.", INJECTION_APPNAME );

            int fdout = 0; 
            struct _in_header header;
            while ( [self readHeader:&header forPath:path from:loaderSocket] ) {

                switch ( path[0] ) {
                    case '/': // load bundle
                        status = NO;
                        if ( header.dataLength == INJECTION_MAGIC )
                            [self performSelectorOnMainThread:@selector(loadBundle)
                                                   withObject:nil waitUntilDone:YES];
                        else
                            NSLog( @"Synchronization error." );
                        if ( !status )
                            NSLog( @"*** Bundle has failed to load. If this is due to symbols not found, make sure that Build Setting 'Symbols Hidden by Default' is NO for your Debug build. ***");
                        write( loaderSocket, &status, sizeof status );
                        break;
                    case '>': // open file/directory to write/create
                        if ( header.dataLength == INJECTION_NOFILE ) {
                            if ( (fdout = open( file, O_CREAT|O_TRUNC|O_WRONLY, 0755 )) < 0 )
                                NSLog( @"Could not open \"%s\" for copy as: %s", file, strerror(errno) );
                        }
                        else if ( header.dataLength == INJECTION_MKDIR ) {
                            int rc = mkdir( file, 0777 );
                            if(0) INLog( @"Return code %d from mkdir of \"%s\" ", rc, file );
                        }
                        else {
                            if ( (fdout = open( file, O_CREAT|O_TRUNC|O_WRONLY, 0755 )) < 0 )
                                NSLog( @"Could not open \"%s\" for download as: %s", file, strerror(errno) );
                            [self writeBytes:header.dataLength withPath:NULL from:loaderSocket to:fdout];
                            close( fdout );
                            fdout = 0;
                        }
                        break;
                    case '<': { // open file/directory to read/list
                        int fdin = open( file, O_RDONLY );
                        struct stat fdinfo;

                        memset( &fdinfo, '\000', sizeof fdinfo );

                        if ( fdin < 0 )
                            NSLog( @"Could not open \"%s\" for reading as: %s", file, strerror(errno) );
                        else if ( fstat( fdin, &fdinfo ) < 0 )
                            NSLog( @"Could not stat \"%s\" for reading as: %s", file, strerror(errno) );

                        if ( S_ISDIR( fdinfo.st_mode ) ) {
                            NSMutableString *listing = [[NSMutableString alloc] init];
                            NSLog( @"Listing directory: %s", file );
                            close( fdin );

                            char *end = file+strlen(file);
                            [self listDirectory:end+1 ending:end into:listing];

                            ssize_t len = (size_t)[listing lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
                            char *data = (char *)malloc( len+1 );
                            [listing getCString:data maxLength:len+1 encoding:NSUTF8StringEncoding];

                            len = strlen( data );
                            write( loaderSocket, &len, sizeof len );
                            if ( write( loaderSocket, data, len ) != len )
                                NSLog( @"Could not write listing." );
                            free( data );
#ifndef INJECTION_ISARC
                            [listing release];
#endif
                        }
                        else if ( fdout ) {
                            INLog( @"Copying %d bytes to \"%s\"", (int)fdinfo.st_size, file );
                            [self writeBytes:fdinfo.st_size withPath:NULL from:fdin to:fdout];
                            close( fdout );
                            fdout = 0;
                        }
                        else {
                            INLog( @"Uploading %d bytes from \"%s\"", (int)fdinfo.st_size, file );
                            int bytes = (int)fdinfo.st_size;
                            write( loaderSocket, &bytes, sizeof &bytes );
                            [self writeBytes:bytes withPath:NULL from:fdin to:loaderSocket];
                        }
                        close( fdin );
                    }
                        break;
                    case '#': { // update image
                        int len, block = 4096;
                        read( loaderSocket, &len, sizeof len );
                        char *buff = (char *)malloc( len );
                        int j;
                        for ( j=0 ; j<len ; )
                            j += read( loaderSocket, buff+j, j+block < len ? block : len-j );
                        NSData *data = [NSData dataWithBytesNoCopy:buff length:len freeWhenDone:YES];
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
                        UIImage *img = [[UIImage alloc] initWithData:data];
#else
                        NSImage *img = [[NSImage alloc] initWithData:data];
#endif
                        [INImageTarget performSelectorOnMainThread:@selector(setImage:)
                                                        withObject:img waitUntilDone:NO];
#ifndef INJECTION_ISARC
                        [img release];
#endif
                    }
                        break;
                    case '@': // project built, reload visible view controllers
                        if ( sbInjection )
                            [self performSelectorOnMainThread:@selector(reloadNibs)
                                                   withObject:nil waitUntilDone:YES];
                        else
                            NSLog( @"'Inject StoryBds' must be enabled on the Tunable Parameters panel to work." );
                        break;
                    default: // parameter or color value update
                        if ( isdigit(path[0]) ) {
                            int tag = path[0]-'0';
                            if ( tag < 5 ) {
                                INParameters[tag] = atof( file );
                                [INDelegates[tag] inParameter:tag hasChanged:INParameters[tag]];
                            }
                            else if ( (tag -= 5) < 5 ) {
                                float r, g, b, a;
                                sscanf( file, "%f,%f,%f,%f", &r, &g, &b, &a );
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
                                UIColor *col = [UIColor colorWithRed:r green:g
                                                                blue:b alpha:a];
#else
                                NSColor *col = [NSColor colorWithCalibratedRed:r green:g
                                                                          blue:b alpha:a];
#endif
#ifndef INJECTION_ISARC
                                [col retain];
                                [INColors[tag] release];
#endif
                                INColors[tag] = col;

                                id target = INColorTargets[tag];
                                SEL action = INColorActions[tag] ? 
                                    INColorActions[tag] : @selector(setColor:);

                                [target performSelectorOnMainThread:action
                                                         withObject:col waitUntilDone:NO];

                                if ( [target respondsToSelector:@selector(setNeedsDisplay)] )
                                    [target setNeedsDisplay];
                            }
                                
                        }
                        else if ( header.dataLength == INJECTION_CLOSE ) {
                            NSLog( @"Project closed, exiting %s loader", INJECTION_APPNAME );
                            close( loaderSocket );
                            return;
                        }
                        else
                            NSLog( @"Invalid command: %s\n", path );
                        break;
                }
            }

            INLog( @"Lost connection, %s", strerror( errno ) );
            close( loaderSocket );
        }

        INLog( @"Giving up on connecting to %s", INJECTION_APPNAME );

#ifndef INJECTION_ISARC
        [pool release];
#else
    }
#endif
}

+ (void)loadBundle {
    NSBundle *bundle = [NSBundle bundleWithPath:[NSString stringWithUTF8String:path]];
    if ( !bundle )
        NSLog( @"Could not initalise bundle at \"%s\"", path );
    else
        INLog( @"Injecting Bundle: %s", path );
    [bundle load];
}

// a little inside knowledge of Objective-C data structures for the new version of the class ...
struct _in_objc_ivars { int twenty, count; struct { long *offsetPtr; char *name, *type; int align, size; } ivars[1]; };
struct _in_objc_ronly { int z1, offsetStart; long offsetEnd, z2; char *className; void *methods; long z3; struct _in_objc_ivars *ivars; };
struct _in_objc_class { Class meta, supr; void *cache, *vtable; struct _in_objc_ronly *internal; };

+ (void)alignIvarsOf:(Class)newClass to:(Class)oldClass {
    // new version of class must not have been messaged at this point
    // i.e. the new version must not have a "+ (void)load" method
    struct _in_objc_class *nc = INJECTION_BRIDGE(struct _in_objc_class *)newClass;
    struct _in_objc_ivars *ivars = nc->internal->ivars;
    [newClass class];

    // align ivars in new class with original
    for ( int i=0 ; ivars && i<ivars->count ; i++ ) {
        Ivar ivar = class_getInstanceVariable(oldClass, ivars->ivars[i].name);
        if ( !ivar )
            NSLog( @"*** Please re-run your application to add ivar '%s' ***",
                  ivars->ivars[i].name );
        else {
            if ( strcmp( ivar_getTypeEncoding( ivar ), ivars->ivars[i].type ) )
                NSLog( @"*** Ivar '%s' has changed type, re-run application. ***",
                      ivars->ivars[i].name );
            *ivars->ivars[i].offsetPtr = ivar_getOffset(ivar);
        }
    }
}

+ (void)dumpIvars:(Class)aClass {
    unsigned i, ic = 0;
    Ivar *vars = class_copyIvarList(aClass, &ic);
    NSLog( @"0x%p[%u]", vars, ic );
    for ( i=0; i<ic ; i++ )
        NSLog( @"%s %s %d", ivar_getName(vars[i]), ivar_getTypeEncoding(vars[i]), (int)ivar_getOffset(vars[i]));
}

+ (void)swizzle:(Class)oldClass from:(Class)newClass {
    unsigned i, mc = 0;
    Method *methods = class_copyMethodList(newClass, &mc);
    for( i=0; i<mc; i++ )
        class_replaceMethod(oldClass, method_getName(methods[i]),
                            method_getImplementation(methods[i]),
                            method_getTypeEncoding(methods[i]));
    free(methods);
}

+ (void)loadedClass:(Class)newClass notify:(BOOL)notify {
    const char *className = class_getName(newClass);
    Class oldClass = objc_getClass(className);

    if  ( newClass != oldClass ) {
        [self alignIvarsOf:newClass to:oldClass];

        // replace implementations for class and instance methods
        [self swizzle:object_getClass(oldClass) from:object_getClass(newClass)];
        [self swizzle:oldClass from:newClass];
    }

#if 0
    [self dumpIvars:oldClass];
    [self dumpIvars:newClass];
#endif
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    if ( notify & 1<<2 ) {
        NSString *msg = [[NSString alloc] initWithFormat:@"Class '%s' injected.", className];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Bundle Loaded"
                                                        message:msg delegate:nil
                                              cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert performSelector:@selector(injectionDismiss)
                    withObject:nil afterDelay:1.];
#ifndef INJECTION_ISARC
        [alert release];
        [msg release];
#endif
    }
#else
    INLog( @" ...ignore any warning, Injection has swizzled class '%s'", className );
#endif
}

+ (void)loadedNotify:(BOOL)notify {
    INLog( @"Bundle \"%s\" loaded successfully.", strrchr( path, '/' )+1 );
#ifndef __IPHONE_OS_VERSION_MIN_REQUIRED
    if ( notify & 1<<3 )
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
#endif
    status = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:kINNotification
                                                        object:nil];
}

#endif

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED

static NSMutableDictionary *nibsByNibName, *optionsByVC;

+ (void)reloadVisibleVC:(UIViewController *)vc fromBundle:(NSBundle *)bundle storyBoard:(NSString *)storyBoard {
    if ( [vc respondsToSelector:@selector(visibleViewController)] )
        vc = [(UINavigationController *)vc visibleViewController];
    if ( [vc presentedViewController] )
        vc = [vc presentedViewController];

    NSString *nibPath = [NSString stringWithFormat:@"%@.storyboardc/%@", storyBoard, vc.nibName];
    UINib *nib = [UINib nibWithNibName:nibPath bundle:bundle];

    if ( !nibsByNibName )
        nibsByNibName = [[NSMutableDictionary alloc] init];

    if ( !nib )
        NSLog( @"Could not open nib named '%@' in bundle: %@", nibPath, bundle );
    else
        [nibsByNibName setObject:nib forKey:vc.nibName];

    [nib instantiateWithOwner:vc options:[optionsByVC objectForKey:[vc description]]];

    [vc viewDidLoad];
    [vc viewWillAppear:YES];
    [vc viewDidAppear:YES];
}

+ (void)reloadNibs {
    NSString *storyBoard = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"UIMainStoryboardFile"];
    NSBundle *bundle = [NSBundle bundleWithPath:[NSString stringWithUTF8String:path+1]];
    INLog( @"Reloading nibs from storyboard: %@", storyBoard );

    UIViewController *rootVC = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    NSArray *vcs = [rootVC respondsToSelector:@selector(viewControllers)] ?
        [(UISplitViewController *)rootVC viewControllers] : [NSArray arrayWithObject:rootVC];
    for ( UIViewController *vc in vcs )
        [self reloadVisibleVC:vc fromBundle:bundle storyBoard:storyBoard];
}

@end

@implementation UINib(BundleInjection)
- (NSArray *)inInstantiateWithOwner:(id)ownerOrNil options:(NSDictionary *)optionsOrNil {
    if ( !optionsByVC )
        optionsByVC = [[NSMutableDictionary alloc] init];
    if ( ownerOrNil && optionsOrNil )
        [optionsByVC setObject:optionsOrNil forKey:[ownerOrNil description]];

    UINib *nib = [ownerOrNil respondsToSelector:@selector(nibName)] ?
        [nibsByNibName objectForKey:[ownerOrNil nibName]] : nil;
    return [nib ? nib : self inInstantiateWithOwner:ownerOrNil options:optionsOrNil];
}

#endif
@end

#ifdef INJECTION_ENABLED
@implementation NSObject(INParameters)
+ (float *)inParameters {
    return INParameters;
}
+ (float)inParameter:(int)tag {
    return INParameters[tag];
}
+ (void)inSetDelegate:(id)delegate forParameter:(int)tag {
    INDelegates[tag] = delegate;
}
+ (void)inSetTarget:(id)target action:(SEL)action forColor:(int)tag {
    INColorTargets[tag] = target;
    INColorActions[tag] = action;
}
+ (void)inSetImageTarget:(id)target {
    INImageTarget = target;
}
@end
#endif
#endif
