#!/usr/bin/perl -w

#  prepareBundle.pl
#  Injection
#
#  Created by John Holdsworth on 16/01/2012.
#  Copyright (c) 2012 John Holdsworth. All rights reserved.
#
#  These files are copyright and may not be re-distributed, whole or in part.
#

BEGIN { 
    use vars qw($_common_pm);
    $Id = '$Id$';
    eval "use common;" if !$_common_pm; die $@ if $@;
}

use strict;

my (@sourcesToInject, @nibs, %nibMap);

foreach my $file ( unique( @extra ) ) {
    push @{$file =~ /\.(xib|storyboard)$/ ? \@nibs : \@sourcesToInject}, $file;
}

print "Preparing @sourcesToInject to load changed classes.\n";

# classes need no longer be patched for injection
#my @toInclude = prepareSources( 0, @sourcesToInject );

if ( !$executablePath ) {
    print "Appliction is not connected.\n";
    exit 0;
}

############################################################################

my ($localBinary, $identity, $isDevice) = setBundleLoader( $executablePath );

my $tmpDir = "/tmp/$ENV{USER}_nibs";
mkdir $tmpDir if ! -d $tmpDir;

my $nibScript = "$InjectionBundle/nib_builder.sh";

IO::File->new( "> $nibScript" )->print( <<'SCRIPT' ) if !-f $nibScript;
#!/bin/bash -x

/Applications/Xcode.app/Contents/Developer/usr/bin/ibtool --errors --warnings --notices --output-format human-readable-text --compile "$1" "$2" --sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.1.sdk

SCRIPT

$appPackage =~ s@/MacOS$@/Resources@ if $appPackage;

foreach my $xib (@nibs) {
    my ($lproj, $name) = $xib =~ m@/((?:\w+.lproj|)/)([^/]+)$@;
    $name =~ s/\.xib$/.nib/;
    $name =~ s/(\.storyboard)$/${1}c/;

    my $nib = my $tmp = "$appPackage/$lproj$name";
    if ( $isDevice ) {
        $tmp = "$tmpDir/$name";
        $nib = "$deviceRoot/tmp/$name";
        (my $root = $name) =~ s@\.\w+$@@;
        $nibMap{$root} = $nib;
    }

    0 == system "/bin/bash -x $nibScript '$tmp' '$xib'"
        or error "Error compiling nib";

    if ( $isDevice ) {
        print "<$tmp\n";
        print "!>$nib\n";
        if ( $tmp =~ /\.storyboardc/ ) {
            my $files = IO::File->new( "cd '$tmp' && find . -print |" )
                or error "Could not find: $tmp";
            while ( my $file = <$files> ) {
                chomp $file;
                if ( $file =~ s@^./@@ ) {
                    print "\\i1Copying $name/$file\n";
                    print "<$tmp/$file\n";
                    print "!>$nib/$file\n";
                    (my $root = $file) =~ s@\.\w+$@@;
                    $nibMap{"$name/$root"} = "$nib/$file";
                }
            }
        }
    }
    else {
        $nibMap{"_CAN_RELOAD_"} = "1";
    }
}

############################################################################

my $changesFile = "$InjectionBundle/InjectionBundle/BundleContents.m";
my @classes = map {$_ =~ /(\w+)\.m/} @sourcesToInject;

my $changesSource = IO::File->new( "> $changesFile" )
    or error "Could not open changes source file as: $!";

$changesSource->print( <<CODE );
/*
    Generated for Injection of class implementations
*/

#define INJECTION_NOIMPL
#define INJECTION_BUNDLE $productName

#undef _injectable
#define _injectable( _className ) _className(INJECTION_BUNDLE)
#undef _injectable_category
#define _injectable_category( _className, _category ) _className($productName##_##_category)

#undef _INCLASS
#define _INCLASS( _className ) _className(INJECTION_BUNDLE)
#undef _INCATEGORY
#define _INCATEGORY( _className, _category ) _className($productName##_##_category)

#undef _instatic
#define _instatic extern

#undef _inglobal
#define _inglobal extern

#undef _inval
#define _inval( _val... ) /* = _val */

#import "${injectionResources}BundleInjection.h"

@{[join "", map "#import \"$_\"\n\n", @sourcesToInject]}

\@interface $productName : NSObject {}
\@end
\@implementation $productName

+ (void)load {
@{[join '', map "    [BundleInjection mapNib:@\"$_\" toPath:@\"$nibMap{$_}\"];\n", keys %nibMap]}
@{[join '', map "    [BundleInjection loadedClass:[$_ class]];\n", @classes]}    [BundleInjection loaded];
}

\@end

CODE
$changesSource->close();

############################################################################

print "\nBuilding $InjectionBundle/InjectionBundle.xcodeproj\n";

my $config = ($localBinary =~ m@/###(\w+)/[^.]+.app(?:/Contents/MacOS)?/[^/]+$@)[0] || "Debug";
$config .= " -sdk iphonesimulator" if $executablePath =~ m@/iPhone Simulator/@;
$config .= " -sdk iphoneos" if $isDevice;
my $rebuild = 0;

build:
my $build = "xcodebuild -project InjectionBundle.xcodeproj -configuration $config";
my $sdk = ($config =~ /-sdk (\w+)/)[0] || 'macosx';

my $buildScript = "$InjectionBundle/compile_$sdk.sh";
my ($recording, $recorded);

if ( $patchNumber < 2 || (stat $bundleProjectFile)[9] > ((stat $buildScript)[9] || 0) ) {
    $recording = IO::File->new( "> $buildScript" )
        or die "Could not open '$buildScript' as: $!";
}
else {
    $build = "bash ../$buildScript # $build";
}

print "$build\n\n";
open BUILD, "cd $InjectionBundle && $build 2>&1 |" or error "Build failed $!\n";

my ($bundlePath, $warned, $w2);
while ( my $line = <BUILD> ) {

    if ( $recording && $line =~ m@/usr/bin/(clang|\S*gcc)@ ) {
        chomp (my $cmd = $line);
        $recording->print( "time $cmd &&\n" );
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
            (my $f = $p) =~ s!^(\.\.?/)!$projRoot$InjectionBundle/$1!;
            "$p\{\\field{\\*\\fldinst HYPERLINK \"$urlPrefix$f$n\"}{\\fldrslt $n}}:"; 
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
    if ( $line =~ /"_OBJC_IVAR_\$_/ && !$warned++ ) {
        $line = "${RED}Classes with \@private or aliased ivars can not be injected..\n$line";
    }
    if ( $line =~ /category is implementing a method which will also be implemented by its primary class/ && !$w2 ) {
        $line = "${RED}Add -Wno-objc-protocol-method-implementation to \"Other C Flags\"\\line in this application's bundle project to suppress this warning.\n$line";
        $w2++;
    }
    if ( $line =~ m@/usr/bin/ibtool @ && (!-f $nibScript || -w $nibScript) and
        (my $cmd = $line) =~ s/^\s*(.*?--compile )(?:"[^"]*"|\S+ ){2}( .*)/$1"\$1" "\$2"$2/ ) {
        IO::File->new( "> $nibScript" )->print( "#!/bin/bash -x\n\n$cmd\n" );
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

my ($bundleRoot, $bundleName) = $bundlePath =~ m@^(.*)/([^/]*)$@;

my $isIOS = $build =~ / -sdk /;
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

if ( $executablePath ) {
    print "Loading Bundle...\n";
    print "!$bundlePath\n";
}
else {
    print "Application not connected.\n";
}
