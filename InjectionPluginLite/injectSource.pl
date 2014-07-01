#!/usr/bin/perl -w

#  $Id: //depot/InjectionPluginLite/injectSource.pl#59 $
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
# Build command for selected file is taken from previous Xcode buils logs
#

my $learnt;

(my $escaped = $selectedFile) =~ s/ /\\\\ /g;
my @logs;

if ( !$buildRoot ) {
    my $learn = "xcodebuild -dry-run $config";
    $learn .= " -project \"$projName.xcodeproj\"" if $projName;
    my $memory = "$archDir/learnt_commands.gz";
    my $mainProjectChanged = mtime( $mainProjectFile ) > mtime( $memory );

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
            elsif ( $line =~ /^    (\/.* -c ("?)(.*)(\2)( -o .*))/ ) {
                $cmd .= $1;
                my $rest = $5;
                if ( $type =~ /ProcessPCH(\+\+)?|CpHeader/ ) {
                    0 == system $cmd.$rest or error "Could not precompile: $cmd.$rest";
                }
                elsif( $type eq 'CompileC' ) {
                    (my $file = $3) =~ s/\\//g;
                    $learn->print( "$cmd\r" );
                }
            }
        }

        $learn->close();
        $build->close();
    }

    @logs = ($memory)
}
else {
    @logs = split "\n", `ls -t $buildRoot/../Logs/Build/*.xcactivitylog`
}

foreach my $log (@logs) {
    last if ($learnt) = grep $_ =~ /XcodeDefault\.xctoolchain/ && $_ =~ /$escaped/, split "\r", `gunzip <$log`;
}

error "Could not locate compile command for $escaped" if !$learnt && $selectedFile =~ /\.swift$/;

############################################################################
#
# Create the "changes" file which #imports the source being injected so it
# can be built into the bundle project. If the compile command is "learnt"
# this will be <calssfile>.m.tmp in the class's original directory and a
# temporaray object file XXXInjectionPoeject/<arch>/injecting_class.o used.
# Otherwise the source will be #imported in "BundleContents.m" for use.
#

my $changesFile = "$InjectionBundle/BundleContents.m";
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

#import "BundleContents.h"

extern
#if __cplusplus
"C" {
#endif
    int injectionHook(void);
#if __cplusplus
};
#endif

\@interface $productName : NSObject
\@end
\@implementation $productName

+ (void)load {
    Class bundleInjection = NSClassFromString(@"BundleInjection");
    [bundleInjection autoLoadedNotify:$flags hook:(void *)injectionHook];
}

\@end

int injectionHook() {
    NSLog( \@"injectionHook():" );
    [$productName load];
    return YES;
}

@{[$learnt ? "" : "#import \"$selectedFile\"\n\n"]}

CODE

$changesSource->close();

############################################################################
#
# This is where the learnt compilation is actually used. It's compiled into
# the file XXXInjectionProject/<arch>/injecting_class.o and linked and the
# bundle project file patched to link "$obj" into the bundle binary. Swift
# files are compiled on mass but their object files can be identified using
# the JSON "-output-file-map".
#

my $sdk = ($config =~ /-sdk (\w+)/)[0] || 'macosx';
my $obj = '';

if ( $learnt ) {

    print "$learnt\n";
    0 == system $learnt or error "Learnt compile failed";

    $obj = "$arch/injecting_class.o";
    my ($toolchain,$map, $out);

    if ( ($toolchain, $map) = $learnt =~ m@(/Applications/Xcode.*/XcodeDefault.xctoolchain)/.*? -output-file-map (.*?\.json) @ ) {
        my $json = loadFile( $map );
        $json =~ s/":/"=>/g;
        $json = eval $json;
        error "JSON conversion error: $@ in $map" if $@;
        $out = $json->{$selectedFile}{object};
    }
    else {
        ($out) = $learnt =~ / -o (.*)$/;
    }

    0 == system "cp -f '$out' $InjectionBundle/$obj" or error "Could not copy object";

    if ( $toolchain ) {
        $obj .= "\", \"-L$toolchain/usr/lib/swift_static/iphonesimulator\", \"-F$buildRoot/Products/Debug-$sdk";
    }
}

$bundleProjectSource =~ s/(OTHER_LDFLAGS = \().*?("-undefined)/$1"$obj", $2/sg;
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

my $buildScript = "$archDir/compile_commands.sh";
my ($recording, $recorded);

if ( mtime( $bundleProjectFile ) > mtime( $buildScript ) ) {
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

    if ( $line =~ m@(/usr/bin/touch -c ("([^"]+)"|(\S+(\\ \S*)*)))@ && !$bundlePath ) {
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
