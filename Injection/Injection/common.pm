#
#  common.pm
#  Injection
#
#  Created by John Holdsworth on 16/01/2012.
#  Copyright (c) 2012 John Holdsworth. All rights reserved.
#
#  These files are copyright and may not be re-distributed, whole or in part.
#

BEGIN { $_common_pm = 1; }

use File::Find;
use IO::File;
use FindBin;
use strict;
use Carp;

use vars qw($state $InjectionBundle $productName $deviceRoot
    $injectionResources $appVersion $urlPrefix $appRoot $Id
    $projectFile $executablePath $patchNumber $unlockCommand
    $flags $spare1 $spare2 $spare3 $spare4 @extra $RED 
    $projRoot $projFile $projName $template $type $type2
    $mainProjectFile $bundleProjectFile $appPackage);

($injectionResources, $appVersion, $urlPrefix, $appRoot,
    $projectFile, $executablePath, $patchNumber, $unlockCommand,
    $flags, $spare1, $spare2, $spare3, $spare4, @extra) = @ARGV;

$productName = "InjectionBundle$patchNumber";
($appPackage, $deviceRoot) = $executablePath =~ m@((^.*)/[^/]+)/[^/]+$@;
($projRoot, $projFile, $projName) = $projectFile =~ m@(^.*/)(([^.]+).[^/]+)$@;

$mainProjectFile = "$projectFile/project.pbxproj";

($template, $type, $type2) =
    loadFile( $mainProjectFile ) =~ /name = UIKit.framework;/ ?
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

chdir "$projectFile/.." or error "Could not chdir to \"$projectFile/..\" as: $!";

sub findOldest {
    my ($filePattern, $type) = @_;
    my @files;

    $filePattern =~ s/\./\\./g;
    $filePattern =~ s/\*/.+/g;

    find( {wanted=>sub {
        my $file = $File::Find::name;
        my $mtime = (stat $file)[9];
        push @files, [$file, $mtime] if $file && $mtime && $file =~/$filePattern$/;
    }, follow=>1, follow_skip=>2, no_chdir=>1}, (".") );

    @files = map $_->[0], sort { $a->[1] <=> $b->[1] } @files;

    shift @files while $type && @files && 
        loadFile( $files[0] ) !~ /$type/;
    return @files;
}

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
    $_[0] = $projRoot.$_[0] if $_[0] !~ m@^/@;
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

sub unique {
    my %hash = map {$_, $_} @_;
    return sort keys %hash;
}

sub excludeInjectionBundle {
    return grep $_ !~ /main\.m|((OSX|iOS)?InjectionBundle|Importer|Tests)\//, @_;
}

sub setBundleLoader {
    my ($localBinary, $identity, $isDevice) = @_;

    if ( $isDevice = $executablePath =~ m@^/var/mobile/@ ) {
        my ($projectName) = $projectFile =~ /(\w+)\.(\w+)$/;
        my $infoFile = "/tmp/$projectName.$ENV{USER}";

        error "To inject to a device, please add the following \"Run Script, Build Phase\" to your project and rebuild:\\line ".
                "echo \"\$CODESIGNING_FOLDER_PATH\" >/tmp/\"\$PROJECT_NAME.\$USER\" && ".
                "echo \"\$CODE_SIGN_IDENTITY\" >>/tmp/\"\$PROJECT_NAME.\$USER\" && exit;\n"
            if !-f $infoFile;

        ($localBinary, $identity) = loadFile( $infoFile );
        $localBinary =~ s@([^./]+).app@$1.app/$1@;
    }

    my $projectContents = loadFile( $bundleProjectFile );
    if ( $localBinary && $projectContents =~ s/(BUNDLE_LOADER = )([^;]+;)/$1"$localBinary";/g ) {
        print "Patching bundle project to app path: $localBinary\n";
        saveFile( $bundleProjectFile, $projectContents );
    }

    return ($localBinary, $identity, $isDevice);
}

my $nolegacy = '@interface\s+(?!\w+\s*\()[^{]+?(?=^[-+@])';
my $string = '@?"(?:[^"\\\\]*\\\\.)*[^"]*"';

#
# Since the move to no longer use categories the implementation is no longer
# patched and much of this code will be removed when things settle down.
# The header still needs to be patched to use explicit ivars or you
# get obscure problems with those implicitly defined by properties.
#
sub prepareSources {
    my ($preProcessing, @sources) = @_;
    my $inPlace = 0;#($flags & 1<<2) == 0;
    my $numberConverted = 0;
    my @toInclude;

    foreach my $sourcePath ( grep $_ =~ /\.mm?$/, excludeInjectionBundle(@sources) ) {
        my $sourceCode = loadFile( $sourcePath );
        my ($fileName) = $sourcePath =~ m@([^/]+$)@;
        print "Patching $fileName\n";

        if(0){
        $sourceCode =~ s/\b_INCLASS\b/_injectable/g;
        $sourceCode =~ s/\b_INCATEGORY\b/_injectable_category/g;

        # convert classes and categories to categories
        $sourceCode =~ s/(\@implementation\s+)(\w+)\b(?!\s*\()/$1_injectable($2)/g;
        $sourceCode =~ s/((\@implementation\s+)(\w+)(?<!_injectable)(?<!_injectable_category)\s*\(\s*(\w+)\b)/$2_injectable_category($3,$4/g;

        # patch out @syntheize when compiling in a bundle
        $sourceCode =~ s/((?:^\@(?:synthesize|dynamic)\s+[^;]+;[^\n]*\n)+)([-+\n])/#ifndef INJECTION_BUNDLE\n$1#endif\n$2/gm;

        my $comment = '/\*+(?:[^*/][^*]*\*+)*/';
        my $cwords = '(?<!\benum\b)(?<!\bstruct\b)(?<!\btypedef\b)(?<!\bclass\b)(?<!\bextern\b)(?<!\bswitch\b)(?<!\bcase\b)(?<!\bdefualt\b)(?<!\bbreak\b)(?<!\btemplate\b)(?<!\binline\b)';
        my $iwords = '(?<!_inprivate\b)(?<!_instatic\b)(?<!_inglobal\b)';
        my $nofunc = '(?!(?:\s+[\w*&<>#]+)*\s*\()';

        my $braces = '{[^{}]*(?:{[^}]*}\s*,?\s*)*[^}]*}';
        my $caster = '\\([^)]+\)[^,;]+';

        # decided it's best not to alter static statements after all...
        $cwords .= '(?<!\bstatic\b)' if my $noStatic = $inPlace&&0 ? '' : '_NOT_';

        # turn static variables into globals and patch initialisers if not static const
        $sourceCode =~ s@($comment)|^(static$noStatic\s+(const\s+)?)?(?<![{\\,{:]\n)(\w[\w<>]*\*?$cwords$iwords$nofunc\s+(?:[^;"]+$string)*[^;]*;)@
            my ($comment, $static, $const, $decl, $out) = ($1, $2, $3, $4, "");

            if ( $comment ) {
                $out = $comment;
            }
            elsif ( (my \@t = $decl =~ /[{}]/g) % 2 == 0 ) {
                my ($var) = $decl =~ /\b(\w+)\s*=/;
                $const = 1 if !$const && $var && $sourceCode !~ /\[$var\s|\n\s+$var\s*=/;
                $out = $static ? $const ? $const eq 1 ?
                        "_inprivate" : "_inprivate const" :
                        "_instatic" : "_inglobal";
                if ( $inPlace && !($const && $out =~ /^_inprivate/) ) {
                    $decl =~ s/\s*=\s*($braces|$caster|$string|[^,;]+)/ _inval( $1 )/gos;  
                }
                $out .= " $decl";
            }
            $out; 
        @gmeos;
        }

        my $savePath = $inPlace ?
            $sourcePath : "$InjectionBundle/InjectionBundle/Tmp$fileName";
        push @toInclude, $inPlace||1 ? $sourcePath : "Tmp$fileName";

        (my $headerPath = $sourcePath) =~ s/\.mm?$/.h/;

        if ( (-f $headerPath || $headerPath =~ s@/Sources/@/Headers/@ && -f $headerPath) &&
            (my $headerCode = loadFile( $headerPath )) ) {#=~ /$nolegacy|\@(private|package)/m ) {
            $headerCode =~ s/#if(n)?def\s+INJECTION_ENABLED\n(.*?)#endif\n\n/$1?$2:""/seg;

            # explicitly define any @synthesized ivars for linking
            my %vars;
            while ( $sourceCode =~ /\n\@synthesize\s+([^;]+);/gmo ) {
                foreach my $var (split /\s*,\s*/, $1) {
                    my $ivar = $var;
                    $ivar = $1 if $var =~ s/\s*=\s*(.*)\s*$//;
                    $vars{$var} = $ivar;
                }
            }

            my $defs = "";

            foreach my $code (($headerCode, $sourceCode)) {
                while ( $code =~ /\n\@property\s*(\([^)]*\)\s*)?([^*;]*)(\*\s*)?(\b\w+)\s*;/gmo ) {
                    my $unsafe = !$1 || !$3 && index( $2, "id" ) != 0 ? "" :
                        index( $1, "assign" ) >= 0 ? "INJECTION_UNSAFE " :
                        index( $1, "weak" ) >= 0 ? "INJECTION_WEAK " : "";
                   $defs .= "\t$2$unsafe@{[$3||'']}@{[delete $vars{$4}||'_'.$4]};\n";
                }
            }

            foreach my $ivar (keys %vars) {
                $defs .= "\tid $vars{$ivar};\n";
            }

            # extensions
            $sourceCode =~ s/(\@interface\s+\w+\s*\(\s*\)\s*\{\s*\n)([^#][^}]+)(\})/
                $defs .= "\n$2";
                "$1#ifndef INJECTION_ENABLED\n$2#endif\n$3";
            /e;

            $headerCode =~ s/($nolegacy)/$1#ifdef INJECTION_ENABLED\n{\n$defs}\n#endif\n\n/m
                if $defs;

            #$headerCode =~ s/(?<!#ifndef INJECTION_ENABLED)(\n\s*\@private.*\n)/\n#ifndef INJECTION_ENABLED$1#endif\n/g;
            #$headerCode =~ s/(?<!#ifndef INJECTION_ENABLED)(\n\s*\@package.*\n)/\n#ifndef INJECTION_ENABLED$1#else\n\@public\n#endif\n/g;

            #(my $saveHeader = $savePath) =~ s/\.mm?$/.h/;
            $numberConverted++ if saveFile( $headerPath, $headerCode );
        }

        ##### $sourceCode = "#line 1 \"$sourcePath\"\n\n\n$sourceCode" if !$inPlace;
        if ( 0 ) { #if ( $inPlace || !$preProcessing ) {
            chmod 0600, $savePath if -f $savePath && !$inPlace;

            $numberConverted++
                if saveFile( $savePath, $sourceCode ) && $sourceCode =~ /\b_instatic\b/;

            chmod 0400, $savePath if !$inPlace;
        }
    }

    print "${RED}Header files have been converted for injection. \\line*** Please build and re-run your application ***\n\n" if $numberConverted > 0;

    return @toInclude;
}

sub revert {
    my ($sourcePath) = @_;

    #print "Unpatching $sourcePath\n";
    my $source = loadFile( $sourcePath );

    $source =~ s/\b_inprivate /static /g;
    $source =~ s/\b_instatic /static /g;
    $source =~ s/\b_inglobal //g;

    $source =~ s/\b_injectable\s*\(\s*(\w+)\s*\)/$1/g;
    $source =~ s/\b_injectable_category\s*\(\s*(\w+)\s*,\s*(\w+)\s*\)/$1($2)/g;

    $source =~ s/\b_inval\((\s*)($string\s*|(?:\([^)]+\))?[^)]+)\)\s*/
        (my $val = $2) =~ s@\s+$@@;
        "= $val";
    /ges;

    # revert @synthesizes
    $source =~ s/#ifndef INJECTION_BUNDLE\n(.*?)#endif\n/$1/smeg;
    $source =~ s/#if(n)?def\s+INJECTION_ENABLED\n(.*?)#endif\n/$1?$2:""/seg;

    saveFile( $sourcePath, $source );

    (my $headerPath = $sourcePath) =~ s/\.mm?$/.h/;
    if ( -w $headerPath ) {
        my $headerSource = loadFile( $headerPath );
        $headerSource =~ s/#if(n)?def\s+INJECTION_ENABLED\n(.*?)#endif\n\n?/
            my ($n,$other) = ($1,$2);
            $other =~ s!#else\n\@public\n!!;
            $n?$other:""/seg;
        saveFile( $headerPath, $headerSource );
    }
}

sub statusTable {
    my ($title, @sources) = @_;
    $title = $title && $title."<span style='font: 10pt Arial'>&nbsp;".
    "<img src='file://$injectionResources/syringe.png'> = ready to inject, ".
    "<img src='file://$injectionResources/locked.png'> = read only file</span>";

    my $html = "<table border=1 cellspacing=0 bgcolor='#eeeeee' style='font: 10pt Arial;' width='100%'><tr>$title";

    foreach my $source (sort @sources) {
        my $extra = "";
        (my $headerPath = $source ) =~ s/\.mm?$/.h/;
        my $header = -f $headerPath && loadFile( $headerPath );
        my $ready = $header && ($header =~ /#ifdef INJECTION_ENABLED/ || $header !~ /$nolegacy/m);

        $extra .= " <img src='file://$injectionResources/syringe.png'>" if $ready;

        if ( !-w $source ) {
            $extra .= " <img src='file://$injectionResources/locked.png'> <a href='$urlPrefix!$source' title='check out and convert'>unlock</a>";
        }
        elsif ( !$ready ) {
            $extra .= " <a href='$urlPrefix+$source' title='convert a class for injection'>convert</a>";
        }
        else {
            $extra .= " <a href='$urlPrefix-$source' title='revert injection\'s changes'>revert</a>";
        }

        my ($rest, $name) = urlprep( $source );
        (my $id = $rest.$name) =~ s/\W/_/g;
        if ( $title ) {
            $html .= "<tr><td id='$id' nowrap>&nbsp;$rest<a href='$source'>$name</a>$extra";
        }
        else {
            return "!document.getElementById( '$id' ).innerHTML = \"&nbsp;$rest<a href='$source'>$name</a>$extra\";";
        }
    }

    return "2$html</table>\n";
}

1;
