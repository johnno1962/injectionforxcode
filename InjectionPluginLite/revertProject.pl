#!/usr/bin/perl -w

#  $Id: //depot/injectionforxcode/InjectionPluginLite/revertProject.pl#1 $
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

my $key = "// From here to end of file added by Injection Plugin //";

print "\\b Reverting project contained in: $projRoot\n";

patchAll( "main.(m|mm)", sub {
    $_[0] =~ s/\n+$key.*/\n/s;
} );

patchAll( "refix.pch", sub {
    $_[0] =~ s/\n+$key.*/\n/s;
} );

patchAll( "AppDelegate.(m|mm)", sub {
    $_[0] =~ s@^.*// From start of file to here added by Injection Plugin //\s+@@es and
    $_[0] =~ s/(#ifdef DEBUG\s*\[BundleInjection load\];\s*#endif\n)+//s;
} );
