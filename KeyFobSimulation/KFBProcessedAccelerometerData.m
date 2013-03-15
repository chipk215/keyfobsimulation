//
//  KFBProcessedAccelerometerData.m
//  KeyFobSimulator
//
//  Created by Chip Keyes on 2/28/13.
//  Copyright (c) 2013 Chip Keyes. All rights reserved.
//

#import "KFBProcessedAccelerometerData.h"

@implementation KFBProcessedAccelerometerData

// Initializer for KFBProcessedAccelerometerData taking three signed bytes corresponding to triaxial accelerometer data
-(id)initWithComponentX: (signed char)x ComponentY:(signed char)y ComponentZ:(signed char)z
{
    self = [super init];
    
    if (self)
    {
        _componentX = [NSNumber numberWithChar:x];
        _componentY = [NSNumber numberWithChar:y];
        _componentZ = [NSNumber numberWithChar:z];
    }
    
    return self;
}


// Clips accelerometer data to +/1 1G.
+(float)clipSample : (float)sampleComponent
{
    float clipped = sampleComponent;
  
    if (clipped > 1.0)
    {
        clipped = 1.0;
    }
    else if (clipped < -1.0)
    {
        clipped = -1.0;
    }

return clipped;

}


// Clips and formats accelerometer data to byte representation.
+(KFBProcessedAccelerometerData *)processAcclerometerSample: (CMAccelerometerData *)sample
{
    float clippedX = [KFBProcessedAccelerometerData clipSample:sample.acceleration.x];
    float clippedY = [KFBProcessedAccelerometerData clipSample:sample.acceleration.y];
    float clippedZ = [KFBProcessedAccelerometerData clipSample:sample.acceleration.z];
    
    signed char magnitudeX = (signed char)(fabs(clippedX) * 127);
    signed char magnitudeY = (signed char)(fabs(clippedY) * 127);
    signed char magnitudeZ = (signed char)(fabs(clippedZ) * 127);
    
    if (clippedX < 0)
    {
        magnitudeX *= -1;
    }
    
    if (clippedY < 0)
    {
        magnitudeY *= -1;
    }
    
    if (clippedZ < 0)
    {
        magnitudeZ *= -1;
    }

    KFBProcessedAccelerometerData *processedSample = [[KFBProcessedAccelerometerData alloc]initWithComponentX:magnitudeX ComponentY:magnitudeY ComponentZ:magnitudeZ];
    
    return processedSample;
    
}

@end
