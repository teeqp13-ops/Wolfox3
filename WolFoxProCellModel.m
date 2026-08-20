// WolFoxProCellModel.m
#import "WolFoxProCellModel.h"

@implementation WolFoxProCellModel

- (void)invokeAction:(id)sender {
    if (self.onAction) self.onAction(sender);
}

+ (instancetype)switchRow:(NSString *)title icon:(NSString *)icon isOn:(BOOL)isOn action:(void (^)(id))action {
    WolFoxProCellModel *m = [WolFoxProCellModel new];
    m.kind = WolFoxCellKindSwitch; m.title = title; m.icon = icon; m.isOn = isOn; m.onAction = action;
    return m;
}

+ (instancetype)buttonRow:(NSString *)title icon:(NSString *)icon action:(void (^)(id))action {
    WolFoxProCellModel *m = [WolFoxProCellModel new];
    m.kind = WolFoxCellKindButton; m.title = title; m.icon = icon; m.onAction = action;
    return m;
}

+ (instancetype)valueRow:(NSString *)title icon:(NSString *)icon value:(NSString *)value action:(void (^)(id))action {
    WolFoxProCellModel *m = [WolFoxProCellModel new];
    m.kind = WolFoxCellKindValue; m.title = title; m.icon = icon; m.valueText = value; m.onAction = action;
    return m;
}

@end
