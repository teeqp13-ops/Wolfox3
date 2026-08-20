// WolFoxProStore.m
#import "WolFoxProStore.h"
#import <sqlite3.h>

@implementation WolFoxProLocation
- (id)copyWithZone:(NSZone *)zone {
    WolFoxProLocation *copy = [[WolFoxProLocation allocWithZone:zone] init];
    copy.ID = self.ID; copy.name = self.name; copy.coordinate = self.coordinate; copy.altitude = self.altitude;
    return copy;
}
@end

@implementation WolFoxProIdentifier
- (id)copyWithZone:(NSZone *)zone {
    WolFoxProIdentifier *copy = [[WolFoxProIdentifier allocWithZone:zone] init];
    copy.uuid = self.uuid; copy.name = self.name; copy.createdAt = self.createdAt;
    return copy;
}
@end

@implementation WolFoxBleProfile
- (id)copyWithZone:(NSZone *)zone {
    WolFoxBleProfile *copy = [[WolFoxBleProfile allocWithZone:zone] init];
    copy.profileID = self.profileID; copy.name = self.name;
    copy.uuid = self.uuid; copy.localName = self.localName; copy.rssi = self.rssi;
    return copy;
}
@end

@implementation WolFoxProStore {
    sqlite3 *_db;
    NSMutableArray *_mutableLocations;
    NSMutableArray *_mutableIdentifiers;
}

+ (instancetype)shared {
    static WolFoxProStore *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [WolFoxProStore new]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        [self openDB];
        [self loadSettings];
    }
    return self;
}

- (void)openDB {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *base = [fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject.path;
    if (!base.length) base = [fm URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject.path;
    NSString *directory = [base stringByAppendingPathComponent:@"WolFox"];
    NSError *directoryError = nil;
    if (![fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&directoryError]) {
        directory = NSTemporaryDirectory();
        NSLog(@"[WolFox][STORE] persistent_directory_fallback=%@", directoryError.localizedDescription);
    }
    NSString *path = [directory stringByAppendingPathComponent:@"wolfox_pro.db"];
    if (sqlite3_open([path UTF8String], &_db) != SQLITE_OK) {
        if (_db) sqlite3_close(_db);
        sqlite3_open(":memory:", &_db);
    }
    
    char *err = NULL;
    const char *sql = "CREATE TABLE IF NOT EXISTS locations (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, lat REAL, lon REAL, alt REAL);";
    if (sqlite3_exec(_db, sql, NULL, NULL, &err) != SQLITE_OK) {
        NSLog(@"[WolFox][STORE] schema_error=%s", err ?: "unknown");
    }
    if (err) sqlite3_free(err);
    [self loadLocations];
}

- (void)loadLocations {
    _mutableLocations = [NSMutableArray new];
    const char *sql = "SELECT id, name, lat, lon, alt FROM locations ORDER BY id DESC;";
    sqlite3_stmt *stmt = NULL;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            WolFoxProLocation *l = [WolFoxProLocation new];
            l.ID = sqlite3_column_int64(stmt, 0);
            const char *nameText = (const char *)sqlite3_column_text(stmt, 1);
            l.name = nameText ? [NSString stringWithUTF8String:nameText] : @"موقع غير معروف";
            l.coordinate = CLLocationCoordinate2DMake(sqlite3_column_double(stmt, 2), sqlite3_column_double(stmt, 3));
            l.altitude = sqlite3_column_double(stmt, 4);
            [_mutableLocations addObject:l];
        }
    }
    if (stmt) sqlite3_finalize(stmt);
}

- (long long)saveLocation:(WolFoxProLocation *)l {
    sqlite3_stmt *stmt = NULL;
    const char *sql = "INSERT INTO locations (name, lat, lon, alt) VALUES (?, ?, ?, ?);";
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, [l.name UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_double(stmt, 2, l.coordinate.latitude);
        sqlite3_bind_double(stmt, 3, l.coordinate.longitude);
        sqlite3_bind_double(stmt, 4, l.altitude);
        if (sqlite3_step(stmt) == SQLITE_DONE) {
            l.ID = sqlite3_last_insert_rowid(_db);
            [_mutableLocations insertObject:l atIndex:0];
        }
    }
    if (stmt) sqlite3_finalize(stmt);
    return l.ID;
}

- (void)deleteLocationID:(long long)ID {
    sqlite3_stmt *stmt = NULL;
    const char *sql = "DELETE FROM locations WHERE id = ?;";
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_int64(stmt, 1, ID);
        if (sqlite3_step(stmt) == SQLITE_DONE) {
            NSUInteger index = [_mutableLocations indexOfObjectPassingTest:^BOOL(WolFoxProLocation *l, NSUInteger idx, BOOL *stop) {
                if (l.ID != ID) return NO;
                *stop = YES;
                return YES;
            }];
            if (index != NSNotFound) [_mutableLocations removeObjectAtIndex:index];
        }
    }
    if (stmt) sqlite3_finalize(stmt);
}

- (NSArray *)locations { return [_mutableLocations copy]; }

- (void)loadSettings {
    @synchronized(self) {
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    if ([u objectForKey:@"WF_PRO_SPOOF_ACT"] == nil) { self.spoofActive = NO; [u setBool:NO forKey:@"WF_PRO_SPOOF_ACT"]; } else { self.spoofActive = [u boolForKey:@"WF_PRO_SPOOF_ACT"]; }
    self.jitterActive = [u boolForKey:@"WF_PRO_JITTER_ACT"];
    self.volumeGestureEnabled = [u objectForKey:@"WF_PRO_VOLUME_GESTURE"] == nil ? YES : [u boolForKey:@"WF_PRO_VOLUME_GESTURE"];
    self.themeIndex = [u integerForKey:@"WF_PRO_THEME_IDX"];
    self.mapStyle = [u integerForKey:@"WF_PRO_MAP_STYLE"];
    self.simSpeed = [u doubleForKey:@"WF_PRO_SIM_SPEED"] ?: 5.0;
    NSNumber *savedLatitude = [u objectForKey:@"WF_PRO_LAT"];
    NSNumber *savedLongitude = [u objectForKey:@"WF_PRO_LON"];
    if ([savedLatitude isKindOfClass:NSNumber.class] && [savedLongitude isKindOfClass:NSNumber.class]) {
        self.currentFakeCoords = CLLocationCoordinate2DMake(savedLatitude.doubleValue, savedLongitude.doubleValue);
    } else {
        self.currentFakeCoords = CLLocationCoordinate2DMake(24.7136, 46.6753);
    }
    if (!CLLocationCoordinate2DIsValid(self.currentFakeCoords)) {
        self.currentFakeCoords = CLLocationCoordinate2DMake(24.7136, 46.6753);
    }
    self.spoofedImagePath = [u stringForKey:@"WF_PRO_CAM_IMG"];
    self.mediaUploadActive = [u boolForKey:@"WF_PRO_MEDIA_UPLOAD_ACTIVE"];
    if (self.spoofedImagePath.length && ![[NSFileManager defaultManager] fileExistsAtPath:self.spoofedImagePath]) {
        self.spoofedImagePath = nil;
        self.mediaUploadActive = NO;
        [u removeObjectForKey:@"WF_PRO_CAM_IMG"];
        [u setBool:NO forKey:@"WF_PRO_MEDIA_UPLOAD_ACTIVE"];
    }
    
    // Load Identifiers from Defaults (simulated structured store)
    _mutableIdentifiers = [NSMutableArray new];
    NSArray *ids = [u arrayForKey:@"WF_PRO_IDS"] ?: @[];
    for (NSDictionary *d in ids) {
        NSUUID *savedUUID = [[NSUUID alloc] initWithUUIDString:d[@"uuid"]];
        if (!savedUUID) continue;
        WolFoxProIdentifier *i = [WolFoxProIdentifier new];
        i.uuid = savedUUID.UUIDString; i.name = d[@"name"];
        NSString *dateStr = d[@"date"];
        i.createdAt = dateStr ? [NSDate dateWithTimeIntervalSince1970:[dateStr doubleValue]] : [NSDate date];
        [_mutableIdentifiers addObject:i];
    }
    NSUUID *activeUUID = [[NSUUID alloc] initWithUUIDString:[u stringForKey:@"WF_PRO_ACTIVE_ID"]];
    self.activeIdentifierUUID = activeUUID.UUIDString;
    if (!activeUUID) [u removeObjectForKey:@"WF_PRO_ACTIVE_ID"];
    
    self.bluetoothActive = [u boolForKey:@"WF_PRO_BT_ACT"];
    self.activeBleProfileID = [u stringForKey:@"WF_PRO_BT_ACTIVE_ID"];
    NSArray *rawProfiles = [u arrayForKey:@"WF_PRO_BT_PROFILES"] ?: @[];
    self.savedBleProfiles = [NSMutableArray new];
    for (NSDictionary *d in rawProfiles) {
        if (![d isKindOfClass:[NSDictionary class]]) continue;
        WolFoxBleProfile *p = [WolFoxBleProfile new];
        p.profileID = d[@"profileID"] ?: [[NSUUID UUID] UUIDString];
        p.name      = d[@"name"] ?: @"جهاز غير معروف";
        p.uuid      = d[@"uuid"] ?: @"";
        p.localName = d[@"localName"] ?: @"";
        p.rssi      = [d[@"rssi"] integerValue];
        [self.savedBleProfiles addObject:p];
    }
    } // @synchronized
}

- (void)saveSettings {
    @synchronized(self) {
        NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
        [u setBool:self.spoofActive forKey:@"WF_PRO_SPOOF_ACT"];
        [u setBool:self.jitterActive forKey:@"WF_PRO_JITTER_ACT"];
        [u setBool:self.volumeGestureEnabled forKey:@"WF_PRO_VOLUME_GESTURE"];
        [u setInteger:self.themeIndex forKey:@"WF_PRO_THEME_IDX"];
        [u setInteger:self.mapStyle forKey:@"WF_PRO_MAP_STYLE"];
        [u setDouble:self.simSpeed forKey:@"WF_PRO_SIM_SPEED"];
        [u setDouble:self.currentFakeCoords.latitude forKey:@"WF_PRO_LAT"];
        [u setDouble:self.currentFakeCoords.longitude forKey:@"WF_PRO_LON"];
        if (self.spoofedImagePath) [u setObject:self.spoofedImagePath forKey:@"WF_PRO_CAM_IMG"];
        else [u removeObjectForKey:@"WF_PRO_CAM_IMG"];
        [u setBool:self.mediaUploadActive forKey:@"WF_PRO_MEDIA_UPLOAD_ACTIVE"];
        
        NSMutableArray *ids = [NSMutableArray new];
        for (WolFoxProIdentifier *i in _mutableIdentifiers) {
            NSString *dateStr = i.createdAt ? [NSString stringWithFormat:@"%.0f", [(NSDate*)i.createdAt timeIntervalSince1970]] : [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
            [ids addObject:@{@"uuid": i.uuid ?: @"", @"name": i.name ?: @"", @"date": dateStr}];
        }
        [u setObject:ids forKey:@"WF_PRO_IDS"];
        if (self.activeIdentifierUUID) [u setObject:self.activeIdentifierUUID forKey:@"WF_PRO_ACTIVE_ID"];
        else [u removeObjectForKey:@"WF_PRO_ACTIVE_ID"];
        
        [u setBool:self.bluetoothActive forKey:@"WF_PRO_BT_ACT"];
        if (self.activeBleProfileID) [u setObject:self.activeBleProfileID forKey:@"WF_PRO_BT_ACTIVE_ID"];
        else [u removeObjectForKey:@"WF_PRO_BT_ACTIVE_ID"];
        NSMutableArray *rawProfiles = [NSMutableArray new];
        for (WolFoxBleProfile *p in self.savedBleProfiles) {
            [rawProfiles addObject:@{
                @"profileID": p.profileID ?: @"",
                @"name":      p.name ?: @"",
                @"uuid":      p.uuid ?: @"",
                @"localName": p.localName ?: @"",
                @"rssi":      @(p.rssi)
            }];
        }
        [u setObject:rawProfiles forKey:@"WF_PRO_BT_PROFILES"];
        
        [u synchronize];
    }
}

- (void)saveIdentifier:(WolFoxProIdentifier *)i {
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:i.uuid];
    if (!uuid) return;
    i.uuid = uuid.UUIDString;
    for (WolFoxProIdentifier *existing in [_mutableIdentifiers copy]) {
        if ([existing.uuid isEqualToString:i.uuid]) [_mutableIdentifiers removeObject:existing];
    }
    [_mutableIdentifiers addObject:i];
    [self saveSettings];
}

- (NSUUID *)validatedActiveIdentifier {
    NSString *value = self.activeIdentifierUUID;
    return value.length ? [[NSUUID alloc] initWithUUIDString:value] : nil;
}

- (BOOL)activateIdentifierString:(NSString *)value {
    NSString *trimmed = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:trimmed];
    if (!uuid) return NO;
    self.activeIdentifierUUID = uuid.UUIDString;
    BOOL alreadySaved = NO;
    for (WolFoxProIdentifier *identifier in _mutableIdentifiers) {
        if ([identifier.uuid isEqualToString:self.activeIdentifierUUID]) {
            alreadySaved = YES;
            break;
        }
    }
    if (!alreadySaved) {
        WolFoxProIdentifier *identifier = [WolFoxProIdentifier new];
        identifier.uuid = self.activeIdentifierUUID;
        identifier.name = @"هوية موحدة";
        identifier.createdAt = [NSDate date];
        [_mutableIdentifiers addObject:identifier];
    }
    [self saveSettings];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_IDENTIFIER_CHANGED" object:self.activeIdentifierUUID];
    return YES;
}

- (void)deactivateIdentifier {
    self.activeIdentifierUUID = nil;
    [self saveSettings];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_IDENTIFIER_CHANGED" object:nil];
}

- (void)deleteIdentifierUUID:(NSString *)uuid {
    NSUInteger index = [_mutableIdentifiers indexOfObjectPassingTest:^BOOL(WolFoxProIdentifier *i, NSUInteger idx, BOOL *stop) {
        if (![i.uuid isEqualToString:uuid]) return NO;
        *stop = YES;
        return YES;
    }];
    if (index != NSNotFound) [_mutableIdentifiers removeObjectAtIndex:index];
    BOOL removedActive = self.activeIdentifierUUID.length && uuid.length &&
                         [self.activeIdentifierUUID caseInsensitiveCompare:uuid] == NSOrderedSame;
    if (removedActive) {
        self.activeIdentifierUUID = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"WF_IDENTIFIER_CHANGED" object:nil];
    }
    [self saveSettings];
}

- (NSArray *)identifiers { return [_mutableIdentifiers copy]; }

- (void)saveBleProfile:(WolFoxBleProfile *)profile {
    if (!profile.profileID) profile.profileID = [[NSUUID UUID] UUIDString];
    // Remove existing with same profileID
    for (WolFoxBleProfile *p in [self.savedBleProfiles copy]) {
        if ([p.profileID isEqualToString:profile.profileID]) {
            [self.savedBleProfiles removeObject:p]; break;
        }
    }
    [self.savedBleProfiles insertObject:profile atIndex:0];
    [self saveSettings];
}

- (void)deleteBleProfileID:(NSString *)profileID {
    for (WolFoxBleProfile *p in [self.savedBleProfiles copy]) {
        if ([p.profileID isEqualToString:profileID]) {
            [self.savedBleProfiles removeObject:p]; break;
        }
    }
    [self saveSettings];
}

- (WolFoxBleProfile *)activeBleProfile {
    NSString *activeID = self.activeBleProfileID;
    if (!activeID.length) return nil;
    @synchronized(self.savedBleProfiles) {
        for (WolFoxBleProfile *profile in self.savedBleProfiles) {
            if ([profile.profileID isEqualToString:activeID]) return [profile copy];
        }
    }
    return nil;
}

- (NSString *)mediaStoragePath {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *base = [fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject.path;
    if (!base.length) base = [fm URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject.path;
    NSString *directory = [base stringByAppendingPathComponent:@"WolFox/Media"];
    NSError *error = nil;
    if (![fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error]) {
        directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"WolFoxMedia"];
        [fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return [directory stringByAppendingPathComponent:@"wf_spoof.jpg"];
}

@end
