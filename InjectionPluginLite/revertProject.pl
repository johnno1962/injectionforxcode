#!/usr/bin/perl -w

#  $Id: //depot/InjectionPluginLite/revertProject.pl#1 $
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

print "\\b Reverting project contained in: $projRoot\n";

patchAll( "main.m", sub {
    $_[0] =~ s/\n*#ifdef.*\n(.*\n)*?#import.*BundleInjection.h"\n#endif\n/\n/;
} );

patchAll( "*refix.pch", sub {
    $_[0] =~ s/\n*#ifdef.*\n(.*\n)*?#import.*BundleInterface.h"\n#endif\n/\n/;
} );
