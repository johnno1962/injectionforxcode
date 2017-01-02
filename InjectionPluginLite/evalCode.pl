#!/usr/bin/perl -w

#  $Id: //depot/injectionforxcode/InjectionPluginLite/evalCode.pl#3 $
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
use URI::Escape;
use common;

my ($pathID, $className, $isSwift, $code) = split /\^/, $selectedFile;
$className =~ s/^\w+\.//;

print "Searching logs in $logDir\n";

FOUND:
foreach my $log (split "\n", `ls -t "$logDir"/*.xcactivitylog`) {
    foreach my $line ( split "\r", `gunzip <$log` ) {
        if ( index( $line, " $arch" ) != -1 && $line =~ /XcodeDefault\.xctoolchain.+@{[$isSwift ?
                " -primary-file " : " -c "]}("[^"]+\/$className\.(m|mm|swift)"|\S+\/$className\.(m|mm|swift))/ ) {
            $selectedFile = $1;
            $learnt = $line;
            last FOUND;
        }
    }
}

if ( !$learnt ) {
    print "Unkown class, using canned Objective-C compile..\n";
    $isSwift = 0;
    $selectedFile = "/tmp/injection_unknown.m";
    chomp( $learnt = <<CANNED );
$xcodeApp/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -x objective-c -arch $arch -fmessage-length=0 -fdiagnostics-show-note-include-stack -fmacro-backtrace-limit=0 -std=gnu99 -Wno-trigraphs -fpascal-strings -fobjc-arc -fmodules -O0 -Wno-missing-field-initializers -Wmissing-prototypes -Wno-implicit-atomic-properties -Wno-receiver-is-weak -Wno-arc-repeated-use-of-weak -Wno-missing-braces -Wparentheses -Wswitch -Wno-unused-function -Wno-unused-label -Wno-unused-parameter -Wunused-variable -Wunused-value -Wno-empty-body -Wno-uninitialized -Wno-unknown-pragmas -Wno-shadow -Wno-four-char-constants -Wno-conversion -Wno-constant-conversion -Wno-int-conversion -Wno-bool-conversion -Wno-enum-conversion -Wshorten-64-to-32 -Wpointer-sign -Wno-newline-eof -Wno-selector -Wno-strict-selector-match -Wno-undeclared-selector -Wno-deprecated-implementations -DDEBUG=1 -isysroot $xcodeApp/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk -fexceptions -fasm-blocks -fstrict-aliasing -Wprotocol -Wdeprecated-declarations -g -Wno-sign-conversion -fobjc-abi-version=2 -fobjc-legacy-dispatch -mios-simulator-version-min=5.0 -c $selectedFile -o /tmp/injection_unknown.o
CANNED
    open UNKNOWN, "> $selectedFile" or die "Could not open canned file.";
    print UNKNOWN <<EMPTY;
\@import UIKit;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-property-synthesis"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wprotocol"
\@implementation $className
+ (Class)class {
    return self;
}
\@end
#pragma clang diagnostic pop

EMPTY
    close UNKNOWN;
}

$selectedFile =~ s/["\\]//g;
$learnt =~ s/( -o .*?\.o).*/$1/g;
$code = uri_unescape( $code );

undef $/;

open SOURCE, $selectedFile or die "Could not read source: $selectedFile";
my $source = <SOURCE>;

my $additionsTag = "// added by XprobePlugin";

my ($swiftClass) = $source =~ /\@objc\(\w+\)\s+class (\w+)/;

$source =~ s@\n*$additionsTag.*|$@ $isSwift ? <<ENDSWIFT : <<ENDCODE @es;


$additionsTag

extension @{[$swiftClass||$className]} {

    func xprint<T>(_ str: T) {
        if let xprobe = NSClassFromString("Xprobe") {
            #if swift(>=3.0)
            Thread.detachNewThreadSelector(Selector(("xlog:")), toTarget:xprobe, with:"\\(str)" as NSString)
            #else
            NSThread.detachNewThreadSelector(Selector("xlog:"), toTarget:xprobe, withObject:"\\(str)" as NSString)
            #endif
        }
    }

    #if swift(>=3.0)
    struct XprobeOutputStream: TextOutputStream {
        var out = ""
        mutating func write(_ string: String) {
            out += string
        }
    }

    func xdump<T>(_ arg: T) {
        var stream = XprobeOutputStream()
        dump(arg, to: &stream)
        xprint(stream.out)
    }
    #endif

    \@objc func onXprobeEval() {
        $code
    }
    
}

ENDSWIFT


$additionsTag

#ifdef DEBUG

\@interface NSObject(Xprobe)
+ (void)xlog:(NSString *)message;
\@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"
static void XLog( NSString *format, ... ) {
    va_list argp;
    va_start(argp, format);
    [NSClassFromString(@"Xprobe") xlog:[[NSString alloc] initWithFormat:format arguments:argp]];
}

static void xprint( const char *msg ) {
    XLog( \@"Swift language used for Objective-C injection: %s", msg );
}
#pragma clang diagnostic pop

\@implementation $className(onXprobeEval)

- (void)onXprobeEval {
    $code;
}

\@end

#endif
ENDCODE

print "!#$className $selectedFile\n";

open SOURCE, "> $selectedFile" or die "Could not write to source: $selectedFile";
print SOURCE $source;
close SOURCE;

my $INJECTION_NOTSILENT = 1<<2;

system "$FindBin::Bin/injectSource.pl",$resources, $workspace, $deviceRoot, $executable, $arch, $patchNumber, $flags&~$INJECTION_NOTSILENT, $unlockCommand, $addresses, $selectedFile, $xcodeApp, $buildRoot, $logDir, $learnt;

die if $? >> 8;

$source =~ s@\n*$additionsTag.*|$@\n@s;

open SOURCE, "> $selectedFile" or die "Could not write to source: $selectedFile";
print SOURCE $source;
close SOURCE;


