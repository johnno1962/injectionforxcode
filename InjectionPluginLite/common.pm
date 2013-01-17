#
#  $Id: //depot/InjectionPluginLite/common.pm#4 $
#  Injection
#
#  Created by John Holdsworth on 16/01/2012.
#  Copyright (c) 2012 John Holdsworth. All rights reserved.
#
#  These files are copyright and may not be re-distributed, whole or in part.
#

use IO::File;
use strict;
use Carp;

use vars qw($resources $workspace $mainFile $executable $patchNumber $flags
    $unlockCommand $addresses $selectedFile $isDevice $isSimulator $isIOS
    $productName $appPackage $deviceRoot $projFile $projRoot $projType
    $InjectionBundle $template $header $appClass $appPackage $RED);

($resources, $workspace, $mainFile, $executable, $patchNumber, $flags, $unlockCommand, $addresses, $selectedFile) = @ARGV;

($projFile, $projRoot, $projType) = $workspace =~ m@^((.*?)/[^/]+\.(xcodeproj|xcworkspace))@;

($appPackage, $deviceRoot) = $executable =~ m@((^.*)/[^/]+)/[^/]+$@;

$productName = "InjectionBundle$patchNumber";

$isDevice = $executable =~ m@^/var/mobile/@;
$isSimulator = $executable =~ m@/iPhone Simulator/@;
$isIOS = $isDevice || $isSimulator;

($template, $header, $appClass) = $isIOS ?
    ("iOSBundleTemplate", "UIKit/UIKit.h", "UIApplication") :
    ("OSXBundleTemplate", "Cocoa/Cocoa.h", "NSApplication");

($InjectionBundle = $template) =~ s/BundleTemplate/InjectionProject/;

BEGIN { $RED = "{\\colortbl;\\red0\\green0\\blue0;\\red255\\green100\\blue100;}\\cb2"; }

sub error {
    croak "${RED}@_";
}

open STDERR, '>&STDOUT';
$| = 1;

chdir $projRoot or error "Could not change to directory '$projRoot' as $!";

sub loadFile {
    my ($path) = @_;
    if ( my $fh = IO::File->new( "< $path" ) ) {
        my $data = join '', $fh->getlines();
        return wantarray() ? 
            split "\n", $data : $data;
    }
    else {
        error "Could not open \"$path\" as: $!" if !$fh;
    }
}

sub saveFile {
    my ($path, $data) = @_;
    my $current = !-f $path || loadFile( $path );

    if ( $data ne $current ) {
        unlock( $path );

        rename $path, "$path.save" if -f $path && !-f "$path.save";

        if ( my $fh = IO::File->new( "> $path" ) ) {
            my ($rest, $name) = urlprep( $path );
            $path = "$rest\{\\field{\\*\\fldinst HYPERLINK \"$path\"}{\\fldrslt $name}}";
            print "Saving $path ...\n" if $path !~ /\.plist/;
            $fh->print( $data );
            $fh->close();
            return 1;
        }
        else {
            error "Could not patch \"$path\" as: $!";
        }
    }

    return 0;
}

sub urlprep {
    $_[0] =~ s@^\./@@;
    my ($rest, $name) = $_[0] =~ m@(^.*/)?([^/]*)$@;
    $rest = "" if not defined $rest;
    $_[0] = $projRoot.$_[0] if $_[0] !~ m@^/@;
    my $urlPrefix = "file://";
    $_[0] = $urlPrefix.$_[0];
    return ($rest, $name);
}

sub unlock {
    my ($file) = @_;
    return if !-f $file || -w $file;
    print "Unlocking $file\n";
    $file =~ s@^./@@;
    $file = "$projRoot$file" if $file !~ m@^/@;
    print "Executing: $unlockCommand\n";
    my $command = sprintf $unlockCommand, map $file, 0..10;
    0 == system $command
        or print "${RED}Could not unlock using command: $command\n";
}

sub patchAll {
    my ($pattern, $change) = @_;
    foreach my $file (IO::File->new( "find . -name '$pattern' |" )->getlines()) {
        chomp $file;
        next if $file =~ /InjectionBundle/;
        my $contents = loadFile( $file );
        $change->( $contents );
        saveFile( $file, $contents );
    }
}

sub unique {
    my %hash = map {$_, $_} @_;
    return sort keys %hash;
}

1;
