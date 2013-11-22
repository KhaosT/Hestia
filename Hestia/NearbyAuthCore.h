//
//  NearbyAuthCore.h
//  Hestia
//
//  Created by Khaos Tian on 8/14/13.
//  Copyright (c) 2013 Oltica. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NearbyAuthCore : NSObject

+ (NearbyAuthCore *)defaultCore;

- (void)getOTPFromPeer;
- (void)authUserWithUUID:(NSString *)uuid OTP:(NSString *)password completionBlock:(void (^)(BOOL isPass))completion;

- (NSDictionary *)usersData;

@end
