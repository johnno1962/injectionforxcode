Injection for Xcode Source
==========================

The source code is provided on the understanding it will not be redistributed in whole
or part for payment and can only be redistributed with the licensing code left in.
License is hereby granted to use this software for two weeks I would prefer that
you made a payment of $10 (or $25 dollars in a commercial environment) as suggested
by the licensing code included in the software in order to continue using it.

To use injection open the InjectionPlugin project, build it and restart Xcode.
Open a simple example project such as UICatalogue or GLEssentials from Apple
and use the "Product/<ProjectName>Patch Project for Injection" menu item to 
prepare the project and rebuild it. When you run the project it should connect
to Xcode which will display a red badge showing the application is prepared
to load patch bundles. Select an implementation source file and use menu item
"Product/Inject Source" to inject any changes you may have made into the app.

The three projects in the source tree are related as follows:

ObjCpp: A type of Foundation++ set of C++ classes prviding operatiors on foundation objects/

Injection: The original application which worked alongside Xcode as submitted to Apple

InjectionPlugin: The Xcode plugin source packaging the application for use inside Xcode

InjectionInstallerIII: an installer application for the Xcode plugin.

If you find (m)any issues in the code get in contact using the email injection@johnholdsworth.com