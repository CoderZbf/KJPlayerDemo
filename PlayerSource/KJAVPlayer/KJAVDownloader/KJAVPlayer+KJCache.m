//
//  KJAVPlayer+KJCache.m
//  KJPlayerDemo
//
//  Created by 杨科军 on 2021/2/10.
//  Copyright © 2021 杨科军. All rights reserved.
//  https://github.com/yangKJ/KJPlayerDemo

#import "KJAVPlayer+KJCache.h"
#import <objc/runtime.h>
#import "KJResourceLoader.h"
#import "KJFileHandleInfo.h"

@interface KJAVPlayer ()
@property (nonatomic,strong) KJResourceLoader *connection;
@property (nonatomic,strong) KJFileHandleInfo *cacheInfo;
@property (nonatomic,assign) KJPlayerState state;
@property (nonatomic,strong) NSError *playError;
@property (nonatomic,strong) NSURL *originalURL;
@property (nonatomic,strong) dispatch_group_t group;
@property (nonatomic,assign) float progress;

@end

@implementation KJAVPlayer (KJCache)

/// 使用边播边缓存，名字不能更改
/// @param videoURL 视频链接地址
- (void)kj_cachePlayVideoURL:(NSURL *)videoURL{
    if (objc_getAssociatedObject(self, &connectionKey)) {
        objc_setAssociatedObject(self, &connectionKey, nil, OBJC_ASSOCIATION_RETAIN);
    }
    self.state = KJPlayerStateBuffering;
    self.playError = [KJLogManager kj_errorSummarizing:KJPlayerCustomCodeCacheNone];
    self.asset = [AVURLAsset URLAssetWithURL:self.connection.kj_createSchemeURL(videoURL)
                                     options:self.requestHeader];
    [self.asset.resourceLoader setDelegate:self.connection queue:dispatch_get_global_queue(0, 0)];
}

#pragma mark - associated

- (KJFileHandleInfo *)cacheInfo{
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setCacheInfo:(KJFileHandleInfo *)cacheInfo{
    objc_setAssociatedObject(self, @selector(cacheInfo), cacheInfo, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - lazy

static char connectionKey;
- (KJResourceLoader *)connection{
    KJResourceLoader *connection = objc_getAssociatedObject(self, &connectionKey);
    if (connection == nil) {
        connection = [[KJResourceLoader alloc] init];
        objc_setAssociatedObject(self, &connectionKey, connection, OBJC_ASSOCIATION_RETAIN);
        PLAYER_WEAKSELF;
        connection.kDidFinished = ^(KJResourceLoader *loader, NSError *error) {
            if (error == nil) return;
            [loader kj_cancelLoading];
            // 存储数据
            weakself.bridge.anyObject = error;
            weakself.bridge.anyOtherObject = weakself.cacheInfo.fileName;
            [weakself.bridge kj_anyArgumentsIndex:521 withBlock:^(NSMutableDictionary * data){
                [data setValue:weakself.cacheInfo.videoURL.absoluteString forKey:@"videoUrl"];
                [data setValue:weakself.cacheInfo.fileFormat forKey:@"videoFormat"];
                [data setValue:@(weakself.cacheInfo.contentLength) forKey:@"videoContentLength"];
            }];
        };
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kj_playerCacheInfoChanged:)
                                                     name:kPlayerFileHandleInfoNotification object:nil];
    }
    return connection;
}

#pragma mark - notification

- (void)kj_playerCacheInfoChanged:(NSNotification*)notification{
    self.cacheInfo = notification.userInfo[kPlayerFileHandleInfoKey];
    PLAYER_WEAKSELF;
    kGCD_player_main(^{
        // 是否开启缓存
        if ([weakself.bridge kj_readStatus:520]) {
            weakself.progress = weakself.cacheInfo.progress;
        }
    });
}

@end

