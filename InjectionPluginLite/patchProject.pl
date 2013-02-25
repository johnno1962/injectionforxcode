#!/usr/bin/perl -w

#  $Id: //depot/InjectionPluginLite/patchProject.pl#8 $
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

my $key = "// From here to end of file added by Injection Plugin //";
my $ifdef = $projName =~ /UICatalog|(iOS|OSX)GLEssentials/ ?
    "__OBJC__ // would normally be DEBUG" : "DEBUG";


print "\\b Patching project contained in: $projRoot\n";

patchAll( "*refix.pch", sub {
    $_[0] =~ s/\n*($key.*)?$/<<CODE/es;


$key

#ifdef $ifdef
#define INJECTION_ENABLED
#import "$resources/BundleInterface.h"
#endif
CODE
} );


$ifdef .= "\n#define INJECTION_PORT $selectedFile" if $isAppCode;

patchAll( "main.m", sub {
    $_[0] =~ s/\n*($key.*)?$/<<CODE/es;


$key

#ifdef $ifdef
static char _inMainFilePath[] = __FILE__;
static const char *_inIPAddresses[] = {@{[join ', ', map "\"$_\"", @ip4Addresses]}, NULL};

#define INJECTION_ENABLED
#import "$resources/BundleInjection.h"
#endif
CODE
} );

my $dontHideSymbols = "GCC_SYMBOLS_PRIVATE_EXTERN = NO;";
patchAll( "project.pbxproj", sub {
    $_[0] =~ s@(/\* Debug \*/ = \{[^{]*buildSettings = \{(\s*)[^}]*)(};)@$1$dontHideSymbols$2$3@g
        if $_[0] !~ /$dontHideSymbols/;
} );
