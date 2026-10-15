// CHServices.h — 枚举 App / 读 Hook 日志
#import <UIKit/UIKit.h>
#import "CHModels.h"

@interface CHScanner : NSObject
/// 手机上所有 App（越狱私有 API），并按"有记录优先"排序
+ (NSArray<CHApp *> *)allApps;
/// 读某 App 的 Hook 记录（时间倒序）
+ (NSArray<CHRecord *> *)recordsForApp:(CHApp *)app limit:(NSInteger)limit;
/// 统计该 App 的总记录数
+ (NSInteger)countForApp:(CHApp *)app;
@end
