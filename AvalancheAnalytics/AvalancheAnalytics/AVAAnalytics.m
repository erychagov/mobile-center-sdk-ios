/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import "AVAAnalyticsPrivate.h"
#import "AvalancheHub+Internal.h"
#import "AVAEventLog.h"

@implementation AVAAnalytics

+ (id)sharedInstance {
  static id sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

- (void)startFeature {  
  AVALogVerbose(@"AVAAnalytics: Started analytics module");
}

+ (void)sendLog:(NSString*)log {
  [[self sharedInstance] sendLog:log];
}

- (void)sendLog:(NSString*)name {

  // Set log
  AVAEventLog *log = [[AVAEventLog alloc] init];
  log.name = name;
  log.sid = [NSUUID UUID];
  
  [self.delegate send:log];
}

@end