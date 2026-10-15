// main.m — 入口 + AppDelegate（启动动画 → 主界面）
#import <UIKit/UIKit.h>
#import "CHRootVC.h"
#import "CHTheme.h"
#import "CHSplashVC.h"

@interface CHAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CHAppDelegate

- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    // ── 启动动画 ──
    CHSplashVC *splash = [CHSplashVC new];
    splash.onFinish = ^{
        CHRootVC *root = [CHRootVC new];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];

        if (@available(iOS 13.0, *)) {
            // ★ 毛玻璃常驻 —— 内容不再穿到导航栏底下
            UINavigationBarAppearance *ap = [UINavigationBarAppearance new];
            [ap configureWithDefaultBackground];
            ap.backgroundColor = [CH_BG colorWithAlphaComponent:0.92];
            ap.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
            ap.shadowColor = CH_LINE;
            ap.titleTextAttributes = @{NSFontAttributeName: [CHTheme mono:15 weight:UIFontWeightBold],
                                       NSForegroundColorAttributeName: CH_ACCENT};
            nav.navigationBar.standardAppearance = ap;
            nav.navigationBar.scrollEdgeAppearance = ap;    // ← 滚动时同样毛玻璃
            nav.navigationBar.compactAppearance = ap;
            nav.navigationBar.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        }
        nav.navigationBar.tintColor = CH_ACCENT;
        nav.navigationBar.prefersLargeTitles = NO;   // ★ 关掉大标题（会撑乱布局）

        [UIView transitionWithView:self.window duration:0.35
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{ self.window.rootViewController = nav; }
                        completion:nil];
    };

    self.window.rootViewController = splash;
    [self.window makeKeyAndVisible];
    return YES;
}

@end

// ── 崩溃日志（App 侧，写到 /tmp 便于排查）──
static void CHCrashHandler(NSException *e) {
    NSString *s = [NSString stringWithFormat:
        @"=== CryptoViewer crash ===\n%@\n\nreason: %@\n\n%@\n",
        [NSDate date], e.reason,
        [e.callStackSymbols componentsJoinedByString:@"\n"]];
    [s writeToFile:@"/tmp/CryptoViewer_crash.log" atomically:YES
          encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"[CryptoViewer] CRASH: %@", e.reason);
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSSetUncaughtExceptionHandler(&CHCrashHandler);
        return UIApplicationMain(argc, argv, nil, @"CHAppDelegate");
    }
}
