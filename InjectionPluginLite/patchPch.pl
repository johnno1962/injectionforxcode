#!/usr/bin/perl -w

#  $Id: //depot/InjectionPluginLite/patchPch.pl#2 $
#  Injection
#
#  Created by John Holdsworth on 15/01/2013.
#  Copyright (c) 2012 John Holdsworth. All rights reserved.
#
#  These files are copyright and may not be re-distributed, whole or in part.
#

use FindBin;
use lib $FindBin::Bin;
use common;
use strict;

my $pchSource = loadFile( $selectedFile );

if ( !($pchSource =~ s/\n*#ifdef.*\n(.*\n)*?#import.*BundleInterface.h"\n#endif\n/\n/) ) {
    $pchSource .= <<CODE;

#ifdef DEBUG
#define INJECTION_ENABLED
#import "$resources/BundleInterface.h"
#endif
CODE
}

saveFile( $selectedFile, $pchSource );
