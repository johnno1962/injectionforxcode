#!/usr/bin/perl -w

#  $Id: //depot/InjectionPluginLite/patchMain.pl#2 $
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

my @ip4Addresses = grep $_ !~ /:/, split " ", $addresses;

my $mainSource = loadFile( $selectedFile );

if ( !($mainSource =~ s/\n*#ifdef.*\n(.*\n)*?#import.*BundleInjection.h"\n#endif\n/\n/) ) {
    $mainSource .= <<CODE;

#ifdef DEBUG
static char _inMainFilePath[] = __FILE__;
static const char *_inIPAddresses[] = {@{[join ', ', map "\"$_\"", @ip4Addresses]}, NULL};

#define INJECTION_ENABLED
#import "$resources/BundleInjection.h"
#endif
CODE
}

saveFile( $selectedFile, $mainSource );
