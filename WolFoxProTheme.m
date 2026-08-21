// WolFoxProTheme.m
#import "WolFoxProTheme.h"
#import "WolFoxProStore.h"

@implementation WolFoxProTheme

+ (BOOL)isDark { return YES; }

+ (UIColor *)windowBackground {
    return [self royalBackground];
}

+ (UIColor *)surfacePrimary {
    return [self royalCard];
}

+ (UIColor *)surfaceSecondary {
    return [self royalField];
}

+ (UIColor *)textPrimary {
    return [UIColor colorWithRed:0.95 green:0.97 blue:1.0 alpha:1.0];
}

+ (UIColor *)textSecondary {
    return [UIColor colorWithRed:0.58 green:0.65 blue:0.76 alpha:1.0];
}

+ (UIColor *)accent { return [self royalBlue]; }
+ (UIColor *)danger { return [UIColor colorWithRed:0.85 green:0.25 blue:0.30 alpha:1.0]; }
+ (UIColor *)success { return [UIColor colorWithRed:0.20 green:0.85 blue:0.40 alpha:1.0]; }
+ (UIColor *)gold { return [UIColor colorWithRed:0.98 green:0.74 blue:0.20 alpha:1.0]; }
+ (UIColor *)royalBackground { return [UIColor colorWithRed:0.027 green:0.043 blue:0.078 alpha:1.0]; }
+ (UIColor *)royalCard { return [UIColor colorWithRed:0.067 green:0.094 blue:0.153 alpha:0.98]; }
+ (UIColor *)royalField { return [UIColor colorWithRed:0.043 green:0.071 blue:0.125 alpha:1.0]; }
+ (UIColor *)royalBlue { return [UIColor colorWithRed:0.145 green:0.388 blue:0.922 alpha:1.0]; }
+ (UIColor *)accentSoft { return [[self royalBlue] colorWithAlphaComponent:0.14]; }
+ (BOOL)reduceMotionEnabled { return UIAccessibilityIsReduceMotionEnabled(); }
+ (NSTimeInterval)transitionDuration { return [self reduceMotionEnabled] ? 0.0 : 0.22; }

+ (UIFont *)fontOfSize:(double)size weight:(UIFontWeight)weight {
    return [UIFont systemFontOfSize:size weight:weight];
}

+ (UIBlurEffectStyle)blurStyle {
    return UIBlurEffectStyleDark;
}

@end
