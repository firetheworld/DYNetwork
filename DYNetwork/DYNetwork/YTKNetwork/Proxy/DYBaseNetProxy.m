//
//  DYBaseNetProxy.m
//  DYNetwork
//
//  Created by 郑良凯 on 2018/1/21.
//  Copyright © 2018年 flame. All rights reserved.
//

#import "DYBaseNetProxy.h"


@implementation DYBaseNetProxy

#pragma mark - Life Cycle
- (instancetype)init {
	self = [super init];
	if (self) {
		_config = [YTKNetworkConfig sharedConfig];
	}
	return self;
}

#pragma mark -

- (NSString *)buildRequestUrl:(YTKBaseRequest *)request {
	NSParameterAssert(request != nil);
	
	NSString *detailUrl = [request requestUrl];
	NSURL *temp = [NSURL URLWithString:detailUrl];
	// If detailUrl is valid URL
	if (temp && temp.host && temp.scheme) {
		return detailUrl;
	}
	// Filter URL if needed
	NSArray *filters = [_config urlFilters];
	for (id<YTKUrlFilterProtocol> f in filters) {
		detailUrl = [f filterUrl:detailUrl withRequest:request];
	}
	
	NSString *baseUrl;
	if ([request useCDN]) {
		if ([request cdnUrl].length > 0) {
			baseUrl = [request cdnUrl];
		} else {
			baseUrl = [_config cdnUrl];
		}
	} else {
		if ([request baseUrl].length > 0) {
			baseUrl = [request baseUrl];
		} else {
			baseUrl = [_config baseUrl];
		}
	}
	// URL slash compability
	NSURL *url = [NSURL URLWithString:baseUrl];
	
	if (baseUrl.length > 0 && ![baseUrl hasSuffix:@"/"]) {
		url = [url URLByAppendingPathComponent:@""];
	}
	
	return [NSURL URLWithString:detailUrl relativeToURL:url].absoluteString;
}

#pragma mark - Subclass override
- (NSURLSessionTask *)sessionTaskForRequest:(YTKBaseRequest *)request error:(NSError * _Nullable __autoreleasing *)error {
	return nil;
}

- (id)getResonsePbject {
	return nil;
}

@end
