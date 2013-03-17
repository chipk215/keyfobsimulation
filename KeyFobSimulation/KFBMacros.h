//
//  KFBMacros.h
//  KeyFobSimulator
//
//  Created by Chip Keyes on 3/8/13.
//  Copyright (c) 2013 Chip Keyes. All rights reserved.
//

#ifndef KeyFobSimulator_KFBMacros_h
#define KeyFobSimulator_KFBMacros_h

// Service UUIDs
#define IMMEDIATE_ALERT_SERVICE           @"1802"
#define Tx_POWER_SERVICE                  @"1804"
#define DEVICE_INFORMATION_SERVICE        @"180A"
#define BATTERY_SERVICE                   @"180F"
#define TI_KEYFOB_ACCELEROMETER_SERVICE   @"FFA0"
#define TI_SIMPLE_KEY_SERVICE_UUID        @"FFE0"

// Characteristic UUIDs
#define ALERT_LEVEL_CHARACTERISTIC                  @"2A06"
#define TRANSMIT_POWER_LEVEL_CHARACTERISTIC         @"2A07"
#define BATTERY_LEVEL_CHARACTERISTIC                @"2A19"
#define SYSTEM_ID_CHARACTERISTIC                    @"2A23"
#define MODEL_NUMBERCHARACTERISTIC                  @"2A24"
#define HARDWARE_REVISION_CHARACTERISTIC            @"2A25"
#define FIRMWARE_REVISION_CHARACTERISTIC            @"2A26"
#define SOFTWARE_REVISION_CHARACTERISTIC            @"2A28"
#define MANUFACTURER_NAME_CHARACTERISTIC            @"2A29" 
#define REGULATORY_CERTIFICATION_CHARACTERISTIC     @"2A2A"
#define PNP_ID_CHARACTERISTIC                       @"2A50"
#define TI_ENABLE_ACCELEROMETER             @"FFA1"
#define TI_ACCELEROMETER_RANGE              @"FFA2"
#define TI_ACCELEROMETER_X_VALUE            @"FFA3"
#define TI_ACCELEROMETER_Y_VALUE            @"FFA4"
#define TI_ACCELEROMETER_Z_VALUE            @"FFA5"
#define TI_TRIAXIAL_ACCELEROMETER_VALUES    @"FFAA"
#define KEY_PRESS_STATE_UUID                @"FFE1"

#define MANUFACTURER_CHARACTERISTIC_VALUE       @"MANUFACTURER NAME"
#define MODEL_NUMBER_CHARACTERISTIC_VALUE       @"MODEL NUMBER"
#define SERIAL_NUMBER_CHARACTERISTIC_VALUE      @"SERIAL NUMBER"
#define HARDWARE_NUMBER_CHARACTERISTIC_VALUE    @"HARDWARE REVISION"
#define FIRMWARE_NUMBER_CHARACTERISTIC_VALUE    @"FIRMWARE REVISION"
#define SOFTWARE_NUMBER_CHARACTERISTIC_VALUE    @"SOFTWARE REVISION"




// sample rate for acceleromter data, e.g 10 sample/second
#define SAMPLE_CLOCK_FREQUENCY_HERTZ 15

// encoded value for 2G dynamic range of accelerometer
#define DYNAMIC_RANGE_2G 20

// Low transmit power is -6dBM
#define TRANSMIT_LOW_POWER -6
// Hi transmit power is 0dBM
#define TRANSMIT_HIGH_POWER 0

#define LOW_TONE_FILE_NAME @"lobeep"
#define HI_TONE_FILE_NAME @"highbeep"
#define SOUND_FILE_TYPE @"mp3"

#define LEFT_SWITCH_PRESSED 0x01
#define RIGHT_SWITCH_PRESSED 0x02

#define HIGH_ALERT_VALUE 2
#define LOW_ALERT_VALUE  1
#define NO_ALERT_VALUE   0

#endif
