#
#  $Id: //depot/InjectionPluginLite/common.pm#3 $
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

use vars qw($resources $mainFile $executable $patchNumber $flags
    $unlockCommand $addresses $selectedFile $isDevice $isSimulator $isIOS
    $RED $InjectionBundle $productName $appPackage $deviceRoot $mainDir
    $template $header $appClass $bundleProjectFile $appPackage);

($resources, $mainFile, $executable, $patchNumber, $flags, $unlockCommand, $addresses, $selectedFile) = @ARGV;

$productName = "InjectionBundle$patchNumber";
($mainDir) = $mainFile =~ m@(.*)/[^/]+$@;

($appPackage, $deviceRoot) = $executable =~ m@((^.*)/[^/]+)/[^/]+$@;

$isDevice = $executable =~ m@^/var/mobile/@;
$isSimulator = $executable =~ m@/iPhone Simulator/@;
$isIOS = $isDevice || $isSimulator;

($template, $header, $appClass) = $isIOS ?
    ("iOSBundleTemplate", "UIKit/UIKit.h", "UIApplication") :
    ("OSXBundleTemplate", "Cocoa/Cocoa.h", "NSApplication");

($InjectionBundle = $template) =~ s/BundleTemplate/InjectionBundle/;
$bundleProjectFile = "$InjectionBundle/InjectionBundle.xcodeproj/project.pbxproj";

BEGIN { $RED = "{\\colortbl;\\red0\\green0\\blue0;\\red255\\green100\\blue100;}\\cb2"; }

sub error {
    croak "${RED}@_";
}

open STDERR, '>&STDOUT';
$| = 1;

chdir $mainDir or error "Could not chdir to \"$mainDir\" as: $!" if $mainDir;

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
    my ($dir, $name) = $path =~ m#^(.*)/([^/]+)$#;
    my $current = !-f $path || loadFile( $path );

    if ( $data ne $current ) {
        unlock( $path );

        my $save = "$dir/save"; mkdir $save, 0755 if !-d $save;
        rename $path, "$save/$name.save" if -f $path && !-f "$save/$name.save";

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
    ###$_[0] = $projRoot.$_[0] if $_[0] !~ m@^/@;
    my $urlPrefix = "file://";
    $_[0] = $urlPrefix.$_[0];
    return ($rest, $name);
}

sub unlock {
    my ($file) = @_;
    return if !-f $file || -w $file;
    print "Unlocking $file\n";
    $file =~ s@^./@@;
    ###$file = "$projRoot$file" if $file !~ m@^/@;
    print "Executing: $unlockCommand\n";
    my $command = sprintf $unlockCommand, map $file, 0..10;
    0 == system $command
        or print "${RED}Could not unlock using command: $command\n";
}

sub unique {
    my %hash = map {$_, $_} @_;
    return sort keys %hash;
}

1;
