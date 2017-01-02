#
#  $Id: //depot/injectionforxcode/InjectionPluginLite/common.pm#2 $
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

use vars qw($resources $workspace $deviceRoot $executable $arch $patchNumber $flags
    $unlockCommand $addresses $selectedFile $isDevice $isSimulator $isAndroid $isAppCode
    $isIOS $productName $appPackage $deviceRoot $projFile $projRoot $projName $projType
    $InjectionBundle $template $header $appClass $RED $xcodeApp $buildRoot $logDir $learnt
    $INJECTION_FLAGCHANGE $INJECTION_STORYBOARD $INJECTION_NOTSILENT $INJECTION_ORDERFRONT
    $INJECTION_ISAPPCODE $INJECTION_DEVICEIOS8);

$INJECTION_FLAGCHANGE = 1<<0; # flag values have changed
$INJECTION_STORYBOARD = 1<<1; # storyboard injection enabled/used
$INJECTION_NOTSILENT  = 1<<2; # print annoying dialogue on injection
$INJECTION_ORDERFRONT = 1<<3; # order from OSX App or simulator
$INJECTION_ISAPPCODE  = 1<<4; # injecting from AppCode plugin
$INJECTION_DEVICEIOS8 = 1<<5; # iOS 8 splits data from app

($resources, $workspace, $deviceRoot, $executable, $arch, $patchNumber, $flags,
    $unlockCommand, $addresses, $selectedFile, $xcodeApp, $buildRoot, $logDir, $learnt) = @ARGV;

($appPackage, my $appRoot, my $appName) = $executable =~ m@((^.*)/([^/]+))/[^/]+$@;

$productName = "InjectionBundle$patchNumber";

$isDevice = $deviceRoot =~ m@^(/private)?/var/mobile/@;
$isSimulator = $deviceRoot =~ m@/(iPhone |Core)Simulator/@;
$isAndroid = $deviceRoot =~ m@^/data/app/@;

$isAppCode = $flags & $INJECTION_ISAPPCODE;
$deviceRoot = $executable if $isAppCode;

$isIOS = $isDevice || $isSimulator || $isAndroid;

# no confirmation message when using AppCode
$flags &= ~$INJECTION_NOTSILENT if $isAppCode;

($template, $header, $appClass) = $isIOS ?
    ("iOSBundleTemplate", "UIKit/UIKit.h", "UIApplication") :
    ("OSXBundleTemplate", "Cocoa/Cocoa.h", "NSApplication");

($InjectionBundle = $template) =~ s/BundleTemplate/InjectionProject/;
if ( $ENV{IS_INJECTION_APP} ) {
    $xcodeApp = "/Applications/Xcode.app" if !-d $xcodeApp;
    $InjectionBundle = "$logDir/../$InjectionBundle" if !$isAppCode && $logDir;
}

BEGIN { $RED = "{\\colortbl;\\red0\\green0\\blue0;\\red255\\green100\\blue100;}\\cb2"; }

sub error {
    croak "\n\\b ${RED}*** @_ ***\n\n";
}

open STDERR, '>&STDOUT';
$| = 1;

($projFile, $projRoot, $projName, $projType) = $workspace =~ m@^((.*?/)([^/]*)\.(xcodeproj|xcworkspace|idea/misc.xml))@
    or error "Could not parse workspace: $workspace";

chdir $projRoot or error "Could not change to directory '$projRoot' as: $!";

sub loadFile {
    my ($path) = @_;
    if ( my $fh = IO::File->new( $path ) ) {
        local $/ = undef;
        my $data = <$fh>;
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

        #rename $path, "$path.save" if -f $path && !-f "$path.save";

        if ( my $fh = IO::File->new( "> $path" ) ) {
            my ($rest, $name) = urlprep( my $link = $path );
            $link = "$rest\{\\field{\\*\\fldinst HYPERLINK \"$link\"}{\\fldrslt $name}}" if !$isAppCode;
            $fh->print( $data );
            $fh->close();
            if ( $path !~ /\.plist$/ ) {
                print "Modified $link ...\n";
                if ( !$isAppCode && 0 ) {
                    (my $diff = `/usr/bin/diff -C 5 \"$path.save\" \"$path\"`) =~ s/([\{\}\\])/\\$1/g;
                    $diff =~ s/\n/\\line/g;
                    print "{\\colortbl;\\red0\\green0\\blue0;\\red245\\green222\\blue179;}\\cb2$diff\n";
                }
            }
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
    my $changed = 0;

    foreach my $file (IO::File->new( "find . | grep -E '($pattern)\$' |" )->getlines()) {
        chomp $file;
        next if $file =~ /(InjectionProject|DerivedData|Pods)\//;
        my $contents = loadFile( $file );
        $changed += $change->( $contents )||0;
        if( saveFile( $file, $contents ) ) {
            system "open '$file'" if !$isAppCode;
        }
    }

    return $changed;
}

sub unique {
    my %hash = map {$_, $_} @_;
    return sort keys %hash;
}

sub copyToDevice {
    my ($from,$to,$pattern) = @_;

    print "Uploading '$from' to device...\n";
    print "<$from\n";
    print "!>$to\n";

    my $files = IO::File->new( "cd \"$from\" && find . -print |" )
        or error "Could not find: $from";
    while ( my $file = <$files> ) {
        chomp $file;
        if ( -d "$from/$file" || !$pattern || $file =~ /$pattern/ ) {
            #print "\\i1Copying $file\n";
            print "<$from/$file\n";
            print "!>$to/$file\n";
        }
    }

    return $to;
}

sub rtfEscape {
    $_[0] =~ s/([\{\}\\])/\\$1/g;
    return $_[0];
}

1;
