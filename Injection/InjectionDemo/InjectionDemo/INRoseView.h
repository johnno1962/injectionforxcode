//
//  INRoseView.h
//  InjectionDemo
//
//  Created by John Holdsworth on 12/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//  $Id$
//

#import <UIKit/UIKit.h>

@interface INRoseView : UIView

@property (strong, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) IBOutlet UIButton *button;

- (IBAction)animate:sender;

@end
