#!/usr/bin/perl -w

#  $Id: //depot/InjectionPluginLite/patchProject.pl#2 $
#  Injection
#
#  Created by John Holdsworth on 15/01/2013.
#  Copyright (c) 2012 John Holdsworth. All rights reserved.
#
#  These files are copyright and may not be re-distributed, whole or in part.
#

use strict;
use FindBin;
use lib $FindBin::Bin;
use common;

my @ip4Addresses = grep $_ !~ /:/, split " ", $addresses;

my $key = "// From here to end of fille added by Injection Plugin //";

print "\\b Patching project contained in: $projRoot\n";

patchAll( "main.m", sub {
    $_[0] =~ s/\n+$key.*|$/<<CODE/es;

    
$key

#ifdef DEBUG
static char _inMainFilePath[] = __FILE__;
static const char *_inIPAddresses[] = {@{[join ', ', map "\"$_\"", @ip4Addresses]}, NULL};

#define INJECTION_ENABLED
#import "$resources/BundleInjection.h"
#endif
CODE
} );

patchAll( "*refix.pch", sub {
    $_[0] =~ s/\n+$key.*|$/<<CODE/es;


$key

#ifdef DEBUG
#define INJECTION_ENABLED
#import "$resources/BundleInterface.h"
#endif
CODE
} );

my $dontHideSymbols = "GCC_SYMBOLS_PRIVATE_EXTERN = NO;";
patchAll( "project.pbxproj", sub {
    $_[0] =~ s@(/\* Debug \*/ = \{[^{]*buildSettings = \{(\s*)[^}]*)(};)@$1$dontHideSymbols$2$3@g
        if $_[0] !~ /$dontHideSymbols/;
} );