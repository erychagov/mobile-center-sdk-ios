#import <Foundation/Foundation.h>
#import "MSConstants+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSChannelConfiguration : NSObject

/**
 * The groupID that will be used for storage by this channel.
 */
@property(nonatomic, copy, readonly) NSString *groupID;

/**
 * The priority of logs for this channel
 */
@property(nonatomic, assign, readonly) MSPriority priority;

/**
 * Threshold after which the queue will be flushed.
 */
@property(nonatomic, readonly) NSUInteger batchSizeLimit;

/**
 * Maximum number of batches forwarded to the sender at the same time.
 */
@property(nonatomic, readonly) NSUInteger pendingBatchesLimit;

/**
 * Interval for flushing the queue.
 */
@property(nonatomic, readonly) float flushInterval;

/**
 * Initializes a new instance based on given settings.
 *
 * @param groupID The id used by the channel to determine a group of logs.
 * @param priority The priority of logs being sent by the channel.
 * @param flushInterval The interval after which a new batch will be finished.
 * @param batchSizeLimit The maximum number of logs after which a new batch will be finished.
 * @param pendingBatchesLimit The maximum number of batches that have currently been forwarded to another component.
 *
 * @return a fully configured `MSChannelConfiguration` instance.
 */
- (instancetype)initWithGroupID:(NSString *)groupID
                       priority:(MSPriority)priority
                  flushInterval:(float)flushInterval
                 batchSizeLimit:(NSUInteger)batchSizeLimit
            pendingBatchesLimit:(NSUInteger)pendingBatchesLimit;

/**
 * Initializes a new instance with default settings.
 *
 * @param groupID The id used by the channel to determine a group of logs.
 *
 * @return a fully configured `MSChannelConfiguration` instance with default settings.
 */
- (instancetype)initDefaultConfigurationWithGroupID:(NSString *)groupID;

@end

NS_ASSUME_NONNULL_END
