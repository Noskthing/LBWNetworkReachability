//
//  LBWNetworkReachability.h
//  LBWNetworkReachability
//
//  Created by ml on 16/7/12.
//  Copyright © 2016年 李博文. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>


extern NSString * kReachabilityChangedNotification;

typedef enum : NSInteger {
    NetworkNotReachable = 0,
    NetworkViaWiFi,
    NetworkWWAN
} NetworkReachabilityStatus;



@interface LBWNetworkReachability : NSObject

+ (instancetype)sharedSystemNetworkReachability;

/**
 *  start listening for reachability notifications on the current runloop
 *
 *  @return whether start listening success
 */
- (BOOL)startNotifier;

- (void)stopNotifier;

- (NetworkReachabilityStatus)currentSystemNetworkReachabilityStatus;

@end
