// CHTheme.m
#import "CHTheme.h"

@implementation CHTheme

+ (UIColor *)bg {
    if (@available(iOS 13.0, *)) return [UIColor systemGroupedBackgroundColor];
    return [UIColor colorWithWhite:0.95 alpha:1];
}
+ (UIColor *)card {
    if (@available(iOS 13.0, *)) return [UIColor secondarySystemGroupedBackgroundColor];
    return [UIColor whiteColor];
}
+ (UIColor *)cardBorder {
    return [UIColor separatorColor];
}
+ (UIColor *)text {
    return [UIColor labelColor];
}
+ (UIColor *)sub {
    return [UIColor secondaryLabelColor];
}
+ (UIColor *)accent {
    return [UIColor colorWithRed:0.20 green:0.55 blue:1.00 alpha:1.0];
}

+ (UIColor *)colorForLayer:(NSString *)layer {
    if ([layer isEqualToString:@"L1"]) return [UIColor systemBlueColor];      // 系统加密
    if ([layer isEqualToString:@"L2"]) return [UIColor systemGreenColor];     // 明文
    if ([layer isEqualToString:@"L3"]) return [UIColor systemOrangeColor];    // 网络
    if ([layer isEqualToString:@"L4"]) return [UIColor systemPurpleColor];    // 自研
    if ([layer isEqualToString:@"SYS"]) return [UIColor systemGrayColor];
    return [UIColor systemTealColor];
}

+ (NSString *)symbolForLayer:(NSString *)layer {
    if ([layer isEqualToString:@"L1"]) return @"lock.shield.fill";
    if ([layer isEqualToString:@"L2"]) return @"text.alignleft";
    if ([layer isEqualToString:@"L3"]) return @"arrow.left.arrow.right";
    if ([layer isEqualToString:@"L4"]) return @"cpu";
    return @"gearshape.fill";
}

@end
