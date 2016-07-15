//
//  NetworkReachabilityManager.h
//  LBWNetworkReachability
//
//  Created by ml on 16/7/12.
//  Copyright © 2016年 李博文. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^CurrentNetworkStatusBlock)();

typedef NS_ENUM(NSUInteger, NetworkStatus) {
    NetworkStatusUnableConnect = 0,
    NetworkStatusWifiAbleConnect,
    NetworkStatusWifiUnableConnect,
    NetworkStatusWWANAbleConnect,
    NetworkStatusWWANUnableConnect,
};
extern NSString * const kNetworkStatusChange;

@interface NetworkReachabilityManager : NSObject


/**
 *  default is www.baidu.com . plz make sure that ur hostName is available for ping
 */
@property (nonatomic,copy)NSString * hostName;

/**
 *  this is network real status
 */
@property (nonatomic,assign) NetworkStatus currentNetworkStatus;

/**
 *  whether or not network can connect.
 */
@property (nonatomic,assign,getter=isConnect) BOOL connect;

/**
 *  start Network Monitor.
 */
- (void)startNotifier;

/**
 *  stop Network Monitor
 */
- (void)stopNotifier;

/**
 *  u must use property or Viar to keep this instance . because in ARC system will deallocating it and u can not get notification. advise that initialize it in AppDelegate and add Observe where u need monititor nerwork status.the notification.object is manager.
 *
 *  @return networkManager
 */
+ (instancetype)sharedManager;

@end
