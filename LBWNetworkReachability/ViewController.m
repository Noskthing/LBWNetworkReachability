//
//  ViewController.m
//  LBWNetworkReachability
//
//  Created by ml on 16/7/11.
//  Copyright © 2016年 李博文. All rights reserved.
//

#import "ViewController.h"
#import "NetworkReachabilityManager.h"


@interface ViewController ()

@property (nonatomic,strong)NetworkReachabilityManager * manager;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
//     _manager = [[NetworkReachabilityManager alloc] init];
//    [_manager startNotifier];
//    
//    SimplePing * simplePing = [[SimplePing alloc] initWithHostName:@"www.baidu.com"];
//    simplePing.delegate = self;
//    simplePing.addressStyle = SimplePingAddressStyleAny;
//    [simplePing start];
    
}

-(void)viewWillAppear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(test:) name:kNetworkStatusChange object:nil];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark    -Simple Ping Delegate

- (void)test:(NSNotification *)notification
{
    NetworkReachabilityManager * manager = notification.object;
    
    switch (manager.currentNetworkStatus)
    {
        case 0:
        {
            NSLog(@"unable");
        }
            break;
        case 1:
        {
            NSLog(@"able");
        }
            break;
        case 2:
        {
            NSLog(@"unable");
        }
            break;
        case 3:
        {
            NSLog(@"able");
        }
            break;
        case 4:
        {
            NSLog(@"unable");
        }
            break;
            
        default:
            break;
    }
}
@end