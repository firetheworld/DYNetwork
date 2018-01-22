//
//  YTKNetworkAgent.m
//
//  Copyright (c) 2012-2016 YTKNetwork https://github.com/yuantiku
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "YTKNetworkAgent.h"
#import "YTKNetworkConfig.h"
#import "YTKNetworkPrivate.h"
#import "DYProxyManager.h"

#import <pthread/pthread.h>

#define Lock() pthread_mutex_lock(&_lock)
#define Unlock() pthread_mutex_unlock(&_lock)

#define kYTKNetworkIncompleteDownloadFolderName @"Incomplete"

static const NSString* mockResultKey = @"result";
static const NSString* mockErrorKey = @"error";

@interface YTKNetworkAgent () <DYBaseNetProxyDelegate>

@end

@implementation YTKNetworkAgent {
    NSMutableDictionary<NSNumber *, YTKBaseRequest *> *_requestsRecord;
    dispatch_queue_t _processingQueue;
    pthread_mutex_t _lock;
    NSIndexSet *_allStatusCodes;
	DYBaseNetProxy *_proxy;
}

#pragma mark - Life Cycle
+ (YTKNetworkAgent *)sharedAgent {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _requestsRecord = [NSMutableDictionary dictionary];
        _processingQueue = dispatch_queue_create("com.yuantiku.networkagent.processing", DISPATCH_QUEUE_CONCURRENT);
        _allStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(100, 500)];
        pthread_mutex_init(&_lock, NULL);
		_proxy = [DYProxyManager getNetProxy];
		_proxy.delegate = self;
    }
    return self;
}

#pragma mark - Manage Request
- (void)addRequest:(YTKBaseRequest *)request {
    NSParameterAssert(request != nil);

    NSError * __autoreleasing requestSerializationError = nil;
	
	// mock Data
	id mockData = [request mockData];
	if (mockData) {
		[self handleMockData:request];
		return;
	}
	
	request.requestTask = [_proxy sessionTaskForRequest:request error:&requestSerializationError];

    if (requestSerializationError) {
        [self requestDidFailWithRequest:request error:requestSerializationError];
        return;
    }

    NSAssert(request.requestTask != nil, @"requestTask should not be nil");

    // Set request task priority
    // !!Available on iOS 8 +
    if ([request.requestTask respondsToSelector:@selector(priority)]) {
        switch (request.requestPriority) {
            case YTKRequestPriorityHigh:
                request.requestTask.priority = NSURLSessionTaskPriorityHigh;
                break;
            case YTKRequestPriorityLow:
                request.requestTask.priority = NSURLSessionTaskPriorityLow;
                break;
            case YTKRequestPriorityDefault:
                /*!!fall through*/
            default:
                request.requestTask.priority = NSURLSessionTaskPriorityDefault;
                break;
        }
    }

    // Retain request
    YTKLog(@"Add request: %@", NSStringFromClass([request class]));
    [self addRequestToRecord:request];
    [request.requestTask resume];
}

- (void)cancelRequest:(YTKBaseRequest *)request {
    NSParameterAssert(request != nil);

    if (request.resumableDownloadPath) {
        NSURLSessionDownloadTask *requestTask = (NSURLSessionDownloadTask *)request.requestTask;
        [requestTask cancelByProducingResumeData:^(NSData *resumeData) {
            NSURL *localUrl = [self incompleteDownloadTempPathForDownloadPath:request.resumableDownloadPath];
            [resumeData writeToURL:localUrl atomically:YES];
        }];
    } else {
        [request.requestTask cancel];
    }

    [self removeRequestFromRecord:request];
}

- (void)cancelAllRequests {
    Lock();
    NSArray *allKeys = [_requestsRecord allKeys];
    Unlock();
    if (allKeys && allKeys.count > 0) {
        NSArray *copiedKeys = [allKeys copy];
        for (NSNumber *key in copiedKeys) {
            Lock();
            YTKBaseRequest *request = _requestsRecord[key];
            Unlock();
            // We are using non-recursive lock.
            // Do not lock `stop`, otherwise deadlock may occur.
            [request stop];
        }
    }
}

- (BOOL)validateResult:(YTKBaseRequest *)request error:(NSError * _Nullable __autoreleasing *)error {
    BOOL result = [request statusCodeValidator];
    if (!result) {
        if (error) {
            *error = [NSError errorWithDomain:YTKRequestValidationErrorDomain code:YTKRequestValidationErrorInvalidStatusCode userInfo:@{NSLocalizedDescriptionKey:@"Invalid status code"}];
        }
        return result;
    }
    id json = [request responseJSONObject];
    id validator = [request jsonValidator];
    if (json && validator) {
        result = [YTKNetworkUtils validateJSON:json withValidator:validator];
        if (!result) {
            if (error) {
                *error = [NSError errorWithDomain:YTKRequestValidationErrorDomain code:YTKRequestValidationErrorInvalidJSONFormat userInfo:@{NSLocalizedDescriptionKey:@"Invalid JSON format"}];
            }
            return result;
        }
    }
    return YES;
}

- (void)addRequestToRecord:(YTKBaseRequest *)request {
	Lock();
	_requestsRecord[@(request.requestTask.taskIdentifier)] = request;
	Unlock();
}

- (void)removeRequestFromRecord:(YTKBaseRequest *)request {
	Lock();
	[_requestsRecord removeObjectForKey:@(request.requestTask.taskIdentifier)];
	YTKLog(@"Request queue size = %zd", [_requestsRecord count]);
	Unlock();
}

#pragma mark - Deal Call Back
- (void)requestDidSucceedWithRequest:(YTKBaseRequest *)request {
	@autoreleasepool {
		[request requestCompletePreprocessor];
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		[request toggleAccessoriesWillStopCallBack];
		[request requestCompleteFilter];
		
		if (request.delegate != nil) {
			[request.delegate requestFinished:request];
		}
		[request toggleAccessoriesDidStopCallBack];
	});
}

- (void)requestDidFailWithRequest:(YTKBaseRequest *)request error:(NSError *)error {
	request.error = error;
	YTKLog(@"Request %@ failed, status code = %ld, error = %@",
		   NSStringFromClass([request class]), (long)request.responseStatusCode, error.localizedDescription);
	
	// Save incomplete download data.
	NSData *incompleteDownloadData = error.userInfo[NSURLSessionDownloadTaskResumeData];
	if (incompleteDownloadData) {
		[incompleteDownloadData writeToURL:[self incompleteDownloadTempPathForDownloadPath:request.resumableDownloadPath] atomically:YES];
	}
	
	// Load response from file and clean up if download task failed.
	if ([request.responseObject isKindOfClass:[NSURL class]]) {
		NSURL *url = request.responseObject;
		if (url.isFileURL && [[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
			request.responseData = [NSData dataWithContentsOfURL:url];
			request.responseString = [[NSString alloc] initWithData:request.responseData encoding:[YTKNetworkUtils stringEncodingWithRequest:request]];
			
			[[NSFileManager defaultManager] removeItemAtURL:url error:nil];
		}
		request.responseObject = nil;
	}
	
	@autoreleasepool {
		[request requestFailedPreprocessor];
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		[request toggleAccessoriesWillStopCallBack];
		[request requestFailedFilter];
		
		if (request.delegate != nil) {
			[request.delegate requestFailed:request];
		}
		[request toggleAccessoriesDidStopCallBack];
	});
}

#pragma mark - Mock
- (void)handleMockData:(YTKBaseRequest *)request {
	id mockData = [request mockData];
	NSInteger delayTime = [request mockDelay];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if (request.delegate) {
			// if offer NSDictionary
			// get key 'result'
			// get key 'error'
			if ([mockData isKindOfClass:[NSDictionary class]]) {
				id result = mockData[mockResultKey];
				if (result) {
					request.responseObject = result;
					[self requestDidSucceedWithRequest:request];
				} else {
					id error = mockData[mockErrorKey];
					request.error = error;
					[self requestDidFailWithRequest:request error:error];
				}
			}
			else {
				// do nothing
			}
		}
		else {
			// do nothing
		}
	});
}


#pragma mark - DYBaseNetProxyDelegate
- (void)handleRequestResult:(NSURLSessionTask *)task responseObject:(id)responseObject error:(NSError *)error {
	Lock();
	YTKBaseRequest *request = _requestsRecord[@(task.taskIdentifier)];
	Unlock();
	
	// When the request is cancelled and removed from records, the underlying
	// AFNetworking failure callback will still kicks in, resulting in a nil `request`.
	//
	// Here we choose to completely ignore cancelled tasks. Neither success or failure
	// callback will be called.
	if (!request) {
		return;
	}
	
	// If request.delegate is nil, just cancel this request
	if (!request.delegate) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self removeRequestFromRecord:request];
		});
		return;
	}
	
	YTKLog(@"Finished Request: %@", NSStringFromClass([request class]));
	
	NSError * __autoreleasing serializationError = nil;
	NSError * __autoreleasing validationError = nil;
	
	NSError *requestError = nil;
	BOOL succeed = NO;
	
	request.responseObject = responseObject;
	if ([request.responseObject isKindOfClass:[NSData class]]) {
		request.responseData = responseObject;
		request.responseObject = [_proxy getResonseObject];
	}
	if (error) {
		succeed = NO;
		requestError = error;
	} else if (serializationError) {
		succeed = NO;
		requestError = serializationError;
	} else {
		succeed = [self validateResult:request error:&validationError];
		requestError = validationError;
	}
	
	if (succeed) {
		[self requestDidSucceedWithRequest:request];
	} else {
		[self requestDidFailWithRequest:request error:requestError];
	}
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[self removeRequestFromRecord:request];
	});
}

#pragma mark - Resumable Download

- (NSString *)incompleteDownloadTempCacheFolder {
    NSFileManager *fileManager = [NSFileManager new];
    static NSString *cacheFolder;

    if (!cacheFolder) {
        NSString *cacheDir = NSTemporaryDirectory();
        cacheFolder = [cacheDir stringByAppendingPathComponent:kYTKNetworkIncompleteDownloadFolderName];
    }

    NSError *error = nil;
    if(![fileManager createDirectoryAtPath:cacheFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
        YTKLog(@"Failed to create cache directory at %@", cacheFolder);
        cacheFolder = nil;
    }
    return cacheFolder;
}

- (NSURL *)incompleteDownloadTempPathForDownloadPath:(NSString *)downloadPath {
    NSString *tempPath = nil;
    NSString *md5URLString = [YTKNetworkUtils md5StringFromString:downloadPath];
    tempPath = [[self incompleteDownloadTempCacheFolder] stringByAppendingPathComponent:md5URLString];
    return [NSURL fileURLWithPath:tempPath];
}

@end
