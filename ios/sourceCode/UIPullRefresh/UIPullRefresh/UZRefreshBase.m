/**
  * APICloud Modules
  * Copyright (c) 2014-2015 by APICloud, Inc. All Rights Reserved.
  * Licensed under the terms of the The MIT License (MIT).
  * Please see the license.html included with this distribution for details.
  */

#import "UZRefreshBase.h"
#import "UZAppUtils.h"
#import "NSDictionaryUtils.h"

typedef enum {
    ACPullToRefreshStateNormal = 1,
    ACPullToRefreshStatePulling,
    ACPullToRefreshStateTriggered,
    ACPullToRefreshStateLoading
} ACPullToRefreshState;

@interface UZRefreshBase ()
<UIScrollViewDelegate>
{
    NSInteger setCbid;
    float boardW, boardH, imageSize;
    float changeY;
    NSString *pullImgPath;
    NSMutableArray *_transImgAry, *_loadImgAry;
    UIImageView *_gifImageView;
}

@property (nonatomic, strong) NSMutableArray *transImgAry;
@property (nonatomic, strong) NSMutableArray *loadImgAry;
@property (nonatomic, strong) UIImageView *gifImageView;
@property (nonatomic, readwrite) ACPullToRefreshState state;

@end

@implementation UZRefreshBase

@synthesize transImgAry = _transImgAry;
@synthesize loadImgAry = _loadImgAry;
@synthesize gifImageView = _gifImageView;
@synthesize state;

#pragma mark - lifeCycle -

- (void)dispose {
    if (setCbid >= 0) {
        [self deleteCallback:setCbid];
    }
    if (_transImgAry) {
        [_transImgAry removeAllObjects];
        self.transImgAry = nil;
    }
    if (_loadImgAry) {
        [_loadImgAry removeAllObjects];
        self.loadImgAry = nil;
    }
    if (_gifImageView) {
        [_gifImageView removeFromSuperview];
        self.gifImageView = nil;
    }
}

- (id)initWithUZWebView:(UZWebView *)webView_ {
    self = [super initWithUZWebView:webView_];
    if (self != nil) {
        [self setWebViewScrollDelegate:self];
        boardW = self.scrollView.frame.size.width;
        boardH = self.scrollView.frame.size.height;
        
        imageSize = boardW*(50.0/320.0);//下拉刷新图标大小
        changeY = (5.0/4.0) * (10.0/9.0) * imageSize;
        
        _transImgAry = [NSMutableArray array];
        _loadImgAry = [NSMutableArray array];
        
        self.state = ACPullToRefreshStateNormal;
        
        setCbid = -1;
    }
    return self;
}

#pragma mark - interface -

- (void)setCustomRefreshHeaderInfo:(NSDictionary *)paramsDict_ {
    NSDictionary *imageInfo = [paramsDict_ dictValueForKey:@"image" defaultValue:@{}];
    if (imageInfo.count == 0) {
        return;
    }
    NSString *pullPath = [imageInfo stringValueForKey:@"pull" defaultValue:@""];
    if (pullPath.length == 0) {
        return;
    } else {
        pullImgPath = [self getPathWithUZSchemeURL:pullPath];
    }
    NSArray *transformAry = [imageInfo arrayValueForKey:@"transform" defaultValue:@[]];
    if (transformAry.count == 0) {
        //return;
    } else {
        for (NSString *singleImgPath in transformAry) {
            if ([singleImgPath isKindOfClass:[NSString class]] && singleImgPath.length>0) {
                NSString *realPath = [self getPathWithUZSchemeURL:singleImgPath];
                UIImage *image = [UIImage imageWithContentsOfFile:realPath];
                if (image) {
                    [_transImgAry addObject:image];
                }
            }
        }
    }
    NSArray *loadAry = [imageInfo arrayValueForKey:@"load" defaultValue:@[]];
    if (loadAry.count == 0) {
        return;
    } else {
        for (NSString *singleImgPath in loadAry) {
            if ([singleImgPath isKindOfClass:[NSString class]] && singleImgPath.length>0) {
                NSString *realPath = [self getPathWithUZSchemeURL:singleImgPath];
                UIImage *image = [UIImage imageWithContentsOfFile:realPath];
                if (image) {
                    [_loadImgAry addObject:image];
                }
            }
        }
    }
    if (setCbid >= 0) {
        [self deleteCallback:setCbid];
    }
    setCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    //添加背景
    NSString *bgColor = [paramsDict_ stringValueForKey:@"bgColor" defaultValue:@"#C0C0C0"];
    UIView *bgView = [[UIView alloc]init];
    bgView.frame = CGRectMake(0, -boardH, boardW, boardH);
    bgView.backgroundColor = [UZAppUtils colorFromNSString:bgColor];
    [self.scrollView addSubview:bgView];
    //添加图片容器
    self.gifImageView = [[UIImageView alloc] init];
    [bgView addSubview:_gifImageView];
}

- (void)refreshHeaderLoading:(NSDictionary *)paramsDict_ {
    [self resetGifImageFrame:-changeY];
    [self startLoadingGifImage];
    UIEdgeInsets contentInset = UIEdgeInsetsMake(changeY, 0, 0, 0);
    [UIView animateWithDuration:0.5
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         self.scrollView.contentInset = contentInset;
                         self.scrollView.contentOffset = CGPointMake(0, -changeY);
                     }
                     completion:^(BOOL finished){
                         [self sendResultEventWithCallbackId:setCbid dataDict:nil errDict:nil doDelete:NO];
                     }];
    self.state = ACPullToRefreshStateLoading;
}

- (void)refreshHeaderLoadDone:(NSDictionary *)paramsDict_ {
    UIEdgeInsets contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
    [UIView animateWithDuration:0.5
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         self.scrollView.contentInset = contentInset;
                         self.scrollView.contentOffset = CGPointMake(0, 0);
                     }
                     completion:nil];
    self.state = ACPullToRefreshStateNormal;
}

#pragma mark - UIScrollViewDelegate -

- (void)resetGifImageFrame:(float)offsetY {
    float dist = -offsetY;
    CGRect rectOriginal = _gifImageView.frame;
    if (dist <= changeY) {
        float gifImgY = dist - dist/5.0;
        rectOriginal.origin.y = boardH - gifImgY;
        float gifImgH = gifImgY - gifImgY/10.0;
        rectOriginal.size.height = gifImgH;
    }
    rectOriginal.origin.x = (boardW-imageSize)/2.0;
    rectOriginal.size.width = imageSize;
    _gifImageView.frame = rectOriginal;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {//2...
    float offsetY = scrollView.contentOffset.y;
    if (offsetY < 0) {
        float dist = -offsetY;
        //改变刷新图标内容
        if (dist <= changeY) {//下拉距离在阈值内
            switch (self.state) {
                case ACPullToRefreshStateNormal:
                    //改变刷新图标大小
                    [self resetGifImageFrame:offsetY];
                    self.state = ACPullToRefreshStatePulling;
                    [_gifImageView stopAnimating];
                    _gifImageView.animationImages = nil;
                    _gifImageView.image = [UIImage imageWithContentsOfFile:pullImgPath];
                    break;
                    
                case ACPullToRefreshStatePulling:
                    //改变刷新图标大小
                    [self resetGifImageFrame:offsetY];
                    break;
                    
                case ACPullToRefreshStateTriggered:
                    //改变刷新图标大小
                    [self resetGifImageFrame:offsetY];
                    self.state = ACPullToRefreshStatePulling;
                    [_gifImageView stopAnimating];
                    _gifImageView.animationImages = nil;
                    _gifImageView.image = [UIImage imageWithContentsOfFile:pullImgPath];
                    break;
                    
                case ACPullToRefreshStateLoading:
                    break;
                    
                default:
                    break;
            }
        } else {
            switch (self.state) {
                case ACPullToRefreshStateNormal:
                    break;
                    
                case ACPullToRefreshStatePulling:
                    self.state = ACPullToRefreshStateTriggered;
                    [self transformTheImage];
                    break;
                    
                case ACPullToRefreshStateTriggered:
                    break;
                    
                case ACPullToRefreshStateLoading:
                    break;
                    
                default:
                    break;
            }
        }
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {//4
    float offsetY = scrollView.contentOffset.y;
    if (offsetY < 0) {
        float dist = -offsetY;
        if (dist > changeY) {
            if (self.state != ACPullToRefreshStateLoading) {
                UIEdgeInsets contentInset = UIEdgeInsetsMake(changeY, 0, 0, 0);
                self.scrollView.contentInset = contentInset;
                self.state = ACPullToRefreshStateLoading;
                [self startLoadingGifImage];
                [self sendResultEventWithCallbackId:setCbid dataDict:nil errDict:nil doDelete:NO];
            }
        }
    }
}

#pragma mark - Uitility -

- (void)transformTheImage {
    [NSThread detachNewThreadSelector:@selector(startTimer) toTarget:self withObject:nil];
    float duration = self.transImgAry.count * 0.1;
    _gifImageView.animationImages = self.transImgAry;
    _gifImageView.animationDuration = duration;
    _gifImageView.animationRepeatCount = 1;
    [self.gifImageView startAnimating];
}

- (void)startTimer {
    float duration = self.transImgAry.count * 0.1;
    [NSTimer scheduledTimerWithTimeInterval:duration target:self selector:@selector(toMainUpdate) userInfo:nil repeats:NO];
    [[NSRunLoop currentRunLoop] run];
}

- (void)toMainUpdate {
    [self performSelectorOnMainThread:@selector(startLoadingGifImage) withObject:nil waitUntilDone:YES];
}

- (void)startLoadingGifImage {
    float duration = self.loadImgAry.count * 0.05;
    _gifImageView.animationImages = self.loadImgAry;
    _gifImageView.animationDuration = duration;
    _gifImageView.animationRepeatCount = 0;
    [self.gifImageView startAnimating];
}

@end
