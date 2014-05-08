# ![Icon](http://injectionforxcode.johnholdsworth.com/injection.png) Injection for Xcode Source

Copyright (c) John Holdsworth 2012

Now in the Mac AppStore: [https://itunes.apple.com/app/objective-c++/id551718707?ls=1&mt=12](https://itunes.apple.com/app/objective-c++/id551718707?ls=1&mt=12)

Injection is a plugin for Xcode that allows you to "inject" Objective-C code changes into a
running application without having to restart it during development and testing. After making
a couple of minor changes to your application's "main.m" and pre-compilation header it
will connect to a server running inside Xcode during testing to receive commands to
load bundles containing the code changes. 

Stop Press: Injection no longer needs to patch your project to operate and is
ready to use on any project at any time. To do this it inserts commands into
your lldb console to load a small bootstrap bundle into your app then works 
as before. You might still want to patch your project if you want to
avoid this slight delay, use with AppCode or Apportable or inject code
onto an iOS device.

![Icon](http://injectionforxcode.johnholdsworth.com/overview.png)

The "unpatched" version of Injection now includes "Xtrace" which will allow
you to log all messages sent to a class or instance using the following commands:

    (lldb) p [UITableView xtrace] // trace all table view instances
    or
    (lldb) p [tableView xtrace] // trace a particular instance only
    
A quick demonstration video/tutorial of Injection in action is available here:

https://vimeo.com/50137444

Announcements of major commits to the repo will be made on twitter [@Injection4Xcode](https://twitter.com/#!/@Injection4Xcode).

To use Injection, open the InjectionPluginLite project, build it and restart Xcode.
You must build the "InjectionPlugin" target selecting to build for the simulator.
Alternatively, you can download a small installer app "Injection Plugin.app" from 
[http://injectionforxcode.com](http://injectionforxcode.com) and use the menu item 
"File/Install Plugin" then restart Xcode (This also installs the AppCode plugin.)
This should add a submenu and an "Inject Source" item to Xcode's "Product" menu.
If at first it doesn't appear, try restarting Xcode again.

Open a simple example project such as UICatalog or GLEssentials from Apple. At this
point you can use the  "Product/Injection Plugin/Patch Project for Injection" menu item
to pre-prepare the project then rebuild it. If you have patched the project it should connect
to Xcode which will display a red badge on it's dock icon showing the application is
prepared to load patch bundles. Otherwise, select text in a class source file and use
menu item "Product/Inject Source" to inject any changes you have made into the app
and it will connect to Xcode and load your changes.

On OS X remember to have your entitlements include "Allow outgoing connections". 

### Using Injection with Xcode 4/5 

The same plugin build can be used safely on Xcode 4 or 5. Xcode 5.1 however, no longer
supports building for garbage collection which is required by Xcode 4. So, if you still
need to use it with Xcode 4 you will need to use Xcode versions up to 5.0.2 to build it
and change the change the GC_ENABLE_OBJC_GC to "supported". For Xcode 5.0+ you can simply
build off github.

If you see the following message when you restart Xcode5, use "Activity Monitor" to
kill off any "ibtoold" daemon processes running that Xcode5 forks off and then restart. 

![Icon](http://injectionforxcode.johnholdsworth.com/socket.png)

If you are using Injection to develop an OS X application you may need a "Run Script, 
Build Phase" of  "rm -rf $CODESIGNING_FOLDER_PATH/Contents/MacOS/InjectionBundle*".

## JetBrains AppCode IDE Support

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

## Using with [Apportable](http://www.apportable.com) 

Injection can work on Android if you follow these steps: Convert your application
by using "apportable load" from the command line inside your project. Unpatch and re-patch
your project for injection as a different patch is applied when there is a ".approj" and 
then run "apportable load" again and it should connect to Xcode. You should then
be able to inject from the Xcode menu as before.

## Storyboard Injection

Injection will now inject UIViewController layouts in a storyboarded application. To do this
you need to select the "Inject Storybds" option in the Tunable Parameters and add the 
following as a "Build Phase" of type "Run Script" to your project (quotes included.)

<pre>
"$HOME/Library/Application Support/Developer/Shared/Xcode/Plug-ins/InjectionPlugin.xcplugin/Contents/Resources/projectBuilt.pl"
</pre>

When you next run the application, if you edit the storyboard and build the project, layout changes will be
injected onto the UIViewControllers currently visible while the application is still running. This is 
achieved by reloading their "nib" onto the existing view controller and sending -viewDidLoad, 
-viewWillAppear:YES and -viewDidAppear:YES to the view controller for it to redraw.
This only works for applications with a single active Storyboard. See class method
+reloadNibs in the file "BundleInjection.h". Storyboard Injection no longer works in Xcode 5.

## Shareware License

This source code is provided on github on the understanding it will not be redistributed.
License is granted to use this software during development for any purpose indefinitely
(it should never be included in a released application!) After two weeks you
will be prompted to register and have the opportunity to make a donation $10
(or $25 in a commercial environment) as suggested by code included in the software.

If you find (m)any issues in the code, get in contact using the email: support (at) injectionforxcode.com

## How it works

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

The projects in the source tree are related as follows:

__InjectionPluginLite__ is a standalone, complete rewrite of the Injection plugin removing
dead code from the long and winding road injection has taken to get to this point. This
is now the only project you need to build. After building, restart Xcode and check for
the new items at the end of the "Product" menu.

__InjectionPluginAppCode__ Java plugin for JetBrains AppCode IDE support.

I've removed the InjectionInstallerIII project as it needs you to have built the plugin anyway
which will have already put it in the right place to load when you restart Xcode.

## Source Files/Roles:

__InjectionPluginLite/Classes/INPluginMenuController.m__

Responsible for coordinating the injection menu and running up TCP server process on port 31442 receiving
connections from applications with their main.m patched for injection. When an incoming connection
arrives it sets the current connection on the associated "client" controller instance.

__InjectionPluginLite/Classes/INPluginClientController.m__

A (currently) singleton instance to shadow a client connection from an application. It runs unix scripts to
prepare the project and bundles used as part of injection and monitors for successful loading of the bundle.

## Perl scripts:

__InjectionPluginLite/patchProject.pl__

Patches all main.m and ".pch" files to include headers for use with injection.

__InjectionPluginLite/injectSource.pl__

The script called when you inject a source file to create/build the injection bundle project
and signal the client application to load the resulting bundle to apply the code changes.

__InjectionPluginLite/openBundle.pl__

Opens the Xcode project used by injection to build a loadable bundle to track down build problems.

__InjectionPluginLite/revertProject.pl__

Un-patches main.m and the project's .pch file when you have finished using injection.

__InjectionPluginLite/common.pm__

Code shared across the above scripts including the code that patches classes into categories.

## Script output line-prefix conventions from -[INPluginClientController monitorScript]:

__>__ open local file for write

__<__ read from local file (and send to local file or to application)

__!>__ open file on device/simulator for write

__!<__ open file on device/simulator for read (can be directory)

__!/__ load bundle at remote path into client application

__?__ display alert to user with message

Otherwise the line is appended as rich text to the console NSTextView.

## Command line arguments to all scripts (in order)

__$resources__ Path to "Resources" directory of plugin for headers etc.

__$workspace__ Path to Xcode workspace document currently open.

__$mainFile__ Path to main.m of application currently connected.

__$executable__ Path to application binary connected to plugin for this project

__$arch__ Architecture of application connected to Xcode

__$patchNumber__ Incrementing counter for sequentially naming bundles

__$flags__ As defined below...

__$unlockCommand__ Command to be used to make files writable from "app parameters" panel

__$addresses__ IP addresses injection server is running on for connecting from device.

__$selectedFile__ Last source file selected in Xcode editor

## Bitfields of $flags argument passed to scripts

__1<<2__ Display UIAlert on load of changes (disabled with the "Silent" tunable parameter)

__1<<3__ Activate application/simulator on load.

__1<<4__ Plugin is running in AppCode.

## Please note:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

