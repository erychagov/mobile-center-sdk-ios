#import "MSChannelDefault.h"
#import "MSFileStorage.h"
#import "MSHttpSender.h"
#import "MSIngestionSender.h"
#import "MSLogManagerDefault.h"
#import "MSLogManagerDefaultPrivate.h"
#import "MSMobileCenterErrors.h"
#import "MSMobileCenterInternal.h"
#import "MobileCenter+Internal.h"

static char *const MSlogsDispatchQueue = "com.microsoft.azure.mobile.mobilecenter.LogManagerQueue";

/**
 * Private declaration of the log manager.
 */
@interface MSLogManagerDefault ()

/**
 * A boolean value set to YES if this instance is enabled or NO otherwise.
 */
@property BOOL enabled;

@end

@implementation MSLogManagerDefault

#pragma mark - Initialization

- (instancetype)initWithAppSecret:(NSString *)appSecret installId:(NSUUID *)installId logUrl:(NSString *)logUrl {
  self = [self initWithSender:[[MSIngestionSender alloc] initWithBaseUrl:logUrl
                                                               appSecret:appSecret
                                                               installId:[installId UUIDString]]
                      storage:[[MSFileStorage alloc] init]];
  return self;
}

- (instancetype)initWithSender:(MSHttpSender *)sender storage:(id<MSStorage>)storage {
  if ((self = [self init])) {
    dispatch_queue_t serialQueue = dispatch_queue_create(MSlogsDispatchQueue, DISPATCH_QUEUE_SERIAL);
    _enabled = YES;
    _logsDispatchQueue = serialQueue;
    _channels = [NSMutableDictionary<NSString *, id<MSChannel>> new];
    _delegates = [NSHashTable weakObjectsHashTable];
    _sender = sender;
    _storage = storage;
  }
  return self;
}

- (void)initChannelWithConfiguration:(MSChannelConfiguration *)configuration {
  MSChannelDefault *channel;
  if (configuration) {
    channel = [[MSChannelDefault alloc] initWithSender:self.sender
                                               storage:self.storage
                                         configuration:configuration
                                     logsDispatchQueue:self.logsDispatchQueue];
    self.channels[configuration.groupID] = channel;
  }
}

#pragma mark - Delegate

- (void)addDelegate:(id<MSLogManagerDelegate>)delegate {
  @synchronized (self) {
    [self.delegates addObject:delegate];
  }
}

- (void)removeDelegate:(id<MSLogManagerDelegate>)delegate {
  @synchronized (self) {
    [self.delegates removeObject:delegate];
  }
}

#pragma mark - Channel Delegate

- (void)addChannelDelegate:(id<MSChannelDelegate>)channelDelegate forGroupID:(NSString *)groupID {
  if (channelDelegate) {
    if (self.channels[groupID]) {
      [self.channels[groupID] addDelegate:channelDelegate];
    } else {
      MSLogWarning([MSMobileCenter logTag], @"Channel has not been initialized for the group ID: %@", groupID);
    }
  }
}

- (void)removeChannelDelegate:(id<MSChannelDelegate>)channelDelegate forGroupID:(NSString *)groupID {
  if (channelDelegate) {
    if (self.channels[groupID]) {
      [self.channels[groupID] removeDelegate:channelDelegate];
    } else {
      MSLogWarning([MSMobileCenter logTag], @"Channel has not been initialized for the group ID: %@", groupID);
    }
  }
}

- (void)enumerateDelegatesForSelector:(SEL)selector withBlock:(void (^)(id<MSLogManagerDelegate> delegate))block {
  @synchronized (self) {
    for (id<MSLogManagerDelegate> delegate in self.delegates) {
      if (delegate && [delegate respondsToSelector:selector]) {
        block(delegate);
      }
    }
  }
}

#pragma mark - Process items

- (void)processLog:(id<MSLog>)log forGroupID:(NSString *)groupID {
  if (!log) {
    return;
  }

  // Get the channel.
  id<MSChannel> channel = self.channels[groupID];
  if (!channel) {
    MSLogWarning([MSMobileCenter logTag], @"Channel has not been initialized for the group ID: %@", groupID);
    return;
  }

  // Internal ID to keep track of logs between modules.
  NSString *internalLogId = MS_UUID_STRING;

  // Notify delegates.
  [self enumerateDelegatesForSelector:@selector(onEnqueuingLog:withInternalId:)
                            withBlock:^(id<MSLogManagerDelegate> delegate) {
                              [delegate onEnqueuingLog:log withInternalId:internalLogId];
                            }];

  // Set common log info.
  log.toffset = [NSNumber numberWithLongLong:(long long)([MSUtility nowInMilliseconds])];

  // Only add device info in case the log doesn't have one. In case the log is restored after a crash or for crashes,
  // We don't want the device information to be updated but want the old one preserved.
  if (!log.device) {
    log.device = [[MSDeviceTracker sharedInstance] device];
  }

  // Asynchronously forward to channel by using the data dispatch queue.
  [channel enqueueItem:log
        withCompletion:^(BOOL success) {
          if (success) {

            // Notify delegates.
            [self enumerateDelegatesForSelector:@selector(onFinishedPersistingLog:withInternalId:)
                                      withBlock:^(id<MSLogManagerDelegate> delegate) {
                                        [delegate onFinishedPersistingLog:log withInternalId:internalLogId];
                                      }];
          } else {

            // Notify delegates.
            [self enumerateDelegatesForSelector:@selector(onFailedPersistingLog:withInternalId:)
                                      withBlock:^(id<MSLogManagerDelegate> delegate) {
                                        [delegate onFailedPersistingLog:log withInternalId:internalLogId];
                                      }];
          }
        }];
}

#pragma mark - Enable / Disable

- (void)setEnabled:(BOOL)isEnabled andDeleteDataOnDisabled:(BOOL)deleteData {
  if (isEnabled != self.enabled) {
    self.enabled = isEnabled;

    // Propagate to sender.
    // Sender will in turn propagates to its channel delegates.
    [self.sender setEnabled:isEnabled andDeleteDataOnDisabled:deleteData];

    // If requested, also delete logs from not started services.
    if (!isEnabled && deleteData) {
      NSArray<NSString *> *runningChannels = self.channels.allKeys;
      for (NSString *groupID in runningChannels) {
        if (![runningChannels containsObject:groupID]) {
          NSError *error = [NSError errorWithDomain:kMSMCErrorDomain
                                               code:kMSMCConnectionSuspendedErrorCode
                                           userInfo:@{NSLocalizedDescriptionKey : kMSMCConnectionSuspendedErrorDesc}];
          [self.channels[groupID] deleteAllLogsWithError:error];
        }
      }
    }
  }
}

- (void)setEnabled:(BOOL)isEnabled andDeleteDataOnDisabled:(BOOL)deleteData forGroupID:(NSString *)groupID {
  if (self.channels[groupID]) {
    [self.channels[groupID] setEnabled:isEnabled andDeleteDataOnDisabled:deleteData];
  } else {
    MSLogWarning([MSMobileCenter logTag], @"Channel has not been initialized for the group ID: %@", groupID);
  }
}

#pragma mark - Other public methods

- (void)setLogUrl:(NSString *)logUrl {
  self.sender.baseURL = logUrl;
}

@end
