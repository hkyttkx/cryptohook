// CHRecordDetailVC.h — 单条记录全屏详情（大内容/复制/分享）
#import <UIKit/UIKit.h>
#import "CHModels.h"
@class CHApp;

@interface CHRecordDetailVC : UIViewController
@property (nonatomic, strong) CHRecord *record;
@property (nonatomic, strong) CHApp *app;   // ★ 用于定位目标 App 沙盒
@end
