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

The four projects in the source tree are related as follows:

__ObjCpp:__ A type of "Foundation++" set of C++ classes I use for operators on common objects.

__Injection:__ The original application which worked alongside Xcode as submitted to Apple

__InjectionPlugin:__ The plugin source packaging the application for use inside Xcode __**__

__InjectionInstallerIII:__ an installer application for the Xcode plugin.

__**__ "InjectionPlugin" is the only project you actually need to build to use injection.
The build will try to codesign the plugin. If you don't have a developer id, clear the
"Code Signing Identity" in the build settings and check that it still works.

If you find (m)any issues in the code, get in contact using the email: support (at) injectionforxcode.com

__InjectionPluginLite__ is a beta of a complete standalone rewrite of the Injection plugin removing
all dead code from the long and winding road injection has taken to get to this point. This version
works slightly differently automating less to support a wider range of workspaces.
To use, select the project's main.m and select "Injection/Patch Project main.m" from
the product menu. To use tunable parameters, select the projects .pch file and
select "Injection/Patch project .pch" to make the interface to injection
available to all sources. This version knows nothing about project files and
does not automatically propagate parameters into injection's bundle project
so you may need to check things such as include path and compiler/ARC.  

## Source Files/Roles:

__InjectionPlugin/Classes/InInjectionPlugin.m__

Singleton subclass of original InAppDelegate class responding to Xcode Menu events.
Superclass responsible for running up TCP server process on port 31442 receiving connections
from applications with their main.m patched for injection. When an incoming connection
arrives it opens an instance of InPluginDocument associated with the project of the 
application.

__InjectionPlugin/Classes/InPluginDocument.m__

An instance is created of this INDocument(NSDocument) subclass to shadow each project being
injected. Superclass runs a series of Perl scripts in response to menu events to patch
projects or code for injection and load the resulting bundles.

__Injection/Injection/InAppDelegate.m__

The original standalone application delegate running the injection service and managing
licensing.

__Injection/Injection/InDirectory.m__

A utility class for OS X 10.6 where FS events can not be selected down to the file level.

__Injection/Injection/InDocument.m__

The subclass responsible for running the scripts used by injection to patch projects 
and classes and parsing their output for actions to perform.

__Injection/Injection/InImageView.m__

NSImageView subclass that knows the path of the file dragged onto it.

__Injection/Injection/validatereceipt.m__

copy protection formerly used for App Store

## Perl scripts:

__Injection/Injection/listDevice.pl__

Lists the files in the sandbox on an iOS device.

__Injection/Injection/openBundle.pl__

Opens the bundle project containing the class categories used for injection.

__Injection/Injection/openProject.pl__

Run when a project is first used for injection to patch main.m and the ".pch" file

__Injection/Injection/openURL.pl__

Opens special URLs used by injection to patch/un-patch specific files.

__Injection/Injection/prepareBundle.pl__

The script called when you inject a source file to patch the source class into a category,
build the injection bundle project and signal the client application to load the resulting
bundle to apply the code changes.

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

__$injectionResources__ Path to "Resources" directory of plugin for headers etc.

__$appVersion__ Injection application version (currently "2.6")

__$urlPrefix__ Prefix for URLs in links in the console view ("file://" for plugin)

__$appRoot__ Path to "Resources" directory of plugin again

__$projectFile__ Path to "<ProjectName>.xcodeproj" for current project document

__$executablePath__ Path to application binary connected to plugin for this project

__$patchNumber__ Incrementing counter for sequentially naming bundles

__$unlockCommand__ Command to be used to make files writable from "app parameters" panel

__$flags__ As defined below...

__$spare1, $spare2, $spare3, $spare4__ reserved for future use..

__@extra__ Arguments to script for example: file(s) to inject

## Bitfields of $flags argument passed to scripts

__1<<0__ Project is a "demo" application i.e. /UICatalog|(iOS|OSX)GLEssentials/

__1<<1__ Pre-convert headers of all writable class implementations.

__1<<2__ Suppress application alert on load of changes.

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

