#!/usr/bin/perl -w 

#  openShadow.pl
#  InjectionPlugin
#
#  Created by John Holdsworth on 23/09/2012.
#

BEGIN {
    use vars qw($_common_pm);
    $Id = '$Id: //depot/Injection/Injection/openBundle.pl#14 $';
    eval "use common;" if !$_common_pm; die $@ if $@;
}

use strict;

my ($sourcePath) = @extra;
my ($fileName) = $sourcePath =~ m@([^/]+$)@;
my $shadowFile = "$InjectionBundle/InjectionBundle/Tmp$fileName";

print "Displaying: $shadowFile\n";
system "open \"$shadowFile\"";
