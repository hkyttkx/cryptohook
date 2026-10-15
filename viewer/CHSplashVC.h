// CHSplashVC.h — 启动动画
#import <UIKit/UIKit.h>

@interface CHSplashVC : UIViewController
/// 动画结束后回调（主界面在这里切换）
@property (nonatomic, copy) void (^onFinish)(void);
@end
