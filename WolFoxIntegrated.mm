// WolFoxIntegrated.mm - WolFox Pro Hooks v1.6.1
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <WebKit/WebKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>
#import "WolFoxProHookManager.h"
#import "WolFoxProStore.h"
#import "WFLicenseClient.h"

@interface WolFoxController : NSObject
+ (instancetype)shared;
- (void)toggleUI;
- (void)handleVolumeGesturePulse;
@end

static BOOL WFProcessIsEligible(void) {
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier.lowercaseString;
    NSString *process = NSProcessInfo.processInfo.processName.lowercaseString;
    if (!bundleID.length) return NO;
    if ([bundleID hasPrefix:@"com.apple."]) return NO;
    if ([process containsString:@"springboard"] || [process containsString:@"backboard"] || [process containsString:@"installd"]) return NO;
    return NSClassFromString(@"UIApplication") != nil;
}

static BOOL WFInstallInstanceHook(Class cls, SEL selector, IMP replacement, IMP *original) {
    if (!cls || !selector || !replacement || !original) return NO;
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        NSLog(@"[WolFox][HOOK] missing_instance_method class=%@ selector=%@", NSStringFromClass(cls), NSStringFromSelector(selector));
        return NO;
    }
    *original = method_getImplementation(method);
    const char *types = method_getTypeEncoding(method);
    if (!class_addMethod(cls, selector, replacement, types)) {
        Method ownedMethod = class_getInstanceMethod(cls, selector);
        method_setImplementation(ownedMethod, replacement);
    }
    NSLog(@"[WolFox][HOOK] installed class=%@ selector=%@", NSStringFromClass(cls), NSStringFromSelector(selector));
    return YES;
}

static BOOL WFInstallClassHook(Class cls, SEL selector, IMP replacement, IMP *original) {
    return WFInstallInstanceHook(object_getClass(cls), selector, replacement, original);
}

static BOOL WFGate(BOOL featureEnabled) {
    return featureEnabled && [WFLicenseClient isRuntimeLicenseValid];
}

#pragma mark - Identifier hooks

static NSUUID *WFActivePublicIdentifier(void) {
    if (![WFLicenseClient isRuntimeLicenseValid]) return nil;
    return [[WolFoxProStore shared] validatedActiveIdentifier];
}

static IMP orig_advertisingIdentifier;
static NSUUID *hook_advertisingIdentifier(ASIdentifierManager *self, SEL _cmd) {
    NSUUID *uuid = WFActivePublicIdentifier();
    if (uuid) return uuid;
    return ((NSUUID *(*)(id, SEL))orig_advertisingIdentifier)(self, _cmd);
}

static IMP orig_identifierForVendor;
static NSUUID *hook_identifierForVendor(UIDevice *self, SEL _cmd) {
    NSUUID *uuid = WFActivePublicIdentifier();
    if (uuid) return uuid;
    return ((NSUUID *(*)(id, SEL))orig_identifierForVendor)(self, _cmd);
}

#pragma mark - Location hooks

static IMP orig_CLLocation_coordinate;
static CLLocationCoordinate2D hook_CLLocation_coordinate(CLLocation *self, SEL _cmd) {
    if (objc_getAssociatedObject(self, &WFSpoofedLocationAssociationKey)) {
        return ((CLLocationCoordinate2D (*)(id, SEL))orig_CLLocation_coordinate)(self, _cmd);
    }
    WolFoxProStore *store = [WolFoxProStore shared];
    if (WFGate(store.spoofActive)) {
        CLLocationCoordinate2D fake = store.currentFakeCoords;
        if (!CLLocationCoordinate2DIsValid(fake)) {
            return ((CLLocationCoordinate2D (*)(id, SEL))orig_CLLocation_coordinate)(self, _cmd);
        }
        if (store.jitterActive) {
            fake.latitude += ((double)arc4random_uniform(100) - 50.0) / 2000000.0;
            fake.longitude += ((double)arc4random_uniform(100) - 50.0) / 2000000.0;
        }
        return fake;
    }
    return ((CLLocationCoordinate2D (*)(id, SEL))orig_CLLocation_coordinate)(self, _cmd);
}

static IMP orig_CLLocationManager_location;
static CLLocation *hook_CLLocationManager_location(CLLocationManager *self, SEL _cmd) {
    WolFoxProStore *store = [WolFoxProStore shared];
    if (WFGate(store.spoofActive)) {
        CLLocationCoordinate2D fake = store.currentFakeCoords;
        if (!CLLocationCoordinate2DIsValid(fake)) {
            return ((CLLocation *(*)(id, SEL))orig_CLLocationManager_location)(self, _cmd);
        }
        if (store.jitterActive) {
            fake.latitude += ((double)arc4random_uniform(100) - 50.0) / 2000000.0;
            fake.longitude += ((double)arc4random_uniform(100) - 50.0) / 2000000.0;
        }
        CLLocation *location = [[CLLocation alloc] initWithCoordinate:fake altitude:300 horizontalAccuracy:5 verticalAccuracy:5 timestamp:NSDate.date];
        objc_setAssociatedObject(location, &WFSpoofedLocationAssociationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return location;
    }
    return ((CLLocation *(*)(id, SEL))orig_CLLocationManager_location)(self, _cmd);
}

#pragma mark - WebView hooks

static id (*orig_WKWebView_init)(WKWebView *, SEL, CGRect, WKWebViewConfiguration *);
static id hook_WKWebView_init(WKWebView *self, SEL _cmd, CGRect frame, WKWebViewConfiguration *configuration) {
    NSUUID *activeIdentifier = WFActivePublicIdentifier();
    if (activeIdentifier && configuration.userContentController) {
        NSString *identifier = activeIdentifier.UUIDString;
        NSString *safe = [identifier stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        safe = [safe stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
        NSString *source = [NSString stringWithFormat:@"window.device=window.device||{};window.device.uuid='%@';window.wolfoxIdentifier='%@';", safe, safe];
        WKUserScript *script = [[WKUserScript alloc] initWithSource:source injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
        [configuration.userContentController addUserScript:script];
    }
    return orig_WKWebView_init(self, _cmd, frame, configuration);
}

#pragma mark - Bluetooth scan identity hooks

static const char kWFCBProxyKey = 0;
static const char kWFCBProfileIDKey = 0;
static const char kWFCBNameKey = 0;
static const char kWFCBUUIDKey = 0;

static WolFoxBleProfile *WFActiveBleProfile(void) {
    WolFoxProStore *store = [WolFoxProStore shared];
    return WFGate(store.bluetoothActive) ? [store activeBleProfile] : nil;
}

static IMP orig_CBPeripheral_name;
static NSString *hook_CBPeripheral_name(CBPeripheral *self, SEL _cmd) {
    WolFoxBleProfile *profile = WFActiveBleProfile();
    NSString *associatedID = objc_getAssociatedObject(self, &kWFCBProfileIDKey);
    if (profile && [associatedID isEqualToString:profile.profileID]) {
        NSString *name = objc_getAssociatedObject(self, &kWFCBNameKey);
        if (name.length) return name;
    }
    return ((NSString *(*)(id, SEL))orig_CBPeripheral_name)(self, _cmd);
}

static IMP orig_CBPeripheral_identifier;
static NSUUID *hook_CBPeripheral_identifier(CBPeripheral *self, SEL _cmd) {
    WolFoxBleProfile *profile = WFActiveBleProfile();
    NSString *associatedID = objc_getAssociatedObject(self, &kWFCBProfileIDKey);
    if (profile && [associatedID isEqualToString:profile.profileID]) {
        NSUUID *identifier = objc_getAssociatedObject(self, &kWFCBUUIDKey);
        if (identifier) return identifier;
    }
    return ((NSUUID *(*)(id, SEL))orig_CBPeripheral_identifier)(self, _cmd);
}

@interface WolFoxCBProxy : NSProxy <CBCentralManagerDelegate> {
    __weak id _delegate;
    __weak CBCentralManager *_manager;
    BOOL _deliveredProfile;
}
- (instancetype)initWithDelegate:(id)delegate;
- (void)setManager:(CBCentralManager *)manager;
- (void)resetScan;
@end

@implementation WolFoxCBProxy
- (instancetype)initWithDelegate:(id)delegate { _delegate = delegate; return self; }
- (void)setManager:(CBCentralManager *)manager { _manager = manager; }
- (void)resetScan { @synchronized(self) { _deliveredProfile = NO; } }
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *signature = [(NSObject *)_delegate methodSignatureForSelector:selector];
    return signature ?: [NSObject instanceMethodSignatureForSelector:@selector(init)];
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    if ([_delegate respondsToSelector:invocation.selector]) [invocation invokeWithTarget:_delegate];
}
- (BOOL)respondsToSelector:(SEL)selector {
    return selector == @selector(centralManager:didDiscoverPeripheral:advertisementData:RSSI:) || [_delegate respondsToSelector:selector];
}
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    id delegate = _delegate;
    if (![delegate respondsToSelector:_cmd]) return;
    WolFoxBleProfile *profile = WFActiveBleProfile();
    if (!profile) {
        [delegate centralManager:central didDiscoverPeripheral:peripheral advertisementData:advertisementData RSSI:RSSI];
        return;
    }
    @synchronized(self) {
        if (_deliveredProfile) return;
        _deliveredProfile = YES;
    }
    NSString *displayName = profile.localName.length ? profile.localName : profile.name;
    NSString *identifierText = profile.uuid.length ? profile.uuid : profile.profileID;
    NSUUID *identifier = [[NSUUID alloc] initWithUUIDString:identifierText];
    if (!identifier) identifier = [[NSUUID alloc] initWithUUIDString:profile.profileID];
    objc_setAssociatedObject(peripheral, &kWFCBProfileIDKey, profile.profileID, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(peripheral, &kWFCBNameKey, displayName, OBJC_ASSOCIATION_COPY_NONATOMIC);
    if (identifier) objc_setAssociatedObject(peripheral, &kWFCBUUIDKey, identifier, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSMutableDictionary *spoofedAdvertisement = advertisementData ? [advertisementData mutableCopy] : [NSMutableDictionary new];
    if (displayName.length) spoofedAdvertisement[CBAdvertisementDataLocalNameKey] = displayName;
    NSNumber *spoofedRSSI = profile.rssi == 0 ? RSSI : @(profile.rssi);
    [delegate centralManager:central didDiscoverPeripheral:peripheral advertisementData:spoofedAdvertisement RSSI:spoofedRSSI ?: @(-55)];
}
@end

static id (*orig_CBCentralManager_initWithDelegate)(CBCentralManager *, SEL, id, dispatch_queue_t, NSDictionary *);
static id hook_CBCentralManager_initWithDelegate(CBCentralManager *self, SEL _cmd, id delegate, dispatch_queue_t queue, NSDictionary *options) {
    Class wolfoxClass = NSClassFromString(@"WolFoxMainViewController");
    if (wolfoxClass && [delegate isKindOfClass:wolfoxClass]) {
        return orig_CBCentralManager_initWithDelegate(self, _cmd, delegate, queue, options);
    }
    WolFoxCBProxy *proxy = [[WolFoxCBProxy alloc] initWithDelegate:delegate];
    id manager = orig_CBCentralManager_initWithDelegate(self, _cmd, proxy, queue, options);
    [proxy setManager:manager];
    objc_setAssociatedObject(manager, &kWFCBProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return manager;
}

static IMP orig_CBCentralManager_scan;
static void hook_CBCentralManager_scan(CBCentralManager *self, SEL _cmd, NSArray<CBUUID *> *services, NSDictionary *options) {
    WolFoxCBProxy *proxy = objc_getAssociatedObject(self, &kWFCBProxyKey);
    [proxy resetScan];
    ((void (*)(id, SEL, id, id))orig_CBCentralManager_scan)(self, _cmd, services, options);
}

#pragma mark - UIImagePickerController camera source hook

static const char kWFCameraPickerKey = 0;
static const char kWFCameraDeliveredKey = 0;

static UIImage *WFConfiguredCameraImage(void) {
    WolFoxProStore *store = [WolFoxProStore shared];
    if (!WFGate(store.mediaUploadActive) || !store.spoofedImagePath.length) return nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:store.spoofedImagePath]) return nil;
    return [UIImage imageWithContentsOfFile:store.spoofedImagePath];
}

static IMP orig_isSourceTypeAvailable;
static BOOL hook_isSourceTypeAvailable(Class cls, SEL _cmd, UIImagePickerControllerSourceType type) {
    if (type == UIImagePickerControllerSourceTypeCamera && WFConfiguredCameraImage()) return YES;
    return ((BOOL (*)(Class, SEL, UIImagePickerControllerSourceType))orig_isSourceTypeAvailable)(cls, _cmd, type);
}

static IMP orig_setSourceType;
static void hook_setSourceType(UIImagePickerController *self, SEL _cmd, UIImagePickerControllerSourceType type) {
    if (type == UIImagePickerControllerSourceTypeCamera && WFConfiguredCameraImage()) {
        objc_setAssociatedObject(self, &kWFCameraPickerKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &kWFCameraDeliveredKey, nil, OBJC_ASSOCIATION_ASSIGN);
        BOOL libraryAvailable = ((BOOL (*)(Class, SEL, UIImagePickerControllerSourceType))orig_isSourceTypeAvailable)(UIImagePickerController.class, @selector(isSourceTypeAvailable:), UIImagePickerControllerSourceTypePhotoLibrary);
        type = libraryAvailable ? UIImagePickerControllerSourceTypePhotoLibrary : UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    }
    ((void (*)(id, SEL, UIImagePickerControllerSourceType))orig_setSourceType)(self, _cmd, type);
}

static IMP orig_UIImagePicker_viewDidAppear;
static void hook_UIImagePicker_viewDidAppear(UIImagePickerController *self, SEL _cmd, BOOL animated) {
    ((void (*)(id, SEL, BOOL))orig_UIImagePicker_viewDidAppear)(self, _cmd, animated);
    if (![objc_getAssociatedObject(self, &kWFCameraPickerKey) boolValue] || [objc_getAssociatedObject(self, &kWFCameraDeliveredKey) boolValue]) return;
    UIImage *image = WFConfiguredCameraImage();
    if (!image) return;
    objc_setAssociatedObject(self, &kWFCameraDeliveredKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    dispatch_async(dispatch_get_main_queue(), ^{
        id<UIImagePickerControllerDelegate> delegate = self.delegate;
        SEL selector = @selector(imagePickerController:didFinishPickingMediaWithInfo:);
        if ([delegate respondsToSelector:selector]) {
            NSDictionary *info = @{UIImagePickerControllerMediaType: @"public.image", UIImagePickerControllerOriginalImage: image};
            [delegate imagePickerController:self didFinishPickingMediaWithInfo:info];
        }
    });
}

#pragma mark - Volume button hook

static IMP orig_UIApplication_pressesBegan;
static void hook_UIApplication_pressesBegan(UIApplication *self, SEL _cmd, NSSet<UIPress *> *presses, UIPressesEvent *event) {
    ((void (*)(id, SEL, id, id))orig_UIApplication_pressesBegan)(self, _cmd, presses, event);
    if (![WolFoxProStore shared].volumeGestureEnabled) return;
    BOOL containsVolumePress = NO;
    for (UIPress *press in presses) {
        if (press.type == 102 || press.type == 103) { containsVolumePress = YES; break; }
    }
    if (!containsVolumePress) return;
    dispatch_async(dispatch_get_main_queue(), ^{ [[WolFoxController shared] handleVolumeGesturePulse]; });
}

#pragma mark - Initialization

__attribute__((constructor)) static void WolFox_Pro_Hooks_Init(void) {
    if (!WFProcessIsEligible()) return;
    NSLog(@"[WolFox][BOOT] dylib_loaded process=%@", NSProcessInfo.processInfo.processName);
    [[WolFoxProHookManager shared] installHooks];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        WFInstallInstanceHook(ASIdentifierManager.class, @selector(advertisingIdentifier), (IMP)hook_advertisingIdentifier, &orig_advertisingIdentifier);
        WFInstallInstanceHook(UIDevice.class, @selector(identifierForVendor), (IMP)hook_identifierForVendor, &orig_identifierForVendor);
        WFInstallClassHook(UIImagePickerController.class, @selector(isSourceTypeAvailable:), (IMP)hook_isSourceTypeAvailable, &orig_isSourceTypeAvailable);
        WFInstallInstanceHook(UIImagePickerController.class, @selector(setSourceType:), (IMP)hook_setSourceType, &orig_setSourceType);
        WFInstallInstanceHook(UIImagePickerController.class, @selector(viewDidAppear:), (IMP)hook_UIImagePicker_viewDidAppear, &orig_UIImagePicker_viewDidAppear);
        WFInstallInstanceHook(CLLocationManager.class, @selector(location), (IMP)hook_CLLocationManager_location, &orig_CLLocationManager_location);
        WFInstallInstanceHook(CLLocation.class, @selector(coordinate), (IMP)hook_CLLocation_coordinate, &orig_CLLocation_coordinate);
        IMP original = NULL;
        if (WFInstallInstanceHook(NSClassFromString(@"WKWebView"), @selector(initWithFrame:configuration:), (IMP)hook_WKWebView_init, &original)) {
            orig_WKWebView_init = (id (*)(WKWebView *, SEL, CGRect, WKWebViewConfiguration *))original;
        }
        original = NULL;
        if (WFInstallInstanceHook(CBCentralManager.class, @selector(initWithDelegate:queue:options:), (IMP)hook_CBCentralManager_initWithDelegate, &original)) {
            orig_CBCentralManager_initWithDelegate = (id (*)(CBCentralManager *, SEL, id, dispatch_queue_t, NSDictionary *))original;
        }
        WFInstallInstanceHook(CBCentralManager.class, @selector(scanForPeripheralsWithServices:options:), (IMP)hook_CBCentralManager_scan, &orig_CBCentralManager_scan);
        WFInstallInstanceHook(CBPeripheral.class, @selector(name), (IMP)hook_CBPeripheral_name, &orig_CBPeripheral_name);
        WFInstallInstanceHook(CBPeripheral.class, @selector(identifier), (IMP)hook_CBPeripheral_identifier, &orig_CBPeripheral_identifier);
        WFInstallInstanceHook(UIApplication.class, @selector(pressesBegan:withEvent:), (IMP)hook_UIApplication_pressesBegan, &orig_UIApplication_pressesBegan);
        NSLog(@"[WolFox][BOOT] hooks_install_complete");
    });
}
