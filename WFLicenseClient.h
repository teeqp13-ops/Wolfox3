// WFLicenseClient.h - V29 Advanced
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WFLicenseStatus) {
    WFLicenseStatusUnknown,
    WFLicenseStatusValid,
    WFLicenseStatusInvalid,
    WFLicenseStatusExpired,
    WFLicenseStatusBlocked,
    WFLicenseStatusNetworkError,
    WFLicenseStatusInvalidToken,
    WFLicenseStatusProjectDisabled,
    WFLicenseStatusUpdateRequired,
    WFLicenseStatusRateLimited,
};

@interface WFLicenseResult : NSObject
@property (nonatomic, assign) BOOL           success;
@property (nonatomic, assign) WFLicenseStatus status;
@property (nonatomic, copy)   NSString       *message;
@property (nonatomic, copy, nullable) NSString *startedAt;
@property (nonatomic, copy, nullable) NSString *expiresAt;
@property (nonatomic, copy, nullable) NSString *planName;
@property (nonatomic, copy, nullable) NSString *errorCode;
@property (nonatomic, copy, nullable) NSString *updateURL;
@property (nonatomic, copy, nullable) NSString *minimumVersion;
@property (nonatomic, assign) BOOL forceUpdate;
@end

@interface WFLicenseClient : NSObject
@property (class, nonatomic, copy) NSString *baseURL;
@property (class, nonatomic, copy) NSString *projectKey;

+ (void)activateCode:(NSString *)code completion:(void(^)(WFLicenseResult *result))completion;
+ (void)verifySavedLicenseWithCompletion:(void(^)(WFLicenseResult *result))completion;
+ (void)validateStrictlyWithCompletion:(void(^)(WFLicenseResult *result))completion;
+ (void)startHeartbeat;
+ (BOOL)hasStoredLicense;
+ (BOOL)isRuntimeLicenseValid;
+ (nullable WFLicenseResult *)lastLicenseResult;
+ (void)markAsActivated;
+ (void)clearStoredLicense;
+ (nullable NSString *)storedCode;
+ (nullable WFLicenseResult *)storedLicenseInfo;
+ (NSString *)deviceIdentifier;

// Method for backward compatibility
+ (void)validateWithCompletion:(void(^)(BOOL success, NSString *message))completion;

@end

NS_ASSUME_NONNULL_END
