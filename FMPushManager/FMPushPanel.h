//
//  FMPushPanel.h
//
//  Created by Maurizio Cremaschi on 23/03/2013.
//  Copyright (c) 2013 Flubber Media Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FMPushPanel : UIViewController <UIWebViewDelegate>

@property (strong, nonatomic) NSString *apnUserInfoURLKey;

+ (FMPushPanel *)sharedInstance;
- (void)registerForApplicationNotifications;
- (void)handleAPN:(NSDictionary *)userInfo;
- (void)debugWithURL:(NSURL *)url;

@end
