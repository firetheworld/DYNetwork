//
//  DYBaseNetProxy.h
//  DYNetwork
//
//  Created by 郑良凯 on 2018/1/21.
//  Copyright © 2018年 flame. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YTKBaseRequest.h"
#import "YTKNetworkConfig.h"

@protocol DYBaseNetProxyDelegate <NSObject>

@required
- (void)handleRequestResult:(NSURLSessionTask *)task responseObject:(id)responseObject error:(NSError *)error;

@end

@interface DYBaseNetProxy : NSObject <DYBaseNetProxyDelegate>

@property (nonatomic, weak) id<DYBaseNetProxyDelegate> delegate;
@property (nonatomic, strong) YTKNetworkConfig *config;

- (id)getResonsePbject;

- (NSString *)buildRequestUrl:(YTKBaseRequest *)request;

- (NSURLSessionTask *)sessionTaskForRequest:(YTKBaseRequest *)request error:(NSError * _Nullable __autoreleasing *)error;
@end
