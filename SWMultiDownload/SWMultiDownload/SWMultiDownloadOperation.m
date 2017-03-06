//
//  SWMultiDownloadOperation.m
//  多线程下载大文件
//
//  Created by 周少文 on 2017/1/26.
//  Copyright © 2017年 Yidu. All rights reserved.
//

#import "SWMultiDownloadOperation.h"
#import "SWMultiDownloadManager.h"
#import <objc/runtime.h>

#define MaxMultilineCount 4

@interface SWMultiDownloadOperation ()
{
    NSURLSessionDataTask *_sessionDataTask;
    dispatch_group_t _group;
}

@property (nonatomic,strong) NSMutableArray<SWSingleDownloader *> *singleDownloaders;
@property (nonatomic,strong) NSError *error;
@property (nonatomic,strong) void(^downloadProgress)(CGFloat progress);
@property (nonatomic,strong) void(^finishDownload)(NSError *error);
@property (nonatomic,strong) NSFileHandle *fileHandle;
@property (nonatomic,strong) NSString *tmpDownloadPath;//临时下载路径

@end

@implementation SWMultiDownloadOperation

- (void)main
{
    if(self.isCancelled) return;
    _group = dispatch_group_create();
    dispatch_group_enter(_group);
    if([[NSFileManager defaultManager] fileExistsAtPath:_filePath]){
        NSLog(@"文件已存在");
        [self setValue:@(YES) forKey:@"isFileExists"];
        [self setValue:@1 forKey:@"progress"];
        _isFileExists = YES;
        [self finishDownloading];
        return;
    }
    [self setValue:@(NO) forKey:@"isFileExists"];
    [self getFileSizeCompletion:^{
        if(self.isCancelled) return;
        [self.singleDownloaders makeObjectsPerformSelector:@selector(startDownloading)];
        [self setValue:@(YES) forKey:@"isDownloading"];
        NSLog(@"多线程下载开始");
    }];
    dispatch_group_wait(_group, DISPATCH_TIME_FOREVER);
    NSLog(@"*******操作执行完毕*********");

}

- (void)cancel
{
    [super cancel];
    [self cancelDownloading];
}

- (NSMutableArray *)singleDownloaders {
    if(!_singleDownloaders){
        _singleDownloaders = [NSMutableArray array];
    }
    return _singleDownloaders;
}

- (NSFileHandle *)fileHandle {
    if(!_fileHandle){
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:_tmpDownloadPath];
    }
    return _fileHandle;
}

- (void)getFileSizeCompletion:(void(^)())complete {
    if(_sessionDataTask){
        [_sessionDataTask cancel];
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_url?:@""]];
    request.HTTPMethod = @"HEAD";//从指定的url上获取header内容(类似Get方式)
    NSURLSession *session = [NSURLSession sharedSession];
    _sessionDataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            long long fileSize = response.expectedContentLength;
            [self createDownloadersWithFileSize:fileSize];
            if(complete){
                complete();
            }
        });
    }];
    [_sessionDataTask resume];
}

- (void)createDownloadersWithFileSize:(long long)fileSize {
    long long singleFileSize = 0;//每条子线程下载量
    if(fileSize % MaxMultilineCount == 0){
        singleFileSize = fileSize/MaxMultilineCount;
    }else{
        singleFileSize = fileSize/MaxMultilineCount + 1;
    }
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_t beginReceiveDataGroup = dispatch_group_create();
    for(int i=0;i<MaxMultilineCount;i++){
        SWSingleDownloader *downloader = [[SWSingleDownloader alloc] init];
        downloader.url = _url;
        NSString *fileName = [[_filePath stringByDeletingPathExtension] lastPathComponent];
        NSString *filePath = [[_filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:[NSString stringWithFormat:@"%.2d-%@",i,fileName]];
        downloader.filePath = [filePath stringByAppendingPathExtension:@"tmp"];
        downloader.begin = i*singleFileSize;
        downloader.end = downloader.begin + singleFileSize - 1;
        dispatch_group_enter(beginReceiveDataGroup);
        downloader.beginReceiveDataCallback = ^{
            dispatch_group_leave(beginReceiveDataGroup);
        };
        dispatch_group_enter(group);
        downloader.finishDownload = ^(NSError *error){
            if(error){
                self.error = error;
                NSLog(@"%d号单线下载失败,原因:%@",i,error.localizedDescription);
            }
            dispatch_group_leave(group);
        };
        [self.singleDownloaders addObject:downloader];
    }
    
    dispatch_group_notify(beginReceiveDataGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (SWSingleDownloader *singleDownloader in self.singleDownloaders) {
            __weak typeof(singleDownloader) weakDownloader = singleDownloader;
            singleDownloader.progressCallback = ^(CGFloat progress){
                @synchronized (self) {
                    NSLog(@"%zd号单线下载器正在下载,下载进度:%f",[self.singleDownloaders indexOfObject:weakDownloader],progress);
                    __block CGFloat temp = 0;
                    [self.singleDownloaders enumerateObjectsUsingBlock:^(SWSingleDownloader*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        temp += obj.progress;
                    }];
                    CGFloat totalProgress = temp/MaxMultilineCount;
                    [self setValue:@(totalProgress) forKey:@"progress"];
                    if(self.singleDownloaders.count == MaxMultilineCount){
                        NSLog(@"总的下载进度:-----------%f",totalProgress);
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if(self.downloadProgress && self.singleDownloaders.count == MaxMultilineCount){
                            self.downloadProgress(totalProgress);
                        }
                    });
                }
            };
        }
    });

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"多线程下载结束");
        if(!_error){
            [self combineFilesCompleted:^{
                [self finishDownloading];
            }];
        }else{
            [self finishDownloading];
        }
    });
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:_tmpDownloadPath]){
        //创建临时文件，文件大小要跟实际大小一致,保证多余的文件的不会重复.
        //1.创建一个0字节文件
        [fileManager createFileAtPath:_tmpDownloadPath contents:nil attributes:nil];
        //2.指定文件大小
        [self.fileHandle truncateFileAtOffset:fileSize];
    }
}

- (void)startDownloadingWithUrl:(NSString *)url toPath:(NSString *)filePath progress:(void(^)(CGFloat progress))progressBlock completed:(void(^)(NSError *error))completedBlock {
    if(_isDownloading) return;
    _error = nil;
    _filePath = filePath;
    _tmpDownloadPath = [[_filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"totalTmp"];
    _url = url;
    _finishDownload = completedBlock;
    _downloadProgress = progressBlock;
    if(self.isFinished) return;
    SWMultiDownloadManager *manager = [SWMultiDownloadManager sharedInstance];
    if([manager.queue operationCount] > 0){
        [self addDependency:[[manager.queue operations] lastObject]];
    }
    [manager.queue addOperation:self];
}

- (void)cancelDownloading {
    [self.singleDownloaders makeObjectsPerformSelector:@selector(cancelDownloading)];
    [self setValue:@(NO) forKey:@"isDownloading"];
    [self.singleDownloaders removeAllObjects];
    if(_group){
        dispatch_group_leave(_group);
    }
}

- (void)finishDownloading {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(_finishDownload){
            _finishDownload(_error);
        }
        if(_downloadProgress && !_error){
            _downloadProgress(1);
        }
    });
    [self setValue:@(NO) forKey:@"isDownloading"];
    [self.singleDownloaders removeAllObjects];
    if(_group){
        dispatch_group_leave(_group);
    }
}

//合并文件
- (void)combineFilesCompleted:(void(^)())completed {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *path = [_filePath stringByDeletingLastPathComponent];
        NSArray *array = [fileManager contentsOfDirectoryAtPath:path error:nil];
        NSString *fileName = [[[_filePath lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"tmp"];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH %@",fileName];
        NSArray *filteredArray = [array filteredArrayUsingPredicate:predicate];
        dispatch_apply(filteredArray.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t index) {
            NSString *fileName = filteredArray[index];
            NSString *path = [[_filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:fileName];
            //读取文件片段
            NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
            NSData *data = [handle readDataToEndOfFile];
            unsigned long long offset = self.singleDownloaders[index].begin;
            [self.fileHandle seekToFileOffset:offset];
            [self.fileHandle writeData:data];
            [handle closeFile];
            //删除下载的片段文件
            [fileManager removeItemAtPath:path error:nil];
            NSLog(@"%zd合并完成",index);
        });
        NSLog(@"全部合并完成");
        [self.fileHandle closeFile];
        self.fileHandle = nil;
        //移动文件,以达到重命名文件的目的
        [fileManager moveItemAtPath:_tmpDownloadPath toPath:_filePath error:nil];
        if(completed){
            dispatch_async(dispatch_get_main_queue(), ^{
                completed();
            });
        }
    });
}

- (void)dealloc
{
    NSLog(@"%s",__func__);
}






@end
