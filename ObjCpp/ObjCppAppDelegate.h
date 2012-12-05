//
//  ObjCppAppDelegate.h
//  ObjCpp
//
//  Created by John Holdsworth on 14/04/2009.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// obj*.h implicitly included from ObjCpp_Prefix.pch

@interface OOTestObjC : NSObject {
#if 0
#ifdef OO_ARC
    OOTestObjC *ref;
#else
    OORef<OOTestObjC *> ref;
#endif
#endif
}
@end

@interface ObjCppAppDelegate : NSObject {
	IBOutlet NSTextField *results;
	OOReference<OOTestObjC *> ivarRef;
	OOArray<OOTestObjC *> ivarArray;
	OODictionary<OOTestObjC *> ivarDict;
	OOString ivarString;
	OOVector<double> ivarVector;
	OOClassDict<OOClassTest> ivarClassDict;
    OORequest lastRequest;
}

- (IBAction)multithread:cell;

@end
