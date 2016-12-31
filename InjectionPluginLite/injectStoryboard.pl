#!/usr/bin/perl -w

#  $Id: //depot/injectionforxcode/InjectionPluginLite/injectStoryboard.pl#1 $
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

my $appBundle = $selectedFile;

if ( $isDevice ) {
    $appBundle = copyToDevice( $appBundle, "$deviceRoot/tmp/Storyboard.bundle", "\\.nib\$" );
}

print "Injecting nibs in bundle: $appBundle\n";
print "!\@$appBundle\n";
