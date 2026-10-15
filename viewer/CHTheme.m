// CHTheme.m
#import "CHTheme.h"

@implementation CHTheme

+ (UIColor *)bg     { return CH_BG; }
+ (UIColor *)card   { return CH_CARD; }
+ (UIColor *)line   { return CH_LINE; }
+ (UIColor *)text   { return CH_TEXT; }
+ (UIColor *)sub    { return CH_SUB; }
+ (UIColor *)accent { return CH_ACCENT; }

+ (UIFont *)mono:(CGFloat)size weight:(UIFontWeight)w {
    UIFont *f = [UIFont monospacedSystemFontOfSize:size weight:w];
    return f ?: [UIFont fontWithName:@"Menlo" size:size];
}
+ (UIFont *)monoBold:(CGFloat)size {
    return [self mono:size weight:UIFontWeightBold];
}

+ (NSAttributedString *)tracked:(NSString *)s font:(UIFont *)f color:(UIColor *)c spacing:(CGFloat)sp {
    return [[NSAttributedString alloc] initWithString:s ?: @"" attributes:@{
        NSFontAttributeName: f,
        NSForegroundColorAttributeName: c,
        NSKernAttributeName: @(sp)
    }];
}

+ (UIColor *)colorForLayer:(NSString *)layer {
    if ([layer isEqualToString:@"L1"]) return CH_BLUE;    // 系统加密
    if ([layer isEqualToString:@"L2"]) return CH_ACCENT;  // 明文
    if ([layer isEqualToString:@"L3"]) return CH_ORANGE;  // 网络
    if ([layer isEqualToString:@"L4"]) return CH_PURPLE;  // 自研
    return CH_SUB;
}

+ (NSString *)symbolForLayer:(NSString *)layer {
    if ([layer isEqualToString:@"L1"]) return @"lock.fill";
    if ([layer isEqualToString:@"L2"]) return @"text.alignleft";
    if ([layer isEqualToString:@"L3"]) return @"bolt.horizontal.fill";
    if ([layer isEqualToString:@"L4"]) return @"cpu";
    return @"circle.fill";
}

+ (NSString *)nameForLayer:(NSString *)layer {
    if ([layer isEqualToString:@"L1"]) return @"SYS CRYPTO";
    if ([layer isEqualToString:@"L2"]) return @"PLAIN";
    if ([layer isEqualToString:@"L3"]) return @"NET";
    if ([layer isEqualToString:@"L4"]) return @"CUSTOM";
    return @"SYS";
}

+ (void)glow:(UIView *)v color:(UIColor *)c radius:(CGFloat)r opacity:(CGFloat)o {
    v.layer.shadowColor = c.CGColor;
    v.layer.shadowRadius = r;
    v.layer.shadowOpacity = o;
    v.layer.shadowOffset = CGSizeZero;
}

+ (void)strokeCard:(UIView *)v {
    v.layer.borderColor = CH_LINE.CGColor;
    v.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
    v.layer.cornerRadius = 12;
    v.layer.cornerCurve = kCACornerCurveContinuous;
    v.backgroundColor = CH_CARD;
}

@end
