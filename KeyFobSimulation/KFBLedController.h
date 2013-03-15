//
//  KFBLedController.h
//  KeyFobSimulator
//
//  Created by Chip Keyes on 3/5/13.
//  Copyright (c) 2013 Chip Keyes. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KFBLedController : NSObject

/*
 *
 * Method Name:  initWithImageView
 *
 * Description:  Initializer for the led controller.
 *
 * Parameter(s): ledImageView - the image view holding the LED graphic on the UI
 *                initiallyOn - YES if the LED is initially on when the controller is instantiated
 *
 */
-(id)initWithImageView: (UIImageView *)ledImageView initiallyOn:(BOOL)initiallyOn;

// Hide the LED and clean up blink timers if needed
-(void)hide;


// Start the LED blinking
-(void)blink;

@end
