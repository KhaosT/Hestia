//
//  NearbyAuthCore.m
//  Hestia
//
//  Created by Khaos Tian on 8/14/13.
//  Copyright (c) 2013 Oltica. All rights reserved.
//

#import "NearbyAuthCore.h"
#import "AeroGearOTP.h"
#import <CoreBluetooth/CoreBluetooth.h>

#define IDENTITY_SERVICE_UUID @"DDDD28AD-53BC-4B74-83B0-68F0E3C21FC2"
#define IDENTITY_CHAR_1_UUID @"C57314FB-8BA1-4751-BB90-4911E7BF8D31"
#define IDENTITY_TOTP_CHAR_UUID @"927C330A-0CB4-4FB6-87F1-E9C4F4CD8676"

#define WEAK_RSSI   -65
#define NEAR_RSSI   -55

@interface NearbyAuthCore()<CBCentralManagerDelegate,CBPeripheralDelegate>{
    CBCentralManager                *_centralManager;
    CBPeripheral                    *_connectedPeripheral;
    
    CBCharacteristic                *_charateristic_TOTP;
    CBCharacteristic                *_characteristic_Info;
    
    NSDictionary                    *_usersData;
    
    NSTimer                         *_rssiTimer;
    
    NSInteger                       _preverousRSSI;
}

@end

@implementation NearbyAuthCore

+ (NearbyAuthCore *)defaultCore
{
    static NearbyAuthCore *authCore = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        authCore = [[self alloc]init];
    });
    return authCore;
}

- (id)init
{
    if (self = [super init]) {
        _centralManager = [[CBCentralManager alloc]initWithDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
        _usersData = [NSDictionary dictionaryWithContentsOfURL:[[NSBundle mainBundle]URLForResource:@"UsersData" withExtension:@"plist"]];
    }
    return self;
}

- (void)startScan
{
    NSLog(@"Bluetooth State:%d",_centralManager.state);
    //if (_centralManager.state == CBCentralManagerStatePoweredOn) {
        [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:IDENTITY_SERVICE_UUID]] options:@{CBCentralManagerScanOptionAllowDuplicatesKey : [NSNumber numberWithBool:YES]}];
    /*}else{
        NSLog(@"NoBLUETOOTH ENABLED");
    }*/
}

- (void)getOTPFromPeer
{
    if (_charateristic_TOTP) {
        [_connectedPeripheral readValueForCharacteristic:_charateristic_TOTP];
    }
}

- (void)authUserWithUUID:(NSString *)uuid OTP:(NSString *)password completionBlock:(void (^)(BOOL isPass))completion
{
    NSString *secret = [[_usersData objectForKey:uuid]objectForKey:@"otpSec"];
    
    NSData *secretData = [AGBase32 base32Decode:secret];
    AGTotp *generator = [[AGTotp alloc]initWithSecret:secretData];
    BOOL isPass = [[generator now]isEqualToString:password];
    completion(isPass);
}

- (NSDictionary *)usersData
{
    return _usersData;
}

- (void)updateRSSI
{
    NSLog(@"Read");
    if (_characteristic_Info) {
        [_connectedPeripheral readRSSI];
    }
}

#pragma mark - CoreBluetoothDelegate

-(void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn) {
        NSLog(@"StartScan");
        [self startScan];
    }
}

-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"%@\nRSSI:%@",advertisementData,RSSI);
    if (RSSI.integerValue > NEAR_RSSI && RSSI.integerValue < - 15) {
        NSLog(@"InRange");
        [central stopScan];
        _connectedPeripheral = peripheral;
        [central connectPeripheral:peripheral options:nil];
    }
}

-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Connected");

    peripheral.delegate = self;
    [peripheral discoverServices:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        _rssiTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(updateRSSI) userInfo:nil repeats:YES];
    });
}

-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    if ([peripheral isEqual:_connectedPeripheral]) {
        [_rssiTimer invalidate];
        [[NSNotificationCenter defaultCenter]postNotificationName:@"DidDisconnectedFromUserDevice" object:nil];
        _rssiTimer = nil;
        _connectedPeripheral = nil;
        _characteristic_Info = nil;
        _charateristic_TOTP = nil;
        [self startScan];
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService *aService in peripheral.services) {
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:IDENTITY_SERVICE_UUID]]) {
            NSLog(@"FindService");
            [peripheral discoverCharacteristics:nil forService:aService];
        }
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    for (CBCharacteristic *aChar in service.characteristics) {
        if ([aChar.UUID isEqual:[CBUUID UUIDWithString:IDENTITY_TOTP_CHAR_UUID]]) {
            NSLog(@"FindTOTP");
            _charateristic_TOTP = aChar;
        }
        if ([aChar.UUID isEqual:[CBUUID UUIDWithString:IDENTITY_CHAR_1_UUID]]) {
            NSLog(@"FindInfo");
            _characteristic_Info = aChar;
            [peripheral readValueForCharacteristic:_characteristic_Info];
        }
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if ([characteristic isEqual:_characteristic_Info]) {
        NSLog(@"UserInfo:%@",[[NSString alloc]initWithData:characteristic.value encoding:NSUTF8StringEncoding]);
        [[NSNotificationCenter defaultCenter]postNotificationName:@"DidFindNewUser" object:[[NSJSONSerialization JSONObjectWithData:characteristic.value options:0 error:nil]objectForKey:@"UUID"]];
    }
    if ([characteristic isEqual:_charateristic_TOTP]) {
        [[NSNotificationCenter defaultCenter]postNotificationName:@"DidGetUserOTP" object:[[NSString alloc]initWithData:characteristic.value encoding:NSUTF8StringEncoding]];
    }
}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"RSSI:%@",peripheral.RSSI);
    if (((peripheral.RSSI.integerValue + _preverousRSSI)/2.0) < WEAK_RSSI) {
        [[NSNotificationCenter defaultCenter]postNotificationName:@"UserDidLeftFromDevice" object:nil];
        [_centralManager cancelPeripheralConnection:peripheral];
    }
    _preverousRSSI = peripheral.RSSI.integerValue;
    if (error) {
        NSLog(@"Error:%@",error);
    }
}

@end
