//
//  SWMultiDownloadManager.h
//  多线程下载大文件
//
//  Created by zhoushaowen on 2017/3/3.
//  Copyright © 2017年 Yidu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SWMultiDownloadOperation.h"

@interface SWMultiDownloadManager : NSObject

@property (nonatomic,readonly,strong) NSOperationQueue *queue;

+ (instancetype)sharedInstance;

/**
 开始下载

 @param url 资源url
 @param filePath 保存路径
 @param progressBlock 下载进度回调
 @param completedBlock 下载完成回调
 */
- (void)downloadBigFileWithUrl:(NSString *)url toPath:(NSString *)filePath progress:(SWMultiDownloadProgressBlock)progressBlock completed:(SWMultiDownloadCompletedBlock)completedBlock;

/**
 取消下载

 @param urlString 资源url
 */
- (void)cancelDownloadWithUrlString:(NSString *)urlString;


@end
