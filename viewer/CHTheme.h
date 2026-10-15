// CHTheme.h — 深色科技风配色（不再是系统色模板）
#import <UIKit/UIKit.h>

// ── 调色板 ──────────────────────────────────────────
#define CH_BG      [UIColor colorWithRed:0.031 green:0.039 blue:0.059 alpha:1.0]  // #080A0F 近黑
#define CH_BG2     [UIColor colorWithRed:0.055 green:0.067 blue:0.098 alpha:1.0]  // #0E1119 次级背景
#define CH_CARD    [UIColor colorWithRed:0.063 green:0.078 blue:0.110 alpha:1.0]  // #10141C 卡片
#define CH_CARD_HI [UIColor colorWithRed:0.086 green:0.106 blue:0.145 alpha:1.0]  // #161B25 卡片(高亮)
#define CH_LINE    [UIColor colorWithRed:0.118 green:0.157 blue:0.212 alpha:1.0]  // #1E2836 描边
#define CH_ACCENT  [UIColor colorWithRed:0.000 green:0.898 blue:0.627 alpha:1.0]  // #00E5A0 霓虹青绿
#define CH_BLUE    [UIColor colorWithRed:0.220 green:0.741 blue:0.973 alpha:1.0]  // #38BDF8 电光蓝
#define CH_PURPLE  [UIColor colorWithRed:0.749 green:0.353 blue:0.949 alpha:1.0]  // #BF5AF2
#define CH_ORANGE  [UIColor colorWithRed:0.984 green:0.749 blue:0.141 alpha:1.0]  // #FBBF24
#define CH_RED     [UIColor colorWithRed:1.000 green:0.231 blue:0.361 alpha:1.0]  // #FF3B5C
#define CH_TEXT    [UIColor colorWithRed:0.910 green:0.933 blue:0.961 alpha:1.0]  // #E8EEF5
#define CH_TEXT2   [UIColor colorWithRed:0.627 green:0.678 blue:0.749 alpha:1.0]  // #A0ADBF
#define CH_SUB     [UIColor colorWithRed:0.420 green:0.478 blue:0.561 alpha:1.0]  // #6B7A8F

@interface CHTheme : NSObject

+ (UIColor *)bg;
+ (UIColor *)card;
+ (UIColor *)line;
+ (UIColor *)text;
+ (UIColor *)sub;
+ (UIColor *)accent;

// 等宽字体（科技感的关键）
+ (UIFont *)mono:(CGFloat)size weight:(UIFontWeight)w;
+ (UIFont *)monoBold:(CGFloat)size;
// 字距
+ (NSAttributedString *)tracked:(NSString *)s font:(UIFont *)f color:(UIColor *)c spacing:(CGFloat)sp;

// 记录类型
+ (UIColor *)colorForLayer:(NSString *)layer;
+ (NSString *)symbolForLayer:(NSString *)layer;
+ (NSString *)nameForLayer:(NSString *)layer;

// 视觉效果
+ (void)glow:(UIView *)v color:(UIColor *)c radius:(CGFloat)r opacity:(CGFloat)o;
+ (void)strokeCard:(UIView *)v;

@end
