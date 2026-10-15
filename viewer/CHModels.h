// CHModels.h — 数据模型
#import <UIKit/UIKit.h>

@interface CHApp : NSObject
@property (nonatomic, copy)   NSString *name;
@property (nonatomic, copy)   NSString *bid;
@property (nonatomic, copy)   NSString *bundlePath;
@property (nonatomic, copy)   NSString *dataPath;
@property (nonatomic, strong) UIImage  *icon;
@property (nonatomic, assign) NSInteger recordCount;
@property (nonatomic, strong) NSDate   *lastActivity;

// 找到日志文件的绝对路径数组
@property (nonatomic, copy, readonly) NSArray<NSString *> *logFiles;
@end

@interface CHRecord : NSObject
@property (nonatomic, assign) NSTimeInterval t;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy)   NSString *layer;   // L1/L2/L3/L4/SYS
@property (nonatomic, copy)   NSString *type;    // CCCrypt / String / HTTP.request …
@property (nonatomic, copy)   NSDictionary *raw;

@property (nonatomic, copy, readonly) NSString *title;     // 卡片主标题
@property (nonatomic, copy, readonly) NSString *subtitle;  // 卡片副标题
@property (nonatomic, copy, readonly) NSString *detail;    // 展开内容
@property (nonatomic, copy, readonly) NSString *algoTag;   // 算法标签（AES-256 / RC4 / HMAC-SHA256 …）
@end
