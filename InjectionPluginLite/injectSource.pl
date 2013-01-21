#!/usr/bin/perl -w

#  $Id$
#  Injection
#
#  Created by John Holdsworth on 16/01/2012.
#  Copyright (c) 2012 John Holdsworth. All rights reserved.
#
#  These files are copyright and may not be re-distributed, whole or in part.
#

use strict;
use FindBin;
use lib $FindBin::Bin;
use common;

my $bundleProjectFile = "$InjectionBundle/InjectionBundle.xcodeproj/project.pbxproj";
my $bundleProjectSource = -f $bundleProjectFile && loadFile( $bundleProjectFile );

if ( !$executable ) {
    print "Application is not connected.\n";
    exit 0;
}

if ( ! -d $InjectionBundle ) {
    print "Copying $template into project.\n";

    0 == system "cp -r \"$resources/$template\" $InjectionBundle && chmod -R og+w $InjectionBundle"
        or error "Could not copy injection bundle.";

    my $bundlePCH = "$InjectionBundle/InjectionBundle-Prefix.pch";
    if ( my ($projectPCH) = split "\n", `find . -name "$projName-Prefix.pch"` ) {
        print "Linking to pre-compilation header: $projectPCH\n";
        unlink $bundlePCH;
        symlink "../$projectPCH", $bundlePCH
            or error "Could not link main preprocessor header as: $!";
    }
    else {
        IO::File->new( ">> $bundlePCH" )->print( <<CODE );

#ifdef DEBUG
    #define INJECTION_ENABLED
    #import "$resources/BundleInterface.h"
#endif
CODE
    }

    $bundleProjectSource = loadFile( $bundleProjectFile );
    my $pbxFile = "$projName.xcodeproj/project.pbxproj";
    if ( -f $pbxFile ) {
        print "Migrating project parameters to bundle..\n";

        my $projectSource = loadFile( $pbxFile );

        # FRAMEWORK_SEARCH_PATHS HEADER_SEARCH_PATHS USER_HEADER_SEARCH_PATHS
        foreach my $parm (qw(ARCHS VALID_ARCHS SDKROOT MACOSX_DEPLOYMENT_TARGET
                GCC_VERSION GCC_PREPROCESSOR_DEFINITIONS GCC_ENABLE_OBJC_GC
                GCC_ENABLE_OBJC_EXCEPTIONS CLANG_ENABLE_OBJC_ARC)) {
            if ( my ($val) = $projectSource =~ /(\b$parm = [^;]*;)/ ) {
                print "Inported setting $val\n";
                $bundleProjectSource =~ s/\b$parm = [^;]*;/$val/g;
            }
        }
    }
}

my ($localBinary, $identity) = ($executable);

if ( $isDevice ) {
    my $infoFile = "/tmp/$ENV{USER}.ident";
    error "To inject to a device, please add the following \"Run Script, Build Phase\" to your project and rebuild:\\line ".
            "echo \"\$CODESIGNING_FOLDER_PATH\" >/tmp/\"\$USER.ident\" && ".
            "echo \"\$CODE_SIGN_IDENTITY\" >>/tmp/\"\$USER.ident\" && exit;\n"
        if !-f $infoFile;

    ($localBinary, $identity) = loadFile( $infoFile );
    $localBinary =~ s@([^./]+).app@$1.app/$1@;
}

if ( $localBinary && $bundleProjectSource =~ s/(BUNDLE_LOADER = )([^;]+;)/$1"$localBinary";/g ) {
    print "Patching bundle project to app path: $localBinary\n";
}

saveFile( $bundleProjectFile, $bundleProjectSource );

############################################################################

my $changesFile = "$InjectionBundle/BundleContents.m";
my @classes = unique loadFile( $selectedFile ) =~ /\@implementation\s+(\w+)\b/g;

my $changesSource = IO::File->new( "> $changesFile" )
    or error "Could not open changes source file as: $!";

$changesSource->print( <<CODE );
/*
    Generated for Injection of class implementations
*/

#define INJECTION_NOIMPL
#define INJECTION_BUNDLE $productName

#import "$resources/BundleInjection.h"

#undef _instatic
#define _instatic extern

#undef _inglobal
#define _inglobal extern

#undef _inval
#define _inval( _val... ) /* = _val */

@{[join "", map "#import \"$_\"\n\n", $selectedFile]}
\@interface $productName : NSObject
\@end
\@implementation $productName

+ (void)load {
@{[join '', map "    extern Class OBJC_CLASS_\$_$_;\n\t[BundleInjection loadedClass:INJECTION_BRIDGE(Class)(void *)&OBJC_CLASS_\$_$_ notify:$flags];\n", @classes]}    [BundleInjection loadedNotify:$flags];
}

\@end

CODE
$changesSource->close();

############################################################################

print "\nBuilding $InjectionBundle/InjectionBundle.xcodeproj\n";

my $config = "Debug";
$config .= " -sdk iphonesimulator" if $isSimulator;
$config .= " -sdk iphoneos" if $isDevice;
my $rebuild = 0;

build:
my $build = "xcodebuild -project InjectionBundle.xcodeproj -configuration $config";
my $sdk = ($config =~ /-sdk (\w+)/)[0] || 'macosx';

my $buildScript = "$InjectionBundle/compile_$sdk.sh";
my ($recording, $recorded);

if ( (stat $bundleProjectFile)[9] > ((stat $buildScript)[9] || 0) ) {
    $recording = IO::File->new( "> $buildScript" )
        or die "Could not open '$buildScript' as: $!";
}
else {
    $build = "bash ../$buildScript # $build";
}

print "$build\n\n";
open BUILD, "cd $InjectionBundle && $build 2>&1 |" or error "Build failed $!\n";

my ($bundlePath, $warned);
while ( my $line = <BUILD> ) {

    if ( $recording && $line =~ m@/usr/bin/(clang|\S*gcc)@ ) {
        chomp (my $cmd = $line);
        $recording->print( "time $cmd 2>&1 &&\n" );
        $recorded++;
    }

    if ( $line =~ m@(/usr/bin/touch -c ("([^"]+)"|(\S+)))@ ) {
        $bundlePath = $3 || $4;
        (my $cmd = $1) =~ s/'/'\\''/g;
        $recording->print( "echo && echo '$cmd' &&\n" ) if $recording;
    }

    $line =~ s/([\{\}\\])/\\$1/g;

    if ( $line =~ /gcc|clang/ ) {
        $line = "{\\colortbl;\\red0\\green0\\blue0;\\red160\\green255\\blue160;}\\cb2\\i1$line";
    }
    if ( $line =~ /\b(error|warning|note):/ ) {
        $line =~ s@^(.*?/)([^/:]+):@
            my ($p, $n) = ($1, $2);
            (my $f = $p) =~ s!^(\.\.?/)!$projRoot/$InjectionBundle/$1!;
            "$p\{\\field{\\*\\fldinst HYPERLINK \"file://$f$n\"}{\\fldrslt $n}}:";
        @ge;
        $line = "{\\colortbl;\\red0\\green0\\blue0;\\red255\\green255\\blue130;}\\cb2$line"
            if $line =~ /\berror:/;
    }
    if ( $line =~ /has been modified since the precompiled header was built/ ) {
        $rebuild++;
    }
    if ( $line =~ /"_OBJC_CLASS_\$_BundleInjection", referenced from:/ ) {
        $line .=  "${RED}Make sure you do not have option 'Symbols Hidden by Default' set in your build.."
    }
    if ( $line =~ /category is implementing a method which will also be implemented by its primary class/ && !$warned ) {
        $line = "${RED}Add -Wno-objc-protocol-method-implementation to \"Other C Flags\"\\line in this application's bundle project to suppress this warning.\n$line";
        $warned++;
    }
    print "$line";
}

close BUILD;

unlink $buildScript if $? || $recording && !$recorded;

if ( $rebuild++ == 1 ) {
    system "cd $InjectionBundle && xcodebuild -project InjectionBundle.xcodeproj -configuration $config clean";
    goto build;
}

error "Build Failed with status: @{[($?>>8)]}. You may need to open and edit the bundle project to resolve issues with either header include paths or Frameworks the bundle links against." if $?;

if ( $recording ) {
    $recording->print( "echo && echo '** COMPILE SUCCEEDED **' && echo;\n" );
    close $recording;
}

############################################################################

print "Renaming bundle..\n";

my ($bundleRoot, $bundleName) = $bundlePath =~ m@^(.*)/([^/]*)$@;
my $newBundle = $isIOS ? "$bundleRoot/$productName.bundle" : "$appPackage/$productName.bundle";

0 == system "rm -rf \"$newBundle\" && cp -r \"$bundlePath\" \"$newBundle\""
    or die "Could not copy bundle";

my $plist = "$newBundle@{[$isIOS?'':'/Contents']}/Info.plist";

system "plutil -convert xml1 \"$plist\"" if $isDevice;

my $info = loadFile( $plist );
$info =~ s/\bInjectionBundle\b/$productName/g;
saveFile( $plist, $info );

system "plutil -convert binary1 \"$plist\"" if $isDevice;

my $execRoot = "$newBundle@{[$isIOS ? '' : '/Contents/MacOS']}";
rename "$execRoot/InjectionBundle", "$execRoot/$productName"
    or die "Rename1 error $! for: $execRoot/InjectionBundle, $execRoot/$productName";

$bundlePath = $newBundle;

############################################################################

if ( $isDevice ) {
    print "Codesigning for iOS device\n";

    0 == system "codesign -s '$identity' \"$bundlePath\""
        or error "Could not code sign as '$identity': $bundlePath";

    my $remoteBundle = "$deviceRoot/tmp/$productName.bundle";

    print "Uploading bundle to device...\n";
    print "<$bundlePath\n";
    print "!>$remoteBundle\n";

    my $files = IO::File->new( "cd \"$bundlePath\" && find . -print |" )
        or error "Could not find: $bundlePath";
    while ( my $file = <$files> ) {
        chomp $file;
        #print "\\i1Copying $file\n";
        print "<$bundlePath/$file\n";
        print "!>$remoteBundle/$file\n";
    }

    $bundlePath = $remoteBundle;
}

if ( $executable ) {
    print "Loading Bundle...\n";
    print "!$bundlePath\n";
}
else {
    print "Application not connected.\n";
}
