#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

static NSString *const DLTPrefsPath = @"/var/mobile/Library/Preferences/com.wolfox.dltube.plist";
static NSString *const DLTSettingsButtonID = @"com.wolfox.dltube.settings-button";
static NSHashTable<AVPlayer *> *DLTPlayers;

static NSDictionary *DLTPreferences(void) {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:DLTPrefsPath];
    return preferences ?: @{};
}

static BOOL DLTPreference(NSString *key, BOOL fallback) {
    id value = DLTPreferences()[key];
    return value ? [value boolValue] : fallback;
}

static void DLTConfigureAudioSession(void) {
    if (!DLTPreference(@"backgroundPlayback", YES)) {
        return;
    }

    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];
}

static void DLTSetPreference(NSString *key, BOOL enabled) {
    NSMutableDictionary *preferences = [DLTPreferences() mutableCopy];
    preferences[key] = @(enabled);
    [preferences writeToFile:DLTPrefsPath atomically:YES];

    if ([key isEqualToString:@"backgroundPlayback"] && enabled) {
        DLTConfigureAudioSession();
    }
}

static UIViewController *DLTTopViewController(void) {
    UIWindow *window = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive ||
            ![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }
    }

    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    if ([controller isKindOfClass:UINavigationController.class]) {
        controller = ((UINavigationController *)controller).visibleViewController;
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        controller = ((UITabBarController *)controller).selectedViewController;
    }
    return controller;
}

@interface DLTSettingsController : NSObject
+ (instancetype)sharedController;
- (void)showSettings;
@end

@implementation DLTSettingsController

+ (instancetype)sharedController {
    static DLTSettingsController *controller;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controller = [DLTSettingsController new];
    });
    return controller;
}

- (void)addToggle:(NSString *)title
              key:(NSString *)key
         fallback:(BOOL)fallback
          toAlert:(UIAlertController *)alert {
    BOOL enabled = DLTPreference(key, fallback);
    NSString *state = enabled ? @"✓" : @"○";
    NSString *actionTitle = [NSString stringWithFormat:@"%@  %@", state, title];
    __weak typeof(self) weakSelf = self;
    UIAlertAction *action = [UIAlertAction actionWithTitle:actionTitle
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(__unused UIAlertAction *selectedAction) {
        DLTSetPreference(key, !enabled);
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf showSettings];
        });
    }];
    [alert addAction:action];
}

- (void)showSettings {
    UIViewController *controller = DLTTopViewController();
    if (!controller || [controller.presentedViewController isKindOfClass:UIAlertController.class]) {
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DLTube"
                                                                   message:@"إعدادات النسخة التجريبية 0.1.0"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [self addToggle:@"التشغيل في الخلفية" key:@"backgroundPlayback" fallback:YES toAlert:alert];
    [self addToggle:@"إعادة التشغيل تلقائيًا" key:@"autoReplay" fallback:NO toAlert:alert];
    [self addToggle:@"تفعيل صورة داخل صورة" key:@"pictureInPicture" fallback:YES toAlert:alert];
    [self addToggle:@"إخفاء زر إنشاء فيديو" key:@"hideCreate" fallback:NO toAlert:alert];
    [self addToggle:@"إخفاء العناصر الإعلانية" key:@"hideAds" fallback:NO toAlert:alert];
    [self addToggle:@"إخفاء أقسام المقترحات" key:@"hideRecommended" fallback:NO toAlert:alert];

    UIAlertAction *downloads = [UIAlertAction actionWithTitle:@"مدير التنزيلات — قيد التطوير"
                                                        style:UIAlertActionStyleDefault
                                                      handler:nil];
    downloads.enabled = NO;
    [alert addAction:downloads];
    [alert addAction:[UIAlertAction actionWithTitle:@"إغلاق" style:UIAlertActionStyleCancel handler:nil]];

    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) {
        popover.sourceView = controller.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(controller.view.bounds),
                                        CGRectGetMaxY(controller.view.bounds) - 80.0,
                                        1.0,
                                        1.0);
    }
    [controller presentViewController:alert animated:YES completion:nil];
}

@end

static void DLTInstallSettingsButton(UIWindow *window) {
    if (!window || [window.accessibilityIdentifier isEqualToString:DLTSettingsButtonID]) {
        return;
    }
    for (UIView *view in window.subviews) {
        if ([view.accessibilityIdentifier isEqualToString:DLTSettingsButtonID]) {
            return;
        }
    }

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.accessibilityIdentifier = DLTSettingsButtonID;
    button.accessibilityLabel = @"إعدادات DLTube";
    button.frame = CGRectMake(16.0, MAX(80.0, CGRectGetHeight(window.bounds) - 150.0), 52.0, 52.0);
    button.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
    button.backgroundColor = [UIColor colorWithRed:0.47 green:0.25 blue:0.95 alpha:0.96];
    button.tintColor = UIColor.whiteColor;
    button.layer.cornerRadius = 26.0;
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = 0.28;
    button.layer.shadowRadius = 8.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 3.0);
    UIImage *icon = [UIImage systemImageNamed:@"arrow.down.circle.fill"];
    if (icon) {
        [button setImage:icon forState:UIControlStateNormal];
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    } else {
        [button setTitle:@"DL" forState:UIControlStateNormal];
    }
    [button addTarget:[DLTSettingsController sharedController]
               action:@selector(showSettings)
     forControlEvents:UIControlEventTouchUpInside];
    [window addSubview:button];
}

static BOOL DLTContainsAnyKeyword(NSString *text, NSArray<NSString *> *keywords) {
    if (text.length == 0) {
        return NO;
    }
    NSString *lowercase = text.lowercaseString;
    for (NSString *keyword in keywords) {
        if ([lowercase containsString:keyword.lowercaseString]) {
            return YES;
        }
    }
    return NO;
}

static void DLTApplyViewFilters(UIView *view) {
    NSString *label = view.accessibilityLabel ?: @"";
    BOOL isLeafOrControl = [view isKindOfClass:UIControl.class] || view.subviews.count == 0;

    if (isLeafOrControl && DLTPreference(@"hideCreate", NO) &&
        DLTContainsAnyKeyword(label, @[@"create", @"إنشاء", @"upload", @"رفع فيديو"])) {
        view.hidden = YES;
    }

    if (isLeafOrControl && DLTPreference(@"hideAds", NO) &&
        DLTContainsAnyKeyword(label, @[@"sponsored", @"advertisement", @"إعلان", @"مموّل"])) {
        view.hidden = YES;
    }

    if (isLeafOrControl && DLTPreference(@"hideRecommended", NO) &&
        DLTContainsAnyKeyword(label, @[@"recommended", @"suggested", @"مقترح", @"موصى به"])) {
        view.hidden = YES;
    }

    for (UIView *subview in view.subviews) {
        DLTApplyViewFilters(subview);
    }
}

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    DLTInstallSettingsButton(self.view.window);
    DLTApplyViewFilters(self.view);
}

%end

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        DLTInstallSettingsButton(self);
    });
}

%end

%hook AVPlayer

- (instancetype)init {
    AVPlayer *player = %orig;
    [DLTPlayers addObject:player];
    return player;
}

- (instancetype)initWithPlayerItem:(AVPlayerItem *)item {
    AVPlayer *player = %orig(item);
    [DLTPlayers addObject:player];
    return player;
}

- (void)pause {
    if (DLTPreference(@"backgroundPlayback", YES) &&
        UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        return;
    }
    %orig;
}

%end

%hook AVPlayerViewController

- (void)setAllowsPictureInPicturePlayback:(BOOL)allowed {
    %orig(DLTPreference(@"pictureInPicture", YES) ? YES : allowed);
}

%end


%ctor {
    @autoreleasepool {
        DLTPlayers = [NSHashTable weakObjectsHashTable];
        DLTConfigureAudioSession();
        [NSNotificationCenter.defaultCenter addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                                                        object:nil
                                                         queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(NSNotification *notification) {
            if (!DLTPreference(@"autoReplay", NO)) {
                return;
            }
            AVPlayerItem *endedItem = notification.object;
            for (AVPlayer *player in DLTPlayers) {
                if (player.currentItem == endedItem) {
                    [player seekToTime:kCMTimeZero completionHandler:^(__unused BOOL finished) {
                        [player play];
                    }];
                }
            }
        }];
    }
}
