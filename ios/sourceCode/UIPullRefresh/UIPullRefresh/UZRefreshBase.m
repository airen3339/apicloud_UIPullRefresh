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
    float transDuration;
    
    UIImageView *_transImageView, *_pullImageView, *_loadImageView;
}

@property (nonatomic, strong) UIImageView *transImageView, *pullImageView, *loadImageView;
@property (nonatomic, readwrite) ACPullToRefreshState state;

@end

@implementation UZRefreshBase

@synthesize transImageView = _transImageView, pullImageView = _pullImageView, loadImageView = _loadImageView;
@synthesize state;

#pragma mark - lifeCycle -

- (void)dispose {
    if (setCbid >= 0) {
        [self deleteCallback:setCbid];
    }
    if (_transImageView) {
        [_transImageView removeFromSuperview];
        self.transImageView = nil;
    }
    if (_pullImageView) {
        [_pullImageView removeFromSuperview];
        self.pullImageView = nil;
    }
    if (_loadImageView) {
        [_loadImageView removeFromSuperview];
        self.loadImageView = nil;
    }
}

- (id)initWithUZWebView:(UZWebView *)webView_ {
    self = [super initWithUZWebView:webView_];
    if (self != nil) {
        [self setWebViewScrollDelegate:self];
        boardW = self.scrollView.frame.size.width;
        boardH = self.scrollView.frame.size.height;
        
        imageSize = boardW * (50.0/320.0);//下拉刷新图标大小
        changeY = (5.0/4.0) * imageSize;// * (10.0/9.0);
        
        self.state = ACPullToRefreshStateNormal;
        
        setCbid = -1;
    }
    return self;
}

#pragma mark - interface -

- (void)setCustomRefreshHeaderInfo:(NSDictionary *)paramsDict_ {
    NSDictionary *imageInfo = [paramsDict_ dictValueForKey:@"image" defaultValue:@{}];
    if (imageInfo.count == 0) {
        //return;
    }
    self.pullImageView = [[UIImageView alloc] init];
    CGRect pullRect;
    pullRect.origin.x = (boardW-imageSize)/2.0;
    pullRect.origin.y = 0;
    pullRect.size.width = imageSize;
    pullRect.size.height = 0;
    NSString *pullPath = [imageInfo stringValueForKey:@"pull" defaultValue:@""];
    if (pullPath.length == 0) {
        pullRect.origin.x = (boardW-imageSize+15)/2.0;
        pullRect.size.width = imageSize-15;
        pullPath = [[NSBundle mainBundle]pathForResource:@"res_UIPullRefresh/pull" ofType:@"png"];
    }
    NSString *pullImgPath = [self getPathWithUZSchemeURL:pullPath];
    _pullImageView.frame = pullRect;
    //转动画
    self.transImageView = [[UIImageView alloc] init];
    NSArray *transformAry = [imageInfo arrayValueForKey:@"transform" defaultValue:@[]];
    if (transformAry.count == 0) {
        NSMutableArray *imgAry = [NSMutableArray array];
        for (int i=1; i<6; i++) {
            NSString *imageName = [NSString stringWithFormat:@"res_UIPullRefresh/transform%d",i];
            NSString *imagePath = [[NSBundle mainBundle]pathForResource:imageName ofType:@"png"];
            [imgAry addObject:imagePath];
        }
        transformAry = imgAry;
        _transImageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    NSMutableArray *_transImgAry = [NSMutableArray array];
    for (NSString *singleImgPath in transformAry) {
        if ([singleImgPath isKindOfClass:[NSString class]] && singleImgPath.length>0) {
            NSString *realPath = [self getPathWithUZSchemeURL:singleImgPath];
            UIImage *image = [UIImage imageWithContentsOfFile:realPath];
            if (image) {
                [_transImgAry addObject:image];
            }
        }
    }
    //加载
    self.loadImageView = [[UIImageView alloc] init];
    NSArray *loadAry = [imageInfo arrayValueForKey:@"load" defaultValue:@[]];
    if (loadAry.count == 0) {
        NSMutableArray *imgAry = [NSMutableArray array];
        for (int i=1; i<9; i++) {
            NSString *imageName = [NSString stringWithFormat:@"res_UIPullRefresh/shake%d",i];
            NSString *imagePath = [[NSBundle mainBundle]pathForResource:imageName ofType:@"png"];
            [imgAry addObject:imagePath];
        }
        loadAry = imgAry;
        _loadImageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    NSMutableArray *_loadImgAry = [NSMutableArray array];
    for (NSString *singleImgPath in loadAry) {
        if ([singleImgPath isKindOfClass:[NSString class]] && singleImgPath.length>0) {
            NSString *realPath = [self getPathWithUZSchemeURL:singleImgPath];
            UIImage *image = [UIImage imageWithContentsOfFile:realPath];
            if (image) {
                [_loadImgAry addObject:image];
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
    self.scrollView.bounces = YES;
    //添加图片容器
    _pullImageView.image = [UIImage imageWithContentsOfFile:pullImgPath];
    
    _transImageView.hidden = YES;
    transDuration = _transImgAry.count * 0.1;
    _transImageView.animationImages = _transImgAry;
    _transImageView.animationDuration = transDuration;
    _transImageView.animationRepeatCount = 1;
    CGRect transRect;
    transRect.origin.x = (boardW-imageSize)/2.0;
    transRect.origin.y = boardH - ((changeY-imageSize)/4.0+imageSize);
    transRect.size.width = imageSize;
    transRect.size.height = imageSize;
    _transImageView.frame = transRect;
    
    _loadImageView.hidden = YES;
    float loadDuration = _loadImgAry.count * 0.05;
    _loadImageView.animationImages = _loadImgAry;
    _loadImageView.animationDuration = loadDuration;
    _loadImageView.animationRepeatCount = 0;
    CGRect loadRect;
    loadRect.origin.x = (boardW-imageSize)/2.0;
    loadRect.origin.y = boardH - ((changeY-imageSize)/4.0+imageSize);
    loadRect.size.width = imageSize;
    loadRect.size.height = imageSize;
    _loadImageView.frame = loadRect;
    
    
    [bgView addSubview:_transImageView];
    [bgView addSubview:_pullImageView];
    [bgView addSubview:_loadImageView];
}

- (void)refreshHeaderLoading:(NSDictionary *)paramsDict_ {
    [self resetGifImageFrame:-changeY];
    [self showLoad];
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
    [UIView animateWithDuration:0.3
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
                    [self showPull];
                    break;
                    
                case ACPullToRefreshStatePulling:
                    //改变刷新图标大小
                    [self resetGifImageFrame:offsetY];
                    break;
                    
                case ACPullToRefreshStateTriggered:
                    //改变刷新图标大小
                    [self resetGifImageFrame:offsetY];
                    self.state = ACPullToRefreshStatePulling;
                    [self showPull];
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
                dispatch_async(dispatch_get_main_queue(), ^{
                    [UIView animateWithDuration:0.25 animations:^{
                        CGFloat top = changeY;
                        UIEdgeInsets inset = scrollView.contentInset;
                        inset.top = top;
                        scrollView.contentInset = inset;
                    } completion:^(BOOL finished) {
                        [self sendResultEventWithCallbackId:setCbid dataDict:nil errDict:nil doDelete:NO];
                    }];
                });

                //[UIView beginAnimations:nil context:NULL];
                //[UIView setAnimationDuration:0.3];
                //scrollView.contentInset = UIEdgeInsetsMake(changeY, 0.0f, 0.0f, 0.0f);
                //[UIView commitAnimations];
                self.state = ACPullToRefreshStateLoading;
                [self showLoad];
            }
        }
    }
}

#pragma mark - Uitility -

- (void)resetGifImageFrame:(float)offsetY {
    float dist = -offsetY;
    CGRect rectOriginal = _pullImageView.frame;
    if (dist <= changeY) {
        float gifImgY = dist - dist/5.0;
        rectOriginal.origin.y = boardH - gifImgY;
        float gifImgH = gifImgY - gifImgY/3.0;
        rectOriginal.size.height = gifImgH;
    }
    _pullImageView.frame = rectOriginal;
}

- (void)transformTheImage {
    [NSThread detachNewThreadSelector:@selector(startTimer) toTarget:self withObject:nil];
    [self showTrans];
}

- (void)startTimer {
    [NSTimer scheduledTimerWithTimeInterval:transDuration target:self selector:@selector(toMainUpdate) userInfo:nil repeats:NO];
    [[NSRunLoop currentRunLoop] run];
}

- (void)toMainUpdate {
    [self performSelectorOnMainThread:@selector(showLoad) withObject:nil waitUntilDone:YES];
}

- (void)showPull {
    self.pullImageView.hidden = NO;
    
    self.loadImageView.hidden = YES;
    [self.loadImageView stopAnimating];
    
    self.transImageView.hidden = YES;
    [self.transImageView stopAnimating];
}

- (void)showTrans {
    self.pullImageView.hidden = YES;
    
    self.loadImageView.hidden = YES;
    [self.loadImageView stopAnimating];
    
    self.transImageView.hidden = NO;
    [self.transImageView startAnimating];
}

- (void)showLoad {
    self.pullImageView.hidden = YES;
    
    self.loadImageView.hidden = NO;
    [self.loadImageView startAnimating];
    
    self.transImageView.hidden = YES;
    [self.transImageView stopAnimating];
}
@end
