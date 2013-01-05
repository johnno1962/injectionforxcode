//
//  InPluginDocument.m
//  InjectionPlugin
//
//  Created by John Holdsworth on 19/09/2012.
//
//

#define INJECTION_NOIMPL

#import "InPluginDocument.h"
#import "InInjectionPlugin.h"

static int running;

@implementation InPluginDocument

- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper ofType:(NSString *)typeName error:(NSError **)outError {
    INLog( @"readFromFileWrapper: %@", fileWrapper );
    [self windowControllerDidLoadNib:nil];
    return YES;
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError {
    INLog( @"readFromURL: %@", url );
    [self windowControllerDidLoadNib:nil];
    return YES;
}

- owner {
    colLabel = inInjectionPlugin->colLabel;
    listView = inInjectionPlugin->statusWeb;
    textView = inInjectionPlugin->consoleView;
    for ( int i=0 ; i<sizeof vals/sizeof *vals ; i++ ) {
        vals[i]    = [inInjectionPlugin valueForKey:OO"val"+i];
        sliders[i] = [inInjectionPlugin valueForKey:OO"slide"+i];
        maxs[i]    = [inInjectionPlugin valueForKey:OO"max"+i];
        wells[i]   = [inInjectionPlugin valueForKey:OO"well"+i];
    }
    if ( !!inInjectionPlugin->lastFile )
        pendingFiles += inInjectionPlugin->lastFile;
    return inInjectionPlugin;
}

- (void)pasteRTF:(NSString *)rtf {
    if ( projectPath != inInjectionPlugin->projLabel.stringValue )
        inInjectionPlugin->projLabel.stringValue = projectPath;
    @try {
        NSAttributedString *as2 = [[NSAttributedString alloc]
                                   initWithRTF:(OO"{"+rtf+"\\line}\n").utf8Data() documentAttributes:nil];

        if ( !as2 ) {
            NSLog( @"-[InPluginDocument<%p> pasteRTF:] Could not convert '%@'", self, rtf );
            [inInjectionPlugin->consoleView insertText:rtf];
        }
        else
            [inInjectionPlugin->consoleView insertText:as2];

        OO_RELEASE( as2 );
    }
    @catch ( NSException *e ) {
        NSLog( @"-[InPluginDocument<%p> pasteRTF:] exception '%@' converting '%@': %@",
              self, [e reason], rtf, [e callStackSymbols] );
    }

    if ( [rtf rangeOfString:@"main.m has been changed for this application"].location != NSNotFound && !nagged++ )
        [inInjectionPlugin alert:@"As this is the first time you have injected this project, main.m and any .pch headers have been patched. "
         "Make sure the DEBUG preprocessor #directive is defined and restart your application."];
    else if ( [rtf rangeOfString:@"Please build and re-run your application"].location != NSNotFound && !nagged++ )
        headerChanged++;
    else if ( [rtf rangeOfString:@"Run Script, Build Phase"].location != NSNotFound )
        [inInjectionPlugin alert:@"To inject to a device an extra \"Build Phase\" has to be added to your project. "
         "See the Injection console for details about how to set this up."];
}

- (int)flags {
    return [super flags] | (inInjectionPlugin->inPlace.state ? 0 : 1<<2);
}

- (void)startFilter:(NSArray *)dirs {
}

- (void)mapSimulator {
}

#ifndef WEB_PLUGIN
- (void)not_connected:(int)diff {
    owner->connected += diff;
}
#endif

- (void)runScript:(cOOString)script extraArgs:(cOOStringArray)extra {
    if ( !running++ )
        [inInjectionPlugin startProgress];

    int flags = [self flags];
    if (owner->convertAll.state || isDemo)
        flags |= 1<<1;

    lastScript = script;
    OOStringArray command = @[@"/usr/bin/perl", @"-w", @"-I"+owner->scriptRoot,
        owner->scriptRoot+script, owner->resourcePath, owner->appVersion,
        owner->appPrefix, owner->scriptRoot, projectPath, executablePath||"",
        [@(patchNumber) stringValue], owner->unlockCommand.stringValue,
        [@(flags) stringValue], @"", @"", @"",
        @"use Compress::Zlib; use MIME::Base64; eval uncompress(substr decode_base64(substr <STDIN>, 5), 3); die $@ if $@; 1;"];
    command += extra;

    [self exec:command];
}

//#import "common.c"

- (void)exec:(NSMutableArray *)command {
    int length = inInjectionPlugin->consoleView.string.length;
    if ( length > 100000 )
        inInjectionPlugin->consoleView.string = @"";
    else
        [inInjectionPlugin->consoleView setSelectedRange:NSMakeRange(length, 0)];

    if ( owner->licensed != owner->refkey ) {
        [self pasteRTF:@"This copy of Injection is not curently licensed."];
        [owner license:nil];
        return;
    }

    INLog( @"Running: %@", command );
    if ( scriptOutput ) {
        [self performSelector:_cmd withObject:command afterDelay:.5];
        return;
    }

    lines = 0, status = 0;
    scriptOutput = (FILE *)1;
    if ( (scriptOutput = task.exec( command )) == NULL )
        [owner error:@"Could not run script: %@", command];
    else
        [self performSelectorInBackground:@selector(monitorScript) withObject:nil];

    //task.send( [NSData dataWithBytesNoCopy:common_pm length:strlen(common_pm) freeWhenDone:NO] );
    [self connected:0];

}

- (void)completed:success {
    if ( success ) {
        [self pasteRTF:@"\\line Bundle loaded successfully.\\line"];
        [self mapSimulator];
        ~filesChanged;
    }
    else {
        [inInjectionPlugin buildError];
        [inInjectionPlugin.console orderFront:self];
    }
    if ( headerChanged )
        [inInjectionPlugin alert:@"As this is the first time you have injected this class the header file has been modifed. "
         "You may need to re-run your application to make ivars available for injection."];
    headerChanged = nagged = 0;
}

- (void)monitorScript {
    [super monitorScript];

    if ( running && !--running )
        [inInjectionPlugin->progressIndicator performSelectorOnMainThread:@selector(removeFromSuperview)
                                                               withObject:nil waitUntilDone:NO];
     if ( status == 0 && lastScript == @"openProject.pl" && (filesChanged = ~pendingFiles) )
        [self startBuild:nil];
}

@end
