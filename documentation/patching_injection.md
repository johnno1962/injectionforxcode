### Patched injection

If you are working on a device or using AppCode you need to patch your project slightly
to use injection. 

This adds a small stub of code to your application's `main.m` that bootstraps
the injection process connecting back to Xcode using the address patched into the `main.m` file.

The code looks like:

```objc
#ifdef DEBUG
static char _inMainFilePath[] = __FILE__;
static const char *_inIPAddresses[] = {"10.12.1.67", "127.0.0.1", 0};

#define INJECTION_ENABLED
#import "/tmp/injectionforxcode/BundleInjection.h"
#endif
```

This patch can be applied automatically using the "Product/Injection Plugin/Patch Project for Injection"
menu item. For a Swift project you'll need to add an empty main.m so it can be patched. Once
your application is running and connected to the plugin - it should be able to inject as before.

There are limitations of course, largely centering around static variables and static or global
functions and their Swift equivalents. Consider the following Objective-C code.

![Icon](http://injectionforxcode.johnholdsworth.com/injection1.png)

One potential problem is that when the new version of the class is loaded it comes with it's own
versions of static variables such as "sharedInstance" and "once" and after injection has occurred 
would generate a new singleton instance. To prevent this, class methods that have the prefix
"shared" are not swizzled on injection to support this common idiom.

When a class has been injected it calls the class method `+ (void)injected` as well as the
instance level `- (void)injected` method on all instances of the class being injected. 

The  later case is more difficult to realise as it requires a list of instances for a particular
class. In order to determine this injection performs a "sweep" or all instances of the app
and instances those instances point to etc which is then filtered by the injecting class.

This process is seeded using the application delegate and all windows. This list is
supplemented by the values returned by method "sharedInstance" of all application classes
if required.

The function `dispatch_on_main` does of course not inject as it has been statically linked into
the application. It does however inject by proxy in the case shown in the "doSomething"
method as it will have been linked locally to version in the object file being injected.
