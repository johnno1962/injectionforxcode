## Storyboard injection and "Inject and Reset"

Pre-requisites:

 *  You are running with patched injection
 *  You have selected "Inject Strybds" in the "Tunable App Parameters" panel
 
You can be able to inject storyboards to some extent. Injection will recompile the storyboard 
being edited and reload the currently loaded view controller and calling following:

``` objc
[vc.view setNeedsLayout];
[vc.view layoutIfNeeded];

[vc viewDidLoad];
[vc viewWillAppear:NO];
[vc viewDidAppear:NO];
```

Another more speculative mode that can be used is "Product/Injection Plugin/Inject and Reset".
The intention is that this should return your application to it's main screen and 
executes the following code after injection:

``` objc
if ( injectAndReset ) {
    UIApplication *app = UIApplication.sharedApplication;
    UIViewController *vc = [app.windows[0] rootViewController];
    UIViewController *newVc = vc.storyboard.instantiateInitialViewController;
    
    if ( !newVc )
        newVc = [[[vc class] alloc] initWithNibName:vc.nibName bundle:nil];
        
    if ( [newVc respondsToSelector:@selector(setDelegate:)] )
        [(id)newVc setDelegate:vc.delegate];
        
    [app.windows[0] setRootViewController:newVc];
    
    if ( [app.delegate respondsToSelector:@selector(setViewController:)] )
        [(NSObject *)app.delegate setViewController:newVc];
        
    injectAndReset = NO;
}
```

This approximates the booting process of a Storyboard based application.

Storyboard injection will not update image resources that are referenced from your Storyboard.
If you explicitly load images in `viewDidLoad` using `[UIImage imageNamed:@"hatstand"]` (which
will reference the main bundle), images should continue to work after the storyboard is updated
and the view is reloaded.
