// CHFilterVC.m — 过滤规则管理（查看 / 移除黑名单）
#import <UIKit/UIKit.h>
#import "CHTheme.h"

#define FCFG_DIR  @"/var/mobile/Library/CryptoHook"
#define FCFG_PATH [FCFG_DIR stringByAppendingPathComponent:@"config.plist"]

@interface CHFilterVC : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSMutableDictionary *cfg;
@property (nonatomic, strong) NSArray *keys;      // config 里的键
@property (nonatomic, strong) NSArray *titles;    // 分组标题
@end

@implementation CHFilterVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CH_BG;
    if (@available(iOS 13.0, *)) self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.title = @"过滤规则";
    self.navigationController.navigationBar.tintColor = CH_ACCENT;

    self.keys   = @[@"excludeUrls", @"excludeTypes", @"excludeCallers", @"excludeKeywords"];
    self.titles = @[@"按域名过滤", @"按类型过滤", @"按调用点过滤", @"按关键词过滤"];

    self.cfg = [NSMutableDictionary dictionaryWithContentsOfFile:FCFG_PATH] ?: [NSMutableDictionary dictionary];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.backgroundColor = CH_BG;
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.table];
    [NSLayoutConstraint activateConstraints:@[
        [self.table.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (NSArray *)listAtIndex:(NSInteger)s {
    NSArray *a = self.cfg[self.keys[s]];
    return [a isKindOfClass:[NSArray class]] ? a : @[];
}

- (void)save {
    // 同时写共享目录 + 各 App 沙盒（跟设置页一致）
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:FCFG_DIR withIntermediateDirectories:YES attributes:nil error:nil];
    [self.cfg writeToFile:FCFG_PATH atomically:YES];
    // 补一份到每个有记录的 App（简化为只写共享目录，dylib 会多路径查找）
    NSLog(@"[CryptoViewer] 过滤规则已保存: %@", self.cfg);
}

#pragma mark - Table
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return self.keys.count; }

- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    NSInteger n = [self listAtIndex:s].count;
    return [NSString stringWithFormat:@"%@  (%ld)", self.titles[s], (long)n];
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    NSInteger n = [self listAtIndex:s].count;
    return n ? n : 1;   // 空的时候给一行提示
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"f";
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:cid];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
    c.backgroundColor = CH_CARD;
    c.textLabel.font = [CHTheme mono:11.5 weight:UIFontWeightRegular];
    c.textLabel.numberOfLines = 2;
    NSArray *list = [self listAtIndex:ip.section];
    if (list.count == 0) {
        c.textLabel.text = @"（空）—— 在详情页点 ⋯ 可添加";
        c.textLabel.textColor = CH_SUB;
        c.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        c.textLabel.text = list[ip.row];
        c.textLabel.textColor = CH_TEXT;
        c.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    return c;
}

- (BOOL)tableView:(UITableView *)t canEditRowAtIndexPath:(NSIndexPath *)ip {
    return [self listAtIndex:ip.section].count > 0;
}

- (void)tableView:(UITableView *)t
    commitEditingStyle:(UITableViewCellEditingStyle)style
     forRowAtIndexPath:(NSIndexPath *)ip {
    if (style != UITableViewCellEditingStyleDelete) return;
    NSMutableArray *arr = [NSMutableArray arrayWithArray:[self listAtIndex:ip.section]];
    if (ip.row >= (NSInteger)arr.count) return;
    [arr removeObjectAtIndex:ip.row];
    self.cfg[self.keys[ip.section]] = arr;
    [self save];
    [t reloadSections:[NSIndexSet indexSetWithIndex:ip.section]
     withRowAnimation:UITableViewRowAnimationAutomatic];
    NSLog(@"[CryptoViewer] 移除过滤项，该内容之后会重新被 hook 到");
}

- (NSString *)tableView:(UITableView *)t titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)ip {
    return @"移除";
}

@end
