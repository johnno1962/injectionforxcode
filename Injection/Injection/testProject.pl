#!/usr/bin/perl -w

#  testProject.pl
#  Injection
#
#  Created by John Holdsworth on 20/05/2012.
#  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
#
#  These files are copyright and may not be re-distributed, whole or in part.
#

BEGIN { 
    use vars qw($_common_pm);
    $Id = '$Id$';
    eval "use common;" if !$_common_pm; die $@ if $@;
}

use strict;

print "Testing Testing...\n";

my @sources = excludeInjectionBundle( findOldest( '*.mm?' ) );
my ($failed, $tested) = (0);

foreach my $sourcePath ( grep $_ =~ /\.mm?$/ && -w $_, @sources ) {
    my $args = join ' ', map "'$_'", @ARGV, $sourcePath;

    my $err = system "'$injectionResources/runner' '$injectionResources/injection.dat' \"$args 2>&1\" 'prepareBundle.pl'";

    $failed++ if $err;
    $tested++;    
    
    print "$failed/$tested - $sourcePath\n";
    
    $ARGV[6]++;
    sleep( $err ? 10 : 1);
}

print "Tests complete.\n";


exit 0;