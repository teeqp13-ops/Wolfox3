// WolFoxProHookManager.h
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

// Shared marker used by every location hook to identify CLLocation objects
// created by WolFox and prevent a second coordinate replacement.
FOUNDATION_EXPORT char WFSpoofedLocationAssociationKey;

@interface WolFoxProHookManager : NSObject

+ (instancetype)shared;
- (void)installHooks;
- (void)deliverFakeUpdate;
- (void)updateRouteStep;

// Multi-waypoint route
- (void)startRouteWithWaypoints:(NSArray<CLLocation *> *)waypoints speedKmh:(double)speed;
- (void)stopRoute;

@property (nonatomic, assign) BOOL active;
@property (nonatomic, strong, nullable) CLLocation *lastRealLocation;
@property (nonatomic, readonly) NSUInteger currentWaypointIndex;
@property (nonatomic, readonly) NSUInteger totalWaypoints;

@end

NS_ASSUME_NONNULL_END
