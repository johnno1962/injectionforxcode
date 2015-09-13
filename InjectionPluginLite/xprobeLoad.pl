#!/usr/bin/perl -w

#  $Id: //depot/InjectionPluginLite/xprobeLoad.pl#4 $
#  Injection
#
#  Created by John Holdsworth on 16/01/2012.
#  Copyright (c) 2012 John Holdsworth. All rights reserved.
#
#  These files are copyright and may not be re-distributed, whole or in part.
#

use strict;
use FindBin;
use lib $FindBin::Bin;
use common;

my $xprobePath = $selectedFile;
my $bundlePath = ($isIOS ? $isDevice ? "Device" : "Sim" : "OSX")."Bundle.loader";

if ( !$isIOS ) {
    my $newBundle = "$appPackage/$patchNumber$productName.loader";
    system "cp -r '$xprobePath/$bundlePath' '$newBundle'";
    $bundlePath = $newBundle;
}
elsif ( $isDevice ) {
    print "Copying $bundlePath to device..\n";
    $bundlePath = copyToDevice( "$xprobePath/$bundlePath", "$deviceRoot/tmp/$patchNumber$bundlePath" );
}
else {
    $bundlePath = "$xprobePath/$bundlePath";
}

print "Loading Bundle...\n";
print "!$bundlePath\n";
