//
//  DYProxyManager.m
//  DYNetwork
//
//  Created by 郑良凯 on 2018/1/21.
//  Copyright © 2018年 flame. All rights reserved.
//

#import "DYProxyManager.h"
#import "DYANFNetProxy.h"

@implementation DYProxyManager

+ (DYBaseNetProxy *)getNetProxy {
	return [[DYANFNetProxy alloc] init];
}

@end
