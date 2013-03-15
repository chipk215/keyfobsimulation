//
//  KFBAccelerometer.h
//  KeyFobSimulator
//
//  Created by Chip Keyes on 2/28/13.
//  Copyright (c) 2013 Chip Keyes. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KFBProcessedAccelerometerData.h"

@interface KFBAccelerometer : NSObject



// Returns boolean indicating availability of accelerometer
+(BOOL)isAccelerometerAvailable;

// Returns boolean indicating whether accelerometer is actively updating
+(BOOL)isEnabled;

// Starts accelerometer updates for pulling data
+(BOOL)startAccelerometerUpdates;

// Stops accelerometer from updating
+(void)stopAccelerometerUpdates;


/*
 *
 * Method Name:  getProcessedAccelerometerSample
 *
 * Description:  Pulls a raw sample fro the accelerometer. Processes the sample by clipping to +/- 1G, and scales the acclerometer value to fit in 1 signed byte (-127 to +127) since that is the format the TI KeyFob uses.
 *
 * Parameter(s): None
 *
 */

+(KFBProcessedAccelerometerData *)getProcessedAccelerometerSample;


@end
