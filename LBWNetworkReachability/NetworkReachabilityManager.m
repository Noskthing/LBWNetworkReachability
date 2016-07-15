//
//  NetworkReachabilityManager.m
//  LBWNetworkReachability
//
//  Created by ml on 16/7/12.
//  Copyright © 2016年 李博文. All rights reserved.
//

#import "NetworkReachabilityManager.h"
#import "SimplePing.h"

#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>


#pragma mark    - LBWNetworkReachability

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

/**
 *  remove observer and set some object nil.
 */
- (void)stopNotifier;

/**
 *  get current syste network status
 *
 *  @return
 */
- (NetworkReachabilityStatus)currentSystemNetworkReachabilityStatus;

@end

NSString * kReachabilityChangedNotification = @"kNetworkReachabilityChangedNotification";

#define kShouldPrintReachabilityFlags 0
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

/**
 *  all is SCNetworkReachability need
 */

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


#pragma mark    - NetworkReachabilityManager

#define kDefaultHostName @"www.baidu.com"

#define SuppressPerformSelectorLeakWarning(Stuff) \
do { \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
Stuff; \
_Pragma("clang diagnostic pop") \
} while (0)

NSString * const kNetworkStatusChange = @"NetworkStatusChange";

@interface NetworkReachabilityManager ()<SimplePingDelegate>
{
    id _target;
    SEL _sel;
    
    //num of try count . when u ping success and network status change it will set 0 . and it will add 1 when u
    //try to simple ping time out
    NSInteger _tryCount;
    
    //save SCNetworkReachabilityStatus
    NetworkReachabilityStatus _networkStatus;
    
    //save previous network sttus . if it is equal to current network status we will not post notification . default is 999 so that the first time from manager start notifier manager must post notification.
    NetworkStatus _previousStatus;
    
    //save simple ping status for checking time out . when u start simple ping it will set YES . And it will set NO when u receive response data project.
    BOOL _isSimplePing;
    
    /**
     *  heart packet for monitor network status . it will post notification when network status changed. default timerInval is 10s.
     */
    NSTimer * _timer;
}

/**
 *  U MUST NOTE THAT ARC is deallocating the SimplePing instancetype so u need to use property or set a iVar . if not,delegate method will not be called.
    And whoes property is Simple Ping also need to handle like Simple Ping
 */
@property (nonatomic,strong)SimplePing * simplePing;

@end

@implementation NetworkReachabilityManager

-(instancetype)init
{
    if (self = [super init])
    {
        //init properties
        _hostName = kDefaultHostName;
        
        _tryCount = 0;
        _isSimplePing = NO;
        
        _connect = NO;
        
        _networkStatus = NetworkNotReachable;
        
        _previousStatus = 999;
    }
    return self;
}

+(instancetype)sharedManager
{
    static NetworkReachabilityManager * networkReachabilityManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        networkReachabilityManager = [[NetworkReachabilityManager alloc] init];
    });
    
    return networkReachabilityManager;
}

-(void)dealloc
{
    [self stopNotifier];
}

-(void)startNotifier
{
    LBWNetworkReachability * networkReachability = [LBWNetworkReachability sharedSystemNetworkReachability];
    [networkReachability startNotifier];
    
    _networkStatus = [networkReachability currentSystemNetworkReachabilityStatus];
    
    _timer = [NSTimer timerWithTimeInterval:10.f target:self selector:@selector(startSimplePing) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
    
    //System network reachability
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkDidChanged:) name:kReachabilityChangedNotification object:nil];
    
    if (_networkStatus != NetworkNotReachable)
    {
        [self startSimplePing];
    }
    else
    {
        _currentNetworkStatus = NetworkStatusUnableConnect;
        _previousStatus = _currentNetworkStatus;
        
        [self flagForSimplePingResult:NO];
    }
}

-(void)stopNotifier
{
    NSLog(@"monitor stop");
    
    LBWNetworkReachability * networkReachability = [LBWNetworkReachability sharedSystemNetworkReachability];
    [networkReachability stopNotifier];
    
    [self removeObserver:self forKeyPath:kReachabilityChangedNotification];
    
    if (_simplePing)
    {
        [_simplePing stop];
    }
    
    if (_timer)
    {
        [_timer invalidate];
        _timer = nil;
    }
    [self clearSimplePing];
}

#pragma mark    - Simple Ping Handling
- (void)clearSimplePing
{
    if (_simplePing)
    {
        _simplePing = nil;
        _simplePing.delegate = nil;
    }
}

- (void)startSimplePing
{
    if (_isSimplePing)
    {
        return;
    }
    
    NSLog(@"------第%ld次开始ping",_tryCount);
    
    [self clearSimplePing];
    
    _simplePing = [[SimplePing alloc] initWithHostName:_hostName];
    _simplePing.delegate = self;
    
    [_simplePing start];
    _isSimplePing = YES;
    
    [self performSelector:@selector(checkSimplePingTimeOut) withObject:nil afterDelay:2.0f];
}

- (void)checkSimplePingTimeOut
{
    NSLog(@"check simple ping time out");
    if (_isSimplePing)
    {
        if (_tryCount < 3)
        {
            [self startSimplePing];
            ++_tryCount;
        }
        else
        {
            _currentNetworkStatus = NetworkStatusUnableConnect;
            [self flagForSimplePingResult:NO];
        }
    }
}

- (void)flagForSimplePingResult:(BOOL)isConnect
{
    NSLog(@"simple ping end");
    _isSimplePing = NO;
    _tryCount = 0;
    _connect = isConnect;
    
    NetworkStatus status = NetworkStatusUnableConnect;
    if (_networkStatus == NetworkStatusUnableConnect)
    {
        status = NetworkStatusUnableConnect;
    }
    else
    {
        if (isConnect)
        {
            if (_networkStatus == NetworkViaWiFi)
            {
                status = NetworkStatusWifiAbleConnect;
            }
            else
            {
                status = NetworkStatusWWANAbleConnect;
            }
        }
        else
        {
            if (_networkStatus == NetworkViaWiFi)
            {
                status = NetworkStatusWifiUnableConnect;
            }
            else
            {
                status = NetworkStatusWWANUnableConnect;
            }
        }
        
        _currentNetworkStatus = status;
    }
    
    
    
    //network status not chage so that manager doesn't post notification.
    if (_currentNetworkStatus == _previousStatus)
    {
        return;
    }
    
    _previousStatus = _currentNetworkStatus;
    [[NSNotificationCenter defaultCenter] postNotificationName:kNetworkStatusChange object:self];
}

#pragma mark    - Notification
- (void)networkDidChanged:(NSNotification *)notification
{
    LBWNetworkReachability * tmp = notification.object;
    _networkStatus = [tmp currentSystemNetworkReachabilityStatus];
    
    NSLog(@"system network status changed");
    if ( _networkStatus != NetworkNotReachable)
    {
        [self startSimplePing];
    }
    else
    {
        [self flagForSimplePingResult:NO];
    }
}

#pragma mark    - Simple Ping Delegate
- (void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address
{
    NSLog(@"simple ping start with addresss");
    //reset
    _tryCount = 0;
    
    //send data
    [_simplePing sendPingWithData:nil];
}

- (void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error
{
    [self flagForSimplePingResult:NO];
}

- (void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber
{
    [self flagForSimplePingResult:YES];
}


- (void)simplePing:(SimplePing *)pinger didFailToSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber error:(NSError *)error
{
    [self flagForSimplePingResult:NO];
}

- (void)simplePing:(SimplePing *)pinger didSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber
{
    
}

- (void)simplePing:(SimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet
{
    [self flagForSimplePingResult:YES];
}
@end
