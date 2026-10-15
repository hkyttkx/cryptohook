// CHServices.h — 枚举 App / 读 Hook 日志 / 图标
#import <UIKit/UIKit.h>
#import "CHModels.h"

@interface CHScanner : NSObject
+ (NSArray<CHApp *> *)allApps;
+ (NSArray<CHRecord *> *)recordsForApp:(CHApp *)app limit:(NSInteger)limit;
/// 聚合版：同内容合并（带 count / 时间范围 / dups）
+ (NSArray<CHRecord *> *)recordsForApp:(CHApp *)app limit:(NSInteger)limit aggregate:(BOOL)agg;
+ (NSInteger)countForApp:(CHApp *)app;

/// 删除单条（回写日志文件）
+ (BOOL)deleteRecord:(CHRecord *)rec;
/// 删除一组（含聚合的 dups）
+ (NSInteger)deleteRecords:(NSArray<CHRecord *> *)recs;
/// 清空某个 App 的全部日志文件
+ (NSInteger)clearApp:(CHApp *)app;

/// App 图标：先读 bundle 里的图标文件，再退到私有 API
+ (UIImage *)iconForBundlePath:(NSString *)bundlePath bid:(NSString *)bid;
@end
