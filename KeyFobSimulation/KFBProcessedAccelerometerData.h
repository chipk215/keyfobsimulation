//
//  KFBProcessedAccelerometerData.h
//  KeyFobSimulator
//
//  Created by Chip Keyes on 2/28/13.
//  Copyright (c) 2013 Chip Keyes. All rights reserved.
//

#import <CoreMotion/CoreMotion.h>
#import <Foundation/Foundation.h>

@interface KFBProcessedAccelerometerData : NSObject


@property (nonatomic, readonly) NSNumber *componentX;
@property (nonatomic, readonly) NSNumber *componentY;
@property (nonatomic, readonly) NSNumber *componentZ;



+(KFBProcessedAccelerometerData *)processAcclerometerSample: (CMAccelerometerData *)sample;


@end
