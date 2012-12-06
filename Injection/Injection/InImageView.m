//
//  INImageView.m
//  Injection
//
//  Created by John Holdsworth on 29/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "INImageView.h"

@implementation InImageView

- (void)setImage:(NSImage *)image
{
    [image setName:[[imageFile lastPathComponent] stringByDeletingPathExtension]];
    [super setImage:image];
}

- (BOOL)performDragOperation:(id )sender {
    BOOL dragSucceeded = [super performDragOperation:sender];
    if (dragSucceeded) {
        NSString *filenamesXML = [[sender draggingPasteboard] stringForType:NSFilenamesPboardType];
        if (filenamesXML) {
            OOStringArray filenames = [NSPropertyListSerialization
                                  propertyListFromData:[filenamesXML dataUsingEncoding:NSUTF8StringEncoding]
                                  mutabilityOption:NSPropertyListImmutable
                                  format:nil
                                  errorDescription:nil];
            if ( filenames >= 1) {
                imageFile.setPath( filenames[0] );
            } else {
                imageFile.setPath( nil );   
            }
        }
    }
    return dragSucceeded;
}

@end
