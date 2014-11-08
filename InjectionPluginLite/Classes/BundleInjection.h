//
//  $Id: //depot/InjectionPluginLite/Classes/BundleInjection.h#74 $
//  Injection
//
//  Created by John Holdsworth on 16/01/2012.
//  Copyright (c) 2012 John Holdsworth. All rights reserved.
//
//  Client application interface to Code Injection system.
//  Added to program's main.(m|mm) to connect to the Injection app.
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

#import "BundleInterface.h"

#ifndef INJECTION_PORT
#define INJECTION_PORT 31442
#endif

#define INJECTION_MAGIC -INJECTION_PORT*INJECTION_PORT
#define INJECTION_APPNAME "Injection"
#define INJECTION_MKDIR -1
#define INJECTION_NOFILE -2
#define INJECTION_CLOSE -3

#define INJECTION_NOTSILENT (1<<2)
#define INJECTION_ORDERFRONT (1<<3)

#if !defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && !defined(__LP64__)
#define INJECTION_LEGACY32BITOSX
#endif

#ifdef DEBUG
#define INLog NSLog
#else
#define INLog while(0) NSLog
#endif

struct _in_header { int pathLength, dataLength; };

@interface BundleInjection : NSObject
+ (BOOL)readHeader:(struct _in_header *)header forPath:(char *)path from:(int)fdin;
+ (BOOL)writeBytes:(off_t)bytes withPath:(const char *)path from:(int)fdin to:(int)fdout;
#ifdef INJECTION_BUNDLE
+ (void)loadedClass:(Class)newClass notify:(BOOL)notify;
+ (void)autoLoadedNotify:(int)notify hook:(void *)hook;
+ (void)loadedNotify:(int)notify hook:(void *)hook;
#endif
@end

#import <netinet/tcp.h>
#import <sys/socket.h>
#import <arpa/inet.h>
#import <sys/stat.h>
#import <unistd.h>
#import <fcntl.h>

#ifndef INJECTION_NOIMPL

#import <dirent.h>

#import <objc/runtime.h>
#import <sys/sysctl.h>
#import <dlfcn.h>

#ifndef ANDROID
#import <mach-o/dyld.h>
#import <mach-o/arch.h>
#import <mach-o/getsect.h>
#endif

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && !defined(INJECTION_LOADER)
#import <UIKit/UIKit.h>
@interface UINib(BundleInjection)
- (NSArray *)inInstantiateWithOwner:(id)ownerOrNil options:(NSDictionary *)optionsOrNil;
@end
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
        ssize_t rc = read( fdin, buffer, bytes < (int)sizeof buffer ? (int)bytes : (int)sizeof buffer );
        ok = ok && rc > 0 && fdout > 0 ? write( fdout, buffer, rc ) == rc : TRUE;
        bytes -= rc;
    }

    return ok;
}

#ifdef INJECTION_ENABLED

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
id INColorDelegate;
id INImageTarget;

static char path[PATH_MAX], *file = &path[1];
static int status, sbInjection;

#ifndef ANDROID
static NSNetServiceBrowser *browser;
static NSNetService *service;

+(void)netServiceBrowser:(NSNetServiceBrowser *)aBrowser didFindService:(NSNetService *)aService moreComing:(BOOL)more {
    service = aService;
#ifndef INJECTION_ISARC
    [service retain];
#endif
    aService.delegate = (id<NSNetServiceDelegate>)self;
    [aService resolveWithTimeout:0];
}

+(void)netServiceBrowser:(NSNetServiceBrowser *)aBrowser didRemoveService:(NSNetService *)aService moreComing:(BOOL)more {
}

+(void)netServiceDidResolveAddress:(NSNetService *)service {
    for ( NSData *addr in service.addresses ) {
        struct sockaddr_in *ip = (struct sockaddr_in *)[addr bytes];
        if ( ip->sin_family == AF_INET ) {
            _inIPAddresses[0] = strdup( inet_ntoa( ip->sin_addr ) );
            NSLog( @"%s service on: %s", INJECTION_APPNAME, _inIPAddresses[0] );
           break;
        }
    }

    [self performSelectorInBackground:@selector(bundleLoader) withObject:nil];
}

+(void)netService:(NSNetService *)service didNotResolve:(NSDictionary *)errorDict {
    NSLog(@"%s could not resolve: %@", INJECTION_APPNAME, errorDict);
    [self performSelectorInBackground:@selector(bundleLoader) withObject:nil];
}

+ (void)load {
    INLog( @"+[BundleInjection load] %s", _inIPAddresses[0] ); ////
    if ( _inIPAddresses[0][0] == '_' ) {
        NSString *bonjourName = [NSString stringWithUTF8String:_inIPAddresses[0]];
        _inIPAddresses[0] = _inIPAddresses[1];

        browser = [NSNetServiceBrowser new];
        browser.delegate = (id<NSNetServiceBrowserDelegate>)self;

        INLog( @"%s looking for service: %@", INJECTION_APPNAME, bonjourName );
        [browser searchForServicesOfType:bonjourName inDomain:@""];
    }
    else
#else
+ (void)load {
#endif
        [self performSelectorInBackground:@selector(bundleLoader) withObject:nil];
}

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

    loaderAddr.sin_family = AF_INET;
	inet_aton( ipAddress, &loaderAddr.sin_addr );
	loaderAddr.sin_port = htons(INJECTION_PORT);

    INLog( @"%s attempting connection to: %s:%d (see project's main.(m|mm)", INJECTION_APPNAME, ipAddress, INJECTION_PORT );

    int loaderSocket, optval = 1;
    if ( (loaderSocket = socket(loaderAddr.sin_family, SOCK_STREAM, 0)) < 0 )
        NSLog( @"Could not open socket for injection: %s", strerror( errno ) );
    else if ( setsockopt( loaderSocket, IPPROTO_TCP, TCP_NODELAY, (void *)&optval, sizeof(optval)) < 0 )
        NSLog( @"Could not set TCP_NODELAY: %s", strerror( errno ) );
    else if ( connect( loaderSocket, (struct sockaddr *)&loaderAddr, sizeof loaderAddr ) >= 0 )
        return loaderSocket;

    close( loaderSocket );
    return 0;
}

static const char **addrPtr, *connectedAddress;

+ (const char *)connectedAddress {
    return connectedAddress;
}

+ (void)bundleLoader {
#ifndef INJECTION_ISARC
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
#else
    @autoreleasepool {
#endif

        Class firstInjection = objc_getClass(class_getName(self));
        if ( [firstInjection connectedAddress] )
            return;

        static char machine[64];
        if ( machine[0] )
            return;

        size_t size = sizeof machine;
        sysctlbyname("hw.machine", machine, &size, NULL, 0);
        machine[size] = '\000';

        const char *localOnly[] = {"127.0.0.1", NULL},
            **addrSwitch = strcmp( machine, "x86_64" ) == 0 ? localOnly : _inIPAddresses;

#ifndef ANDROID
        const struct mach_header *m_header = _dyld_get_image_header(0);
        const NXArchInfo *info = NXGetArchInfoFromCpuType(m_header->cputype, m_header->cpusubtype);
        const char *arch = info->name;
#ifdef INJECTION_LEGACY32BITOSX
        NSLog( @"\n\n**** Injection does not work with 32 bit \"legacy\" OS X Objective-C runtime. ****\n\n" );
#endif
#else
        const char *arch = "android";
#endif
        size_t alen = strlen(arch)+1;

        int i;
        for ( i=0 ; i<100 ; i++ ) {
            int loaderSocket = 0;

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

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && !defined(INJECTION_LOADER)
            if ( (sbInjection = status & 2) )
                method_exchangeImplementations(
                   class_getInstanceMethod([UINib class], @selector(instantiateWithOwner:options:)),
                   class_getInstanceMethod([UINib class], @selector(inInstantiateWithOwner:options:)));
#else
            sbInjection = 0;
#endif

            NSString *executablePath = NSHomeDirectory();//[[NSBundle mainBundle] executablePath];
            [executablePath getCString:path maxLength:sizeof path encoding:NSUTF8StringEncoding];
            [self writeBytes:alen withPath:path from:0 to:loaderSocket];
            write(loaderSocket, arch, alen);

            INLog( @"Connected to \"%s\" plugin, ready to load %s code.", INJECTION_APPNAME, arch );
            connectedAddress = *addrPtr;

            int fdout = 0;
            struct _in_header header;
            while ( [self readHeader:&header forPath:path from:loaderSocket] ) {
                if ( !path[0] && header.dataLength == INJECTION_MAGIC )
                    continue; // WiFi keepalive

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
                        else if ( header.dataLength == INJECTION_MKDIR )
                            mkdir( file, 0777 );
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
#ifndef INJECTION_LOADER
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
#else
                        NSLog( @"Image injection not available in \"unpatched\" Injection" );
#endif
                    }
                        break;

                    case '@': // project built, reload visible view controllers
#if __IPHONE_OS_VERSION_MIN_REQUIRED
                        if ( sbInjection )
                            [self performSelectorOnMainThread:@selector(reloadNibs)
                                                   withObject:nil waitUntilDone:YES];
                        else
                            NSLog( @"'Inject StoryBds' must be enabled on the Tunable Parameters panel." );
#else
                        NSLog( @"Storyboard injection only available for iOS in Xcode 4." );
#endif
                        break;

                    case '!': // log message to console window
                        printf( "%s\n", file );
                        break;

                    default: // parameter or color value update
                        if ( isdigit(path[0]) ) {
                            int tag = path[0]-'0';
                            if ( tag < 5 ) {
                                INParameters[tag] = atof( file );
                                INLog( @"Param #%d -> %f", tag, INParameters[tag] );
                                [INDelegates[tag] inParameter:tag hasChanged:INParameters[tag]];
                            }
                            else if ( (tag -= 5) < 5 ) {
#ifndef INJECTION_LOADER
                                float r, g, b, a;
                                sscanf( file, "%f,%f,%f,%f", &r, &g, &b, &a );
                                INLog( @"Color #%d -> %f,%f,%f,%f", tag, r, g, b, a );
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
                                if ( [INColorDelegate respondsToSelector:@selector(inColor:hasChanged:)] )
                                    [INColorDelegate inColor:tag hasChanged:col];
#else
                                static int warned;
                                if ( !warned++ )
                                    NSLog( @"Color tuning not available in \"unpatched\" Injection" );
#endif
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

            NSLog( @"Lost connection, %s", strerror( errno ) );
            close( loaderSocket );
        }

        INLog( @"Giving up on connecting to %s", INJECTION_APPNAME );

#ifndef INJECTION_ISARC
        [pool release];
#else
    }
#endif
}

#ifndef ANDROID
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
struct _in_objc_class { Class meta, supr; void *cache, *vtable; struct _in_objc_ronly *internal;
    // data new to swift
    int f1, f2; // added for Beta5
    int size, tos, mdsize, eight;
    struct _swift_data {
        unsigned long flags;
        const char *className;
        int fieldcount, flags2;
        const char *ivarNames;
        struct _swift_field **(*get_field_data)();
    } *swiftData;
    IMP dispatch[1];
};

#else

// Apportable's Objective-C data structures ...
struct _in_objc_ivars { int twenty, count; struct { long *offsetPtr; char *name, *type; int align, size; } ivars[1]; };
struct _in_objc_ronly { int z1, offsetStart; int offsetEnd, z2; char *className; void *methods, *skip2; struct _in_objc_ivars *ivars; };
struct _in_objc_class { Class meta, supr; void *cache, *vtable; struct _in_objc_ronly *internal; };

#import <elf.h>

+ (const char *)registerSelectorsInLibrary:(const char *)file containing:(void *)hook {

    struct stat st;
    if ( stat( file, &st ) < 0 )
        return "could not stat file";

    char *buffer = (char *)malloc( st.st_size );

    FILE *fp = fopen( file, "r" );
    if ( !fp )
        return "Could not open file";
    if ( fread( buffer, 1, st.st_size, fp ) != st.st_size )
        return "Could not read file";
    fclose( fp );

    Elf32_Ehdr *hdr = (Elf32_Ehdr *)buffer;

    //NSLog( @"Offsets: %lld %d %d %d %d", st.st_size, hdr->e_phoff, hdr->e_shoff, hdr->e_shentsize, hdr->e_shnum );

    if ( hdr->e_shoff > st.st_size )
        return "Bad segment header offset";

    Elf32_Shdr *sections = (Elf32_Shdr *)(buffer+hdr->e_shoff);

    // assumes names section is last...
    const char *names = buffer+sections[hdr->e_shnum-1].sh_offset;
    if ( names > buffer + st.st_size )
        return "Bad section name table offset";

    unsigned offset = 0, nsels = 0;

    for ( int i=0 ; i<hdr->e_shnum ; i++ ) {
        Elf32_Shdr *sect = &sections[i];
        const char *name = names+sect->sh_name;
        //NSLog( @"Section: %s 0x%x[%d] %d %d", name, sect->sh_offset, sect->sh_size, sect->sh_addr, sect->sh_addralign );
        if ( strcmp( name, "__DATA, __objc_selrefs, literal_pointers, no_dead_strip" ) == 0 ) {
            offset = sect->sh_addr;
            nsels = sect->sh_size;
        }
    }

    if ( !offset )
        return "Unable to locate selrefs section";

    Dl_info info;
    if ( !dladdr( hook, &info ) )
        return "Could not find load address";

    SEL *sels = (SEL *)((char *)info.dli_fbase+offset);
    for ( unsigned i=0 ; i<nsels/sizeof *sels ; i++ )
        sels[i] = sel_registerName( (const char *)(void *)sels[i] );

    free( buffer );
    return NULL;
}

+ (void)loadBundle {
    NSLog( @"Loading shared library: %s", path );
    void *library = dlopen( path, RTLD_NOW);
    if ( !library )
        NSLog( @"%s: %s", INJECTION_APPNAME, dlerror() );
    else {
        int (*hook)() = dlsym( library, "injectionHook" );
        if ( !hook )
            NSLog( @"Unable to locate injectionHook() in: %s", path );
        else {
            const char *err = [self registerSelectorsInLibrary:path containing:hook];
            if ( err )
                NSLog( @"registerSelectorsInLibrary: %s", err );
            status = hook( path );
        }
    }
}

#endif

+ (void)alignIvarsOf:(Class)newClass to:(Class)oldClass {
    // this used to be necessary due to the vagaries of clang
    // new version of class must not have been messaged at this point
    // i.e. the new version must not have a "+ (void)load" method
    struct _in_objc_class *nc = INJECTION_BRIDGE(struct _in_objc_class *)newClass;
    struct _in_objc_ivars *ivars = nc->internal->ivars;
    [newClass class];

    // align ivars in new class with original
    for ( int i=0 ; ivars && i<ivars->count ; i++ ) {
        const char *ivarName = ivars->ivars[i].name;
        Ivar ivar = class_getInstanceVariable(oldClass, ivarName);
        if ( !ivar )
            NSLog( @"*** Please re-run your application to add ivar '%s' ***", ivarName );
        else {
            if ( strcmp( ivar_getTypeEncoding( ivar ), ivars->ivars[i].type ) != 0 )
                NSLog( @"*** Ivar '%s' has changed type, re-run application. ***",
                      ivars->ivars[i].name );

            long *newOffsetPtr = ivars->ivars[i].offsetPtr, oldOffset = ivar_getOffset(ivar);
            if ( *newOffsetPtr != oldOffset ) {
                NSLog( @"Aligning ivar: %s.%s as %ld != %ld",
                      class_getName(oldClass), ivarName, *newOffsetPtr, oldOffset );
                *newOffsetPtr = oldOffset;
            }
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

+ (BOOL)dontSwizzleProperty:(Class)oldClass sel:(SEL)sel {
    char name[PATH_MAX];
    strcpy(name,sel_getName(sel));
    return class_getProperty(oldClass,sel_getName(sel)) ||
        (strncmp(name,"set",3)==0 && (name[3] = tolower(name[3])) && class_getProperty(oldClass,name+3));
}

+ (void)swizzle:(char)which className:(const char *)className onto:(Class)oldClass from:(Class)newClass {
    unsigned i, mc = 0;
    Method *methods = class_copyMethodList(newClass, &mc);

    for( i=0; i<mc; i++ ) {
        SEL name = method_getName(methods[i]);

        // don't swizzle getters/setters
        if ( [self dontSwizzleProperty:oldClass sel:name] )
            continue;

        IMP newIMPL = method_getImplementation(methods[i]);
        const char *type = method_getTypeEncoding(methods[i]);

        //INLog( @"Swizzling: %c[%s %s] %s to: %p", which, className, sel_getName(name), type, newIMPL );
#ifdef INJECTION_LOADER
        if ( originals.find(oldClass) != originals.end() &&
            originals[oldClass].find(name) != originals[oldClass].end() )
            originals[oldClass][name].original = (XTRACE_VIMP)newIMPL;
        else
#endif
            class_replaceMethod(oldClass, name, newIMPL, type);
    }

    free(methods);
}

+ (void)loadedClass:(Class)newClass notify:(int)notify {
    const char *className = class_getName(newClass);
    Class oldClass = objc_getClass(className);

    if  ( newClass != oldClass ) {
        ////[self alignIvarsOf:newClass to:oldClass];

        // replace implementations for class and instance methods
        [self swizzle:'+' className:className onto:object_getClass(oldClass) from:object_getClass(newClass)];
        [self swizzle:'-' className:className onto:oldClass from:newClass];

#ifndef INJECTION_LEGACY32BITOSX
        // if swift language class, copy vtable
        struct _in_objc_class *newclass = (struct _in_objc_class *)INJECTION_BRIDGE(void *)newClass;
        if ( (unsigned long)newclass->internal & 0x1 ) {
            struct _in_objc_class *oldclass = (struct _in_objc_class *)INJECTION_BRIDGE(void *)oldClass;
            size_t bytes = oldclass->mdsize - offsetof(struct _in_objc_class, dispatch) - 2*sizeof(IMP);
            memcpy( oldclass->dispatch, newclass->dispatch, bytes );
        }
#endif
    }

    // if class has a +injected method call it.
    if ( [oldClass respondsToSelector:@selector(injected)] )
        [oldClass injected];

    // If XprobePlugin loaded? Call -injected on selected instance
    Class xprobe = objc_getClass("Xprobe");
    if ( [xprobe respondsToSelector:@selector(injectedClass:)] )
        [xprobe injectedClass:oldClass];

#if 0
    [self dumpIvars:oldClass];
    [self dumpIvars:newClass];
#endif
#ifndef INJECTION_LOADER
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    if ( notify & INJECTION_NOTSILENT ) {
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
#endif
}

+ (void)loadedNotify:(int)notify hook:(void *)hook {
#ifndef ANDROID
    [self fixClassRefs:hook];
#endif

    INLog( @"Bundle \"%s\" loaded successfully.", strrchr( path, '/' )+1 );
#ifndef __IPHONE_OS_VERSION_MIN_REQUIRED
    if ( notify & INJECTION_ORDERFRONT )
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
#endif
    status = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:kINNotification
                                                        object:nil];
}

#ifndef ANDROID
+ (void)fixClassRefs:(void *)hook {
    Dl_info info;
    if ( !dladdr( hook, &info ) )
        NSLog( @"Could not find load address" );
    
#ifndef __LP64__
    uint32_t size = 0;
    char *referencesSection = getsectdatafromheader((struct mach_header *)info.dli_fbase,
                                                    "__DATA", "__objc_classrefs", &size );
#else
    uint64_t size = 0;
    char *referencesSection = getsectdatafromheader_64((struct mach_header_64 *)info.dli_fbase,
                                                       "__DATA", "__objc_classrefs", &size );
#endif

    if ( referencesSection ) {
        Class *classReferences = (Class *)(void *)((char *)info.dli_fbase+(uint64_t)referencesSection);
        for ( unsigned long i=0 ; i<size/sizeof *classReferences ; i++ ) {
            const char *className = class_getName(classReferences[i]);
            Class originalClass = objc_getClass( className );
            if ( originalClass && classReferences[i] != originalClass ) {
                INLog( @"Fixing references to class: %s %p -> %p", className, classReferences[i], originalClass );
                classReferences[i] = originalClass;
            }
        }
    }
}
#endif

+ (void)autoLoadedNotify:(int)notify hook:(void *)hook {
#ifndef ANDROID
    __block BOOL seenInjectionClass = NO;
    Dl_info info;
    if ( !dladdr( hook, &info ) )
        NSLog( @"Could not find load address" );

#ifndef __LP64__
    uint32_t size = 0;
#ifdef INJECTION_LEGACY32BITOSX
    // vain attempt support for legacy 32bit OS X runtime
    struct _sym {
        int u1, u2;
        short nclass, ncat;
        Class classes[1];
    } *sym = (struct _sym *)(void *)((char *)info.dli_fbase+
                                     (uint64_t)getsectdatafromheader((struct mach_header *)info.dli_fbase,
                                                    "__OBJC", "__symbols", &size ));
    char *referencesSection = (char *)((char *)&sym[0].classes-(char *)info.dli_fbase);
    size = sym[0].nclass*sizeof(Class);
    seenInjectionClass = YES;
#else
    char *referencesSection = getsectdatafromheader((struct mach_header *)info.dli_fbase,
                                                    "__DATA", "__objc_classlist", &size );
#endif
#else
    uint64_t size = 0;
    char *referencesSection = getsectdatafromheader_64((struct mach_header_64 *)info.dli_fbase,
                                                       "__DATA", "__objc_classlist", &size );
#endif

    INLog( @"Bundle \"%s\" loaded successfully.", strrchr( path, '/' )+1 );

    if ( referencesSection )
        dispatch_async(dispatch_get_main_queue(), ^{
            Class *classReferences = (Class *)(void *)((char *)info.dli_fbase+(uint64_t)referencesSection);
            for ( unsigned long i=0 ; i<size/sizeof *classReferences ; i++ ) {
                Class newClass = classReferences[i];
                const char *className = class_getName(newClass);

                if ( seenInjectionClass ) {
                    INLog( @"Swizzling %s %p %p", className, newClass, objc_getClass(className) );
#ifndef INJECTION_LEGACY32BITOSX
                    [newClass class];
#endif
                    [self loadedClass:newClass notify:notify];
                }

                static const char injectionPrefix[] = "InjectionBundle";
                seenInjectionClass = strncmp(className,injectionPrefix,(sizeof injectionPrefix)-1)==0;
            }

            [self fixClassRefs:hook];

#ifndef __IPHONE_OS_VERSION_MIN_REQUIRED
            if ( notify & INJECTION_ORDERFRONT )
                [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
#endif
            [[NSNotificationCenter defaultCenter] postNotificationName:kINNotification
                                                                object:nil];
        });
    else
        NSLog( @"Injection Error: Could not locate referencesSection" );

    status = referencesSection != NULL;
#endif
}

#endif

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && !defined(INJECTION_LOADER)

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

    INLog( @"Reloading nib %@ onto %@", nibPath, vc );
    [nib instantiateWithOwner:vc options:[optionsByVC objectForKey:[vc description]]];

    [vc viewDidLoad];
    [vc viewWillAppear:YES];
    [vc viewDidAppear:YES];
}

+ (void)reloadNibs {
    NSString *storyBoard = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"UIMainStoryboardFile"];
    NSBundle *bundle = [NSBundle bundleWithPath:[NSString stringWithUTF8String:path+1]];

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
