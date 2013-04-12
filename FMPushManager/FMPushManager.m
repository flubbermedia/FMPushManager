//
//  FMPushManager.m
//
//  Created by Maurizio Cremaschi on 23/03/2013.
//  Copyright (c) 2013 Flubber Media Ltd. All rights reserved.
//

#import "FMPushManager.h"
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>

static NSString * const kDefaultAPNUserInfoURLKey = @"flubber.url";
static NSString * const kUserDefaultsURLKey = @"com.flubbermedia.pushmanager.url.cached";

@implementation NSURLRequest (DictionaryParameters)

+ (NSURLRequest *)requestWithURL:(NSURL *)url GETParameters:(NSDictionary *)parameters
{
    NSMutableArray *parts = [NSMutableArray new];
    for (NSString *key in parameters) {
        NSString *encodedValue = [parameters[key] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *encodedKey = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *part = [NSString stringWithFormat: @"%@=%@", encodedKey, encodedValue];
        [parts addObject:part];
    }
    NSString *encodedDictionary = [parts componentsJoinedByString:@"&"];
    NSString *urlPath = [NSString stringWithFormat:@"%@?%@", url, encodedDictionary];
    
    return [NSURLRequest requestWithURL:[NSURL URLWithString:urlPath]];
}

@end

@interface FMPushManager ()

@property (strong, nonatomic) UIView *darkView;
@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) UIButton *closeButton;
@property (strong, nonatomic) UIActivityIndicatorView *activityIndicatorView;
@property (assign, nonatomic) BOOL webViewIsVisible;

@end

@implementation FMPushManager

+ (FMPushManager *)sharedInstance
{
    static FMPushManager *_sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [FMPushManager new];
    });
    return _sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        _apnUserInfoURLKey = kDefaultAPNUserInfoURLKey;
        _frameForiPhonePanel = CGRectMake(0, 0, 240, 300);
        _frameForiPadPanel = CGRectMake(0, 0, 480, 600);
        _requestLocalParameters = @{
                                    @"appid":      [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"],
                                    @"appversion": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
                                    @"applocale":  [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode],
                                    @"device":     [[UIDevice currentDevice] model],
                                    };
    }
    return self;
}

#pragma mark - Public methods

- (void)registerForApplicationNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (&UIApplicationDidFinishLaunchingNotification) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidFinishLaunching:)
                                                     name:UIApplicationDidFinishLaunchingNotification
                                                   object:nil];
    }
    
    if (&UIApplicationDidBecomeActiveNotification) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
    
    if (&UIApplicationDidEnterBackgroundNotification) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    }
}

- (void)handleAPN:(NSDictionary *)userInfo
{
    NSString *urlString = userInfo[_apnUserInfoURLKey];
    NSURL *url = (urlString.length) ? [NSURL URLWithString:urlString] : nil;
    
    if ([url.absoluteString hasPrefix:@"http"]) {
        [self showWebOverlay:url];
    } else if (url) {
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url];
        }
    } else {
        [self showStandardAlertView:userInfo];
    }
}

- (void)debugWithURL:(NSURL *)url
{
#if DEBUG
    [[NSUserDefaults standardUserDefaults] setURL:url forKey:kUserDefaultsURLKey];
#endif
}

#pragma mark - Standard alert view

- (void)showStandardAlertView:(NSDictionary *)userInfo
{
    NSString *applicationName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    
    NSDictionary *aps = userInfo[@"aps"];
    NSString *message = aps[@"alert"];
    NSString *sound = aps[@"sound"];
    
    // play sound
    NSString *soundPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:sound];
    if ([[NSFileManager defaultManager] fileExistsAtPath:soundPath])
    {
        NSURL *soundURL = [NSURL fileURLWithPath:soundPath];
        SystemSoundID theSound;
        AudioServicesCreateSystemSoundID((__bridge CFURLRef)soundURL, &theSound);
        AudioServicesPlaySystemSound(theSound);
    }
    
    // show alert
    UIAlertView *alertView = [UIAlertView new];
    alertView.title = applicationName;
    alertView.message = message;
    [alertView addButtonWithTitle:@"OK"];
    [alertView show];
}

#pragma mark - Web overlay

- (void)showWebOverlay:(NSURL *)url
{
    [self showWebOverlay:url caching:YES];
}

- (void)showWebOverlay:(NSURL *)url caching:(BOOL)caching
{
    [self clearNotifications];
    
    if (caching) {
        [[NSUserDefaults standardUserDefaults] setURL:url forKey:kUserDefaultsURLKey];
        return;
    }
    
    if (_webViewIsVisible) {
        [_webView loadRequest:[self requestWithURL:url]];
        return;
    }
    
    _webViewIsVisible = YES;
    
    UIView *rootView = [UIApplication sharedApplication].keyWindow.rootViewController.view;
    
    _darkView = [[UIView alloc] initWithFrame:rootView.bounds];
    _darkView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    _darkView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    _darkView.alpha = 0;
    [rootView addSubview:_darkView];
    
    CGRect frame;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        frame = _frameForiPadPanel;
    } else {
        frame = _frameForiPhonePanel;
    }
    
    _webView = [[UIWebView alloc] initWithFrame:frame];
    _webView.delegate = self;
    _webView.backgroundColor = [UIColor blackColor];
    _webView.opaque = NO;
    _webView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleRightMargin;
    _webView.center = CGPointMake(CGRectGetWidth(_darkView.bounds)/2, CGRectGetHeight(_darkView.bounds)/2);
    _webView.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, 0, _webView.center.y + CGRectGetHeight(_webView.bounds)/2);
    _webView.scalesPageToFit = NO;
    _webView.scrollView.scrollEnabled = NO;
    _webView.layer.borderColor = [UIColor whiteColor].CGColor;
    _webView.layer.borderWidth = 5;
    _webView.layer.cornerRadius = 10;
    _webView.layer.masksToBounds = YES;
    [_darkView addSubview:_webView];
    
    _closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _closeButton.frame = CGRectMake(CGRectGetWidth(_webView.bounds) - 36 - 5, 5, 36, 36);
    [_closeButton setImage:[UIImage imageNamed:@"FMPushManager.bundle/btn-close.png"] forState:UIControlStateNormal];
    [_closeButton addTarget:self action:@selector(tapOnCloseButton:) forControlEvents:UIControlEventTouchUpInside];
    [_webView addSubview:_closeButton];
    
    _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    _activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleRightMargin;
    _activityIndicatorView.center = CGPointMake(CGRectGetWidth(_webView.bounds)/2, CGRectGetHeight(_webView.bounds)/2);
    _activityIndicatorView.hidesWhenStopped = YES;
    [_webView addSubview:_activityIndicatorView];
    
	[_webView loadRequest:[self requestWithURL:url]];
    
    double delayInSeconds = 0.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [UIView animateWithDuration:0.3 animations:^{
            _darkView.alpha = 1;
            _webView.transform = CGAffineTransformIdentity;
        }];
    });
}

- (void)dismissWebOverlay:(BOOL)animated
{
    _webViewIsVisible = NO;
    
    [UIView animateWithDuration:(animated ? 0.3 : 0) animations:^{
        _darkView.alpha = 0;
        _webView.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, 0, _webView.center.y + CGRectGetHeight(_webView.bounds)/2);
    } completion:^(BOOL finished) {
        [_darkView removeFromSuperview];
        _darkView = nil;
        _webView = nil;
        _closeButton = nil;
    }];
}

#pragma mark - Actions & Gestures

- (void)tapOnCloseButton:(id)sender
{
    [self dismissWebOverlay:YES];
}
         
#pragma mark - Application notifications

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSDictionary *apn = notification.userInfo[UIApplicationLaunchOptionsRemoteNotificationKey];
    if (apn) {
        [self handleAPN:apn];
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    NSURL *url = [[NSUserDefaults standardUserDefaults] URLForKey:kUserDefaultsURLKey];
    if (url) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kUserDefaultsURLKey];
        [self showWebOverlay:url caching:NO];
    }
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    NSURL *url = [[NSUserDefaults standardUserDefaults] URLForKey:kUserDefaultsURLKey];
    if (url == nil) {
        [self dismissWebOverlay:NO];
    }
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [_activityIndicatorView startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [_activityIndicatorView stopAnimating];
}

#pragma mark - Utilities

- (NSURLRequest *)requestWithURL:(NSURL *)url
{
    if (_requestLocalParameters) {
        return [NSURLRequest requestWithURL:url GETParameters:_requestLocalParameters];
    }
    return [NSURLRequest requestWithURL:url];
}

- (void)clearNotifications
{
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
}

@end
