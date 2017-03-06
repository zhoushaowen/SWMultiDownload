//
//  SWMultiDownloadManager.m
//  多线程下载大文件
//
//  Created by zhoushaowen on 2017/3/3.
//  Copyright © 2017年 Yidu. All rights reserved.
//

#import "SWMultiDownloadManager.h"
#import "SWMultiDownloadOperation.h"

static SWMultiDownloadManager *manager = nil;

@interface SWMultiDownloadManager ()

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
        _queue.maxConcurrentOperationCount = 3;
    }
    return self;
}
















@end
