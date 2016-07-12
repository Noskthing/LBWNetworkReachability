//
//  NetworkReachabilityManager.h
//  LBWNetworkReachability
//
//  Created by ml on 16/7/12.
//  Copyright © 2016年 李博文. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NetworkReachabilityManager : NSObject


/**
 *  default is www.baidu.com . plz make sure that ur hostName is available for ping
 */
@property (nonatomic,copy)NSString * hostName;



+ (instancetype)sharedManager;

@end
