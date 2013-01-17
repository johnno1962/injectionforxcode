Injection for Xcode Source
==========================

Copyright (c) John Holdsworth 2012

Injection is a plugin for Xcode that allows you to "inject" Objective-C code changes into a
running application without having to restart it during development and testing. After making
a couple of minor changes to your application's "main.m" and pre-compilation header it
will connect to a server running inside Xcode during testing to receive commands to
load bundles containing the code changes you make. 

Stop Press: Injection no longer has to convert your classes into categories so no changes are made
to your source code in order for it to work. It works for OS X and iOS projects in the
simulator and on the device (if you add an extra "run script" build phase as instructed.)
The time taken to inject is the amount of time it takes to recompile the class modified.

A quick demonstration video/tutorial of Injection in action is available here:

https://vimeo.com/50137444

Announcements of major commits to the repo will be made on twitter [@Injection4Xcode](https://twitter.com/#!/@Injection4Xcode).

To use injection, open the InjectionPlugin project, build it and restart Xcode.
This should add a submenu and an "Inject Source" item to Xcode's "Product" menu.
Open a simple example project such as UICatalog or GLEssentials from Apple
and use the "Product/<ProjectName>Patch Project for Injection" menu item to 
prepare the project and rebuild it. When you run the project it should connect
to Xcode which will display a red badge showing the application is prepared to 
load patch bundles. Select text in an implementation source file and use menu item
"Product/Inject Source" to inject any changes you may have made into the app.
Be sure to #define DEBUG.

Injection no longer need to patch your class source or headers in any way. Support
for injecting projects using "CocoaPods" which use "workspaces" added since version 2.7.
The plugin assumes the workspace file has the same name as the actual project ".xcodeproj".
Classes in the project or Pods can be injected as well as categories or extensions.
The only limitation now is that the class being injected must not have a +load method.

## License

The source code is provided on the understanding it will not be redistributed in whole
or part for payment and can only be redistributed with it's licensing code left in.
License is hereby granted to evaluate this software for two weeks after which if you
are finding it useful I would prefer you made a payment of $10 (or $25 in a 
commercial environment) as suggested by the licensing code included in the software
in order to continue using it.

The projects in the source tree are related as follows:

__InjectionPluginLite__ is a standalone, complete rewrite of the Injection plugin removing
dead code from the long and winding road injection has taken to get to this point. This
is now the only project you need to build. After building, restart Xcode and check for
the new items at the end of the "Product" menu.

Code for the previous version of the plugin is as follows

__ObjCpp:__ A type of "Foundation++" set of C++ classes I use for operators on common objects.

__Injection:__ The original application which worked alongside Xcode as submitted to Apple

__InjectionPlugin:__ The plugin source packaging the application for use inside Xcode

__InjectionInstallerIII:__ an installer application for the Xcode plugin.


If you find (m)any issues in the code, get in contact using the email: support (at) injectionforxcode.com

## Source Files/Roles:

__InjectionPluginLite/Classes/INPluginMenuController.m__

Responsible for coordinating the injection menu and running up TCP server process on port 31442 receiving
connections from applications with their main.m patched for injection. When an incoming connection
arrives it opens sets the current connection on the associated "client" instance.

__InjectionPluginLite/Classes/INPluginClientController.m__

An singleton instance to shadow a client connection which monitors connection to application
client being injected and runs unix scripts to prepare the project/bundles as part of injection.

## Perl scripts:

__Injection/Injection/patchProject.pl__

Run when a project is first used for injection to patch main.m and any ".pch" files.

__Injection/Injection/openBundle.pl__

Opens the bundle project used by injection to inject code.

__Injection/Injection/injectSource.pl__

The script called when you inject a source file to build the injection bundle project
and signal the client application to load the resulting bundle to apply the code changes.

__Injection/Injection/revertProject.pl__

Un-patches main.m and the project's .pch file when you have finished using injection.

__Injection/Injection/common.pm__

Code shared across the above scripts including the code that patches classes into categories.

## Script output line-prefix conventions from -[InDocument monitorScript]:

__#/__ directory to be monitored for individual file changes (n/a in plugin version)

__#!__ directory to be added to array for FSEvents (n/a for plugin version)

__##__ Start FSEvent stream (n/a "") and use the regexp given for file filter.

__>__ open local file for write

__<__ read from local file (and send to local file or to application)

__!>__ open file on device/simulator for write

__!<__ open file on device/simulator for read (can be directory)

__!/__ load bundle at remote path into client application

__!:__ set local "key file" variable (main.m and .pch locations)

__%!__ evaluate javascript in source status window

__%2__ load line as HTML into source status window

__%1__ append line as HTML to console NSTextView

__?__ display alert to user with message

Otherwise the line is appended as rich text to the console NSTextView.

## Command line arguments to all scripts (in order)

__$resources__ Path to "Resources" directory of plugin for headers etc.

__$workspace__ Path to Xcode workspace document currently open.

__$mainFile__ Path to main.m of application currently connected.

__$executable__ Path to application binary connected to plugin for this project

__$patchNumber__ Incrementing counter for sequentially naming bundles

__$flags__ As defined below...

__$unlockCommand__ Command to be used to make files writable from "app parameters" panel

__$addresses__ IP addresses injection server is running on for connecting from device.

__$selectedFile__ Last source file selected in Xcode editor

## Bitfields of $flags argument passed to scripts

__1<<2__ Suppress application alert on load of changes.

__1<<3__ Activate application/simulator on load.

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

