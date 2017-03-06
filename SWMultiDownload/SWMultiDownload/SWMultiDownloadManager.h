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

@property (nonatomic,strong,readonly) NSOperationQueue *queue;

+ (instancetype)sharedInstance;

@end
