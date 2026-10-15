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
            UINavigationBarAppearance *ap = [UINavigationBarAppearance new];
            [ap configureWithTransparentBackground];
            ap.titleTextAttributes = @{NSFontAttributeName: [CHTheme mono:15 weight:UIFontWeightBold],
                                       NSForegroundColorAttributeName: CH_ACCENT};
            nav.navigationBar.standardAppearance = ap;
            nav.navigationBar.scrollEdgeAppearance = ap;
            nav.navigationBar.compactAppearance = ap;
        }
        nav.navigationBar.tintColor = CH_ACCENT;

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

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"CHAppDelegate");
    }
}
