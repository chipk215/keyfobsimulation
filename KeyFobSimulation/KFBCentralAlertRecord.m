//
//  KFBCentralAlertRecord.m
//  KeyFobSimulator
//
//  Created by Chip Keyes on 3/8/13.
//  Copyright (c) 2013 Chip Keyes. All rights reserved.
//

#import "KFBCentralAlertRecord.h"

@implementation KFBCentralAlertRecord

// Initializer for record
-(id)initWithCentral: (CBCentral *)central andAlertValue:(unsigned char)value
{
    self = [super init];
    if (self)
    {
        _central = central;
        _alertValue = value;
    }
    
    return self;
}
@end
