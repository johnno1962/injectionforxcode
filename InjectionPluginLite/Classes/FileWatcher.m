//
//  FileWatcher.m
//  Injector
//
//  Created by John Holdsworth on 08/03/2015.
//  Copyright (c) 2015 John Holdsworth. All rights reserved.
//

#import "FileWatcher.h"

@implementation FileWatcher {
    FSEventStreamRef fileEvents;
}

static void fileCallback( ConstFSEventStreamRef streamRef,
                         void *clientCallBackInfo,
                         size_t numEvents, void *eventPaths,
                         const FSEventStreamEventFlags eventFlags[],
                         const FSEventStreamEventId eventIds[] ) {
    FileWatcher *self = (__bridge FileWatcher *)clientCallBackInfo;
    [self performSelectorOnMainThread:@selector(filesChanged:)
                           withObject:(__bridge id)eventPaths waitUntilDone:NO];
}

- (instancetype)initWithRoot:(NSString *)projectRoot plugin:(InjectionCallback)callback;
{
    if ( (self = [super init]) ) {
        self.callback = callback;
        static struct FSEventStreamContext context;
        context.info = (__bridge void *)self;
        fileEvents = FSEventStreamCreate(kCFAllocatorDefault,
                                         fileCallback, &context,
                                         (__bridge CFArrayRef)@[projectRoot],
                                         kFSEventStreamEventIdSinceNow, .1,
                                         kFSEventStreamCreateFlagUseCFTypes|
                                         kFSEventStreamCreateFlagFileEvents);
            FSEventStreamScheduleWithRunLoop(fileEvents, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
            FSEventStreamStart( fileEvents );
    }

    return self;
}

- (void)filesChanged:(NSArray *)changes;
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableSet *changed = [NSMutableSet new];

    for ( NSString *path in changes )
        if ( [path rangeOfString:INJECTABLE_PATTERN
                         options:NSRegularExpressionSearch].location != NSNotFound &&
            [path rangeOfString:@"DerivedData/|InjectionProject/|main.mm?$"
                        options:NSRegularExpressionSearch].location == NSNotFound &&
            [fileManager fileExistsAtPath:path] )
            [changed addObject:path];

    //NSLog( @"filesChanged: %@", changed );
    if ( changed.count )
        self.callback( [[changed objectEnumerator] allObjects] );
}

- (void)dealloc;
{
    FSEventStreamStop( fileEvents );
    FSEventStreamInvalidate( fileEvents );
    FSEventStreamRelease( fileEvents );
#ifdef __clang__
#if __has_feature(objc_arc)
#else
    [super dealloc];
#endif
#endif
}

@end
