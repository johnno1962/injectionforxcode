//
//  INAppDelegate.m
//  InjectionInstaller
//
//  Created by John Holdsworth on 20/09/2012.
//  Copyright (c) 2012 John Holdsworth. All rights reserved.
//

#import "INAppDelegate.h"
#import "BundleInterface.h"

@implementation INAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    webView.drawsBackground = NO;
    [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://injection.johnholdsworth.com/plugintro.html"]]];
    [window makeKeyAndOrderFront:self];
}

- (IBAction)install:sender {
    char command[PATH_MAX];
    snprintf( command, sizeof command,
             "cp -rf '%s/InjectionPlugin.xcplugin' ~/Library/Application\\ Support/Developer/Shared/Xcode/Plug-ins/",
             [[[NSBundle mainBundle] resourcePath] UTF8String] );

    system( "mkdir -p ~/Library/Application\\ Support/Developer/Shared/Xcode/Plug-ins/" );
    if ( system( command ) != 0 )
        [[NSAlert alertWithMessageText:@"Plugin Install Error:"
                         defaultButton:@"OK" alternateButton:nil otherButton:nil
             informativeTextWithFormat:@"Error installing plugin, check console."] runModal];
    else
        [disclaimer orderFront:self];
}

- (IBAction)remove:sender {
    if ( system( "\\rm -r ~/Library/Application\\ Support/Developer/Shared/Xcode/Plug-ins/InjectionPlugin.xcplugin" ) != 0 )
        [[NSAlert alertWithMessageText:@"Plugin Removal Error:"
                         defaultButton:@"OK" alternateButton:nil otherButton:nil
             informativeTextWithFormat:@"Error removing plugin, check console."] runModal];
}

- (IBAction)help:sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://injection.johnholdsworth.com/plugin.html"]];
}

- (void)windowWillClose:(NSNotification *)notification {
    [[NSApplication sharedApplication] terminate:self];
}

- (void)webView:(WebView *)aWebView didReceiveTitle:(NSString *)aTitle forFrame:(WebFrame *)frame {
    if ( frame == [webView mainFrame] )
        webView.window.title = aTitle;
}

- (void)webView:(WebView *)aWebView decidePolicyForMIMEType:(NSString *)type request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener {
	if ( [WebView canShowMIMEType:type] ) {
		[listener use];
		return;
	}

	loader = [[WebDownload alloc] initWithRequest:request delegate:self];
    [listener ignore];
}

- (void)cleanup {
    [loader release];
    loader = nil;
}

- (void)download:(NSURLDownload *)download didReceiveResponse:(NSURLResponse *)response {
	NSSavePanel *saver = [NSSavePanel savePanel];
	[saver setTitle:@"Downloading File"];
	[saver setExtensionHidden:NO];
	[saver setNameFieldStringValue:[file = [response suggestedFilename] retain]];

	if ( [saver runModal] == NSOKButton )
		[loader setDestination:[dest = [[saver URL] path] retain] allowOverwrite:YES];
	else {
		[loader cancel];
		[self cleanup];
	}
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length {
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error {
	window.title = [NSString stringWithFormat:@"Download failed with error: %@", error.localizedDescription];
    [self cleanup];
}

- (void)downloadDidFinish:(NSURLDownload *)download {
	window.title = [NSString stringWithFormat:@"Download of %@ complete.", file];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:dest]];
    [self cleanup];
}

@end
