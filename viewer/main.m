// main.m — CryptoViewer 入口 + AppDelegate
#import <UIKit/UIKit.h>
#import "CHRootVC.h"
#import "CHTheme.h"

@interface CHAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CHAppDelegate

- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    CHRootVC *root = [CHRootVC new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];

    // 大标题 + 透明导航栏（现代观感）
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *ap = [UINavigationBarAppearance new];
        [ap configureWithTransparentBackground];
        ap.titleTextAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]};
        ap.largeTitleTextAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:34 weight:UIFontWeightBold]};
        nav.navigationBar.standardAppearance = ap;
        nav.navigationBar.scrollEdgeAppearance = ap;
        nav.navigationBar.compactAppearance = ap;
    }
    nav.navigationBar.prefersLargeTitles = YES;

    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"CHAppDelegate");
    }
}
