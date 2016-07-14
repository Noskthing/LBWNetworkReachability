//
//  AppDelegate.h
//  LBWNetworkReachability
//
//  Created by ml on 16/7/11.
//  Copyright © 2016年 李博文. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NetworkReachabilityManager.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (nonatomic,strong) NetworkReachabilityManager *networkManager;

@end

