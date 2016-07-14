//
//  LBWNetworkReachability.m
//  LBWNetworkReachability
//
//  Created by ml on 16/7/12.
//  Copyright © 2016年 李博文. All rights reserved.
//

#import "LBWNetworkReachability.h"
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>


NSString * kReachabilityChangedNotification = @"kNetworkReachabilityChangedNotification";

#define kShouldPrintReachabilityFlags 1
static void PrintReachabilityFlags(SCNetworkReachabilityFlags flags, const char* comment)
{
#if kShouldPrintReachabilityFlags
    
    NSLog(@"Reachability Flag Status: %c%c %c%c%c%c%c%c%c %s\n",
          (flags & kSCNetworkReachabilityFlagsIsWWAN)				? 'W' : '-',
          (flags & kSCNetworkReachabilityFlagsReachable)            ? 'R' : '-',
          
          (flags & kSCNetworkReachabilityFlagsTransientConnection)  ? 't' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionRequired)   ? 'c' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)  ? 'C' : '-',
          (flags & kSCNetworkReachabilityFlagsInterventionRequired) ? 'i' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionOnDemand)   ? 'D' : '-',
          (flags & kSCNetworkReachabilityFlagsIsLocalAddress)       ? 'l' : '-',
          (flags & kSCNetworkReachabilityFlagsIsDirect)             ? 'd' : '-',
          comment
          );
#endif
}

static void SystemNetworkReachabilityCallback (SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
#pragma unused (target, flags)
    NSCAssert(info != NULL, @"info was NULL in ReachabilityCallback");
    NSCAssert([(__bridge NSObject*) info isKindOfClass: [LBWNetworkReachability class]], @"info was wrong class in ReachabilityCallback");
    
    LBWNetworkReachability * noteObject = (__bridge LBWNetworkReachability *)info;
    // Post a notification to notify the client that the network reachability changed.
    //on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName: kReachabilityChangedNotification object: noteObject];
    });
    
}

@interface LBWNetworkReachability ()

@property (nonatomic,assign)SCNetworkReachabilityRef networkReachabilityRef;

@property (nonatomic,strong)dispatch_queue_t networkReachabilitySerialQueue;


@end


@implementation LBWNetworkReachability

- (instancetype)init
{
    if (self = [super init])
    {
        struct sockaddr_in address;
        bzero(&address, sizeof(address));
        address.sin_len = sizeof(address);
        address.sin_family = AF_INET;
        
        _networkReachabilityRef = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&address);
        
        _networkReachabilitySerialQueue = dispatch_queue_create("com.leeB0Wen.clever", NULL);
    }
    return self;
}

- (void)dealloc
{
    [self stopNotifier];
    if (_networkReachabilityRef != NULL)
    {
        CFRelease(_networkReachabilityRef);
        _networkReachabilityRef = NULL;
    }
    
    _networkReachabilitySerialQueue = nil;
    
}
#pragma mark
+ (instancetype)sharedSystemNetworkReachability
{
    static id systemNetworkReachability = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        systemNetworkReachability = [[self alloc] init];
    });
    
    return systemNetworkReachability;
}

- (BOOL)startNotifier
{
    BOOL returnValue = NO;
    
    SCNetworkReachabilityContext context = {0,NULL,NULL,NULL,NULL};
    context.info = (__bridge void *)self;
    
    if (SCNetworkReachabilitySetCallback(_networkReachabilityRef,SystemNetworkReachabilityCallback,&context))
    {
        if (SCNetworkReachabilityScheduleWithRunLoop(_networkReachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode))
        {
            returnValue = YES;
        }
    }
    
    return returnValue;
}

- (void)stopNotifier
{
    if (_networkReachabilityRef != NULL)
    {
        SCNetworkReachabilityUnscheduleFromRunLoop(_networkReachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    }
}

- (NetworkReachabilityStatus)currentSystemNetworkReachabilityStatus
{
    NSAssert(_networkReachabilityRef != NULL, @"currentNetworkStatus called with NULL SCNetworkReachabilityRef");
    NetworkReachabilityStatus returnValue = NetworkNotReachable;
    SCNetworkReachabilityFlags flags;
    
    if (SCNetworkReachabilityGetFlags(_networkReachabilityRef, &flags))
    {
        returnValue = [self networkStatusForFlags:flags];
    }
    
    return returnValue;
}

#pragma mark    - Network Flag Handling
- (NetworkReachabilityStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags
{
    PrintReachabilityFlags(flags, "networkStatusForFlags");
    
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
    {
        // The target host is not reachable.
        return NetworkNotReachable;
    }
    
    NetworkReachabilityStatus returnValue = NetworkNotReachable;
    
    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
    {
        /*
         If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
         */
        returnValue = NetworkViaWiFi;
    }
    
    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
         (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
    {
        /*
         ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
         */
        
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
        {
            /*
             ... and no [user] intervention is needed...
             */
            returnValue = NetworkViaWiFi;
        }
    }
    
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
    {
        /*
         ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
         */
        returnValue = NetworkWWAN;
    }
    
    return returnValue;
}

@end