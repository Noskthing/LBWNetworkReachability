//
//  SystemNetworkReachability.h
//  LBWNetworkReachability
//
//  Created by ml on 16/7/11.
//  Copyright © 2016年 李博文. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>


typedef enum : NSInteger {
    SystemNetworkReachabilityNotReachable = 0,
    SystemNetworkReachabilityReachableViaWiFi,
    SystemNetworkReachabilityReachableViaWWAN
} SystemNetworkReachabilityStatus;

@interface SystemNetworkReachability : NSObject

+ (instancetype)sharedSystemNetworkReachability;

/**
 *  start listening for reachability notifications on the current runloop
 *
 *  @return whether start listening success
 */
- (BOOL)startNotifier;

- (void)stopNotifier;

- (SystemNetworkReachabilityStatus)currentSystemNetworkReachabilityStatus;
@end
