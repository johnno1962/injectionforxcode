//
//  INMasterViewController.h
//  StoryboardDemo
//
//  Created by John Holdsworth on 24/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class INDetailViewController;

@interface INMasterViewController : UITableViewController

@property (strong, nonatomic) INDetailViewController *detailViewController;

@end
