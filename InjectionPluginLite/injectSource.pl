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
my $mainProjectFile = "$projName.xcodeproj/project.pbxproj";

sub mtime {
    my ($file) = @_;
    return (stat $file)[9]||0;
}

if ( !$executable ) {
    print "Application is not connected.\n";
    exit 0;
}

############################################################################
#
# If project has not been injected before, copy template bundle project
# and bring across key parameters also setting header include path.
#

if ( ! -d $InjectionBundle ) {
    print "Copying $template into project.\n";

    0 == system "cp -r \"$FindBin::Bin/$template\" $InjectionBundle && chmod -R og+w $InjectionBundle"
        or error "Could not copy injection bundle.";

    # try to use main project's precompilation header
    my $bundlePCH = "$InjectionBundle/InjectionBundle-Prefix.pch";
    if ( my ($projectPCH) = split "\n", `find . -name "$projName-Prefix.pch"` ) {
        print "Linking $bundlePCH to main pre-compilation header: $projectPCH\n";
        unlink $bundlePCH;
        symlink "../$projectPCH", $bundlePCH
            or error "Could not link main preprocessor header as: $!";
    }

    $bundleProjectSource = loadFile( $bundleProjectFile );
    if ( -f $mainProjectFile ) {
        print "Migrating project parameters to bundle..\n";
        my $mainProjectSource = loadFile( $mainProjectFile );

        # has Objective-C++ been used in the main project?
        if ( $mainProjectSource =~ /sourcecode.cpp.objcpp/ ) {
            $bundleProjectSource =~ s/(explicitFileType = sourcecode).c.objc/$1.cpp.objcpp/;
        }

        # FRAMEWORK_SEARCH_PATHS HEADER_SEARCH_PATHS USER_HEADER_SEARCH_PATHS GCC_VERSION
        # ARCHS VALID_ARCHS GCC_PREPROCESSOR_DEFINITIONS GCC_ENABLE_OBJC_EXCEPTIONS
        foreach my $parm (qw(MACOSX_DEPLOYMENT_TARGET IPHONEOS_DEPLOYMENT_TARGET
                ARCHS VALID_ARCHS SDKROOT GCC_ENABLE_OBJC_GC CLANG_ENABLE_OBJC_ARC
                CLANG_CXX_LANGUAGE_STANDARD CLANG_CXX_LIBRARY)) {
            if ( my ($val) = $mainProjectSource =~ /(\b$parm = [^;]*;)/ ) {
                print "Inported setting $val\n";
                $bundleProjectSource =~ s/\b$parm = [^;]*;/$val/g;
            }
        }

    }

    # set include path from list of directories containing headers in the main project
    # This should allow injection to work for all classes in this project but you may
    # still mean you need to open the injection bundle project to add to this path if
    # you are injecting classes in frameworks.
    if ( my @includePath = loadFile( "find . -name '*.h' | sed -e 's!/[^/]*\$!!' | sort -u | grep -v InjectionProject |" ) ) {
        $bundleProjectSource =~ s!(HEADER_SEARCH_PATHS = \(\n)(\s+)"../\*\*",!
            $1.join "\n", map "$2\"\\\".$_\\\"\",", @includePath;
        !eg;
    }
}

############################################################################
#
# Determine the xcode build command for the bundle subproject and determine
# the code signing identity for when we are injecting to a device.
#

mkdir my $archDir = "$InjectionBundle/$arch";
my $config = " -configuration Debug -arch $arch";
$config .= " -sdk iphonesimulator" if $isSimulator;
$config .= " -sdk iphoneos" if $isDevice;

my ($localBinary, $identity) = ($executable);

if ( $isDevice ) {
    my $infoFile = "$InjectionBundle/identity.txt";

    if ( !-f $infoFile ) {
        my %VARS = `xcodebuild -showBuildSettings $config` =~ /    (\w+) = (.*)\n/g;
        IO::File->new( "> $infoFile" )->print( "$VARS{CODESIGNING_FOLDER_PATH}\n$VARS{CODE_SIGN_IDENTITY}\n");
    }

    ($localBinary, $identity) = loadFile( $infoFile );
    $localBinary =~ s@([^./]+).app@$1.app/$1@;
}

if ( $localBinary && $bundleProjectSource =~ s/(BUNDLE_LOADER = )([^;]+;)/$1"$localBinary";/g ) {
    print "Patching bundle project to app path: $localBinary\n";
}

############################################################################
#
# This section is about learning the compile commands for classes in the
# main project using "xcodebuild -dry-run". This helps avoid issues with
# header include paths or specific compileation options used by the main
# project. They are stored in a "memory" file - by architecture.
#

my $learn = "xcodebuild -dry-run $config";
$learn .= " -project \"$projName.xcodeproj\"" if $projName;
my $memory = "$archDir/compile_memory.txt.gz";
my $mainProjectChanged = mtime( $mainProjectFile ) > mtime( $memory );
my $canLearn = !$isAndroid && 1;
my %memory;

if ( $canLearn ) {
    if ( !-f $memory || $mainProjectChanged ) {

        print "Learning compilations for files in project: $learn\n";

        my $build = IO::File->new( "rm -rf build; $learn 2>&1 |" );
        my $learn = IO::File->new( "| gzip >$memory" );
        my ($cmd, $type) = ('');

        while ( defined (my $line = <$build>) ) {
            if ( $line =~ /^([^ ]+) / ) {
                $type = $1;
                $cmd = '';
                #print "-------- $type\n";
            }
            elsif ( $line =~ /^    cd (.*)/ ) {
                $cmd .= "cd $1 && ";
            }
            elsif ( $line =~ /^    setenv (\w+) (.*)/ ) {
                $cmd .= "export $1=$2 && ";
            }
            elsif ( $line =~ /^    (\/.* -c ("?)(.*)(\2))( -o .*)/ ) {
                $cmd .= $1;
                my $rest = $5;
                if ( $type =~ /ProcessPCH(\+\+)?|CpHeader/ ) {
                    0 == system $cmd.$rest or error "Could not precompile: $cmd.$rest";
                }
                elsif( $type eq 'CompileC' ) {
                    (my $file = $3) =~ s/\\//g;
                    $learn->print( "$file\n$cmd\n" );
                }
            }
        }

        $learn->close();
        $build->close();
    }

    my @memory = loadFile( "gunzip <$memory |" );
    for ( my $i=0 ; $i<@memory ; $i+=2 ) {
        push @{$memory{$memory[$i]}}, $memory[$i+1];
    }
}

############################################################################
#
# Create the "changes" file which #imports the source being injected so it
# can be built into the bundle project. If the compile command is "learnt"
# this will be <calssfile>.m.tmp in the class's original directory and a
# temporaray object file XXXInjectionPoeject/<arch>/injecting_class.o used.
# Otherwise the source will be #imported in "BundleContents.m" for use.
#

my @classes = unique loadFile( $selectedFile ) =~ /\@implementation\s+(\w+)\b/g;
my $changesFile = "$InjectionBundle/BundleContents.m";
my $learnt = $memory{$selectedFile};

if ( $learnt || $isAndroid ) {
    IO::File->new( "> $changesFile" )
        ->print( "// learnt compilation.\n" );
    ($changesFile = $selectedFile) =~ s/(\.\w+)$/_$1/;
}

my $changesSource = IO::File->new( "> $changesFile" )
    or error "Could not open changes source file as: $!";

$changesSource->print( <<CODE );
/*
    Generated for Injection of class implementations
*/

#define INJECTION_NOIMPL
#define INJECTION_BUNDLE $productName

#define INJECTION_ENABLED
#import "$resources/BundleInjection.h"

#undef _instatic
#define _instatic extern

#undef _inglobal
#define _inglobal extern

#undef _inval
#define _inval( _val... ) /* = _val */

@{[$learnt||$isAndroid?'':'#import "BundleContents.h"']}

#if __cplusplus
extern "C" {
#endif
    int injectionHook();
#if __cplusplus
};
#endif

\@interface $productName : NSObject
\@end
\@implementation $productName

+ (void)load {
    Class bundleInjection = NSClassFromString(@"BundleInjection");
@{[join '', map "    extern Class OBJC_CLASS_\$_$_;\n\t[bundleInjection loadedClass:INJECTION_BRIDGE(Class)(void *)&OBJC_CLASS_\$_$_ notify:$flags];\n", @classes]}    [bundleInjection loadedNotify:$flags hook:(void *)injectionHook];
}

\@end

int injectionHook() {
    NSLog( \@"injectionHook():" );
    [$productName load];
    return YES;
}

@{[join "", map "#import \"$_\"\n\n", $selectedFile]}

CODE

$changesSource->close();

############################################################################
#
# At this point basic support has been patched in for an Apportable build on
# Android devices where a .approj file is present. Your milage may vary...
#

if ( $isAndroid ) {
    my $pkg;
    patchAll( "Info.plist", sub {
        $pkg ||= ($_[0] =~ m@<key>CFBundleIdentifier</key>\s*<string>([^<]*)<@s)[0];
        return 0;
    } );
    $pkg =~ s/\${PRODUCT_NAME:rfc1034identifier}/$projName/;
    $pkg =~ s/ /_/g;

    print "\nPerforming Android Build...\n";
    chdir "$ENV{HOME}/.apportable/SDK" or die "Could not chdir as: $!";

    # ninja build file used for 1.1.09
    my $ninja = loadFile( "Build/build.ninja" );
    my $rule = $selectedFile =~ /\.mm$/ ? "compile_cxx" : "compile_c";
    my ($command) = $ninja =~ /rule ${rule}_.*\n  command = ((?:.*\$\n)*.*)/;
    my ($per_file_flags) = $ninja =~ /per_file_flags = (.*)/;
    my $tmpobj = "/tmp/injection_$ENV{USER}";

    $command =~ s/\$per_file_flags\b/$per_file_flags/g;
    $command =~ s/\$in\b/"$changesFile"/g;
    $command =~ s/\$out\b/"$tmpobj.o"/g;

    $command =~ s/\$\n\s+//g;
    $command =~ s/\$(.)/$1/g;

    (my $prjName = $projName) =~ s/ //g;
    my @syslibs = qw(android c m v z dl log cxx stdc++ System SystemConfiguration Security CFNetwork
        Foundation CoreFoundation CoreGraphics CoreText BridgeKit OpenAL GLESv1_CM GLESv2 EGL xml2);

    $command .= " && ./toolchain/macosx/android-ndk/toolchains/arm-linux-androideabi-*/prebuilt/darwin-x86*/arm-linux-androideabi/bin/ld $tmpobj.o \"Build/android-armeabi-debug/$prjName/apk/lib/armeabi/libverde.so\" @{[map \"sysroot/usr/lib/armeabi/lib$_.so\", @syslibs]} -shared -o $tmpobj.so";

    # print "$command";

    0 == system( $command ) or error "Build failed: $changesFile";

    print "Loading shared library..\n";
    print "<$tmpobj.so\n";
    print "!>/data/data/$pkg/cache/$productName.so\n";
    print "!/data/data/$pkg/cache/$productName.so\n";
    print "Command sent to device.\n";
    exit 0;
}

############################################################################
#
# This is where the learnt compilation is actually used. It's compiled into
# the file XXXInjectionProject/<arch>/injecting_class.o and linked and the
# bundle project file patched to link "$obj" into the bundle binary.
#

my $obj = '';
if ( $learnt ) {
    print "Using learnt compilation.\n";

    foreach my $compile (@$learnt) {
        my ($arch) = $compile =~ / -arch (\w+) /;
        $compile =~ s/(.mm?$)/_$1/;
        $compile = "time $compile -o \"$projRoot$InjectionBundle/$arch/injecting_class.o\"";
        print "$compile\n";
        if ( system $compile ) {
            unlink $memory;
            system "$learn clean";
            error "*** Learnt Compile Failed: $compile\n\n** Build memory cleared, please try again. **\n\n";
        }
    }

    unlink $changesFile;
    $obj = "\"$arch/injecting_class.o\", ";
}

$bundleProjectSource =~ s/(OTHER_LDFLAGS = \().*?("-undefined)/$1$obj$2/sg;
saveFile( $bundleProjectFile, $bundleProjectSource );

############################################################################
#
# Perform the actual xcodebuild of the XXXInjectionProject to build the
# bundle to be loaded into the application. This is quite slow so after
# one build the commands used are recorded into a bash script to be used
# until next time the bundle project file changes.
#

print "\nBuilding $InjectionBundle/InjectionBundle.xcodeproj\n";

my $rebuild = 0;

build:
my $build = "xcodebuild $config";
my $sdk = ($config =~ /-sdk (\w+)/)[0] || 'macosx';

my $buildScript = "$archDir/compile_commands.sh";
my ($recording, $recorded);

if ( $mainProjectChanged || mtime( $bundleProjectFile ) > mtime( $buildScript ) ) {
    $recording = IO::File->new( "> $buildScript" )
        or die "Could not open '$buildScript' as: $!";
}
else {
    # used recorded commands to avoid overhead of xcodebuild
    $build = "bash ../$buildScript # $build";
}

print "$build\n\n";
open BUILD, "cd $InjectionBundle && $build 2>&1 |" or error "Build failed $!\n";

my ($bundlePath, $warned);
while ( my $line = <BUILD> ) {

    if ( $recording && $line =~ m@/usr/bin/(clang|\S*gcc)@ & $line !~ /-header -arch/  ) {
        chomp (my $cmd = $line);
        $recording->print( "echo '$cmd'; time $cmd 2>&1 &&\n" );
        $recorded++;
    }

    if ( $line =~ m@(/usr/bin/touch -c ("([^"]+)"|(\S+(\\ \S*)*)))@ ) {
        $bundlePath = $3 || $4;
        (my $cmd = $1) =~ s/'/'\\''/g;
        $recording->print( "echo && echo '$cmd' &&\n" ) if $recording;
    }

    # support for Xcode 5 DP4-5+
    elsif ( $line =~ m@/dsymutil (.+/InjectionBundle.bundle)/InjectionBundle@ ) {
        ($bundlePath = $1) =~ s/\\//g;
        (my $cmd = "/usr/bin/touch -c \"$bundlePath\"") =~ s/'/'\\''/g;
        $recording->print( "echo && echo '$cmd' &&\n" ) if $recording;
    }

    $line =~ s/([\{\}\\])/\\$1/g;

    if ( !$isAppCode ) {
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
    }

    if ( $line =~ /has been modified since the precompiled header/ ) {
        $rebuild++; # retry once after xcodebuild clean
    }

    print $line;
}

close BUILD;

unlink $buildScript if $? || $recording && !$recorded;

# If there has been a .pch file change it's worth trying again once
if ( $rebuild++ == 1 ) {
    system "cd $InjectionBundle && xcodebuild $config clean";
    goto build;
}

if ( $? ) {
    error "Build Failed with status: @{[($?>>8)]}. You may need to open and edit the bundle project to resolve issues with either header include paths or Frameworks the bundle links against.";
}

if ( $recording ) {
    $recording->print( "echo && echo '** RECORDED BUILD SUCCEEDED **' && echo;\n" );
    close $recording;
}

############################################################################
#
# Now we actually load the bundle using specially prefixed commands sent
# back to Xcode which passes them on through a socket connection to the
# BundleInjection.h code in the application.
#

print "Renaming bundle so it reloads..\n";

my ($bundleRoot) = $bundlePath =~ m@^\"?(.*)/([^/]*)$@;
my $newBundle = $isIOS ? "$bundleRoot/$productName.bundle" : "$appPackage/$productName.bundle";

my $command = "rm -rf \"$newBundle\" && cp -r \"$bundlePath\" \"$newBundle\"";
print "$command\n";
0 == system $command or error "Could not copy bundle to: $newBundle";

$bundlePath = $newBundle;

if ( $isDevice ) {
    print "Codesigning with identity '$identity' for iOS device\n";

    0 == system "codesign -s '$identity' \"$bundlePath\""
        or error "Could not codesign as '$identity': $bundlePath";

    $bundlePath = copyToDevice( $bundlePath, "$deviceRoot/tmp/$productName.bundle" );
}

print "Loading Bundle...\n";
print "!$bundlePath\n";
