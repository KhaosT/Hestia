//
//  ViewController.m
//  Hestia
//
//  Created by Khaos Tian on 8/14/13.
//  Copyright (c) 2013 Oltica. All rights reserved.
//

#import "ViewController.h"
#import "NearbyAuthCore.h"
#import "MovementViewController.h"
#import "MapDisplayView.h"

@interface ViewController ()<UIAlertViewDelegate>{
    NSString                *_currentUserUUID;
    UIAlertView             *_passwordAlert;
    //UIPopoverController     *_movementPopover;
}

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(didGetOTP:) name:@"DidGetUserOTP" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(userDidLeftFromDevice:) name:@"UserDidLeftFromDevice" object:nil];

    UIInterpolatingMotionEffect *mx = [[UIInterpolatingMotionEffect alloc]
                                       initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
    mx.maximumRelativeValue = @39.0;
    mx.minimumRelativeValue = @-39.0;
    
    UIInterpolatingMotionEffect *mx2 = [[UIInterpolatingMotionEffect alloc]
                                        initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
    mx2.maximumRelativeValue = @39.0;
    mx2.minimumRelativeValue = @-39.0;
    
    [_avatarView addMotionEffect:mx];
    [_avatarView addMotionEffect:mx2];
    
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)userDidLeftFromDevice:(NSNotification *)note
{
    if (_passwordAlert) {
        _passwordAlert.delegate = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [_passwordAlert dismissWithClickedButtonIndex:0 animated:YES];
        });
    }
}

- (void)didGetOTP:(NSNotification *)note
{
    [[NearbyAuthCore defaultCore]authUserWithUUID:_currentUserUUID OTP:note.object completionBlock:^(BOOL isPass) {
        if (isPass) {
            NSLog(@"PassAuth");
            UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Pass" message:[NSString stringWithFormat:@"Welcome %@",[[[[NearbyAuthCore defaultCore]usersData] objectForKey:_currentUserUUID] objectForKey:@"name"]] delegate:Nil cancelButtonTitle:@"Done" otherButtonTitles:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                [alert show];
            });
        }else{
            NSLog(@"FailedAuth");
            UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Fail" message:@"You are not allowed to use this." delegate:Nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                [alert show];
            });
        }
    }];
}

- (void)setUserUUID:(NSString *)uuid
{
    _currentUserUUID = [uuid copy];
    NSLog(@"Welcome:%@",[[[[NearbyAuthCore defaultCore]usersData] objectForKey:_currentUserUUID] objectForKey:@"name"]);
    dispatch_async(dispatch_get_main_queue(), ^{
        _otpAuthButton.enabled = YES;
        _passwordAuthButton.enabled = YES;
        _welcomeLabel.text = [NSString stringWithFormat:@"Welcome, %@",[[[[NearbyAuthCore defaultCore]usersData] objectForKey:_currentUserUUID] objectForKey:@"name"]];
        [_avatarView setImage:[UIImage imageNamed:[[[[NearbyAuthCore defaultCore]usersData] objectForKey:_currentUserUUID] objectForKey:@"avatar"]]];
    });
}

- (IBAction)dismissAuthView:(id)sender {
    [[NSNotificationCenter defaultCenter]postNotificationName:@"UserDismissAuthViewController" object:nil];
}

- (IBAction)authWithOTP:(id)sender {
    [[NearbyAuthCore defaultCore]getOTPFromPeer];
}

- (IBAction)authWithPassword:(id)sender {
    _passwordAlert = [[UIAlertView alloc]initWithTitle:@"Your Password" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Done", nil];
    _passwordAlert.alertViewStyle = UIAlertViewStyleSecureTextInput;
    [_passwordAlert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    _passwordAlert = nil;
    if (buttonIndex == 1) {
        UITextField *passwordField = [alertView textFieldAtIndex:0];
        if ([passwordField.text isEqualToString:[[[[NearbyAuthCore defaultCore]usersData] objectForKey:_currentUserUUID] objectForKey:@"password"]]) {
            NSLog(@"PassAuth");
            UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Pass" message:[NSString stringWithFormat:@"Welcome %@",[[[[NearbyAuthCore defaultCore]usersData] objectForKey:_currentUserUUID] objectForKey:@"name"]] delegate:Nil cancelButtonTitle:@"Done" otherButtonTitles:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                [alert show];
            });
        }else{
            NSLog(@"FailedAuth");
            UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Fail" message:@"You are not allowed to use this." delegate:Nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                [alert show];
            });
        }
        NSLog(@"Password:%@",passwordField.text);
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

@end
