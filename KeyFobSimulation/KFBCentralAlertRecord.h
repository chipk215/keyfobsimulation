//
//  KFBCentralAlertRecord.h
//  KeyFobSimulator
//
//  Created by Chip Keyes on 3/8/13.
//  Copyright (c) 2013 Chip Keyes. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface KFBCentralAlertRecord : NSObject

// Central configuring alerts
@property (nonatomic, strong)CBCentral *central;


// current value of alert for central
@property(nonatomic, readwrite)unsigned char alertValue;


// Initializer for record
-(id)initWithCentral: (CBCentral *)central andAlertValue:(unsigned char)value;


@end
