# ![Icon](http://injectionforxcode.johnholdsworth.com/injection.png) Injection Plugin for Xcode

Copyright (c) John Holdsworth 2012-16

injectionforxcode is an extension to the Xcode IDE that allows you to patch the implementation
of a class method without having to restart the application. It preforms this by parsing the
build logs of the application to determine how a source file was last compiled then wraps
the result of re-compiling into a bundle which is loaded into the application. At this stage
there are two version of the class available to the app, one with the modified versions of
method implementations that are "swizzled" onto the original class so they take effect.

This swizzling takes advantage of the fact that Objective-C's binds method invocations to
implementations at run time. Provided that the method or class is not final or private 
(i.e. the method can be overridden) this can also be performed on Swift classes by patching the
class "vtable". This excludes the injection of methods of structs.

To use injectionforxcode, downloading this project and building it and restarting Xcode is sufficient
to install the plugin or if you have the [Alcatraz Package Manager](http://alcatraz.io/) installed
you can use that for an automated install. Once installed, if you are working in the simulator,
all that is required to inject a source is to use the new "Product/Inject Source" menu item
and the source will be recompiled, bundled, loaded and swizzled into your application (you
can ignore any messages about duplicate class definitions your code changes to method
implementations should take effect.) To remove the plugin type the following into a console:

    rm -rf ~/Library/Application\ Support/Developer/Shared/Xcode/Plug-ins/InjectionPlugin.xcplugin

Announcements of major commits to the repo will be made on twitter [@Injection4Xcode](https://twitter.com/#!/@Injection4Xcode).

If you are working on the device or using AppCode you need to patch your project slightly
to use injection. This adds a small stub of code to your application's main.m that bootstraps
the injection process connecting back to Xcode using the address patched into the main.m file.
This patch can be applied automatically using the "Product/Injection Plugin/Patch Project for Injection"
menu item. For a Swift project you'll need to add an empty main.m so it can be patched. Once
your application has run and connected to the plugin it should be able to inject as before.

There are limitations of course, largely centering around static variables and static or global
functions and their Swift equivalents. Consider the following Objective-C code.

![Icon](http://injectionforxcode.johnholdsworth.com/injection1.png)

One potential problem is that when the new version of the class is loaded it comes with it's own
versions of static variables such as "sharedInstance" and "once" and after injection has occurred 
would generate a new singleton instance. To prevent this class methods that have the prefix
"shared" are not swizzled on injection to support this common idiom.

When a class has been injected it calls the class method "+(void)injected" as well as the
instance level "-(void)injected" method on all instances of the class being injected. The 
later case is more difficult to realise as it requires a list of instances for a particular
class. In order to determine this injection performs a "sweep" or all instances of the app
and instances those instances point to etc which is then filtered by the injecting class.
This process is seeded using the application delegate and all windows. This list is
supplemented by the values returned by method "sharedInstance" of all application classes
if required.

The function dispatch_on_main does of course not inject as it has been statically linked into
the application. It does however inject by proxy in the case shown in the "doSomething"
method as it will have been linked locally to version in the object file being injected.

### What about Swift?

![Icon](http://injectionforxcode.johnholdsworth.com/injection2.png)

Swift, presents a few more stumbling blocks for the uninitiated. Provided that methods are of
a non final class and a non final (this excludes structs alas) they can be injected.
In this example the shared instance variable is declared "static" rather than "class" to make
sure it is not injected ensure there is only ever one singleton. For the "injected"
methods to work you class must inherit from NSObject.

More problematic is the more common use of variable or functions outside a class which are
referred to across files of a bundle. Swift 1.2+ takes the view these "internal" scope
symbols should not be available across bundles and are made "private extern" in
their object file making them unavailable at run time. This means that the above code
will inject but another file referring to the dispatch_on_main function will fail
with obscure dynamic loading errors.

The simplest solution is to make these variables and functions public though, for a framework
this may be unsatisfactory. The alternative is to patch the object files of the project to remove the
private extern flag and relink the bundle. In order to do this a script ~/bin/unhide.sh
is created by the plugin build which should be called as an additional 
"Run Script" build phase to perform this patch and relink. 

### Use with AppCode 

Injection can be used from inside AppCode provided the application has been patched and
you have previously injected that project fro inside Xcode to set up a link to it's 
build logs. To use, copy the jar file “InjectionPluginAppCode/Injection.jar” to
"~/Library/Application Support/AppCode33". You’ll need to re-patch the project
from inside AppCode as it uses a different port number to connect.

### Storyboard injection and "Inject and Reset"

Provided you are running with patched injection and have selected "Inject Strybds" in
the "Product/Injection Plugin/Tunable App Parameters" panel you may be able to inject
storyboards to some extent. It will recompile the storyboard being edited and reload
the current view controller in the application and call the following.

    [vc.view setNeedsLayout];
    [vc.view layoutIfNeeded];

    [vc viewDidLoad];
    [vc viewWillAppear:NO];
    [vc viewDidAppear:NO];

Another more speculative mode that can be used is "Product/Injection Plugin/Inject an Reset".
The intention is that this should return your application to it's main screen and 
executes the following code after injection.

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
        //[app.delegate application:app didFinishLaunchingWithOptions:nil];
        injectAndReset = NO;
    }

### Tunable Parameters

![Icon](http://injectionforxcode.johnholdsworth.com/params2.png)

Tunable parameters can be useful for tuning physics but used to be a good deal easier to use than
now as projects seldom include *-Prefix.pch files as before. To use you need to include the
following code in your class using tunable parameters or your project's bridging header for Swift.

    #ifdef DEBUG
    #define INJECTION_ENABLED

    #import "/tmp/injectionforxcode/BundleInterface.h"
    #endif

This will define two arrays INParameters and INColors which can be "tuned" directly
from inside Xcode using the "Product/Injection Plugin/Tunable App Parameters" panel.
There are delegate methods for when a parameter changes, consult this header file
for details.

### "Nagware" License

This source code is provided on github on the understanding it will not be redistributed.
License is granted to use this software during development for any purpose for two weeks
(it should never be included in a released application!) After two weeks you
will be invited to make a donation $10 (or $25 in a commercial environment)
as suggested by code included in the software.

If you find (m)any issues in the code, get in contact using the email: support (at) injectionforxcode.com

### Please note:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

