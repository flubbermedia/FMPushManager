//
//  FMPushManager.h
//
//  Created by Maurizio Cremaschi on 23/03/2013.
//  Copyright (c) 2013 Flubber Media Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FMPushManager : NSObject <UIWebViewDelegate>

@property (strong, nonatomic) NSString *apnUserInfoURLKey;

+ (FMPushManager *)sharedInstance;
- (void)registerForApplicationNotifications;
- (void)handleAPN:(NSDictionary *)userInfo;
- (void)debugWithURL:(NSURL *)url;

@end
