// CHServices.h — 枚举 App / 读 Hook 日志 / 图标
#import <UIKit/UIKit.h>
#import "CHModels.h"

@interface CHScanner : NSObject
+ (NSArray<CHApp *> *)allApps;
+ (NSArray<CHRecord *> *)recordsForApp:(CHApp *)app limit:(NSInteger)limit;
+ (NSInteger)countForApp:(CHApp *)app;

/// App 图标：先读 bundle 里的图标文件，再退到私有 API
+ (UIImage *)iconForBundlePath:(NSString *)bundlePath bid:(NSString *)bid;
@end
