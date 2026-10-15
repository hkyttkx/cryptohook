// CHTheme.h — 配色/字体集中管理
#import <UIKit/UIKit.h>

@interface CHTheme : NSObject
+ (UIColor *)bg;
+ (UIColor *)card;
+ (UIColor *)cardBorder;
+ (UIColor *)text;
+ (UIColor *)sub;
+ (UIColor *)accent;

// 记录类型 -> 颜色
+ (UIColor *)colorForLayer:(NSString *)layer;
+ (NSString *)symbolForLayer:(NSString *)layer;
@end
