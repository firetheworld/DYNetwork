//
//  DYANFNetProxy.m
//  DYNetwork
//
//  Created by 郑良凯 on 2018/1/21.
//  Copyright © 2018年 flame. All rights reserved.
//

#import "DYANFNetProxy.h"
#import <AFNetworking/AFNetworking.h>

@implementation DYANFNetProxy {
	AFJSONResponseSerializer *_jsonResponseSerializer;
	AFXMLParserResponseSerializer *_xmlParserResponseSerialzier;
	AFHTTPSessionManager *_manager;
}

#pragma mark - Init
- (instancetype)init {
	self = [super init];
	if (self) {
		_manager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:self.config.sessionConfiguration];
	}
	return self;
}

#pragma mark - Serializer Init
- (AFJSONResponseSerializer *)jsonResponseSerializer {
	if (!_jsonResponseSerializer) {
		_jsonResponseSerializer = [AFJSONResponseSerializer serializer];
//		_jsonResponseSerializer.acceptableStatusCodes = _allStatusCodes;
		
	}
	return _jsonResponseSerializer;
}

- (AFXMLParserResponseSerializer *)xmlParserResponseSerialzier {
	if (!_xmlParserResponseSerialzier) {
		_xmlParserResponseSerialzier = [AFXMLParserResponseSerializer serializer];
//		_xmlParserResponseSerialzier.acceptableStatusCodes = _allStatusCodes;
	}
	return _xmlParserResponseSerialzier;
}

- (AFHTTPRequestSerializer *)requestSerializerForRequest:(YTKBaseRequest *)request {
	AFHTTPRequestSerializer *requestSerializer = nil;
	if (request.requestSerializerType == YTKRequestSerializerTypeHTTP) {
		requestSerializer = [AFHTTPRequestSerializer serializer];
	} else if (request.requestSerializerType == YTKRequestSerializerTypeJSON) {
		requestSerializer = [AFJSONRequestSerializer serializer];
	}
	
	requestSerializer.timeoutInterval = [request requestTimeoutInterval];
	requestSerializer.allowsCellularAccess = [request allowsCellularAccess];
	
	// If api needs server username and password
	NSArray<NSString *> *authorizationHeaderFieldArray = [request requestAuthorizationHeaderFieldArray];
	if (authorizationHeaderFieldArray != nil) {
		[requestSerializer setAuthorizationHeaderFieldWithUsername:authorizationHeaderFieldArray.firstObject
														  password:authorizationHeaderFieldArray.lastObject];
	}
	
	// If api needs to add custom value to HTTPHeaderField
	NSDictionary<NSString *, NSString *> *headerFieldValueDictionary = [request requestHeaderFieldValueDictionary];
	if (headerFieldValueDictionary != nil) {
		for (NSString *httpHeaderField in headerFieldValueDictionary.allKeys) {
			NSString *value = headerFieldValueDictionary[httpHeaderField];
			[requestSerializer setValue:value forHTTPHeaderField:httpHeaderField];
		}
	}
	return requestSerializer;
}

#pragma mark -
- (NSURLSessionTask *)sessionTaskForRequest:(YTKBaseRequest *)request error:(NSError * _Nullable __autoreleasing *)error {
	YTKRequestMethod method = [request requestMethod];
	NSString *url = [self buildRequestUrl:request];
	id param = request.requestArgument;
	AFConstructingBlock constructingBlock = [request constructingBodyBlock];
	AFHTTPRequestSerializer *requestSerializer = [self requestSerializerForRequest:request];
	
	switch (method) {
		case YTKRequestMethodGET:
			if (request.resumableDownloadPath) {
				return [self downloadTaskWithDownloadPath:request.resumableDownloadPath requestSerializer:requestSerializer URLString:url parameters:param progress:request.resumableDownloadProgressBlock error:error];
			} else {
				return [self dataTaskWithHTTPMethod:@"GET" requestSerializer:requestSerializer URLString:url parameters:param error:error];
			}
		case YTKRequestMethodPOST:
			return [self dataTaskWithHTTPMethod:@"POST" requestSerializer:requestSerializer URLString:url parameters:param constructingBodyWithBlock:constructingBlock error:error];
		case YTKRequestMethodHEAD:
			return [self dataTaskWithHTTPMethod:@"HEAD" requestSerializer:requestSerializer URLString:url parameters:param error:error];
		case YTKRequestMethodPUT:
			return [self dataTaskWithHTTPMethod:@"PUT" requestSerializer:requestSerializer URLString:url parameters:param error:error];
		case YTKRequestMethodDELETE:
			return [self dataTaskWithHTTPMethod:@"DELETE" requestSerializer:requestSerializer URLString:url parameters:param error:error];
		case YTKRequestMethodPATCH:
			return [self dataTaskWithHTTPMethod:@"PATCH" requestSerializer:requestSerializer URLString:url parameters:param error:error];
	}
}


#pragma mark -

- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
							   requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
									   URLString:(NSString *)URLString
									  parameters:(id)parameters
										   error:(NSError * _Nullable __autoreleasing *)error {
	return [self dataTaskWithHTTPMethod:method requestSerializer:requestSerializer URLString:URLString parameters:parameters constructingBodyWithBlock:nil error:error];
}

- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
							   requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
									   URLString:(NSString *)URLString
									  parameters:(id)parameters
					   constructingBodyWithBlock:(nullable void (^)(id <AFMultipartFormData> formData))block
										   error:(NSError * _Nullable __autoreleasing *)error {
	NSMutableURLRequest *request = nil;

	if (block) {
		request = [requestSerializer multipartFormRequestWithMethod:method URLString:URLString parameters:parameters constructingBodyWithBlock:block error:error];
	} else {
		request = [requestSerializer requestWithMethod:method URLString:URLString parameters:parameters error:error];
	}

	__block NSURLSessionDataTask *dataTask = nil;
	dataTask = [_manager dataTaskWithRequest:request
						   completionHandler:^(NSURLResponse * __unused response, id responseObject, NSError *_error) {
							   if ([self.delegate respondsToSelector:@selector(handleRequestResult:responseObject:error:)]) {
//								   [self.delegate handleRequestResult:dataTask responseObject:responseObject error:_error];
								   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
									   [self.delegate handleRequestResult:dataTask responseObject:responseObject error:_error];

								   });
							   }
						   }];

	return dataTask;
}

- (NSURLSessionDownloadTask *)downloadTaskWithDownloadPath:(NSString *)downloadPath
										 requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
												 URLString:(NSString *)URLString
												parameters:(id)parameters
												  progress:(nullable void (^)(NSProgress *downloadProgress))downloadProgressBlock
													 error:(NSError * _Nullable __autoreleasing *)error {
	// add parameters to URL;
	NSMutableURLRequest *urlRequest = [requestSerializer requestWithMethod:@"GET" URLString:URLString parameters:parameters error:error];

	NSString *downloadTargetPath;
	BOOL isDirectory;
	if(![[NSFileManager defaultManager] fileExistsAtPath:downloadPath isDirectory:&isDirectory]) {
		isDirectory = NO;
	}
	// If targetPath is a directory, use the file name we got from the urlRequest.
	// Make sure downloadTargetPath is always a file, not directory.
	if (isDirectory) {
		NSString *fileName = [urlRequest.URL lastPathComponent];
		downloadTargetPath = [NSString pathWithComponents:@[downloadPath, fileName]];
	} else {
		downloadTargetPath = downloadPath;
	}

	// AFN use `moveItemAtURL` to move downloaded file to target path,
	// this method aborts the move attempt if a file already exist at the path.
	// So we remove the exist file before we start the download task.
	// https://github.com/AFNetworking/AFNetworking/issues/3775
	if ([[NSFileManager defaultManager] fileExistsAtPath:downloadTargetPath]) {
		[[NSFileManager defaultManager] removeItemAtPath:downloadTargetPath error:nil];
	}

//	BOOL resumeDataFileExists = [[NSFileManager defaultManager] fileExistsAtPath:[self incompleteDownloadTempPathForDownloadPath:downloadPath].path];
//	NSData *data = [NSData dataWithContentsOfURL:[self incompleteDownloadTempPathForDownloadPath:downloadPath]];
//	BOOL resumeDataIsValid = [YTKNetworkUtils validateResumeData:data];

//	BOOL canBeResumed = resumeDataFileExists && resumeDataIsValid;
//	BOOL resumeSucceeded = NO;
	__block NSURLSessionDownloadTask *downloadTask = nil;
	// Try to resume with resumeData.
	// Even though we try to validate the resumeData, this may still fail and raise excecption.
//	if (canBeResumed) {
//		@try {
//			downloadTask = [_manager downloadTaskWithResumeData:data progress:downloadProgressBlock destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
//				return [NSURL fileURLWithPath:downloadTargetPath isDirectory:NO];
//			} completionHandler:
//							^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
//								[self handleRequestResult:downloadTask responseObject:filePath error:error];
//							}];
//			resumeSucceeded = YES;
//		} @catch (NSException *exception) {
//			YTKLog(@"Resume download failed, reason = %@", exception.reason);
//			resumeSucceeded = NO;
//		}
//	}
//	if (!resumeSucceeded) {
//		downloadTask = [_manager downloadTaskWithRequest:urlRequest progress:downloadProgressBlock destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
//			return [NSURL fileURLWithPath:downloadTargetPath isDirectory:NO];
//		} completionHandler:
//						^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
//							[self handleRequestResult:downloadTask responseObject:filePath error:error];
//						}];
//	}
	return downloadTask;
}

@end
