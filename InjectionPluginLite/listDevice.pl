#!/usr/bin/perl -w

#  listDevice.pl
#  Injection
#
#  Created by John Holdsworth on 22/01/2012.
#  Copyright (c) 2012 John Holdsworth. All rights reserved.
#
#  These files are copyright and may not be re-distributed, whole or in part.
#

use strict;
use FindBin;
use lib $FindBin::Bin;
use common;

my $lstmp = "/tmp/listing_$ENV{USER}.txt";
my $html = "<table style='font: 10pt Courier' border=1 cellspacing=0><tr><tr bgcolor='#d0d0d0'><th>Size<th>Mode<th>Path";

die "No device root" if !$deviceRoot;
unlink $lstmp;

print "Listing: $deviceRoot\n";
print ">$lstmp\n";
print "!<$deviceRoot\n";

sleep 1 while !-f $lstmp || -z $lstmp;

foreach my $line ( split "\n", loadFile( $lstmp ) ) {
    my ($size, $mode, $file) = split "\t", $line;
    $file =~ s@(.)\.$@$1@ if ($mode & 0170000) == 0040000;
    my $type = "";
    $type = "@" if ($mode & 0170000) == 0120000;
    
    my ($dir,$name) = $file =~ m@^(.*/|)([^/]+)$@;
    
    $html .= sprintf "<tr><td align=right nowrap>%7d<td align=right nowrap>%6o<td>%s", $size, $mode,
        !$name ? $file :
        "$dir<a href='urlPrefix&lt;$deviceRoot/$dir/$name'>$name$type</a>";
}

print "%$html</table>\n";
unlink $lstmp;
