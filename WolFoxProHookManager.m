// WolFoxProHookManager.m
#import "WolFoxProHookManager.h"
#import "WolFoxProStore.h"
#import "WFLicenseClient.h"
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <math.h>

static const char kWFManagerProxyKey;
char WFSpoofedLocationAssociationKey;

@interface WolFoxProDelegateProxy : NSObject <CLLocationManagerDelegate>
@property (nonatomic, weak) id originalDelegate;
@property (nonatomic, weak) CLLocationManager *manager;
- (BOOL)beginForwarding;
- (void)endForwarding;
@end

@implementation WolFoxProDelegateProxy
- (BOOL)respondsToSelector:(SEL)s { return [super respondsToSelector:s] || [self.originalDelegate respondsToSelector:s]; }
- (id)forwardingTargetForSelector:(SEL)s { return [self.originalDelegate respondsToSelector:s] ? self.originalDelegate : [super forwardingTargetForSelector:s]; }

- (BOOL)beginForwarding {
    @synchronized(self) {
        NSNumber *isForwarding = objc_getAssociatedObject(self, @selector(beginForwarding));
        if (isForwarding.boolValue) return NO;
        objc_setAssociatedObject(self, @selector(beginForwarding), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return YES;
    }
}

- (void)endForwarding {
    @synchronized(self) {
        objc_setAssociatedObject(self, @selector(beginForwarding), @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)locationManager:(CLLocationManager *)m didUpdateLocations:(NSArray<CLLocation *> *)l {
    if (![self beginForwarding]) return;
    self.manager = m;
    id strongDelegate = self.originalDelegate;
    @try {
        CLLocation *orig = l.lastObject;
        if (orig) [WolFoxProHookManager shared].lastRealLocation = orig;
        WolFoxProStore *store = [WolFoxProStore shared];
        CLLocationCoordinate2D fake = store.currentFakeCoords;
        BOOL shouldSpoof = store.spoofActive &&
                           [WFLicenseClient isRuntimeLicenseValid] &&
                           CLLocationCoordinate2DIsValid(fake);
        if (shouldSpoof) {
            if (store.jitterActive) {
                fake.latitude  += ((double)arc4random_uniform(100) - 50.0) / 2000000.0;
                fake.longitude += ((double)arc4random_uniform(100) - 50.0) / 2000000.0;
            }

            CLLocation *spoofed = [[CLLocation alloc] initWithCoordinate:fake altitude:orig ? orig.altitude : 300.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]];
            objc_setAssociatedObject(spoofed, &WFSpoofedLocationAssociationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (strongDelegate && [strongDelegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                [strongDelegate locationManager:m didUpdateLocations:@[spoofed]];
            } else if (strongDelegate && [strongDelegate respondsToSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)]) {
                [strongDelegate locationManager:m didUpdateToLocation:spoofed fromLocation:orig];
            }
        } else {
            if (strongDelegate && [strongDelegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                [strongDelegate locationManager:m didUpdateLocations:l];
            } else if (strongDelegate && [strongDelegate respondsToSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)]) {
                CLLocation *newLocation = l.lastObject;
                CLLocation *oldLocation = l.count > 1 ? l[l.count - 2] : nil;
                [strongDelegate locationManager:m didUpdateToLocation:newLocation fromLocation:oldLocation];
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[WolFox][GPS] delegate_forward_exception=%@", e.name);
    } @finally {
        [self endForwarding];
    }
}
@end

@implementation WolFoxProHookManager {
    NSHashTable *_proxies;
    NSArray<CLLocation *> *_routeWaypoints;
    NSUInteger _waypointIndex;
    double _routeSpeedKmh;
    NSTimer *_routeTimer;
    NSUInteger _routeGeneration;
}

@synthesize currentWaypointIndex = _waypointIndex;

- (NSUInteger)totalWaypoints { return _routeWaypoints.count; }

+ (instancetype)shared {
    static WolFoxProHookManager *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [WolFoxProHookManager new]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _proxies = [NSHashTable weakObjectsHashTable];
    }
    return self;
}

- (void)installHooks {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"[WolFox][GPS] install_hooks_begin");
        Method m1 = class_getInstanceMethod([CLLocationManager class], @selector(setDelegate:));
        if (!m1) {
            NSLog(@"[WolFox][GPS] install_hooks_failed missing=setDelegate:");
            return;
        }
        IMP orig = method_getImplementation(m1);
        const char *types = method_getTypeEncoding(m1);
        IMP replacement = imp_implementationWithBlock(^(CLLocationManager *mgr, id delegate) {
            if (!mgr) {
                ((void(*)(id, SEL, id))orig)(mgr, @selector(setDelegate:), delegate);
                return;
            }

            WolFoxProDelegateProxy *existing = objc_getAssociatedObject(mgr, &kWFManagerProxyKey);
            if (!delegate) {
                if (existing) existing.originalDelegate = nil;
                objc_setAssociatedObject(mgr, &kWFManagerProxyKey, nil, OBJC_ASSOCIATION_ASSIGN);
            } else if ([delegate isKindOfClass:[WolFoxProDelegateProxy class]]) {
                existing = (WolFoxProDelegateProxy *)delegate;
            } else if (existing && existing.originalDelegate == delegate) {
                delegate = existing;
            } else {
                WolFoxProDelegateProxy *proxy = [WolFoxProDelegateProxy new];
                proxy.originalDelegate = delegate;
                proxy.manager = mgr;
                [[WolFoxProHookManager shared] addProxy:proxy];
                objc_setAssociatedObject(mgr, &kWFManagerProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                NSLog(@"[WolFox][GPS] delegate_proxy_attached_once");
                delegate = proxy;
            }
            ((void(*)(id, SEL, id))orig)(mgr, @selector(setDelegate:), delegate);
        });

        // Add an override when setDelegate: is inherited; otherwise replace the
        // CLLocationManager implementation itself. This avoids changing a
        // superclass implementation shared by unrelated objects.
        if (!class_addMethod([CLLocationManager class], @selector(setDelegate:), replacement, types)) {
            Method ownedMethod = class_getInstanceMethod([CLLocationManager class], @selector(setDelegate:));
            method_setImplementation(ownedMethod, replacement);
        }

        NSLog(@"[WolFox][GPS] install_hooks_complete");
    });
}

- (void)addProxy:(id)p {
    if (!p) return;
    @synchronized(_proxies) {
        if (![_proxies containsObject:p]) [_proxies addObject:p];
    }
}

- (void)deliverFakeUpdate {
    WolFoxProStore *store = [WolFoxProStore shared];
    if (!store.spoofActive || ![WFLicenseClient isRuntimeLicenseValid]) {
        return;
    }

    CLLocationCoordinate2D fake = store.currentFakeCoords;
    if (!CLLocationCoordinate2DIsValid(fake)) {
        NSLog(@"[WolFox][GPS] fake_update_skipped invalid_coordinate lat=%.6f lon=%.6f", fake.latitude, fake.longitude);
        return;
    }
    CLLocation *spoofed = [[CLLocation alloc] initWithCoordinate:fake altitude:300.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]];
    // Prevent hook_CLLocation_coordinate from re-spoofing this object
    objc_setAssociatedObject(spoofed, &WFSpoofedLocationAssociationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSArray *snapshot;
    @synchronized(_proxies) {
        snapshot = _proxies.allObjects;
    }
    for (WolFoxProDelegateProxy *proxy in snapshot) {
        if (proxy && proxy.manager && proxy.originalDelegate) {
            if (![proxy beginForwarding]) continue;
            @try {
                if ([proxy.originalDelegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                    [proxy.originalDelegate locationManager:proxy.manager didUpdateLocations:@[spoofed]];
                } else if ([proxy.originalDelegate respondsToSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)]) {
                    [proxy.originalDelegate locationManager:proxy.manager didUpdateToLocation:spoofed fromLocation:self.lastRealLocation];
                }
            } @catch (NSException *e) {
                NSLog(@"[WolFox][GPS] fake_update_exception=%@", e.name);
            } @finally {
                [proxy endForwarding];
            }
        }
    }
}

- (void)startRouteWithWaypoints:(NSArray<CLLocation *> *)waypoints speedKmh:(double)speed {
    [self stopRoute];
    if (waypoints.count < 2 || ![WFLicenseClient isRuntimeLicenseValid]) return;
    // Route points are WolFox-internal CLLocation objects. Mark them so the
    // global coordinate hook returns their original coordinates while route
    // math is being calculated.
    for (CLLocation *waypoint in waypoints) {
        objc_setAssociatedObject(waypoint, &WFSpoofedLocationAssociationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    _routeWaypoints = [waypoints copy];
    _routeSpeedKmh  = speed > 0 ? speed : 5.0;
    _waypointIndex  = 0;
    [WolFoxProStore shared].routeActive = YES;
    // Set starting position
    [WolFoxProStore shared].currentFakeCoords = waypoints[0].coordinate;
    NSUInteger generation = ++_routeGeneration;
    void (^scheduleTimer)(void) = ^{
        if (generation != self->_routeGeneration || ![WolFoxProStore shared].routeActive || ![WFLicenseClient isRuntimeLicenseValid]) return;
        self->_routeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateRouteStep) userInfo:nil repeats:YES];
    };
    if ([NSThread isMainThread]) scheduleTimer();
    else dispatch_async(dispatch_get_main_queue(), scheduleTimer);
}

- (void)stopRoute {
    _routeGeneration++;
    [_routeTimer invalidate]; _routeTimer = nil;
    _routeWaypoints = nil; _waypointIndex = 0;
    [WolFoxProStore shared].routeActive = NO;
}

- (void)updateRouteStep {
    if (![WFLicenseClient isRuntimeLicenseValid]) {
        [self stopRoute];
        return;
    }
    WolFoxProStore *store = [WolFoxProStore shared];

    // Legacy single-target mode (from WolFoxMaster toggleRouteSimulation)
    if (!_routeWaypoints) {
        CLLocationCoordinate2D current = store.currentFakeCoords;
        CLLocationCoordinate2D target  = store.targetRouteCoords;
        double speedKmPerSec = store.simSpeed / 3600.0;
        double step = speedKmPerSec / 111.1;
        double dLat = target.latitude  - current.latitude;
        double dLon = target.longitude - current.longitude;
        double dist = sqrt(dLat*dLat + dLon*dLon);
        if (dist < step || dist < 1e-9) {
            store.currentFakeCoords = target;
            store.routeActive = NO;
        } else {
            current.latitude  += (dLat / dist) * step;
            current.longitude += (dLon / dist) * step;
            store.currentFakeCoords = current;
        }
        [self deliverFakeUpdate];
        return;
    }

    // Multi-waypoint mode
    if (_waypointIndex >= _routeWaypoints.count - 1) {
        [self stopRoute];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_ROUTE_FINISHED" object:nil];
        return;
    }

    CLLocation *current = [[CLLocation alloc] initWithLatitude:store.currentFakeCoords.latitude longitude:store.currentFakeCoords.longitude];
    objc_setAssociatedObject(current, &WFSpoofedLocationAssociationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CLLocation *target  = _routeWaypoints[_waypointIndex + 1];

    double speedKmPerSec = _routeSpeedKmh / 3600.0;
    double stepDeg = speedKmPerSec / 111.1;

    double dLat = target.coordinate.latitude  - current.coordinate.latitude;
    double dLon = target.coordinate.longitude - current.coordinate.longitude;
    double dist  = sqrt(dLat*dLat + dLon*dLon);

    if (dist <= stepDeg || dist < 1e-9) {
        // Reached this waypoint, move to next
        store.currentFakeCoords = target.coordinate;
        _waypointIndex++;
    } else {
        CLLocationCoordinate2D next;
        next.latitude  = current.coordinate.latitude  + (dLat / dist) * stepDeg;
        next.longitude = current.coordinate.longitude + (dLon / dist) * stepDeg;
        store.currentFakeCoords = next;
    }

    if (store.jitterActive) {
        CLLocationCoordinate2D jittered = store.currentFakeCoords;
        jittered.latitude  += ((double)arc4random_uniform(100) - 50.0) / 2000000.0;
        jittered.longitude += ((double)arc4random_uniform(100) - 50.0) / 2000000.0;
        store.currentFakeCoords = jittered;
    }

    [self deliverFakeUpdate];
}

@end
