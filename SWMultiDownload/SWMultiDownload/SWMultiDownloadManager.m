//
//  SWMultiDownloadManager.m
//  多线程下载大文件
//
//  Created by zhoushaowen on 2017/3/3.
//  Copyright © 2017年 Yidu. All rights reserved.
//

#import "SWMultiDownloadManager.h"

static SWMultiDownloadManager *manager = nil;

@interface SWMultiDownloadManager ()
{
    NSOperationQueue *_queue;
}

@end

@implementation SWMultiDownloadManager

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(!manager){
            manager = [[self alloc] init];
        }
    });
    return manager;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(!manager){
            manager = [super allocWithZone:zone];
        }
    });
    return manager;
}

- (instancetype)init
{
    if(self = [super init]){
        _queue = [[NSOperationQueue alloc] init];
        _queue.maxConcurrentOperationCount = 1;
    }
    return self;
}

- (void)downloadBigFileWithUrl:(NSString *)url toPath:(NSString *)filePath progress:(SWMultiDownloadProgressBlock)progressBlock completed:(SWMultiDownloadCompletedBlock)completedBlock {
    NSAssert(url.length > 0, @"url不能为空");
    for (SWMultiDownloadOperation *operation in _queue.operations) {
        if([operation.url isEqualToString:url]){
            NSLog(@"url:%@,已经在下载中了",url);
            return;
        }
    }
    SWMultiDownloadOperation *operation = [SWMultiDownloadOperation new];
    operation.url = url;
    operation.filePath = filePath;
    operation.progressBlock = progressBlock;
    operation.completedBlock = completedBlock;
    if([_queue operationCount] > 0){
        [operation addDependency:[[_queue operations] lastObject]];
    }
    [_queue addOperation:operation];
}

- (void)cancelDownloadWithUrlString:(NSString *)urlString {
    for (SWMultiDownloadOperation *operation in _queue.operations) {
        if([operation.url isEqualToString:urlString]){
            [operation cancelDownloading];
            break;
        }
    }
}














@end
