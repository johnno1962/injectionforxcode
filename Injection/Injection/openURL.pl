#!/usr/bin/perl -w

#  openURL.pl
#  Injection
#
#  Created by John Holdsworth on 25/02/2012.
#  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
#
#  These files are copyright and may not be re-distributed, whole or in part.
#

BEGIN { 
    use vars qw($_common_pm);
    $Id = '$Id: //depot/Injection/Injection/openURL.pl#9 $';
    eval "use common;" if !$_common_pm; die $@ if $@;
}

use strict;

my ($file) = @extra;
my ($type, $rest) = $file =~ /^(.)(.*)/;

if ( $type eq "/" ) {
    system "open \"$file\"";
}
elsif ( $type eq '<' ) {
    my $tmpfile = "/tmp/".($file =~ m@/([^/]+)$@)[0];
    print "Uploading to $tmpfile\n";

    print ">$tmpfile\n";
    print "!<$rest\n";

    # ugly wait for file
    sleep 1 while !-f $tmpfile;
    for ( my $i=0 ; $i<10 ; $i++ ) {
        last if !-z $tmpfile;
    }

    system "open \"$tmpfile\"";
}
else {
    if ( $type eq '!' ) {
        unlock( $rest );
        prepareSources( 0, $rest );
    }
    elsif ( $type eq '+' ) {
        prepareSources( 0, $rest );
    }
    elsif ( $type eq '-' ) {
        revert( $rest );
    }
    else {
        error "${RED}Invalid action URL: $file\n";
    }
    print "%".statusTable( "", $rest );
}
