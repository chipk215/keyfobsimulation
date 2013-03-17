//
//  KFBViewController.m
//  KeyFobSimulator
//
//  Created by Chip Keyes on 2/26/13.
//  Copyright (c) 2013 Chip Keyes. All rights reserved.
//


#import "KFBViewController.h"
#import "KFBAccelerometer.h"
#import "KFBAudioPlayer.h"
#import "KFBLedController.h"
#import "KFBMacros.h"
#import "KFBCentralAlertRecord.h"


@interface KFBViewController () <AVAudioPlayerDelegate>

// Display transmit power level on UI
@property (weak, nonatomic) IBOutlet UILabel *transmitPowerLabel;

// tiny LED on tip of key fob
@property (weak, nonatomic) IBOutlet UIImageView *tinyYellowLed;

// handles blinking of the led
@property (strong, nonatomic)KFBLedController *ledController;

// Yellow LED images which indicate a button press on the UI
@property (weak, nonatomic) IBOutlet UIImageView *leftYellowLed;
@property (weak, nonatomic) IBOutlet UIImageView *rightYellowLed;

// peripheralManager property which manages advertising, connection state, etc.
@property (strong, nonatomic)CBPeripheralManager  *peripheralManager;

// key fob services & characteristics
@property (strong, nonatomic) CBMutableService * simpleKeyService;
@property (strong, nonatomic) CBMutableCharacteristic *keyPressed;

@property (strong, nonatomic) CBMutableService * batteryService;
@property (strong, nonatomic) CBMutableCharacteristic *batteryLevel;

@property (strong, nonatomic) CBMutableService * accelerometerService;
@property (strong, nonatomic) CBMutableCharacteristic *enableAccelerometer;
// dynamic range -- // Range is encoded: 2G = 20   8G= 80  --- It is configured in the fob firmware  to always be 20
@property (strong, nonatomic) CBMutableCharacteristic *accelerometerRange;
@property (strong, nonatomic) CBMutableCharacteristic *accelerometerX;
@property (strong, nonatomic) CBMutableCharacteristic *accelerometerY;
@property (strong, nonatomic) CBMutableCharacteristic *accelerometerZ;

// Custom 3 component accelerometer characteristic not supported by TI's Key Fob
@property (strong, nonatomic) CBMutableCharacteristic *accelerometerXYZ;


@property (strong, nonatomic) CBMutableService *transmitPowerService;
@property (strong, nonatomic) CBMutableCharacteristic *powerLevel;

// holds the current transmit power level, either 0dBm or -6dBm
@property (nonatomic, readwrite)signed char transmitPower;

//Immediate Alert Service
@property (strong, nonatomic) CBMutableService *immediateAlertService;
@property (strong, nonatomic) CBMutableCharacteristic *alertLevel;

// list of centrals which have programmed immediate alerts
@property (nonatomic, strong) NSMutableArray *centralsConfiguringAlerts;

// audio players for playing tones - may play simultaneously
@property (strong, nonatomic) KFBAudioPlayer *lowTonePlayer;
@property (strong, nonatomic) KFBAudioPlayer *highTonePlayer;

// Device Information Service
@property (strong, nonatomic) CBMutableService *deviceInformationService;
@property (strong, nonatomic) CBMutableCharacteristic *manufacturerName;
@property (strong, nonatomic) CBMutableCharacteristic *modelNumber;
@property (strong, nonatomic) CBMutableCharacteristic *serialNumber;
@property (strong, nonatomic) CBMutableCharacteristic *hardwareRevision;
@property (strong, nonatomic) CBMutableCharacteristic *firmwareRevision;
@property (strong, nonatomic) CBMutableCharacteristic *softwareRevision;
@property (strong, nonatomic) CBMutableCharacteristic *systemID;
@property (strong, nonatomic) CBMutableCharacteristic *reguatoryCertification;
@property (strong, nonatomic) CBMutableCharacteristic *pnpID;


// displays status of bluetooth adapater status for peripheralManager
@property (weak, nonatomic) IBOutlet UILabel *hostBluetoothStatus;

// switch which allows user to turn advertising on and off
@property (weak, nonatomic) IBOutlet UISwitch *advertiseSwitchControl;

// information key fob broadcasts when advertising
@property (strong, nonatomic) NSDictionary *keyFobAdvertisingDictionary;

// subscriber lists
@property (nonatomic, strong) NSMutableArray *keyPressedSubscribers;
@property (nonatomic, strong) NSMutableArray *batterySubscribers;
@property (nonatomic, strong) NSMutableArray *accelerometerXSubscribers;
@property (nonatomic, strong) NSMutableArray *accelerometerYSubscribers;
@property (nonatomic, strong) NSMutableArray *accelerometerZSubscribers;
@property (nonatomic, strong) NSMutableArray *accelerometerXYZSubscribers;


// timer which drives the sampling of accelerometer data
@property (nonatomic, strong) dispatch_source_t sampleClock;
@property (nonatomic,strong) dispatch_queue_t sampleQueue;
@property (nonatomic,strong) dispatch_queue_t transmitQueue;

// synchronizes requests to transmit notifications with the readiniess of the transmit buffer to receive data
@property (nonatomic, strong) dispatch_semaphore_t transmitQueueSemaphore;

// indicates communication channel is ready for more data
@property (nonatomic, readwrite) BOOL sendReady;

// state variables for key press buttons
@property (nonatomic,readwrite) BOOL rightButtonIsDown;
@property (nonatomic, readwrite) BOOL leftButtonIsDown;

// slider control used to set the battery level
@property (weak, nonatomic) IBOutlet UISlider *batterySlider;
@property (weak, nonatomic) IBOutlet UILabel *batteryLevelLabel;

// instrumentation counters

// number of transmits having to wait for transmit queue
@property (nonatomic, readwrite)NSUInteger delaySendCount;

// total number of transmits
@property (nonatomic, readwrite)NSUInteger transmitCount;


// control handlers
- (IBAction)batteryLevelSlider:(UISlider *)sender;
- (IBAction)rightButtonDown:(UIButton *)sender;
- (IBAction)leftButtonDown:(UIButton *)sender;
- (IBAction)rightButtonUp:(UIButton *)sender;
- (IBAction)leftButtonUp:(UIButton *)sender;
- (IBAction)advertiseSwitch:(UISwitch *)sender;


@end

@implementation KFBViewController


#pragma mark- Properties


// lazily initialize an led controler which controls blinking
-(KFBLedController *)ledController
{
    if (_ledController == nil)
    {
        _ledController = [[KFBLedController alloc] initWithImageView:self.tinyYellowLed initiallyOn:NO];
    }
    
    return _ledController;
}


// lazily initialize an audio player which plays a low fequency immediate alert tone
-(KFBAudioPlayer *)lowTonePlayer
{
    if (_lowTonePlayer == nil)
    {
        NSString *soundFilePath = [[NSBundle mainBundle] pathForResource:LOW_TONE_FILE_NAME ofType:SOUND_FILE_TYPE];
        NSURL *soundFileURL = [NSURL fileURLWithPath:soundFilePath];
        NSError *error;
        _lowTonePlayer = [[KFBAudioPlayer alloc] initWithContentsOfURL:soundFileURL error:&error];
        if (error)
        {
            DLog(@"Error creating low tone audio player: %@",error);
            
        }
         _lowTonePlayer.delegate = self;
    }
    
    return _lowTonePlayer;
}

//lazily initialize an audio player which plays a higher frequency immediate alert tone
-(KFBAudioPlayer *)highTonePlayer
{
    if (_highTonePlayer == nil)
    {
        NSString *soundFilePath = [[NSBundle mainBundle] pathForResource:HI_TONE_FILE_NAME ofType:SOUND_FILE_TYPE];
        NSURL *soundFileURL = [NSURL fileURLWithPath:soundFilePath];
        NSError *error;
        _highTonePlayer = [[KFBAudioPlayer alloc] initWithContentsOfURL:soundFileURL error:&error];
        if (error)
        {
            DLog(@"Error creating high tone audio player: %@",error);
            
        }
        _highTonePlayer.delegate = self;
    }
    
    return _highTonePlayer;
}


/*
 *
 * Method Name:  transmitQueueSemaphore
 *
 * Description:  Lazy intializer of semaphore.
 *
 *       Synchronizes notification transmit requests with availability of transmit queue.
 *       See the CBPeripheralManagerDelegate method peripheralManagerIsReadyToUpdateSubscribers: to see where semaphore is    signaled after a blocking wait. 
 *
 * Parameter(s): none
 *
 */
-(dispatch_semaphore_t) transmitQueueSemaphore
{
     if (! _transmitQueueSemaphore)
     {
         _transmitQueueSemaphore = dispatch_semaphore_create(1);
     }
    
    return _transmitQueueSemaphore;
}


// Lazily initialize a dispatch queue for sampling accelerometer data
-(dispatch_queue_t) sampleQueue
{
    if (! _sampleQueue)
    {
        _sampleQueue = dispatch_queue_create("sampleQueue", NULL);
    }
    return _sampleQueue;
}


// Lazily initialize a dispatch queue for sampling accelerometer data
-(dispatch_queue_t) transmitQueue
{
    if (! _transmitQueue)
    {
        _transmitQueue = dispatch_queue_create("transmitQueue", NULL);
    }
    return _transmitQueue;
}


/*
 *
 * Method Name:  sampleClock
 *
 * Description:  Obtains/pulls the latest accelerometer sample, processes the sample (clip, scale to byte) and sends to subscribers which have signed up for notifications.
 *
 *
 * Parameter(s): none
 *
 */
-(dispatch_source_t)sampleClock
{
    if (! _sampleClock)
    {
        _sampleClock = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0, 0, self.sampleQueue);
        
        dispatch_source_set_event_handler(_sampleClock, ^{
            
            dispatch_async(self.sampleQueue, ^{
                
                // Process the raw acclerometer data and transmit to subscribers
                KFBProcessedAccelerometerData *processedSample;
                processedSample = [KFBAccelerometer getProcessedAccelerometerSample];
                
                [self sendAccelerometerData:processedSample];
            });
        });
        
        dispatch_resume(_sampleClock);
    }
    return _sampleClock;
}


// Updates the UI label with battery level when slider moves
-(void)updateBatteryLevelLabel
{
    NSUInteger value = (NSUInteger) self.batterySlider.value;
    self.batteryLevelLabel.text = [NSString stringWithFormat:@"Battery Level: %u",value];
}


// Initializes the advertising dictionary with published services
-(NSDictionary *)keyFobAdvertisingDictionary
{
    if (_keyFobAdvertisingDictionary==nil)
    {
        NSArray * serviceUUIDs = [NSArray arrayWithObjects:self.simpleKeyService.UUID, self.accelerometerService.UUID, self.immediateAlertService.UUID, self.batteryService.UUID,  nil ];
        
        // value key, value key...
        _keyFobAdvertisingDictionary = [NSDictionary dictionaryWithObjectsAndKeys:serviceUUIDs,CBAdvertisementDataServiceUUIDsKey,@"Keyfobdemo",CBAdvertisementDataLocalNameKey, nil];
    }
    return _keyFobAdvertisingDictionary;
}


/*
 *
 * Method Name:  simpleKeyService
 *
 * Description:  Lazily initiate the simpleKeyService which exposes a single characteristic.
 *
 *               Provides notifications (no read) when keys/buttons are pressed or released.
 *
 * Parameter(s): None
 *
 */
-(CBMutableService *)simpleKeyService
{
    if (_simpleKeyService == nil)
    {
        CBUUID *uuid = [CBUUID UUIDWithString:TI_SIMPLE_KEY_SERVICE_UUID];
        _simpleKeyService = [[CBMutableService alloc] initWithType:uuid primary:YES];
        
        CBUUID *keyPressUUID = [CBUUID UUIDWithString:KEY_PRESS_STATE_UUID];
        _keyPressed = [[CBMutableCharacteristic alloc] initWithType:keyPressUUID
                                                         properties:CBCharacteristicPropertyNotify
                                                              value:nil
                                                        permissions:CBAttributePermissionsReadable];
        
        _simpleKeyService.characteristics = [NSArray arrayWithObject: _keyPressed];
        
        _leftButtonIsDown = NO;
        _rightButtonIsDown = NO;
        
        _keyPressedSubscribers = [NSMutableArray arrayWithCapacity:1];
        
        _centralsConfiguringAlerts = [NSMutableArray arrayWithCapacity:1];
    }
    return _simpleKeyService;
}


/*
 *
 * Method Name:  batteryService
 *
 * Description:  Lazily initialize batteryService which exposes a single characteristic.
 *
 *               Provides both notifications and read access to battery level. 
 *               The battery level is set with a slider on the UI.
 *
 * Parameter(s): None
 *
 */
-(CBMutableService *)batteryService
{
    if (_batteryService == nil)
    {
        CBUUID *uuid = [CBUUID UUIDWithString:BATTERY_SERVICE];
        _batteryService = [[CBMutableService alloc] initWithType:uuid primary:YES];
        
        CBUUID *batteryLevelUUID = [CBUUID UUIDWithString:BATTERY_LEVEL_CHARACTERISTIC];
        _batteryLevel= [[CBMutableCharacteristic alloc] initWithType:batteryLevelUUID
                                                          properties:(CBCharacteristicPropertyNotify + CBCharacteristicPropertyRead)
                                                               value:nil
                                                         permissions:CBAttributePermissionsReadable];
        
        _batteryService.characteristics = [NSArray arrayWithObject: _batteryLevel];
        
        _batterySubscribers = [NSMutableArray arrayWithCapacity:1];
    }
    
    return _batteryService;
}




/*
 *
 * Method Name:  accelerometerService
 *
 * Description:  Lazily initialize the accelerometer service which exposes six characteristics:
 *               
 *       enableAccelerometer - read/write characteristic which allows the client to turn the accelerometer on and off.
 *
 *       accelerometerRange - read only characteristic returning an encoded value representing the dynamic range of the acclerometer. Like the key fob, this characteristic always returns 20 which corresponds to a dynamic range of 2G (+/- 1G).
 *
 *       accelerometerX - notification (no read) of accelerometer x-axis value
 *
 *       accelerometerY - notification (no read) of accelerometer y-axis value
 *
 *       accelerometerZ - notification (no read) of accelerometer z-axis value
 *
 *       accelerometerXYZ - this characteristic is not supported the the key fob firmware. It returns all three acclerometer components in a single characteristic. It is accessible only via notifications.
 *       
 *
 * Parameter(s): None
 *
 */
-(CBMutableService *)accelerometerService
{
    if (_accelerometerService == nil)
    {
        CBUUID *uuid = [CBUUID UUIDWithString:TI_KEYFOB_ACCELEROMETER_SERVICE];
        _accelerometerService = [[CBMutableService alloc] initWithType:uuid primary:YES];
        
        CBUUID *enableAcccelerometerUUID = [CBUUID UUIDWithString:TI_ENABLE_ACCELEROMETER];
        _enableAccelerometer= [[CBMutableCharacteristic alloc] initWithType:enableAcccelerometerUUID
                                                          properties:(CBCharacteristicPropertyWrite + CBCharacteristicPropertyRead)
                                                               value:nil
                                                         permissions:(CBAttributePermissionsReadable + CBAttributePermissionsWriteable)];
        
        // This is TI's implementation and encoding for the dynamic range of the acccelerometer
        signed char rangeValue[2];
        rangeValue[0] = DYNAMIC_RANGE_2G;
        rangeValue[1] = 0;
        NSData *rangeData = [NSData dataWithBytes:rangeValue length:2];
        CBUUID *acccelerometerRangeUUID = [CBUUID UUIDWithString:TI_ACCELEROMETER_RANGE];
        _accelerometerRange = [[CBMutableCharacteristic alloc] initWithType:acccelerometerRangeUUID
                                                                 properties:CBCharacteristicPropertyRead
                                                                      value:rangeData
                                                                permissions:CBAttributePermissionsReadable];

        
        
        CBUUID *acccelerometerXUUID = [CBUUID UUIDWithString:TI_ACCELEROMETER_X_VALUE];
        _accelerometerX= [[CBMutableCharacteristic alloc] initWithType:acccelerometerXUUID
                                                          properties:CBCharacteristicPropertyNotify
                                                               value:nil
                                                         permissions:CBAttributePermissionsReadable];
        
        
        CBUUID *acccelerometerYUUID = [CBUUID UUIDWithString:TI_ACCELEROMETER_Y_VALUE];
        _accelerometerY= [[CBMutableCharacteristic alloc] initWithType:acccelerometerYUUID
                                                            properties:CBCharacteristicPropertyNotify
                                                                 value:nil
                                                           permissions:CBAttributePermissionsReadable];
        
        CBUUID *acccelerometerZUUID = [CBUUID UUIDWithString:TI_ACCELEROMETER_Z_VALUE];
        _accelerometerZ= [[CBMutableCharacteristic alloc] initWithType:acccelerometerZUUID
                                                            properties:CBCharacteristicPropertyNotify 
                                                                 value:nil
                                                           permissions:CBAttributePermissionsReadable];
        
        
        CBUUID *acccelerometerXYZUUID = [CBUUID UUIDWithString:TI_TRIAXIAL_ACCELEROMETER_VALUES];
        _accelerometerXYZ= [[CBMutableCharacteristic alloc] initWithType:acccelerometerXYZUUID
                                                            properties:CBCharacteristicPropertyNotify
                                                                 value:nil
                                                           permissions:CBAttributePermissionsReadable];
        
        _accelerometerService.characteristics = [NSArray arrayWithObjects:_enableAccelerometer,
                                                 _accelerometerRange,_accelerometerX, _accelerometerY,
                                                 _accelerometerZ, _accelerometerXYZ,nil];
        
        
        _accelerometerXSubscribers = [NSMutableArray arrayWithCapacity:1];
        _accelerometerYSubscribers = [NSMutableArray arrayWithCapacity:1];
        _accelerometerZSubscribers = [NSMutableArray arrayWithCapacity:1];
        _accelerometerXYZSubscribers = [NSMutableArray arrayWithCapacity:1];
        
    }
    return _accelerometerService;
}


/*
 *
 * Method Name:  transmitPowerService
 *
 * Description:  Lazily initialize the transmitPowerService which exposes a single read only characteristic communicating the transmit power of the server. The key fob can switch between 0dBM and -6 dBM which is simulated in this service. Switching of transmit power is accomplished via the left key/button as implemeneted in the key fob.
 *
 * Parameter(s): None
 *
 */
-(CBMutableService *)transmitPowerService
{
    if (_transmitPowerService == nil)
    {
        CBUUID *uuid = [CBUUID UUIDWithString:Tx_POWER_SERVICE];
        _transmitPowerService = [[CBMutableService alloc] initWithType:uuid primary:YES];
        
        CBUUID *powerLevelUUID = [CBUUID UUIDWithString:TRANSMIT_POWER_LEVEL_CHARACTERISTIC];
        _powerLevel = [[CBMutableCharacteristic alloc] initWithType:powerLevelUUID
                                                         properties:CBCharacteristicPropertyRead
                                                              value:nil
                                                        permissions:CBAttributePermissionsReadable];
        
        _transmitPowerService.characteristics = [NSArray arrayWithObjects:_powerLevel,nil];
        _transmitPower = TRANSMIT_HIGH_POWER;
    }
    
    return _transmitPowerService;
}


/*
 *
 * Method Name:  immediateAlertService
 *
 * Description:  Enables the immediate alert and provides a characteristic for selecting
 // high and low frequency alert tones
 *
 * Parameter(s): none
 *
 */
-(CBMutableService *)immediateAlertService
{
    if (_immediateAlertService == nil)
    {
        CBUUID *uuid = [CBUUID UUIDWithString:IMMEDIATE_ALERT_SERVICE];
        _immediateAlertService = [[CBMutableService alloc] initWithType:uuid primary:YES];
        
        CBUUID *alertLevelUUID = [CBUUID UUIDWithString:ALERT_LEVEL_CHARACTERISTIC];
        _alertLevel = [[CBMutableCharacteristic alloc] initWithType:alertLevelUUID
                                                         properties:CBCharacteristicPropertyWrite
                                                              value:nil
                                                        permissions:(CBAttributePermissionsReadable + CBAttributePermissionsWriteable)];
        
        _immediateAlertService.characteristics = [NSArray arrayWithObjects:_alertLevel,nil];
    }
    return _immediateAlertService;
}


#define SYSTEM_ID_LENGTH 8
// Helper method which generates a fake system ID
-(NSData *)getSystemData
{
    unsigned char systemIDBytes[SYSTEM_ID_LENGTH] = {0x12, 0x34, 0x56, 0xFF, 0xFE, 0x9A,0xBC,  0xDE};
    
    return [NSData dataWithBytes:(const void *)systemIDBytes length:SYSTEM_ID_LENGTH];
}


#define REGULATORY_LIST_LENGTH 14
// Helper method which generates regulatory data returned by key fob
-(NSData *)getRegulatoryData
{
    unsigned char regulatoryBytes[REGULATORY_LIST_LENGTH] = {0xFE, 0x00, 0x65, 0x78, 0x70, 0x65, 0x72, 0x69, 0x6D, 0x65, 0x6E, 0x74, 0x61, 0x6C};
    
    return [NSData dataWithBytes:(const void *)regulatoryBytes length:REGULATORY_LIST_LENGTH];
}


#define PNP_LENGTH 7
// Helper method which generates PNP data returned by key fob
-(NSData *)getPNPData
{
    unsigned char pnpBytes[PNP_LENGTH] = {0x01, 0x0D, 0x00, 0x00, 0x00, 0x10, 0x01};
    
    return [NSData dataWithBytes:(const void *)pnpBytes length:PNP_LENGTH];
}

/*
 *
 * Method Name:  deviceInformationService
 *
 * Description:  Defines the Device Information Service and characteristics
 *
 * Parameter(s): none
 *
 */
-(CBMutableService *)deviceInformationService
{
    if (_deviceInformationService == nil)
    {
        CBUUID *uuid = [CBUUID UUIDWithString:DEVICE_INFORMATION_SERVICE];
        _deviceInformationService = [[CBMutableService alloc]initWithType:uuid primary:YES];
        
        CBUUID *manufacturerUUID = [CBUUID UUIDWithString:MANUFACTURER_NAME_CHARACTERISTIC];
        NSData *manufacturerData = [MANUFACTURER_CHARACTERISTIC_VALUE dataUsingEncoding:NSUTF8StringEncoding];
        _manufacturerName = [[CBMutableCharacteristic alloc] initWithType:manufacturerUUID
                                                               properties:CBCharacteristicPropertyRead
                                                                    value:manufacturerData
                                                              permissions:CBAttributePermissionsReadable];
        
        CBUUID *modelUUID = [CBUUID UUIDWithString:MODEL_NUMBERCHARACTERISTIC];
        NSData *modelData = [MODEL_NUMBER_CHARACTERISTIC_VALUE dataUsingEncoding:NSUTF8StringEncoding];
        _modelNumber = [[CBMutableCharacteristic alloc] initWithType:modelUUID
                                                               properties:CBCharacteristicPropertyRead
                                                                    value:modelData
                                                              permissions:CBAttributePermissionsReadable];
        
        CBUUID *serialUUID = [CBUUID UUIDWithString:MODEL_NUMBERCHARACTERISTIC];
        NSData *serialData = [MODEL_NUMBER_CHARACTERISTIC_VALUE dataUsingEncoding:NSUTF8StringEncoding];
        _serialNumber = [[CBMutableCharacteristic alloc] initWithType:serialUUID
                                                          properties:CBCharacteristicPropertyRead
                                                               value:serialData
                                                         permissions:CBAttributePermissionsReadable];

        CBUUID *hardwareUUID = [CBUUID UUIDWithString:HARDWARE_REVISION_CHARACTERISTIC];
        NSData *hardwareData = [HARDWARE_NUMBER_CHARACTERISTIC_VALUE dataUsingEncoding:NSUTF8StringEncoding];
        _hardwareRevision = [[CBMutableCharacteristic alloc] initWithType:hardwareUUID
                                                           properties:CBCharacteristicPropertyRead
                                                                value:hardwareData
                                                          permissions:CBAttributePermissionsReadable];
        
        CBUUID *softwareUUID = [CBUUID UUIDWithString:SOFTWARE_REVISION_CHARACTERISTIC];
        NSData *softwareData = [SOFTWARE_NUMBER_CHARACTERISTIC_VALUE dataUsingEncoding:NSUTF8StringEncoding];
        _softwareRevision = [[CBMutableCharacteristic alloc] initWithType:softwareUUID
                                                               properties:CBCharacteristicPropertyRead
                                                                    value:softwareData
                                                              permissions:CBAttributePermissionsReadable];
        
        CBUUID *firmwareUUID = [CBUUID UUIDWithString:FIRMWARE_REVISION_CHARACTERISTIC];
        NSData *firmwareData = [FIRMWARE_NUMBER_CHARACTERISTIC_VALUE dataUsingEncoding:NSUTF8StringEncoding];
        _firmwareRevision = [[CBMutableCharacteristic alloc] initWithType:firmwareUUID
                                                               properties:CBCharacteristicPropertyRead
                                                                    value:firmwareData
                                                              permissions:CBAttributePermissionsReadable];
        
        
        CBUUID *systemUUID = [CBUUID UUIDWithString:SYSTEM_ID_CHARACTERISTIC];
        NSData *systemData = [self getSystemData];
        _systemID = [[CBMutableCharacteristic alloc] initWithType:systemUUID
                                                               properties:CBCharacteristicPropertyRead
                                                                    value:systemData
                                                              permissions:CBAttributePermissionsReadable];
        
        CBUUID *regulatoryUUID = [CBUUID UUIDWithString:REGULATORY_CERTIFICATION_CHARACTERISTIC];
        NSData *regulatoryData = [self getRegulatoryData];
        _reguatoryCertification = [[CBMutableCharacteristic alloc] initWithType:regulatoryUUID
                                                       properties:CBCharacteristicPropertyRead
                                                            value:regulatoryData
                                                      permissions:CBAttributePermissionsReadable];
        
        
        CBUUID *pnpUUID = [CBUUID UUIDWithString:PNP_ID_CHARACTERISTIC];
        NSData *pnpData = [self getPNPData];
        _pnpID = [[CBMutableCharacteristic alloc] initWithType:pnpUUID
                                                    properties:CBCharacteristicPropertyRead
                                                         value:pnpData
                                                    permissions:CBAttributePermissionsReadable];
        
      
        _deviceInformationService.characteristics =  [NSArray arrayWithObjects:_manufacturerName,
                                                      _modelNumber, _serialNumber, _hardwareRevision,
                                                      _softwareRevision, _firmwareRevision, _systemID,
                                                      _reguatoryCertification, _pnpID, nil];
        
    }
    
    return _deviceInformationService;
}


//Initializes peripheral manager
-(CBPeripheralManager *)peripheralManager
{
    if (_peripheralManager == nil)
    {
        _peripheralManager = [[CBPeripheralManager alloc]initWithDelegate:self queue:nil];
    }
    return _peripheralManager;
}


#pragma mark- Controller Lifecycle

// Set up view controller 
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.transmitPowerLabel.text = [NSString stringWithFormat:@"Transmit Power= %u dBm",self.transmitPower];
    
    self.sendReady = YES;
    
    self.delaySendCount=0;
    self.transmitCount=0;
    
    [self updateBatteryLevelLabel];
    
	[self.peripheralManager addService:self.simpleKeyService];
    [self.peripheralManager addService:self.batteryService];
    [self.peripheralManager addService:self.accelerometerService];
    [self.peripheralManager addService:self.transmitPowerService];
    [self.peripheralManager addService:self.immediateAlertService];
    [self.peripheralManager addService:self.deviceInformationService];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [KFBAccelerometer stopAccelerometerUpdates];    
}


#pragma mark- Actions

// Handler for slider which sets battery level
- (IBAction)batteryLevelSlider:(UISlider *)sender
{
    [self updateBatteryLevelLabel];
    [self sendBatteryData];
}

// Handler for right button down action
- (IBAction)rightButtonDown:(UIButton *)sender
{
    self.rightButtonIsDown = YES;
    self.rightYellowLed.hidden = NO;
    [self sendKeyPressData];
    
    DLog(@"Transmit Count= %u",self.transmitCount);
    DLog(@"Delay Send Count= %u",self.delaySendCount);
    
}

/*
 *
 * Method Name:  leftButtonDown
 *
 * Description:  Handler for left button on the UI which corresponds to the left key on the key fob.
 *
 *
 *           Key fob left key functionality has been implemented to change the transmission power and turn off immediate alerts.
 *
 * Parameter(s): sender - the button control associated with the touch down event.
 *
 */
- (IBAction)leftButtonDown:(UIButton *)sender
{
    self.leftButtonIsDown = YES;
    self.leftYellowLed.hidden = NO;
    [self sendKeyPressData];
    
    // terminate active immediate alerts
    [self.ledController hide];
    if (self.lowTonePlayer.isPlaying)
    {
        [self.lowTonePlayer stop];
    }
    
    // the left key on the TI key fob also toggles the transmit power
    if (self.transmitPower == TRANSMIT_HIGH_POWER)
    {
        self.transmitPower = TRANSMIT_LOW_POWER;
    }
    else
    {
        self.transmitPower = TRANSMIT_HIGH_POWER;
    }
    
    self.transmitPowerLabel.text = [NSString stringWithFormat:@"Transmit Power= %d dBm",_transmitPower];
}


// Handler for right button up
- (IBAction)rightButtonUp:(UIButton *)sender
{
    self.rightButtonIsDown = NO;
    self.rightYellowLed.hidden = YES;
    [self sendKeyPressData];
}


// Handler for left button up
- (IBAction)leftButtonUp:(UIButton *)sender
{
    self.leftButtonIsDown = NO;
    self.leftYellowLed.hidden = YES;
    [self sendKeyPressData];
}


// Turn advertising on and off
- (IBAction)advertiseSwitch:(UISwitch *)sender
{
    if (sender.on)
    {
        DLog(@"Advertising");
        [self.peripheralManager startAdvertising:self.keyFobAdvertisingDictionary];
    }
    else
    {
        DLog(@"Stop Advertising");
        [self.peripheralManager stopAdvertising];
    }
}


#pragma mark- Private Methods

// Converts CBCentralManagerState to a string... implement as a category on CBCentralManagerState?
+(NSString *)getCBPeripheralStateName:(CBPeripheralManagerState) state
{
    NSString *stateName;
    
    switch (state) {
        case CBPeripheralManagerStatePoweredOn:
            stateName = @"Bluetooth Powered On - Ready";
            
            break;
        case CBPeripheralManagerStateResetting:
            stateName = @"Resetting";
            break;
            
        case CBPeripheralManagerStateUnsupported:
            stateName = @"Unsupported";
            break;
            
        case CBPeripheralManagerStateUnauthorized:
            stateName = @"Unauthorized";
            break;
            
        case CBPeripheralManagerStatePoweredOff:
            stateName = @"Bluetooth Powered Off";
            break;
            
        default:
            stateName = @"Unknown";
            break;
    }
    return stateName;
}



/*
 *
 * Method Name:  getSwitchData
 *
 * Description:  Encodes switch postion into a byte structure.
 *               Left switch positon is bit 0.
 *               Right switch positon is bit 1.
 *
 * Parameter(s): none
 *
 */
-(NSData *)getSwitchData
{
    NSData *switchData;
    unsigned char switchPositions = 0;
    
    if (self.leftButtonIsDown)
    {
        switchPositions = switchPositions | LEFT_SWITCH_PRESSED;
    }
    
    if (self.rightButtonIsDown)
    {
        switchPositions = switchPositions | RIGHT_SWITCH_PRESSED;
    }
    
    switchData = [NSData dataWithBytes:(const void *)&switchPositions length:1];
    
    return switchData;
}



// Logging Helper
-(void)logSentKeyPressedData:( const uint8_t *)reportData
{
    NSUInteger switchPosition = reportData[0];
    if (switchPosition & LEFT_SWITCH_PRESSED)
    {
        DLog(@"Left Switch Pressed");
    }
    if (switchPosition & RIGHT_SWITCH_PRESSED)
    {
        DLog(@"Right Switch Pressed");
    }
    if (switchPosition == 0)
    {
        DLog(@"Neither Switch Pressed");
    }
}



/*
 *
 * Method Name:  transmit
 *
 * Description:  Transmits notification data synching with transmit queue.
 *
 * Parameter(s): transmitData - data to send
 *               characteristic - characteristic sending notification
 *
 */
-(void)transmit:(NSData *)transmitData forCharacteristic: (CBMutableCharacteristic *)characteristic onSubscribedCentrals:(NSArray *)subscribers
{
    
    dispatch_async(self.transmitQueue, ^{
        
    BOOL sent = NO;
    
    do
    {
        dispatch_semaphore_wait(self.transmitQueueSemaphore, DISPATCH_TIME_FOREVER);
        self.sendReady = [self.peripheralManager updateValue:transmitData forCharacteristic:characteristic onSubscribedCentrals:subscribers];
        if (self.sendReady)
        {
            dispatch_semaphore_signal(self.transmitQueueSemaphore);
            sent = YES;
            self.transmitCount +=1;
        }
        else
        {
            DLog(@"Delay transmitting...");
            self.delaySendCount+=1;
        }
    } while (! sent);
    
    });
}


/*
 *
 * Method Name:  sendKeyPressData
 *
 * Description:  Packages key press data into an NSData object and sends to all subscribing Centrals.
 *
 * Parameter(s): none
 *
 */
- (void)sendKeyPressData
{
    DLog(@"Entering sendKeyPressData");
    if ([self.keyPressedSubscribers count] > 0 )
    {
        NSData *transmitData = [self getSwitchData];
        [self transmit:transmitData forCharacteristic:self.keyPressed onSubscribedCentrals:self.keyPressedSubscribers];
    }
}


/*
 *
 * Method Name:  sendAccelerometerData
 *
 * Description:  Sends three separate notifications to a subscribed Central corresponding to X,Y,and Z accelerometer characteristics.
 *   Every data item is transmitted, even if transmitting requires wating on the transmit queue to become ready.
 *
 * Parameter(s): processedSample - the accelerometer components to transmit
 *
 */
-(void)sendAccelerometerData:(KFBProcessedAccelerometerData *)processedSample
{
       
    DLog(@"Entering sendAcclerometerData");
    
    if ([self.accelerometerXYZSubscribers count] > 0)
    {
        signed char byte[3];
        byte[0] = [processedSample.componentX charValue];
        byte[1] = [processedSample.componentY charValue];
        byte[2] = [processedSample.componentZ charValue];
        
        NSData *transmitData;
        transmitData = [NSData dataWithBytes:byte length:3];
        [self transmit:transmitData forCharacteristic:self.accelerometerXYZ onSubscribedCentrals:self.accelerometerXYZSubscribers];
    }

    if ([self.accelerometerXSubscribers count] > 0)
    {
        signed char byte;
        byte = [processedSample.componentX charValue];
        
        NSData *transmitData;
        transmitData = [NSData dataWithBytes:&byte length:1];
        [self transmit:transmitData forCharacteristic:self.accelerometerX onSubscribedCentrals:self.accelerometerXSubscribers];
        
    }
    
     if ([self.accelerometerYSubscribers count] > 0)
    {
        signed char byte;
        byte = [processedSample.componentY charValue];
        
        NSData *transmitData;
        transmitData = [NSData dataWithBytes:&byte length:1];
        [self transmit:transmitData forCharacteristic:self.accelerometerY onSubscribedCentrals:self.accelerometerYSubscribers];
    }
    
    if ([self.accelerometerZSubscribers count] > 0)
    {
        signed char byte;
        byte = [processedSample.componentZ charValue];
        
        NSData *transmitData;
        transmitData = [NSData dataWithBytes:&byte length:1];
        [self transmit:transmitData forCharacteristic:self.accelerometerZ onSubscribedCentrals:self.accelerometerZSubscribers];
    }
}



/*
 *
 * Method Name:  sendBatteryData
 *
 * Description:  Packages battery level value into an NSData object and sends to all subscribing Centrals.
 *
 * Parameter(s): none
 *
 */
-(void)sendBatteryData
{
     DLog(@"Entering sendBatteryData");
    if ([self.batterySubscribers count] > 0 )
    {
        NSData *transmitData;
        unsigned char data = (unsigned char)self.batterySlider.value;
        transmitData = [NSData dataWithBytes:&data length:1];
        [self transmit:transmitData forCharacteristic:self.batteryLevel onSubscribedCentrals:self.batterySubscribers];
    }
}

/*
 *
 * Method Name:  isCentral:currentlySubscribedIn:subscriberList
 *
 * Description:  Determines if the Central provided as an argument is contained in the specified subscriberList.
 *
 *               Returns YES if already subscribed, otherwise NO
 *
 * Parameter(s): central - the central to check on.
 *               subscriberList - the list to check against
 *
 */
-(BOOL)isCentral: (CBCentral *)central currentlySubscribedIn:(NSArray *)subscriberList
{
    BOOL alreadySubscribed = NO;
    for ( CBCentral *centralSubscriber in subscriberList)
    {
        if (central.UUID  &&  CFEqual(central.UUID,centralSubscriber.UUID ))
        {
            alreadySubscribed = YES;
            break;
        }
    }
    
    return alreadySubscribed;
}



/*
 *
 * Method Name:  getRecordForCentral
 *
 * Description:  Returns the record in the list corresponding to the central passed in by argument.
 *               If corresponding record not found then return nil.
 *
 * Parameter(s): central - the central to look for.
 *
 */
-(KFBCentralAlertRecord *)getRecordForCentral: (CBCentral *)central 
{
    KFBCentralAlertRecord *record = nil;
   
    for ( KFBCentralAlertRecord *centralRecord in self.centralsConfiguringAlerts)
    {
        if (central.UUID  &&  CFEqual(central.UUID,centralRecord.central.UUID ))
        {
            record = centralRecord;
            break;
        }
    }
    return record;
}


/*
 *
 * Method Name:  isToneActive
 *
 * Description:  Iterates through centralsConfiguringAlerts list to determine if any centrals have the corresponding tone enabled
 *
 * Parameter(s): alertValue - the alert tone value to look for (none, lo, hi)
 *
 */
-(BOOL)isToneActive:(unsigned char)alertValue
{
    BOOL returnValue = NO;
    
    for ( KFBCentralAlertRecord *centralRecord in self.centralsConfiguringAlerts)
    {
        if (centralRecord.alertValue == alertValue)
        {
            returnValue = YES;
            break;
        }
    }
    return returnValue;
}


/*
 *
 * Method Name:  removeSubscriber:fromList
 *
 * Description:  Remove the specified central from the specified subscriber list if the central is contained in the list.
 *
 * Parameter(s): central - the subscriber to remove.
 *               subscriberList - the subscriber list to check
 *
 */
-(void)removeSubscriber: (CBCentral *)central fromList:(NSMutableArray *)subscriberList
{
    BOOL matchFound = NO;
    NSUInteger index=0;
    for ( CBCentral *centralSubscriber in subscriberList)
    {
        if (central.UUID  &&  CFEqual(central.UUID,centralSubscriber.UUID ))
        {
            matchFound = YES;
            break;
        }
        else
        {
            index+=1;
        }
    }
    
    if (matchFound)
    {
        [subscriberList removeObjectAtIndex:index];
    }
    
}


#pragma mark- CBPeripheralManagerDelegate Protocol Methods


// Ensure Bluetooth on device is available and powered on.
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheralManager
{
    DLog(@"Peripheral Manager Delegate DidUpdate State Invoked");
    
    if (peripheralManager.state ==CBCentralManagerStatePoweredOn)
    {
        self.hostBluetoothStatus.textColor = [UIColor greenColor];
        
        self.advertiseSwitchControl.enabled = YES;
    }
    else if ( (peripheralManager.state == CBPeripheralManagerStateUnknown) ||
             (peripheralManager.state == CBPeripheralManagerStateResetting) )
    {
        self.hostBluetoothStatus.textColor = [UIColor blackColor];
        self.advertiseSwitchControl.enabled = NO;
    }
    else
    {
        self.hostBluetoothStatus.textColor = [UIColor redColor];
        self.advertiseSwitchControl.enabled = NO;
    }
    
    self.hostBluetoothStatus.text = [[self class ] getCBPeripheralStateName: peripheralManager.state];
}



//Catch when someone subscribes to our characteristic, then start sending them data
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
   
    DLog(@"Central subscribed to characteristic");
    if ([characteristic.UUID isEqual:self.keyPressed.UUID])
    {
        BOOL alreadySubscribed = [self isCentral:central currentlySubscribedIn:self.keyPressedSubscribers ];
        
        if (! alreadySubscribed)
        {
            [self.keyPressedSubscribers addObject:central];
        }
    }
    else if ([characteristic.UUID isEqual:self.batteryLevel.UUID])
    {
        BOOL alreadySubscribed = [self isCentral:central currentlySubscribedIn:self.batterySubscribers ];
        
        if (! alreadySubscribed)
        {
            [self.batterySubscribers addObject:central];
        }
    }
    else if ([characteristic.UUID isEqual:self.accelerometerX.UUID])
    {
        DLog(@"Have X Component Subscriber");
        BOOL alreadySubscribed = [self isCentral:central currentlySubscribedIn:self.accelerometerXSubscribers ];
        
        if (! alreadySubscribed)
        {
            [self.accelerometerXSubscribers addObject:central];
        }
        
    }
    else if ([characteristic.UUID isEqual:self.accelerometerY.UUID])
    {
        DLog(@"Have Y Component Subscriber");
        BOOL alreadySubscribed = [self isCentral:central currentlySubscribedIn:self.accelerometerYSubscribers ];
        
        if (! alreadySubscribed)
        {
            [self.accelerometerYSubscribers addObject:central];
        }
    }
    else if ([characteristic.UUID isEqual:self.accelerometerZ.UUID])
    {
        DLog(@"Have Z Component Subscriber");
        BOOL alreadySubscribed = [self isCentral:central currentlySubscribedIn:self.accelerometerZSubscribers ];
        
        if (! alreadySubscribed)
        {
            [self.accelerometerZSubscribers addObject:central];
        }
    }
    else if ([characteristic.UUID isEqual:self.accelerometerXYZ.UUID])
    {
        DLog(@"Have XYZ Component Subscriber");
        BOOL alreadySubscribed = [self isCentral:central currentlySubscribedIn:self.accelerometerXYZSubscribers ];
        
        if (! alreadySubscribed)
        {
            [self.accelerometerXYZSubscribers addObject:central];
        }
    }
}




// Recognise when the central unsubscribes
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    DLog(@"Central unsubscribed from characteristic");
    if ([characteristic.UUID isEqual:self.keyPressed.UUID])
    {
        [self removeSubscriber:central fromList:self.keyPressedSubscribers];
    }
    else if ([characteristic.UUID isEqual:self.batteryLevel.UUID])
    {
        [self removeSubscriber:central fromList:self.batterySubscribers];
    }
    else if ([characteristic.UUID isEqual:self.accelerometerX.UUID])
    {
        [self removeSubscriber:central fromList:self.accelerometerXSubscribers];
    }
    else if ([characteristic.UUID isEqual:self.accelerometerY.UUID])
    {
        [self removeSubscriber:central fromList:self.accelerometerYSubscribers];
    }
    else if ([characteristic.UUID isEqual:self.accelerometerZ.UUID])
    {
        [self removeSubscriber:central fromList:self.accelerometerZSubscribers];
    }
    else if ([characteristic.UUID isEqual:self.accelerometerXYZ.UUID])
    {
        [self removeSubscriber:central fromList:self.accelerometerXYZSubscribers];
    }

}


/*!
 *  @method peripheralManager:didReceiveReadRequest:
 *
 *  @param peripheral   The peripheral manager requesting this information.
 *  @param request      A <code>CBATTRequest</code> object.
 *
 *  @discussion         This method is invoked when <i>peripheral</i> receives an ATT request for a characteristic with a dynamic value.
 *                      For every invocation of this method, @link respondToRequest:withResult: @/link must be called.
 *
 *  @see                CBATTRequest
 *
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
    DLog(@"didReceiveReadRequest Invoked");
    
    if ([request.characteristic.UUID isEqual:self.batteryLevel.UUID])
    {
    
        NSData *transmitData;
        unsigned char data = (unsigned char)self.batterySlider.value;
    
        transmitData = [NSData dataWithBytes:&data length:1];
    
        request.value = transmitData;
    
        [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
    }
    else if ([request.characteristic.UUID isEqual:self.enableAccelerometer.UUID])
    {
        BOOL isEnabled = [KFBAccelerometer isEnabled];
        unsigned char data = isEnabled ? 1:0;
        NSData *transmitData;
        transmitData = [NSData dataWithBytes:&data length:1];
        request.value = transmitData;
        
        [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
    }
    else if ([request.characteristic.UUID isEqual:self.powerLevel.UUID])
    {
        NSData *transmitData;
        signed char data = self.transmitPower;
        transmitData = [NSData dataWithBytes:&data length:1];
        request.value = transmitData;
        [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
    }
    
}


/*!
 *  @method peripheralManager:didReceiveWriteRequests:
 *
 *  @param peripheral   The peripheral manager requesting this information.
 *  @param requests     A list of one or more <code>CBATTRequest</code> objects.
 *
 *  @discussion         This method is invoked when <i>peripheral</i> receives an ATT request or command for one or more characteristics with a dynamic value.
 *                      For every invocation of this method, @link respondToRequest:withResult: @/link should be called exactly once. If <i>requests</i> contains
 *                      multiple requests, they must be treated as an atomic unit. If the execution of one of the requests would cause a failure, the request
 *                      and error reason should be provided to <code>respondToRequest:withResult:</code> and none of the requests should be executed.
 *
 *  @see                CBATTRequest
 *
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
    CBATTRequest * returnRequest;
    CBATTError returnError = CBATTErrorRequestNotSupported;
    for (CBATTRequest * request in requests)
    {
        if ([request.characteristic.UUID isEqual:self.enableAccelerometer.UUID])
        {
            DLog(@"Did receive enable accelerometer request");
            returnRequest = request;
            NSData *value = request.value;
            unsigned char data;
            [value getBytes:&data length:1];
            returnError = CBATTErrorSuccess;
            if (data)
            {
                [KFBAccelerometer startAccelerometerUpdates];
                dispatch_source_set_timer(self.sampleClock, DISPATCH_TIME_NOW, 1ull * NSEC_PER_SEC / SAMPLE_CLOCK_FREQUENCY_HERTZ, 1ull * NSEC_PER_SEC/100);
            }
            else
            {
                dispatch_source_cancel(self.sampleClock);
                self.sampleClock = nil;
                [KFBAccelerometer stopAccelerometerUpdates];
            }
        }
        
        if ( [request.characteristic.UUID isEqual:self.alertLevel.UUID])
        {
            DLog(@"Did receive immediate alert request");
            // process immediate alert request
            //  value 0 - no alert 
            //  value 1 - low alert for 10 seconds or until a left button press
            //  value 2 - high alert for 10 seconds or until a left button press
            returnRequest = request;
            
            NSData *value = request.value;
            unsigned char data;
            [value getBytes:&data length:1];
            returnError = CBATTErrorSuccess;
            KFBCentralAlertRecord *record  = [self getRecordForCentral:request.central];
            if (record != nil)
            {
                record.alertValue = data;
            }
            else
            {
                // create an alert record
                record = [[KFBCentralAlertRecord alloc]initWithCentral:request.central
                                                         andAlertValue:data];
                
            }
            
            if (data ==  NO_ALERT_VALUE)
            {
                // DLog(@"Received request to turn off immediate alert");
                // do any centrals currently have an alert configured for a low tone
                BOOL haveActiveLowTone = [self isToneActive:LOW_ALERT_VALUE];
                if (! haveActiveLowTone)
                {
                    [self.lowTonePlayer stop];
                }
                BOOL haveActiveHighTone = [self isToneActive:HIGH_ALERT_VALUE];
                if (! haveActiveHighTone)
                {
                    [self.highTonePlayer stop];
                }
                
                // stop led from blinking if no tones are active
                if (!haveActiveLowTone && !haveActiveHighTone)
                {
                    [self.ledController hide];
                }
            }
            else if (data == LOW_ALERT_VALUE)
            {
                // DLog(@"Received request to turn on low immediate alert");
                if (!self.lowTonePlayer.isPlaying)
                {
                    [self.lowTonePlayer play:5.0];
                    [self.ledController blink];
                }
            }
            else if (data == HIGH_ALERT_VALUE)
            {
                // DLog(@"Received request to turn on high immediate alert");
                if (!self.highTonePlayer.isPlaying)
                {
                    [self.highTonePlayer play:5.0];
                    [self.ledController blink];
                }
            }
        }
    }
    
    [peripheral respondToRequest:returnRequest withResult: returnError];
    
}

// This callback comes in when the PeripheralManager is ready to send the next chunk of data.
// This is to ensure that packets will arrive in the order they are sent
- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    DLog(@"PeripheralManagerIsReadyToUpdateSubscribers");
    dispatch_semaphore_signal(self.transmitQueueSemaphore);
    self.sendReady = YES;
    
}


/*!
 *  @method peripheralManager:didAddService:error:
 *
 *  @param peripheral   The peripheral manager providing this information.
 *  @param service      The service that was added to the local database.
 *  @param error        If an error occurred, the cause of the failure.
 *
 *  @discussion         This method returns the result of an @link addService: @/link call. If the service could
 *                      not be published to the local database, the cause will be detailed in the <i>error</i> parameter.
 *
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
    if (error)
    {
        DLog(@"Error adding service-- %@",error.description);
    }
}


#pragma mark- AVAudioPlayerDelegate Methods

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    // stop the blinking LED when the tone stops
    [self.ledController hide];
}

@end
