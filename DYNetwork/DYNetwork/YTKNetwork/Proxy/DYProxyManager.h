//
//  DYProxyManager.h
//  DYNetwork
//
//  Created by 郑良凯 on 2018/1/21.
//  Copyright © 2018年 flame. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DYBaseNetProxy.h"

@interface DYProxyManager : NSObject

+ (DYBaseNetProxy *)getNetProxy;

@end
