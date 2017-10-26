//
//  ViewController.m
//  iOSCollarSampleData
//
//  Created by Christos Christodoulou on 09/10/2017.
//  Copyright © 2017 Christos Christodoulou. All rights reserved.
//

#import "ViewController.h"
#import <MapKit/MapKit.h>
#import "CocoaLumberjack.h"
#import "DDLog.h"
#import "DDFileLogger.h"
#import <MessageUI/MessageUI.h>
#import <CocoaLumberjack/CocoaLumberjack.h>
@import CoreLocation;
@import CoreMotion;
@import CoreBluetooth;

static const DDLogLevel ddLogLevel = DDLogLevelVerbose;


@interface ViewController () <MKMapViewDelegate, CLLocationManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate, UITextFieldDelegate>
{
    double latitude_UserLocation, longitude_UserLocation;
    int count;
    int countSensor;
    BOOL scanStarted;
    int restartTimerPeriod;
}


@property (weak, nonatomic) IBOutlet UILabel *collarLabel;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UILabel *locationLabel;
@property (weak, nonatomic) IBOutlet UILabel *altitudeLabel;
@property (weak, nonatomic) IBOutlet UILabel *pressureLabel;
@property (weak, nonatomic) IBOutlet UILabel *relativeAltitude;
@property (weak, nonatomic) IBOutlet UILabel *countLabel;
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UILabel *sensorDataLabel;
@property (weak, nonatomic) IBOutlet UILabel *batteryLabel;
@property (weak, nonatomic) IBOutlet UILabel *countSensorLabel;
@property (weak, nonatomic) IBOutlet UITextField *sensorPeriodTime;

@property (strong, nonatomic) CMAltimeter *altimeter;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (retain, nonatomic) NSTimer *locationDetectTimer;

@property (strong,nonatomic) CBCentralManager *manager;
@property (strong,nonatomic) CBPeripheral *p;
@property (strong,nonatomic) CBPeripheral *connectedPeripheral;
@property (strong,nonatomic) NSMutableDictionary *discoveredPeripherals;
@property (strong,nonatomic) NSMutableArray *devices;
@property (retain, nonatomic) NSTimer *restartTimer;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.mapView.delegate = self;
    self.mapView.showsUserLocation = YES;
    self.mapView.mapType = MKMapTypeHybrid;

    count = 0;
    countSensor = 0;
    restartTimerPeriod = 60;
    
    //Keyboard stuff
   UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    tapRecognizer.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapRecognizer];
}

- (void)handleSingleTap:(UITapGestureRecognizer *) sender
{
    restartTimerPeriod = [self.sensorPeriodTime.text intValue];
    [self.view endEditing:YES];
}

- (IBAction)startPressed:(id)sender {
    if(!scanStarted) {
        scanStarted = YES;
        self.locationDetectTimer = [NSTimer scheduledTimerWithTimeInterval:10.0f target:self selector:@selector(findLaLo:) userInfo:nil repeats:YES];
        
        NSLog(@"scanPressed  init CentralManager");
        [self.devices removeAllObjects];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.sensorDataLabel.text = @"";
            [self.startButton setTitle: @"Stop" forState: UIControlStateNormal];
        });
        self.devices = [[NSMutableArray alloc]init];
        self.discoveredPeripherals = [[NSMutableDictionary alloc] init];
        self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];
    }
    else {
        NSLog(@"scanStopped");

        scanStarted = NO;
        [self.manager cancelPeripheralConnection:self.connectedPeripheral];
        [self.locationManager stopUpdatingLocation];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.startButton setTitle: @"Start" forState: UIControlStateNormal];
        });
    }

}

- (void)findLaLo:(NSTimer *)timer {
    // check if the barometer is available
    if (![CMAltimeter isRelativeAltitudeAvailable]) {
        NSLog(@"Barometer is not available on this device. Sorry!");
        return;
    } else {
        NSLog(@"Barometer is available.");
    }
    
    // start altitude tracking
    [self.altimeter startRelativeAltitudeUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMAltitudeData * _Nullable altitudeData, NSError * _Nullable error) {
        
        // this block is called every time there's an update
        // access data here (for example, populate labels)
        [self updateLabels:altitudeData];
    }];
    
    [self loadUserLocation];
}

- (IBAction)emailPressed:(id)sender {
    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
        mailViewController.mailComposeDelegate = self;
        NSMutableData *errorLogData = [NSMutableData data];
        for (NSData *errorLogFileData in [self errorLogData]) {
            [errorLogData appendData:errorLogFileData];
        }
        [mailViewController addAttachmentData:errorLogData mimeType:@"text/plain" fileName:@"sampleAltimeterData.log"];
        [mailViewController setSubject:NSLocalizedString(@"Sample Altimeter Data", @"")];
        NSArray *toRecipientsNames = [NSArray arrayWithObjects:@"gpolitis@kyontracker.com",@"gmavropoulos@kyontracker.com",@"cchristodoulou@kyontracker.com", @"kfrantzeskakis@kyontracker.com",nil];
        [mailViewController setToRecipients:toRecipientsNames];
        
        [self presentViewController:mailViewController animated:YES completion:nil];
        
    } else {
        NSString *message = NSLocalizedString(@"Sorry, your issue can't be reported right now. This is most likely because no mail accounts are set up on your mobile device.", @"");
        [[[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles: nil] show];
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    CLLocation *currentLocation = newLocation;
    latitude_UserLocation = currentLocation.coordinate.latitude;
    longitude_UserLocation = currentLocation.coordinate.longitude;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.locationLabel.text = [NSString stringWithFormat:@"Latitude : %.5f, Longtitude : %.5f", latitude_UserLocation, longitude_UserLocation];
        self.altitudeLabel.text = [NSString stringWithFormat: @"Altitude | %f",currentLocation.altitude];
        self.countLabel.text = [NSString stringWithFormat: @"Count location: %d", count+1];
//        DDLogInfo(@" %.8f,  %.8f", latitude_UserLocation, longitude_UserLocation);
//        DDLogInfo(@" %@", self.altitudeLabel.text);
    });
    
    if (currentLocation != nil) {
//        self.sensorDataLabel.text = [NSString stringWithFormat:@"@LA : %.8f, LO : %.8f, ALT : %f,", currentLocation.coordinate.latitude, currentLocation.coordinate.longitude, currentLocation.altitude];
        //        NSLog(@"@LA : %.8f, LO : %.8f, ALT : %f,", currentLocation.coordinate.latitude, currentLocation.coordinate.longitude, currentLocation.altitude)
    }
    count++;
     [self loadMapView];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    [self.locationManager stopUpdatingLocation];
}

- (void)loadUserLocation
{
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.distanceFilter = kCLDistanceFilterNone;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [self.locationManager requestWhenInUseAuthorization];
    }
    [self.locationManager startUpdatingLocation];
}

- (void)loadMapView
{
    CLLocationCoordinate2D objCoor2D = {.latitude = latitude_UserLocation, .longitude = longitude_UserLocation};
    MKCoordinateSpan objCoorSpan = {.latitudeDelta = 0.005, .longitudeDelta = 0.005};
    MKCoordinateRegion objMapRegion = {objCoor2D, objCoorSpan};
    [self.mapView setRegion:objMapRegion];
}

- (CMAltimeter *)altimeter {
    if (!_altimeter) {
        _altimeter = [[CMAltimeter alloc]init];
    }
    return _altimeter;
}

- (void)updateLabels:(CMAltitudeData *)altitudeData {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc]init];
    formatter.maximumFractionDigits = 2;
    formatter.minimumIntegerDigits = 1;
    
    NSString *altitude = [NSString stringWithFormat:@"%@", [formatter stringFromNumber:altitudeData.relativeAltitude]];
    NSString *pressure = [NSString stringWithFormat:@"%@", [formatter stringFromNumber:altitudeData.pressure]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.relativeAltitude.text = [NSString stringWithFormat:@"Relative Altitude | %@", altitude];
        self.pressureLabel.text = [NSString stringWithFormat:@"Air Pressure | %0.2f",  [pressure floatValue]*10];
//        DDLogInfo(@" %@", self.relativeAltitude.text);
//        DDLogInfo(@" %@", self.pressureLabel.text);
    });
}


#pragma mark - CBCentralManagerDelegate Callbacks

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOff) {
        NSLog(@"CBCentralManager not powered on yet");
        
        [self.manager cancelPeripheralConnection:self.connectedPeripheral];
        self.manager = nil;
        return;
    }
    
    if (central.state == CBManagerStateUnauthorized) {
        NSLog(@"CBCentralManager CBManagerStateUnauthorized");
        [self.manager cancelPeripheralConnection:self.connectedPeripheral];
        self.manager = nil;
        return;
        
    }
    
    if (central.state == CBManagerStateUnknown) {
        NSLog(@"CBCentralManager CBManagerStateUnknown");
        [self.manager cancelPeripheralConnection:self.connectedPeripheral];
        self.manager = nil;
        return;
    }
    
    if (central.state == CBManagerStateUnsupported) {
        NSLog(@"CBCentralManager CBManagerStateUnsupported");
        [self.manager cancelPeripheralConnection:self.connectedPeripheral];
        self.manager = nil;
        return;
    }
    
    if (central.state == CBManagerStatePoweredOn) {
        NSLog(@"CBCentralManager CBManagerStatePoweredOn");
        NSDictionary *xOptions = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber  numberWithBool:YES], CBCentralManagerScanOptionAllowDuplicatesKey, nil];
        [self.manager scanForPeripheralsWithServices:nil options:xOptions];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
//    dispatch_async(dispatch_get_main_queue(), ^{
//        self.currentStateLabel.text = @"Discovering Peripherals";
//    });
    
    if ([self.devices containsObject:peripheral]) {
        NSLog(@"STEP: PERIPHERAL EXIST in DEVICES: %@", peripheral.name);
        return;
    }
    else {
        NSLog(@"STEP: PERIPHERAL ADDED in DEVICES: %@", peripheral.name);
        [self.devices addObject:peripheral];
        if ([peripheral.name isEqualToString: @"KYC:9C1D58154DC1"] ) {//9C1D58154DC1 //9C1D58154F80
            [self.manager connectPeripheral:peripheral options:nil];
            [self.manager stopScan];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.collarLabel.text = [NSString stringWithFormat:@"Collar: %@", peripheral.name];
//            [self.tableView reloadData];
        });
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"STEP: didConnectPeripheral: %@", peripheral.name);
    peripheral.delegate = self;
    self.connectedPeripheral = peripheral;
    [NSThread sleepForTimeInterval:4.0f];//Not sure if we need this one
    [self.connectedPeripheral discoverServices:@[[CBUUID UUIDWithString:@"A030"]]];//-- A030 NORMAL SERVICE
    
//    dispatch_async(dispatch_get_main_queue(), ^{
//        self.currentStateLabel.text =  [NSString stringWithFormat:@"Connected to:  %@", peripheral.name];
//        self.disconnectButton.enabled = YES;
//        self.disconnectButton.backgroundColor = [UIColor redColor];
//    });
}



- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"STEP: didDisconnectPeripheral: %@", peripheral.name);
//    dispatch_async(dispatch_get_main_queue(), ^{
//        self.currentStateLabel.text =  [NSString stringWithFormat:@"Disconnected:  %@", peripheral.name];
//    });
    //Start 1 min timer
    //Restart the scan after 1 minute
    self.restartTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:restartTimerPeriod]
                                                 interval:0
                                                   target:self
                                                 selector:@selector(restartScan:)
                                                 userInfo:nil
                                                  repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.restartTimer forMode:NSDefaultRunLoopMode];
    
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"STEP: Got didFailToConnectPeripheral:  %@", peripheral.name);
//    dispatch_async(dispatch_get_main_queue(), ^{
//        self.currentStateLabel.text =  [NSString stringWithFormat:@"Failed to:  %@", peripheral.name];
//    });
}

#pragma mark - CBPeripheralDelegate Callbacks

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *service in peripheral.services)
    {
        if ([[service.UUID UUIDString] isEqualToString:@"A030"] ) //-- A030  NORMAL SERVICE
        {
            [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:@"A032"]] forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        if ([[characteristic.UUID UUIDString] isEqualToString:@"A032"])//-- A032
        {
            [peripheral readValueForCharacteristic:characteristic];//request to read value from characteristic
            break;
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    UInt8 SOC;
    UInt8 batteryPercentageAndchargingStatus;
    UInt8 temperature;
    UInt8 wet;
    UInt8 streched;
    UInt32 pressure;
    UInt32 lastMessagesUpdateTimeStamp;
    UInt32 FirmwarePIC24FJ;
    UInt32 FirmwareCC2540;
    BOOL isWet;
    BOOL charging;
    BOOL isStreched;
    
    if ([[characteristic.UUID UUIDString] isEqualToString:@"A032"]) {//-- Α032 OR not in validation process
        
        NSData *rawData = characteristic.value;
        // Length Validation
        if (rawData.length != 19) {
            NSLog(@"INVALID RAW DATA LENGTH, DISCARD THIS READ");
            [self.manager cancelPeripheralConnection:peripheral];
            return;
        }
        countSensor++;
        //0 UInt8 Battery Percentage (State Of Charge) and Charging Status
        [[rawData subdataWithRange:NSMakeRange(0, 1)] getBytes:&batteryPercentageAndchargingStatus length:sizeof(batteryPercentageAndchargingStatus)];
        if (batteryPercentageAndchargingStatus > 128) {
            NSLog(@"Charging.....");
            batteryPercentageAndchargingStatus = batteryPercentageAndchargingStatus - 128;
            NSLog(@"%hhu",batteryPercentageAndchargingStatus);
            charging = YES;
        }else{
            NSLog(@"Not charging..... %hhu",batteryPercentageAndchargingStatus);
            charging = FALSE;
        }
        [[rawData subdataWithRange:NSMakeRange(0, 1)] getBytes:&SOC length:1];
        NSString *socString = [[NSNumber numberWithInt:SOC] stringValue];
        
        //1-3, Pressure
        [[rawData subdataWithRange:NSMakeRange(1, 3)] getBytes:&pressure length:sizeof(pressure)];
        pressure = CFSwapInt32HostToBig(pressure);
        pressure /= 256;
        pressure &= 0x00FFFFFF;
        NSLog(@"PRESSURE IS : %u",(unsigned int)pressure);
        NSLog(@"RAWDATA1 : %@",rawData);
        
        // 4, Temperature
        [[rawData subdataWithRange:NSMakeRange(4, 1)] getBytes:&temperature length:sizeof(temperature)];
        NSLog(@"TEMPERATURE IS %u",(unsigned int)temperature);
        NSLog(@"RAWDATA2 : %@",rawData);
        
        // 5, Wet (uint8). Values=1 if wet, otherwise 0.
        [[rawData subdataWithRange:NSMakeRange(0, 1)] getBytes:&wet length:sizeof(wet)];
        
        isWet = (wet == 1) ? TRUE : FALSE;
        NSLog(@"is Yet: %d",isWet);
        
        //6, Stretched (deformed) Collar (uint8). Values=1 if stretched, otherwise 0.
        [[rawData subdataWithRange:NSMakeRange(0, 1)] getBytes:&streched length:sizeof(streched)];
        isStreched = (streched == 1) ? TRUE : FALSE;
        NSLog(@"is Streched: %d",isStreched);
        
        //11-14 Last Messages Update Timestamp (uint32)
        [[rawData subdataWithRange:NSMakeRange(11, 4)] getBytes:&lastMessagesUpdateTimeStamp length:sizeof(lastMessagesUpdateTimeStamp)];
        NSLog(@"Last message update %u",(unsigned int)lastMessagesUpdateTimeStamp);
        
        if (lastMessagesUpdateTimeStamp == 4294967295) { // 0xFFFFFFFF = 4294967295
            lastMessagesUpdateTimeStamp = 0;
        }
        
        // 15-16, PIC24FJ Firmware Version
        [[rawData subdataWithRange:NSMakeRange(15, 2)] getBytes:&FirmwarePIC24FJ length:sizeof(FirmwarePIC24FJ)];
        FirmwarePIC24FJ = CFSwapInt32HostToBig(FirmwarePIC24FJ);
        NSLog(@"Swaaped FirmwarePIC24FJ %u",(unsigned int)FirmwarePIC24FJ);
        
        // 16-17, CC2540 Firmware Version
        [[rawData subdataWithRange:NSMakeRange(17, 2)] getBytes:&FirmwareCC2540 length:sizeof(FirmwareCC2540)];
        FirmwareCC2540 = CFSwapInt32HostToBig(FirmwareCC2540);
        NSLog(@"Swaaped FirmwareCC2540 %u",(unsigned int)FirmwareCC2540);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.sensorDataLabel.text =  [NSString stringWithFormat:@"Pressure | %0.2f | Temp | %u | %@ |",(float)pressure/100, (unsigned int)temperature, rawData];
            self.countSensorLabel.text = [NSString stringWithFormat: @"Count sensor: %d", countSensor+1];
            self.batteryLabel.text = [NSString stringWithFormat: @"Battery | %@",socString];
            if (latitude_UserLocation != 0 || longitude_UserLocation != 0) {
                DDLogInfo(@" %@  %@ | %@ | %@ | %@ | Latitude | %.8f | Longtitude | %.8f", self.sensorDataLabel.text, self.batteryLabel.text, self.relativeAltitude.text, self.pressureLabel.text, self.altitudeLabel.text, latitude_UserLocation, longitude_UserLocation);
            }

            NSLog(@"disconnect Automatically from read Sensors");
            [self.manager cancelPeripheralConnection:self.connectedPeripheral];
        });
        
    }
}


#pragma mark - restartScan Timer
- (void)restartScan:(NSTimer *)timer
{
    NSLog(@"restartTimer reconnect");
    if (self.restartTimer) {
        [self.restartTimer invalidate];
        self.restartTimer = nil;
    }
    if ([self.connectedPeripheral.name isEqualToString: @"KYC:9C1D58154DC1"] ) {//9C1D58154DC1 //9C1D58154F80
        [self.manager connectPeripheral:self.connectedPeripheral options:nil];
    }
//    [self.tableView reloadData];
    
    //    self.devices = nil;
    //    NSDictionary *xOptions = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber  numberWithBool:YES], CBCentralManagerScanOptionAllowDuplicatesKey, nil];
    //    [self.manager scanForPeripheralsWithServices:nil options:xOptions];
}

#pragma mark - error
- (NSMutableArray *)errorLogData {
    DDFileLogger *ddFileLogger = [DDFileLogger new];
    NSArray <NSString *> *logFilePaths = [ddFileLogger.logFileManager sortedLogFilePaths];
    NSMutableArray <NSData *> *logFileDataArray = [NSMutableArray new];
    for (NSString* logFilePath in logFilePaths) {
        NSURL *fileUrl = [NSURL fileURLWithPath:logFilePath];
        NSData *logFileData = [NSData dataWithContentsOfURL:fileUrl options:NSDataReadingMappedIfSafe error:nil];
        if (logFileData) {
            [logFileDataArray insertObject:logFileData atIndex:0];
        }
    }
    return logFileDataArray;
}

- (void)mailComposeController:(MFMailComposeViewController *)mailer didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [self becomeFirstResponder];
    [mailer dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - textfield delegate
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    self.sensorPeriodTime.text = textField.text;
    restartTimerPeriod = [textField.text doubleValue];
    return YES;
}
- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.sensorPeriodTime.text = textField.text;
    restartTimerPeriod = [textField.text doubleValue];
    NSLog(@"restartTimerPeriod | %d", restartTimerPeriod);
    [self.view endEditing:YES];
}

// It is important for you to hide the keyboard
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    
    [textField resignFirstResponder];
    return YES;
}

@end
