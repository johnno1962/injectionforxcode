//
//  INImageView.h
//  Injection
//
//  Created by John Holdsworth on 29/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "objcpp.h"

@interface InImageView : NSImageView {
@public
    OOFile imageFile;
}

@end
