//
//  MovementViewController.h
//  Hestia
//
//  Created by Khaos Tian on 8/14/13.
//  Copyright (c) 2013 Oltica. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MovementViewController : UIViewController

@property (weak, nonatomic) IBOutlet UINavigationBar *titleNavigationBar;

@property (weak, nonatomic) IBOutlet UIScrollView *mapScrollerView;
@property (weak, nonatomic) IBOutlet UIButton *lockButton;
- (IBAction)pressLockButton:(id)sender;

@end
