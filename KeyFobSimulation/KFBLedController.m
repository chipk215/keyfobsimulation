//
//  KFBLedController.m
//  KeyFobSimulator
//
//  Created by Chip Keyes on 3/5/13.
//  Copyright (c) 2013 Chip Keyes. All rights reserved.
//

#import "KFBLedController.h"

// blink interval with equal on/off duty cycle
#define BLINK_INTERVAL 0.5

@interface KFBLedController()

// image view outlet for LED 
@property (nonatomic, weak)UIImageView *imageView;

// timer used to toggel LED bloink state
@property (nonatomic, strong)NSTimer *blinkTimer;
@end

@implementation KFBLedController

// Initialize the controller, ensure LED hidden state matches provided argument
-(id)initWithImageView: (UIImageView *)ledImageView initiallyOn:(BOOL)initiallyOn
{
    self = [super init];
    if (self)
    {
        _imageView = ledImageView;
        
        // if initially on is YES then hidden = NO
        _imageView.hidden = ! initiallyOn;
               
    }
    
    return self;
}


// toggle LED hidden state on each call
-(void)toggleLedState
{
    DLog(@"toggle invoked");
    // on turn it off and vice versa
    self.imageView.hidden = ! self.imageView.hidden;
    
}

/*
 *
 * Method Name:  blink
 *
 * Description:  Set up a timer to toggle LED hidden state
 *
 * Parameter(s): none
 *
 */
-(void)blink
{
    SEL theSelector;
    NSMethodSignature *aSignature;
    NSInvocation *anInvocation;
    
    theSelector = @selector(toggleLedState);
    aSignature = [KFBLedController instanceMethodSignatureForSelector:theSelector];
    anInvocation = [NSInvocation invocationWithMethodSignature:aSignature];
    [anInvocation setSelector:theSelector];
    
    if (self.blinkTimer)
    {
        [self.blinkTimer invalidate];
        self.blinkTimer = nil;
    }
    
    self.blinkTimer = [NSTimer timerWithTimeInterval:BLINK_INTERVAL target:self selector:@selector(toggleLedState) userInfo:nil repeats:YES];
    
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [runLoop addTimer:self.blinkTimer forMode:NSDefaultRunLoopMode];
    
}


// hide the LED and clean up timer if needed
-(void)hide
{
    if (self.blinkTimer)
    {
        [self.blinkTimer invalidate];
        self.blinkTimer = nil;
    }
    
    self.imageView.hidden = YES;
}

@end
