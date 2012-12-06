//
//  InPluginDocument.h
//  InjectionPlugin
//
//  Created by John Holdsworth on 19/09/2012.
//
//

#import "InDocument.h"

@interface InPluginDocument : InDocument {
    OOStringArray pendingFiles;
    int headerChanged, nagged;
}

@end
