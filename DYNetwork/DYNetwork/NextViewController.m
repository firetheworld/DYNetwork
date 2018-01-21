//
//  NextViewController.m
//  DYNetwork
//
//  Created by 郑良凯 on 2018/1/21.
//  Copyright © 2018年 flame. All rights reserved.
//

#import "NextViewController.h"
#import "TestApi.h"

@interface NextViewController ()<YTKRequestDelegate, YTKRequestAccessory>

@property (nonatomic, strong) TestApi *api;

@end

@implementation NextViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	self.view.backgroundColor = [UIColor cyanColor];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.api = [[TestApi alloc] initWithLocation:@"nanjing"];
	self.api.delegate = self;
//	[self.api addAccessory:@[self]];
	[self.api start];
	[self.api stop];
}

- (void)viewDidAppear:(BOOL)animated {
	TestApi *api = [[TestApi alloc] initWithLocation:@"beijing"];
	api.delegate = self;
	[api start];
}

- (void)dealloc {
	NSLog(@"NextViewController dealloc");
}

#pragma mark - YTKRequestAccessory
- (void)requestWillStart:(id)request {
	NSLog(@"requestWillStart");
}

- (void)requestDidStop:(id)request {
	NSLog(@"requestDidStop");
}

#pragma mark - YTKRequestDelegate
- (void)requestFailed:(__kindof YTKBaseRequest *)request {
	NSLog(@"requestFailed");
}

- (void)requestFinished:(__kindof YTKBaseRequest *)request {
	NSLog(@"requestFinished: %@", request);
}

@end
