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

// ── 聚合（去重）──
@property (nonatomic, assign) NSInteger count;       // 出现次数（默认 1）
@property (nonatomic, assign) NSTimeInterval firstT; // 首次时间
@property (nonatomic, assign) NSTimeInterval lastT;  // 最近时间
@property (nonatomic, strong) NSMutableArray<CHRecord *> *dups;  // 同内容的其它实例

// ── 来源（用于删除回写文件）──
@property (nonatomic, copy)   NSString *srcFile;     // 日志文件绝对路径
@property (nonatomic, assign) NSInteger lineIdx;     // 在文件中的行号（0 基）

/// 去重键（方案 C：按 type + 关键字段）
@property (nonatomic, copy, readonly) NSString *dedupKey;

@property (nonatomic, copy, readonly) NSString *title;     // 卡片主标题
@property (nonatomic, copy, readonly) NSString *subtitle;  // 卡片副标题
@property (nonatomic, copy, readonly) NSString *detail;    // 展开内容
@property (nonatomic, copy, readonly) NSString *algoTag;   // 算法标签（AES-256 / RC4 / HMAC-SHA256 …）
@property (nonatomic, copy, readonly) NSString *opTag;     // 操作（ENC / DEC / REQ / RESP / HASH）
@end
