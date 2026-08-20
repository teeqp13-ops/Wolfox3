// WolFoxProStore.h - Pro Persistence Layer
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WolFoxProLocation : NSObject <NSCopying>
@property (nonatomic, assign) long long ID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
@property (nonatomic, assign) double altitude;
@end

@interface WolFoxProIdentifier : NSObject <NSCopying>
@property (nonatomic, copy) NSString *uuid;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSDate *createdAt;
@end

@interface WolFoxBleProfile : NSObject <NSCopying>
@property (nonatomic, copy) NSString *profileID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *uuid;       // CBPeripheral UUID string
@property (nonatomic, copy) NSString *localName;  // advertised name
@property (nonatomic, assign) NSInteger rssi;
@end

@interface WolFoxProStore : NSObject

+ (instancetype)shared;

// Locations (SQLite based)
@property (readonly, copy, nonatomic) NSArray<WolFoxProLocation *> *locations;
- (long long)saveLocation:(WolFoxProLocation *)location;
- (void)deleteLocationID:(long long)ID;

// Identifiers (Defaults based)
@property (readonly, copy, nonatomic) NSArray<WolFoxProIdentifier *> *identifiers;
@property (nonatomic, copy, nullable) NSString *activeIdentifierUUID;
- (nullable NSUUID *)validatedActiveIdentifier;
- (BOOL)activateIdentifierString:(NSString *)value;
- (void)deactivateIdentifier;
- (void)saveIdentifier:(WolFoxProIdentifier *)identifier;
- (void)deleteIdentifierUUID:(NSString *)uuid;

// Global Settings
@property (nonatomic, assign) BOOL spoofActive;
@property (nonatomic, assign) BOOL jitterActive;
@property (nonatomic, assign) BOOL volumeGestureEnabled;
@property (nonatomic, assign) CLLocationCoordinate2D currentFakeCoords;
@property (nonatomic, assign) NSInteger themeIndex;
@property (nonatomic, assign) NSInteger mapStyle; // 0: Standard, 1: Satellite, 2: Hybrid
@property (nonatomic, assign) double simSpeed;
@property (nonatomic, assign) BOOL routeActive;
@property (nonatomic, assign) CLLocationCoordinate2D targetRouteCoords;
@property (nonatomic, copy, nullable) NSString *spoofedImagePath;
@property (nonatomic, assign) BOOL mediaUploadActive;

// Bluetooth Spoofing
@property (nonatomic, assign) BOOL bluetoothActive;
@property (nonatomic, copy, nullable) NSString *activeBleProfileID;
@property (nonatomic, strong) NSMutableArray<WolFoxBleProfile *> *savedBleProfiles;

- (void)saveSettings;
- (void)loadSettings;
- (NSString *)mediaStoragePath;

// BLE Profiles
- (void)saveBleProfile:(WolFoxBleProfile *)profile;
- (void)deleteBleProfileID:(NSString *)profileID;
- (nullable WolFoxBleProfile *)activeBleProfile;

@end

NS_ASSUME_NONNULL_END
