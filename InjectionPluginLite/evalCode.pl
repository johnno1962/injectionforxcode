#!/usr/bin/perl -w

#  $Id: //depot/InjectionPluginLite/evalCode.pl#3 $
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

FOUND:
foreach my $log (split "\n", `ls -t $buildRoot/../Logs/Build/*.xcactivitylog`) {
    foreach my $line ( split "\r", `gunzip <$log` ) {
        if ( $line =~ /XcodeDefault\.xctoolchain.+@{[$isSwift ? " -primary-file ": " -c "]}("[^"]+\/$className\.(m|mm|swift)"|\S+\/$className\.(m|mm|swift))/ ) {
            $selectedFile = $1;
            $learnt = $line;
            last FOUND;
        }
    }
}

$learnt or error "Could not locate source for class: $className";

$selectedFile =~ s/["\\]//g;
$learnt =~ s/( -o .*?\.o).*/$1/g;
$code = uri_unescape( $code );

undef $/;

open SOURCE, $selectedFile or die "Could not read source: $selectedFile";
my $source = <SOURCE>;

my $additionsTag = "// added by XprobePlugin";

$source =~ s@\n*$additionsTag.*|$@ $isSwift ? <<ENDSWIFT : <<ENDCODE @es;


$additionsTag

extension $className {

    func xprintln(str:String) {
        if let xprobe: AnyClass = NSClassFromString("Xprobe") {
            dispatch_after(DISPATCH_TIME_NOW, dispatch_get_main_queue(), {
                NSThread.detachNewThreadSelector(Selector("xlog:"), toTarget:xprobe, withObject:str as NSString)
            })
        }
    }

    \@objc func injected() {
        $code
    }
    
}

ENDSWIFT


$additionsTag

#ifdef DEBUG

\@interface NSObject(Xprobe)
+ (void)xlog:(NSString *)message;
\@end

static void XLog( NSString *format, ... ) {
    va_list argp;
    va_start(argp, format);
    [NSClassFromString(@"Xprobe") xlog:[[NSString alloc] initWithFormat:format arguments:argp]];
}

\@implementation $className(Injected)

- (void)injected {
$code
}

\@end

#endif
ENDCODE

open SOURCE, "> $selectedFile" or die "Could not write to source: $selectedFile";
print SOURCE $source;
close SOURCE;

my $INJECTION_NOTSILENT = 1<<2;

system "$FindBin::Bin/injectSource.pl",$resources, $workspace, $mainFile, $executable, $arch, $patchNumber, $flags&~$INJECTION_NOTSILENT, $unlockCommand, $addresses, $selectedFile, $buildRoot, $learnt;

die if $? >> 8;

$source =~ s@\n*$additionsTag.*|$@\n@s;

open SOURCE, "> $selectedFile" or die "Could not write to source: $selectedFile";
print SOURCE $source;
close SOURCE;


