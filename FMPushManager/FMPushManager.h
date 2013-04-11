//
//  FMPushManager.h
//
//  Created by Maurizio Cremaschi on 23/03/2013.
//  Copyright (c) 2013 Flubber Media Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FMPushManager : NSObject <UIWebViewDelegate>

@property (strong, nonatomic) NSString *apnUserInfoURLKey;
@property (strong, nonatomic) NSDictionary *requestLocalParameters;
@property (assign, nonatomic) CGRect frameForiPadPanel;
@property (assign, nonatomic) CGRect frameForiPhonePanel;

+ (FMPushManager *)sharedInstance;
- (void)registerForApplicationNotifications;
- (void)handleAPN:(NSDictionary *)userInfo;
- (void)debugWithURL:(NSURL *)url;

@end
