#!/usr/bin/perl -w

#  openBundle.pl
#  Injection
#
#  Created by John Holdsworth on 20/01/2012.
#  Copyright (c) 2012 John Holdsworth. All rights reserved.
#
#  These files are copyright and may not be re-distributed, whole or in part.
#

BEGIN { 
    use vars qw($_common_pm);
    $Id = '$Id: //depot/Injection/Injection/openBundle.pl#15 $';
    eval "use common;" if !$_common_pm; die $@ if $@;
}

use strict;

setBundleLoader( $executablePath );

system "open \"$InjectionBundle/InjectionBundle.xcodeproj\"";
