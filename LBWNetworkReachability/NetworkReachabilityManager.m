//
//  NetworkReachabilityManager.m
//  LBWNetworkReachability
//
//  Created by ml on 16/7/12.
//  Copyright © 2016年 李博文. All rights reserved.
//

#import "NetworkReachabilityManager.h"
#import "SimplePing.h"
#import "LBWNetworkReachability.h"

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
    
    //save simple ping status for checking time out . when u start simple ping it will set YES . And it will set NO when u receive response data project.
    BOOL _isSimplePing;
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
        
        _networkStatus = NetworkNotReachable;
        
        //System network reachability
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkDidChanged:) name:kReachabilityChangedNotification object:nil];
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


-(void)startNotifier
{
    LBWNetworkReachability * networkReachability = [LBWNetworkReachability sharedSystemNetworkReachability];
    [networkReachability startNotifier];
    
    _networkStatus = [networkReachability currentSystemNetworkReachabilityStatus];
    if (_networkStatus != NetworkNotReachable)
    {
        [self startSimplePing];
    }
    else
    {
        _currentNetworkStatus = NetworkStatusUnableConnect;
        [[NSNotificationCenter defaultCenter] postNotificationName:kNetworkStatusChange object:self];
    }
}

-(void)stopNotifier
{
    LBWNetworkReachability * networkReachability = [LBWNetworkReachability sharedSystemNetworkReachability];
    [networkReachability stopNotifier];
    
    if (_simplePing)
    {
        [_simplePing stop];
    }
    [self clearSimplePing];
}

#pragma mark    -Simple Ping Handle
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
            [[NSNotificationCenter defaultCenter] postNotificationName:kNetworkStatusChange object:self];
        }
    }
}

- (void)flagForSimplePingResult:(BOOL)isConnect
{
    _isSimplePing = NO;
    _tryCount = 0;
    
    NetworkStatus status = NetworkStatusUnableConnect;
    
    if (isConnect)
    {
        if (_networkStatus == NetworkViaWiFi)
        {
            status = NetworkStatusWifiAbleConnect;
        }
        else
        {
            status = NetworkStatusWifiUnableConnect;
        }
    }
    else
    {
        if (_networkStatus == NetworkViaWiFi)
        {
            status = NetworkStatusWWANAbleConnect;
        }
        else
        {
            status = NetworkStatusWWANUnableConnect;
        }
    }
    
    _currentNetworkStatus = status;
    [[NSNotificationCenter defaultCenter] postNotificationName:kNetworkStatusChange object:self];
}

#pragma mark    -Notification
- (void)networkDidChanged:(NSNotification *)notification
{
    LBWNetworkReachability * tmp = notification.object;
    _networkStatus = [tmp currentSystemNetworkReachabilityStatus];
    
    NSLog(@"hahahaha");
    if ( _networkStatus != NetworkNotReachable)
    {
        [self startSimplePing];
    }
    else
    {
        [self flagForSimplePingResult:NO];
    }
}

#pragma mark    -Simple Ping Delegate
- (void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address
{
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
