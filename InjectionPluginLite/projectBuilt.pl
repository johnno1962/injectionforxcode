#!/usr/bin/perl -w

#  $Id: //depot/InjectionPluginLite/projectBuilt.pl#1 $
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
use IO::Socket::INET;

my $bundle = $ENV{CODESIGNING_FOLDER_PATH};
my $identity = $ENV{CODE_SIGN_IDENTITY}||"";

my $socket = IO::Socket::INET->new( "localhost:31442" );
$socket->print( pack "iia*a*", length $identity, length $bundle, $identity, $bundle );
