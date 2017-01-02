#!/usr/bin/perl -w

#  $Id: //depot/injectionforxcode/InjectionPluginLite/patchProject.pl#2 $
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
shift @ip4Addresses; # bonjour address seems unreliable

my %ipPrecedence = (
    10 => 2,
    192 => 1,
    169 => -1,
    172 => -2,
    127 => -9,
);

sub prec {
    my ($network) = $_[0] =~ /^(\d+)\./;
    return $ipPrecedence{$network} || 0;
}

@ip4Addresses = sort { prec($b) <=> prec($a) } @ip4Addresses;

my $key = "// From here to end of file added by Injection Plugin //";
my $ifdef = $projName =~ /UICatalog|(iOS|OSX)GLEssentials/ ?
    "__OBJC__ // would normally be DEBUG" : "DEBUG";


print "\\b Patching project contained in: $projRoot\n";

###################################################################################################
# patch project .pch files (if not using AppCode)
#if ( !$isAppCode ) {
#    patchAll( "refix.pch|Bridging-Header-Not.h", sub {
#    $_[0] =~ s/\n*($key.*)?$/<<CODE/es;
#
#
#$key
#
##ifdef $ifdef
##define INJECTION_ENABLED
#
##import "$resources/BundleInterface.h"
##endif
#CODE
#    } );
#}

$ifdef .= "\n#define INJECTION_PORT $selectedFile" if $isAppCode || $selectedFile;

###################################################################################################
# patch normal Xcode projects
if ( !-d "$projRoot$projName.approj" ) {
    patchAll( "\./main.(m|mm)", sub {
        $_[0] =~ s/\n*($key.*)?$/<<CODE/es;


$key

#ifdef $ifdef
static char _inMainFilePath[] = __FILE__;
static const char *_inIPAddresses[] = {@{[join ', ', map "\"$_\"", @ip4Addresses]}, 0};

#define INJECTION_ENABLED
#import "$resources/BundleInjection.h"
#endif
CODE
    } ) or error "Could not locate project's main.(m|mm) to patch.\nTo patch a Swift project please create an empty main.m";
}

###################################################################################################
# patch projects using apportable
else {
    patchAll( "main.(m|mm)", sub {
        $_[0] =~ s/\n+$key.*/\n/s;
    } );

    patchAll( "AppDelegate.(m|mm)", sub {
        $_[0] =~ s/^/<<CODE/es and

#define DEBUG 1 // for Apportable
#ifdef $ifdef
static char _inMainFilePath[] = __FILE__;
static const char *_inIPAddresses[] = {@{[join ', ', map "\"$_\"", @ip4Addresses]}, 0};

#define INJECTION_ENABLED
#import "$resources/BundleInjection.h"
#endif

// From start of file to here added by Injection Plugin //

CODE
    $_[0] =~ s/(didFinishLaunching.*?{[^\n]*\n)/<<CODE/sie;
$1#ifdef DEBUG
    [BundleInjection load];
#endif
CODE
    } );
}

###################################################################################################
# ensure symbols exported
#my $dontHideSymbols = "GCC_SYMBOLS_PRIVATE_EXTERN = NO;";
#patchAll( "project.pbxproj", sub {
#    $_[0] =~ s@(/\* Debug \*/ = \{[^{]*buildSettings = \{(\s*)[^}]*)(};)@$1$dontHideSymbols$2$3@g
#        if $_[0] !~ /$dontHideSymbols/;
#} );
