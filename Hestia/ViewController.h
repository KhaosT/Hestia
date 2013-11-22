//
//  ViewController.h
//  Hestia
//
//  Created by Khaos Tian on 8/14/13.
//  Copyright (c) 2013 Oltica. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIImageView *avatarView;
@property (weak, nonatomic) IBOutlet UIButton *otpAuthButton;
@property (weak, nonatomic) IBOutlet UILabel *welcomeLabel;
@property (weak, nonatomic) IBOutlet UIButton *passwordAuthButton;

- (IBAction)authWithOTP:(id)sender;
- (IBAction)authWithPassword:(id)sender;
- (void)setUserUUID:(NSString *)uuid;
- (IBAction)dismissAuthView:(id)sender;

@end
