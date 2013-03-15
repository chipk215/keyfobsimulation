//
//  KFBAccelerometer.m
//  KeyFobSimulator
//
//  Created by Chip Keyes on 2/28/13.
//  Copyright (c) 2013 Chip Keyes. All rights reserved.
//

#import <CoreMotion/CoreMotion.h>
#import "KFBAccelerometer.h"

@interface KFBAccelerometer()

@property (strong, nonatomic) CMMotionManager *motionManager;

@end

// Single motionManager used to acccess accelerometer
static CMMotionManager* motionManager;

@implementation KFBAccelerometer


// static initializer
+(void)initialize
{
    motionManager = [[CMMotionManager alloc]init];
}


// Returns boolean indicating availability of accelerometer
+(BOOL)isAccelerometerAvailable
{
    if (motionManager)
    {
        return [motionManager isAccelerometerAvailable];
    }
    else
    {
        return NO;
    }
}


// Returns boolean indicating whether accelerometer is active
+(BOOL)isEnabled
{
    BOOL returnValue = NO;
    if (motionManager)
    {
        if ([motionManager isAccelerometerAvailable] &&
            [motionManager isAccelerometerActive])
        {
            returnValue = YES;
        }
    }
    
    return returnValue;
}


// Starts accelerometer updates for pulling data
+(BOOL)startAccelerometerUpdates
{
   
    BOOL success = NO;
    if (motionManager)
    {
        if ([motionManager isAccelerometerAvailable])
        {
             DLog(@"Start Accelerometer Updates invoked.");
            [motionManager startAccelerometerUpdates];
            success = YES;
        }
    }
    
    return success;
}


// Stops accelerometer from updating
+(void)stopAccelerometerUpdates
{
    if (motionManager)
    {
        if ([motionManager isAccelerometerAvailable] &&
         [motionManager isAccelerometerActive])
        {
            [motionManager stopAccelerometerUpdates];
        }
    }
}


/*
 *
 * Method Name:  getProcessedAccelerometerSample
 *
 * Description:  Pulls a raw sample fro the accelerometer. Processes the sample by clipping to +/- 1G, and scales the acclerometer value to fit in 1 signed byte (-127 to +127) since that is the format the TI KeyFob uses.
 *
 * Parameter(s): None
 *
 */
+(KFBProcessedAccelerometerData *)getProcessedAccelerometerSample
{
    KFBProcessedAccelerometerData *processedSample=nil;
    
    if (motionManager)
    {
        CMAccelerometerData *rawSample = motionManager.accelerometerData;
//        DLog(@"Raw X= %lf",rawSample.acceleration.x);
//        DLog(@"Raw Y= %lf",rawSample.acceleration.y);
//        DLog(@"Raw Z= %lf",rawSample.acceleration.z);
        
        processedSample = [KFBProcessedAccelerometerData processAcclerometerSample:rawSample];
    }
    return processedSample;
    
}

@end
