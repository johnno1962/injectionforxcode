//
//  InDirectory.h
//  Injection
//
//  Created by John Holdsworth on 26/01/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "objcpp.h"

@interface InDirectory : NSObject {
    char path[PATH_MAX], *end;
    OONumberDict mtimes;
}

- initPath:(const char *)aPath;
- (OOStringArray)changed;

@end
