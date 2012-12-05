//
//  Catcher.m - print stack trace of exceptions and break to debugger
//  ObjCpp
//
//  Created by John Holdsworth on 27/11/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//
//  $Id: //depot/ObjCpp/Catcher.m#9 $
//  $DateTime: 2012/08/27 20:29:17 $
//

#ifdef DEBUG
#import <Foundation/Foundation.h>

@interface NSException(Catcher)
@end

@implementation NSException(Catcher)

// only for use in applications which do not use exceptions routinely themselves...
- (id)initWithName:(NSString *)theName reason:(NSString *)theReason userInfo:(NSDictionary *)userInfo {

    @try {
        @throw self;
    }
    @catch ( NSException *ex ) {
        NSLog( @"%@", [ex callStackSymbols] );
    }

    NSLog( @"*** Terminating app due to uncaught exception '%@', reason: '%@'", theName, theReason );

	(*(int *)0)++; // invalid memory access hands control over to debugger...
	return self;
}

@end
#endif
