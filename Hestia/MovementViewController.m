//
//  MovementViewController.m
//  Hestia
//
//  Created by Khaos Tian on 8/14/13.
//  Copyright (c) 2013 Oltica. All rights reserved.
//

#import "MovementViewController.h"
#import "MapDisplayView.h"
#import "NearbyAuthCore.h"
#import "ViewController.h"

#define PENDING_HEIGHT 50.0

@interface MovementViewController ()<UIScrollViewDelegate,UIBarPositioningDelegate>{
    NSMutableDictionary        *_pinsOnScreen;
    
    MapDisplayView      *_mapView;
    
    NSDictionary        *_currentMapInfo;
    
    NSString            *_currentMapNo;
    NSString            *_lastUserUUID;
    
    id                  _UserDidChangePosition;
    
    float               _scale_ratio;
    
    ViewController      *_uservc;
    
    BOOL                _userDismissed;
    
    NSTimer             *_disconnectTimer;
}
@end

@implementation MovementViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)configureView
{
    _titleNavigationBar.delegate = self;
    _mapScrollerView.delegate = self;
    UIImage *lockImage = [UIImage imageNamed:@"lock"];
    [_lockButton setImage:[lockImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    //_mapScrollerView.maximumZoomScale = 3.0;
    _mapView = [[MapDisplayView alloc]initWithFrame:_mapScrollerView.frame];
    [_mapScrollerView addSubview:_mapView];
    [self setupMapForMajor:@"1"];
}

- (void)setupMapForMajor:(NSString *)majorNumber
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _currentMapNo = majorNumber;
        NSBundle *mapInfoBundle = [NSBundle bundleWithURL:[[NSBundle mainBundle]URLForResource:@"IndoorMap_3" withExtension:@"bundle"]];
        NSDictionary *mapInfo = [NSDictionary dictionaryWithContentsOfURL:[mapInfoBundle URLForResource:@"info" withExtension:@"plist"]];
        _titleNavigationBar.topItem.title = [mapInfo objectForKey:@"name"];
        _currentMapInfo = mapInfo;
        _scale_ratio = (self.view.frame.size.width - 150) / [[_currentMapInfo objectForKey:@"mapSizeY"] floatValue];
        CGSize mapSize = CGSizeMake([[_currentMapInfo objectForKey:@"mapSizeX"] floatValue]*_scale_ratio, [[_currentMapInfo objectForKey:@"mapSizeY"] floatValue]*_scale_ratio);
        [_mapScrollerView setContentSize:mapSize];
        _mapView.frame = CGRectMake(0, 0, mapSize.width, mapSize.height);
        _mapView.center = CGPointMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0 - PENDING_HEIGHT);
        [_mapView setMapURL:[mapInfoBundle URLForResource:[_currentMapInfo objectForKey:@"mapName"] withExtension:[_currentMapInfo objectForKey:@"mapType"]]];
        [_mapView setNeedsDisplay];
        
    });
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _pinsOnScreen = [[NSMutableDictionary alloc]init];
    [self configureView];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(didFindNewUser:) name:@"DidFindNewUser" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(userDidLeftFromDevice:) name:@"UserDidLeftFromDevice" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(dismissAuthView:) name:@"UserDismissAuthViewController" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(didDisconnectedFromUserDevice:) name:@"DidDisconnectedFromUserDevice" object:nil];
    
    _UserDidChangePosition = [[NSNotificationCenter defaultCenter]addObserverForName:@"UserDidChangePosition" object:nil queue:[[NSOperationQueue alloc]init] usingBlock:^(NSNotification *note) {
        NSDictionary *userLocation = note.object;
        NSBundle *mapInfoBundle = [NSBundle bundleWithURL:[[NSBundle mainBundle]URLForResource:@"IndoorMap_3" withExtension:@"bundle"]];
        
        if (!_currentMapInfo) {
            NSDictionary *mapInfo = [NSDictionary dictionaryWithContentsOfURL:[mapInfoBundle URLForResource:@"info" withExtension:@"plist"]];
            _currentMapInfo = mapInfo;
        }
        if (_currentMapNo) {
            if (![[userLocation objectForKey:@"major"]isEqualToString:_currentMapNo]) {
                _currentMapNo = [[_currentMapInfo objectForKey:@"major"]stringValue];
                [self setupMapForMajor:_currentMapNo];
            }
        }else{
            _currentMapNo = [[_currentMapInfo objectForKey:@"major"]stringValue];
            [self setupMapForMajor:_currentMapNo];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.33 animations:^{
                if ([[userLocation objectForKey:@"major"] isEqualToString:_currentMapNo]) {
                    UIImageView *pinView = [_pinsOnScreen objectForKey:[userLocation objectForKey:@"uuid"]];
                    if (pinView == nil) {
                        UIImage *locationPinImage = [UIImage imageNamed:[[[[NearbyAuthCore defaultCore]usersData] objectForKey:[userLocation objectForKey:@"uuid"]] objectForKey:@"avatar"]];
                        pinView = [[UIImageView alloc]initWithImage:locationPinImage];
                        pinView.frame = CGRectMake(0, 0, 50, 50);
                        [_mapView addSubview:pinView];
                        [_pinsOnScreen setObject:pinView forKey:[userLocation objectForKey:@"uuid"]];
                    }
                    pinView.center = [self calculateUserLocationWithMajor:[userLocation objectForKey:@"major"] Minor:[userLocation objectForKey:@"minor"]];
                }else{
                    UIImageView *pinView = [_pinsOnScreen objectForKey:[userLocation objectForKey:@"uuid"]];
                    if (pinView) {
                        [pinView removeFromSuperview];
                        [_pinsOnScreen removeObjectForKey:[userLocation objectForKey:@"uuid"]];
                    }
                }
            }];
        });
    }];
	// Do any additional setup after loading the view.
}

- (void)didFindNewUser:(NSNotification *)note
{
    if (_disconnectTimer) {
        [_disconnectTimer invalidate];
        _disconnectTimer = nil;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        _lockButton.hidden = NO;
    });
    if (_lastUserUUID) {
        if ([_lastUserUUID isEqualToString:note.object]) {
            return;
        }
    }
    
    _userDismissed = NO;
    if (_uservc) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:nil];
        });
        
        _uservc = nil;
    }
    
    _lastUserUUID = [note.object copy];
    if (!_userDismissed && !_uservc) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _uservc = [self.storyboard instantiateViewControllerWithIdentifier:@"UserInteractVC"];
            [_uservc setUserUUID:note.object];
            [self presentViewController:_uservc animated:YES completion:nil];
            /*[UIView animateWithDuration:0.33 animations:^{
             [self.view addSubview:_uservc.view];
             }];*/
        });
    }
}

- (void)userDidLeftFromDevice:(NSNotification *)note
{
    if (_disconnectTimer) {
        [_disconnectTimer invalidate];
        _disconnectTimer = nil;
    }
    _userDismissed = NO;
    if (_uservc) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _lockButton.hidden = YES;
            [self dismissViewControllerAnimated:YES completion:nil];
        });
        
        _uservc = nil;
    }
    _lastUserUUID = nil;
}

- (void)didDisconnectedFromUserDevice:(NSNotification *)note
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_disconnectTimer) {
            [_disconnectTimer invalidate];
            _disconnectTimer = nil;
        }
        _disconnectTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(userDidLeftFromDevice:) userInfo:nil repeats:NO];
        _lockButton.hidden = YES;
    });
}

- (void)dismissAuthView:(NSNotification *)note
{
    _userDismissed = YES;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (CGPoint)calculateUserLocationWithMajor:(NSString *)major Minor:(NSString *)minor
{
    CGPoint firstPoint = CGPointMake([[[[_currentMapInfo objectForKey:@"beacons"] objectForKey:minor]objectForKey:@"x"] floatValue] * _scale_ratio, [[[[_currentMapInfo objectForKey:@"beacons"] objectForKey:minor]objectForKey:@"y"] floatValue] * _scale_ratio);
    
    return firstPoint;
}

- (CGPoint)diffBetweenPoint1:(CGPoint)p1 andPoint2:(CGPoint)p2
{
    CGFloat xDist = (p2.x - p1.x);
    CGFloat yDist = (p2.y - p1.y);
    CGPoint diff = CGPointMake(xDist, yDist);
    return diff;
}

- (CGFloat)distanceBetweenPoint1:(CGPoint)p1 andPoint2:(CGPoint)p2
{
    CGFloat xDist = (p2.x - p1.x);
    CGFloat yDist = (p2.y - p1.y);
    CGFloat distance = sqrt((xDist * xDist) + (yDist * yDist));
    return distance;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIBarPosition)positionForBar:(id <UIBarPositioning>)bar
{
    if ([bar isEqual:_titleNavigationBar]) {
        return UIBarPositionTopAttached;
    }else{
        return UIBarPositionAny;
    }
}

- (IBAction)pressLockButton:(id)sender {
    if (!_uservc) {
        _uservc = [self.storyboard instantiateViewControllerWithIdentifier:@"UserInteractVC"];
        [_uservc setUserUUID:_lastUserUUID];
    }
    [self presentViewController:_uservc animated:YES completion:nil];

}

@end
