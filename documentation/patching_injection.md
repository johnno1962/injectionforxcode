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
