# ![Icon](http://injectionforxcode.johnholdsworth.com/injection.png) Injection for Xcode Source

Copyright (c) John Holdsworth 2012-15

Injection is a plugin for Xcode that allows you to "inject" Objective-C and Swift code changes
into a running application without having to restart it during development and testing. 
Injection no longer requires you to patch your project or it's sources for
iOS projects in the simulator. To use: download this project, build it and restart Xcode.
When your application is running type control-= and any modifications to the selected
class should be applied to your application while it runs. That's it.

After making a couple of minor changes to your application's "main.m" and pre-compilation header
known as "patched" injection you can also inject to an iOS device over WiFi. To do this,
select "Product/Injection Plugin/Patch Project for Injection". You may want to do this
anyway so injection starts more quickly. To patch a Swift project you need to add an
empty main.m to your project. If you don't like control-= as a shortcut it is a
preference in the "Tunable App Parameters Panel".

When classes are injected they receive a +injected message and instances will receive
a -injected message so you can reload view controllers for example. This is achieved
using a sweep of objects visible from [UIApplication sharedApplication] and it's windows.
If required, for all classes that have a +sharedInstance method in your app or frameworks,
this method is called and the result added to the list of seeds for the sweep.

The plugin is now integrated with the [XprobePlugin](https://github.com/johnno1962/Xprobe).
Once installed, use the Product/Xprobe/Load menu item to inspect the objects in your application
and search for the object you wish to execute code against and click it's link to
inspect/select it. You can then open an editor which allows you to execute
Objective-C or Swift code against the object (implemented as a catgeory/extension.)
Use Xlog/xprintln to log output back to the Xprobe window.

The InjectionPluginAppCode project has also been updated for 3.1 so you can now inject Swift from
AppCode if you patch your project from inside AppCode.

![Icon](http://injectionforxcode.johnholdsworth.com/overview.png)

The "unpatched" auto-loading version of Injection now includes "Xtrace" which will allow
you to log all messages sent to a class or instance using the following commands:

    (lldb) p [UITableView xtrace] // trace all table view instances
    or
    (lldb) p [tableView xtrace] // trace a particular instance only
    
A quick demonstration video/tutorial of Injection in action is available here:

https://vimeo.com/50137444

Announcements of major commits to the repo will be made on twitter [@Injection4Xcode](https://twitter.com/#!/@Injection4Xcode).

To use Injection, open the InjectionPluginLite project, build it and restart Xcode.
Injection is also available in the [Alcatraz](http://alcatraz.io/) meta plugin.
This should add a submenu and an "Inject Source" item to Xcode's "Product" menu.
If at first it doesn't appear, try restarting Xcode again.

In the simulator, Injection can be used "unpatched", loading a bundle on demand
to provide support for injection. You should be able to type control-= at any time you
are editing a method implementation to have the changes updated in your application.

If you want to use injection from a device you will need to patch your project using
the  "Product/Injection Plugin/Patch Project for Injection" menu item to pre-prepare 
the project then rebuild it. This will connect immediately to Xcode when you run your
app showing a red badge on Xcode's dock icon. You may want to do this for the simulator 
as well as it is faster.

On OS X remember to have your entitlements include "Allow outgoing connections". If
you have problems with injection you can remove the plugin my typing:

    rm -rf ~/Library/Application\ Support/Developer/Shared/Xcode/Plug-ins/InjectionPlugin.xcplugin

### Storyboard Injection currently working

When editing the storyboard of the currently displayed view controller you can
inject it to experiment with colors and layout and it will reload with the following
methods being called:

```objc
    [vc.view setNeedsLayout];
    [vc.view layoutIfNeeded];

    [vc viewDidLoad];
    [vc viewWillAppear:NO];
    [vc viewDidAppear:NO];
```

This works on a device and you need to have selected "Inject Strybds" in the
"Tunable App Parameters" panel before running the application. Unfortunately,
segues are not preserved and are not reliable after injection.

### "Inject and Reset"

It may be useful to inject code and reset your application to it's initial
interface without the delay of a relaunch by using the new "control-shift-=".
This executes the following code which attempts to reset the app storyboard:

```objc
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
```

### Injecting classes using "internal" scope inside Swift

With Xcode 6.3.1/Swift 1.2 injection has become a little more difficult as "internal"
symbols that may be required for the injecting class to link against are now
given visibility "hidden" which makes them unavailable resulting in crashes
if you refer to functions or variables outside classes that are not public.
This can be resolved by adding a "Run Script" build phase to your framework 
or main app target to call the following command.

    ~/bin/unhide.sh

This should patch the object files in the framework to export any hidden symbols
and relinks the executable making all swift symbols available to the dynamic
link loader facilitating their injection.

### JetBrains AppCode IDE Support

The InjectionPluginAppCode project provides basic support for code injection in the
AppCode IDE. To use, install the file Injection.jar into directory
"~/Library/Application Support/appCode10". The new menu options should appear at the end 
of the "Run" menu when you restart AppCode. For it to work you must also have the most 
recent version of the Xcode plugin installed as they share some of the same scripts. 

As the AppCode plugin runs on a different port you need to unpatch and then repatch
your project for injection each time you switch IDE or edit "main.m". Also, for some 
reason there is  a very long delay when the client first connects to the plugin. 
This seems to be Java specific. If anyone has any ideas how to fix this, get in touch!

All the code to perform injection direct to a device is included but this is always
a "challenge" to get going. It requires an extra build phase to run a script and
the client app has to find it's way over Wi-Fi to connect back to the plugin.
Start small by injecting to the simulator then injecting to a device using the Xcode 
plugin. Then try injecting to the device from AppCode after re-patching the project.

### "Nagware" License

This source code is provided on github on the understanding it will not be redistributed.
License is granted to use this software during development for any purpose for two weeks
(it should never be included in a released application!) After two weeks you
will be invited to make a donation $10 (or $25 in a commercial environment)
as suggested by code included in the software.

If you find (m)any issues in the code, get in contact using the email: support (at) injectionforxcode.com

### How it works

A project patched for injection #imports the file "BundleInjection.h" from the resources of the 
plugin into it's "main.m" source file. Code in this header uses a +load method to connect back
through a socket to a server running inside Xcode and waits in a thread for commands to load bundles.

When you inject a source, it is #imported into "BundleContents.m" in a bundle project which is then built
and the application messaged by Xcode through the socket connection to load the bundle. When the bundle
loads, it too has a +load method which calls the method [BundleInjection loadClass:theNewClass notify:flags].
This method aligns the instance variables of the newly loaded class to the original (as @properties can be reordered) 
and then swizzles the new implementations onto the original class.

Support for injecting projects using "CocoaPods" and "workspaces" has been added since version 2.7.
Classes in the project or Pods can be injected as well as categories or extensions.
The only limitation is that the class being injected must not itself have a +load method.
Other options are on the "Project..Tunable Parameters" page such as the "Silent" option for
turning off the message dialogue each time classes are injected.

![Icon](http://injectionforxcode.johnholdsworth.com/params2.png)

With patched injection, the global variables INParameters and INColors are exposed to all
classes in the project through it's .pch file. These variables are linked in real time to
the sliders and colour wells on the Tunable Parameters panel once the application has started.
These can be used for micro-tuning your application or it's appearance.

The projects in the source tree are related as follows:

__InjectionPluginLite__ is a standalone, complete rewrite of the Injection plugin removing
dead code from the long and winding road injection has taken to get to this point. This
is now the only project you need to build. After building, restart Xcode and check for
the new items at the end of the "Product" menu.

__InjectionPluginAppCode__ Java plugin for JetBrains AppCode IDE support.

I've removed the InjectionInstallerIII project as it needs you to have built the plugin anyway
which will have already put it in the right place to load when you restart Xcode.

### Source Files/Roles:

__InjectionPluginLite/Classes/INPluginMenuController.m__

Responsible for coordinating the injection menu and running up TCP server process on port 31442 receiving
connections from applications with their main.m patched for injection. When an incoming connection
arrives it sets the current connection on the associated "client" controller instance.

__InjectionPluginLite/Classes/INPluginClientController.m__

A (currently) singleton instance to shadow a client connection from an application. It runs unix scripts to
prepare the project and bundles used as part of injection and monitors for successful loading of the bundle.

### Perl scripts:

__InjectionPluginLite/patchProject.pl__

Patches all main.m and ".pch" files to include headers for use with injection.

__InjectionPluginLite/injectSource.pl__

The script called when you inject a source file to create/build the injection bundle project
and signal the client application to load the resulting bundle to apply the code changes.

__InjectionPluginLite/evalCode.pl__

Support for XprobePlugin's "eval code" function.

__InjectionPluginLite/openBundle.pl__

Opens the Xcode project used by injection to build a loadable bundle to track down build problems.

__InjectionPluginLite/revertProject.pl__

Un-patches main.m and the project's .pch file when you have finished using injection.

__InjectionPluginLite/common.pm__

Code shared across the above scripts including the code that patches classes into categories.

Otherwise the line is appended as rich text to the console NSTextView.

### Command line arguments to all scripts (in order)

__$resources__ Path to "Resources" directory of plugin for headers etc.

__$workspace__ Path to Xcode workspace document currently open.

__$mainFile__ Path to main.m of application currently connected.

__$executable__ Path to application binary connected to plugin for this project

__$arch__ Architecture of application connected to Xcode

__$patchNumber__ Incrementing counter for sequentially naming bundles

__$flags__ As defined below...

__$unlockCommand__ Command to be used to make files writable from "app parameters" panel

__$addresses__ IP addresses injection server is running on for connecting from device.

__$xcoodeApp__ Path to Xcode application being used.

__$buildRoot__ build directory for the project being injected.

__$logDir__ more reliable path to project's build logs.

__$selectedFile__ Last source file selected in Xcode editor

### Bitfields of $flags argument passed to scripts

__1<<1__ Storyboard injection is selected.

__1<<2__ Display UIAlert on load of changes (disabled with the "Silent" tunable parameter)

__1<<3__ Activate application/simulator on load.

__1<<4__ Plugin is running in AppCode.

### Script output line-prefix conventions from -[INPluginClientController monitorScript]:

__>__ open local file for write

__<__ read from local file (and send to local file or to application)

__!>__ open file on device/simulator for write

__!<__ open file on device/simulator for read (can be directory)

__!/__ load bundle at remote path into client application

__?__ display alert to user with message

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

