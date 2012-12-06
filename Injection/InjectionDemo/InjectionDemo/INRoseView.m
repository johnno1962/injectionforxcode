//
//  INRoseView.m
//  InjectionDemo
//
//  Created by John Holdsworth on 12/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//  $Id$
//
// A demonstration for code injection showing the various notifications and
// how to use the INParameters array to take parameters from the Control Panel.
//
// The background underlying color and three colors of a gradient can be altered
// using the colorwells on the control panel. Also, an image can be provided for 
// a UIView by dragging it onto the imagewell of the control panel. After this it 
// will update automatically to facilitate iterations over a background graphic.
//
// This code is also a reference on how the various types of Objective-C II ivars
// need to be treaded in order for the class to be recompiled as a category.
//

//
// The pre-processor directives used below are normally applied automatically
// when the project is opened or when a class is first unlocked or built.
//

#import "INRoseView.h"

// "extension" ivars are not visible to categories
// and must be moved to the class interface header.
@interface INRoseView () 

// explicit ivar declarations
@property (assign, nonatomic) float roseOffset;
@property (assign, nonatomic) float colorOffset;
@property (assign, nonatomic) BOOL animating;

@end

// _injectable() macro converts class into a category
// when being compiled for a loadble bundle.

@implementation _injectable(INRoseView)

// @synthesize can not be compiled in a category,
// INJECTION_BUNDLE is defined during bundle build.

#ifndef INJECTION_BUNDLE
@synthesize roseOffset, colorOffset, animating;
#endif

// set up linkages to control panel //
- (void)awakeFromNib {
    
    // receive notification on bundle load
    INJECTION_NOTIFY( self );
    
    // set up parameter change delegates
    INJECTION_DELEGATE_ALL( self );
    
    // setup background colorwell #0 target using object interface
    [NSObject inSetTarget:self action:@selector(setBackgroundColor:) forColor:0];
    
    // direct setting of action "setNeedsDisplay" for gradient colors #1->#3
    INColorTargets[1] = INColorTargets[2] = INColorTargets[3] = self;
    INColorActions[1] = INColorActions[2] = INColorActions[3] = 
        @selector(setNeedsDisplay);
    
    // imageview target for setImage:
    INImageTarget = _imageView;
}

- (void)injectionBundleLoaded:(NSNotification *)notification {
    NSLog( @"Injection Bundle has been loaded with code changes." );
    [self performSelectorOnMainThread:@selector(setNeedsDisplay) withObject:nil waitUntilDone:NO];
}

- (void)inParameter:(int)tag hasChanged:(float)value {
    // Parameter slider value has changed on the "Control Panel"
    [self performSelectorOnMainThread:@selector(setNeedsDisplay) withObject:nil waitUntilDone:NO];
}

// These vars expand to be global in main build
// and "extern" in bundle build. When injection
// is not enabled statics revert to being static.
_inglobal NSString *aGlobalVariable;

// Initializers are expanded only during main project build.
// _inval( _val ) expands to "= _val" then "/**/" in bundle.
_instatic NSString *aStaticVariableWithInitialValue _inval( @"static" );

// a private class variable static to the bundle
_inprivate float power, radius;

// prevents clang warning
extern float psin( float phi );
extern float pcos( float phi );

// Functions should be left global
// Dynamic loader does not seem to
// mind about the duplicate symbols.
// The new function version is used.

float psin( float phi ) {
    float s = sin( phi );
    return (s<0?-1:1) * powf( fabs( s ), power ) * radius; 
}
float pcos( float phi ) {
    return psin( phi + M_PI_2 );
}

// edit method and save to see your changes take effect //
- (void)drawRect:(CGRect)rect
{
    // Drawing code
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGContextRef cg = UIGraphicsGetCurrentContext();
    
    // draw three color gradient over background
	CGFloat colors[3][4];
	for ( int c=0 ; c<3 ; c++ ) {
        const CGFloat *cpts = CGColorGetComponents( INColors[c+1].CGColor );
        colors[c][0] = cpts ? cpts[0] : 0.0;
        colors[c][1] = cpts ? cpts[1] : 0.0;
        colors[c][2] = cpts ? cpts[2] : 0.0;
        colors[c][3] = cpts ? cpts[3] : 0.0;
    }
    
	CGGradientRef gradient = CGGradientCreateWithColorComponents(cs, (float *)colors, 
                                                                 NULL, sizeof colors/sizeof colors[0]);
	CGContextDrawLinearGradient( cg, gradient, CGPointMake( 0, 0 ),
                                CGPointMake( 0, rect.size.height ), 
                                kCGGradientDrawsBeforeStartLocation );
	CGGradientRelease(gradient);
    
    radius = rect.size.width/2.;
    
    // affects "squareness" of the spiral
    // reference to control panel parameter
    power = INParameters[0];
    
    // initial parameters for the spiral
    float x0 = radius, y0 = radius+12, phi0 = roseOffset, phi1 = roseOffset + M_PI,
        dphi = MAX( .01, 0.1*INParameters[1] ), rphi = MIN( .9*INParameters[2], .99 ),
        colorphi = colorOffset;
    
    // draw lines until angle phi0 catches up with phi1
    while ( phi0 < phi1 ) {
        
        // color rotates around color circle as lines are drawn
        CGFloat Y = .5, U = sin(colorphi), V = cos(colorphi);
        CGFloat R = Y + 1.4075 * V;
        CGFloat G = Y - 0.3455 * U - 0.7169 * V;
        CGFloat B = Y + 1.7790 * U;
        
        CGFloat cols[4] = {R,G,B,1.};
        CGColorRef cgc = CGColorCreate( cs, cols );
        CGContextSetStrokeColorWithColor( cg, cgc );
        CGColorRelease(cgc);
        
        // draw colored line across circle
        CGContextMoveToPoint( cg, x0 + psin( phi0 ), y0 + pcos( phi0 ) );
        CGContextAddLineToPoint( cg, x0 + psin( phi1 ), y0 + pcos( phi1 ) );
        CGContextDrawPath( cg, kCGPathStroke );
        
        // move line and color phase on.
        phi0 += dphi;
        phi1 += dphi * rphi;
        
        // macro form of parameter reference
        // which has default value for release
        colorphi += dphi * INPARAM( 3, 1 );
    }
    
    CGColorSpaceRelease(cs);
}

- (void)animate {
    if ( !animating )
        return;
    
    // edit and save to see changes
    roseOffset -= .09; // rotate rose
    colorOffset -= .13; // rotate colors
    
    [self setNeedsDisplay];
    
    // object oriented parameter reference
    float delay = [NSObject inParameter:4];
    [self performSelector:@selector(animate) withObject:nil afterDelay:.05*delay];
}

- (IBAction)animate:sender {
    if ( (animating = !animating) )
        [self animate];
}

@end
