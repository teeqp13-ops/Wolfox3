// WolFoxProCellModel.h
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WolFoxCellKind) {
    WolFoxCellKindSwitch,
    WolFoxCellKindSlider,
    WolFoxCellKindValue,
    WolFoxCellKindButton
};

@interface WolFoxProCellModel : NSObject
@property (nonatomic, assign) WolFoxCellKind kind;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *icon;
@property (nonatomic, assign) BOOL isOn;
@property (nonatomic, assign) double value;
@property (nonatomic, copy, nullable) NSString *valueText;
@property (nonatomic, copy, nullable) void (^onAction)(id sender);

- (void)invokeAction:(id)sender;

+ (instancetype)switchRow:(NSString *)title icon:(NSString *)icon isOn:(BOOL)isOn action:(void (^)(id))action;
+ (instancetype)buttonRow:(NSString *)title icon:(NSString *)icon action:(void (^)(id))action;
+ (instancetype)valueRow:(NSString *)title icon:(NSString *)icon value:(NSString *)value action:(void (^)(id))action;

@end

NS_ASSUME_NONNULL_END
