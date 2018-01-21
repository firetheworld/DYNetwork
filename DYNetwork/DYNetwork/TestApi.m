//
//  TestApi.m
//  DYNetwork
//
//  Created by 郑良凯 on 2018/1/21.
//  Copyright © 2018年 flame. All rights reserved.
//

#import "TestApi.h"

@implementation TestApi {
	NSString *_location;
}

- (instancetype)initWithLocation:(NSString *)location {
	self = [super init];
	if (self) {
		_location = location;
	}
	return self;
}

- (NSString *)requestUrl {
	return [NSString stringWithFormat:@"/s6/weather/forecast?location=%@",_location];
}

@end
