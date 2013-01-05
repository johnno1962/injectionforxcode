#!/usr/bin/perl -w

#  openProject.pl
#  Injection
#
#  Created by John Holdsworth on 16/01/2012.
#  Copyright (c) 2012 John Holdsworth. All rights reserved.
#
#  These files are copyright and may not be re-distributed, whole or in part.
#

BEGIN {
    use vars qw($_common_pm);
    $Id = '$Id: //depot/Injection/Injection/openProject.pl#44 $';
    eval "use common;" if !$_common_pm; die $@ if $@;
}

use strict;

my @ip4Addresses = grep $_ !~ /:/, @extra;

print "{\\rtf1\\ansi\\def0}\n\\lline Opening project \\b1 '$projectFile'\n";

my ($mainPCH, @others) = findOldest( "^$projName([_-]Prefix)?.pch", $type );
if ( !$mainPCH ) {
    ($mainPCH, @others) = excludeInjectionBundle( findOldest( ".pch", $type ) );
}
else {
    (@others) = grep $_ ne $mainPCH, excludeInjectionBundle( findOldest( ".pch", $type ) );
}

error "Project '$projectFile' does not have a .pch header that imports <$type>" if !$mainPCH;

print "!:PCH=$projRoot$mainPCH\n";

############################################################################

my ($projectMain) = findOldest( "main.m", $type2 );
error "Could not locate main.m containing '$type2'.\n" if !$projectMain;

my $mainSource = loadFile( $projectMain );
$mainSource =~ s/\s*(#ifdef INJECTION_ENABLED.*)?$/<<CODE/se;


#ifdef INJECTION_ENABLED
static char _inProjectFile[] = "$projectFile";
static const char *_inIPAddresses[] = {@{[join ', ', map "\"$_\"", @ip4Addresses]}, NULL};

#import "${injectionResources}BundleInjection.h"
#endif
CODE

print "{${RED}main.m has been changed for this application.\\line *** Please build and re-run your application ***}\n" 
    if saveFile( $projectMain, $mainSource );

print "!:MAIN=$projRoot$projectMain\n";

############################################################################

my @cflags;

if ( ! -d $InjectionBundle ) {

    print "Patching project not to hide symbols by default.\n";
    my $projectSource = loadFile( $mainProjectFile );

    $projectSource =~ s@(/\* Debug \*/ = \{[^{]*buildSettings = \{(\s*)[^}]*)(};)@$1GCC_SYMBOLS_PRIVATE_EXTERN = NO;$2$3@g;

    saveFile( $mainProjectFile, $projectSource );

    print "Copying $template into project.\n";
    0 == system "cp -r \"$appRoot$template\" $InjectionBundle && chmod -R og+w $InjectionBundle"
        or error "Could not copy injection bundle.";

    print "Migrating project parameters to bundle..\n";
    my $bundleProject = loadFile( $bundleProjectFile );
    my $isGCC;

    # FRAMEWORK_SEARCH_PATHS HEADER_SEARCH_PATHS USER_HEADER_SEARCH_PATHS
    foreach my $parm (qw(ARCHS VALID_ARCHS SDKROOT MACOSX_DEPLOYMENT_TARGET
            GCC_VERSION GCC_PREPROCESSOR_DEFINITIONS GCC_ENABLE_OBJC_GC
            GCC_ENABLE_OBJC_EXCEPTIONS CLANG_ENABLE_OBJC_ARC)) {
        if ( my ($val) = $projectSource =~ /(\b$parm = [^;]*;)/ ) {
            print "Inported setting $val\n";
            $bundleProject =~ s/\b$parm = [^;]*;/$val/g;
            $isGCC = 1 if $val =~ /GCC_VERSION.*gcc/;
        }
    }

    my %appframeworks = map {$_, $_} $projectSource =~ /name = (\w+)\.framework;/g;
    my %bundleFrameworks = map {$_, $_} $bundleProject =~ /name = (\w+)\.framework;/g;
    delete @appframeworks{('SenTestingKit', keys %bundleFrameworks)};
    print "Frameworks for bundle: @{[keys %appframeworks]}\n";
    my $ldFlags = join ' ', map "-framework $_", keys %appframeworks;
    $bundleProject =~ s/(OTHER_LDFLAGS = ")(";)/$1$ldFlags$2/g if $ldFlags;

    push @cflags, "-Wno-objc-protocol-method-implementation"
        unless $isGCC || $template =~ /OSXBundleTemplate/;
    saveFile( $bundleProjectFile, $bundleProject );

    my $bundlePCH = "$InjectionBundle/InjectionBundle/InjectionBundle-Prefix.pch";
    if ( ! -l $bundlePCH ) {
        print "Linking to oldest pre-compilation header.\n";
        unlink $bundlePCH;
        symlink "../../$mainPCH", $bundlePCH
        or error "Could not link main preprocessor header: $!";
    }

    while ( $projectSource =~ m@/\* [^.]+\.xcodeproj \*/.*? path = (.*?)/([^./]+).xcodeproj@g ) {
        print "Linking in framework at '$1'.\n";
        symlink $1, $2 if !-l $2;
    }
}

############################################################################

my $ifdef = $flags & 1<<0 ? <<IFDEF : <<IFDEF;
//#ifdef DEBUG
#define INJECTION_ENABLED
//#endif
IFDEF
#ifdef DEBUG
#define INJECTION_ENABLED
#endif
IFDEF

foreach my $pch ( excludeInjectionBundle( findOldest( ".pch", $type ) ) ) {
    my $header = loadFile( $pch );

    $header =~ s@^/[\s\*]+(Definitions For Injection|Preprocessor Definitions For Injection follow).*#endif\n@@sm;
    $header .= <<CODE if $header !~ /BundleInterface\.h/;

// *IMPORTANT* -- Don't leave injection enabled when releasing! //

$ifdef
#import "${injectionResources}BundleInterface.h"
CODE

    $header =~ s/(#import ").*(BundleInterface.h")/$1${injectionResources}$2/;

    print "Added #defines to project pre-compilation header $pch.\n"
        if saveFile( $pch, $header );
}

############################################################################

my $fileFilter =  "[^~].(mm?|xib|storyboard)";
my @sources = excludeInjectionBundle( findOldest( $fileFilter ) );
my @classes = grep $_ =~ /\.mm?$/, @sources;

# pre-convert all obj-c sources which are writable to categories
prepareSources( 1, grep -w $_ && !-l $_, @classes ) if $flags & 1<<1;

#print "Determining header include path.\n";
my @dirs = map {($_ =~ m@^(.*)/[^/]*$@)[0]} @sources;
my @includePath = sort @dirs = unique( @dirs );
my $includePath = join " ", @cflags;# , map "'-I../$_'", @includePath;

my $projectContents = loadFile( $bundleProjectFile );
if ( $projectContents =~ s/__BUNDLE_INCLUDES__/"$includePath"/g ) {
    print "Patched header include path.\n"
        if saveFile( $bundleProjectFile, $projectContents );
}

print "Determining directories to monitor...\n";
(my $projectRoot = $projectFile) =~ s@/[^/]+$@@;

my @monitors;

foreach my $i (0..$#includePath) {
    chomp( $includePath[$i] = `cd '$includePath[$i]'; pwd -P` );
    push @monitors, $includePath[$i]
        if !grep $includePath[$i] =~ /^\Q$_\E/, @monitors;
}

foreach my $dir (@includePath) {
    #print "Watching: $dir\n";
    print "#$dir/\n";
}

foreach my $dir (@monitors) {
    #print "Watching: $dir/\n";
    print "#!$dir/\n";
}

print "##$fileFilter\$\n";

print "%".statusTable( "<tr bgcolor='#d0d0d0'><td>&nbsp;<b>Project Source Status</b> -- ", @classes );

print "\n\\b1 Injection is ready to use, run application to start.\n";

exit 0;
