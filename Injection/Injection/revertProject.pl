#!/usr/bin/perl -w

#  revertProject.pl
#  Injection
#
#  Created by John Holdsworth on 16/01/2012.
#  Copyright (c) 2012 John Holdsworth. All rights reserved.
#
#  These files are copyright and may not be re-distributed, whole or in part.
#

BEGIN { 
    use vars qw($_common_pm);
    $Id = '$Id: //depot/Injection/Injection/revertProject.pl#19 $';
    eval "use common;" if !$_common_pm; die $@ if $@;
}

use strict;

my ($projectMain) = findOldest( "main.m" );
my $mainSource = loadFile( $projectMain );

print "Unpatching main.m to load bundles.\n";
$mainSource =~ s/\s*#ifdef INJECTION_ENABLED.*?#endif\n//s;
saveFile( $projectMain, $mainSource );

print "Unpatching PCHs.\n";
foreach my $pch ( excludeInjectionBundle( findOldest( ".pch", $type ) ) ) {
    my $PCH = loadFile( $pch );
    $PCH =~ s@\n// \Q**IMPORTANT**\E.*?#import[^\n]+\n@@s;
    saveFile( $pch, $PCH );
}

my @sources = excludeInjectionBundle( findOldest( '*.mm?' ) );

# revert all obj-c sources
foreach my $sourcePath ( grep $_ =~ /\.mm?$/, @sources ) {
    revert( $sourcePath );
}

exit 0;