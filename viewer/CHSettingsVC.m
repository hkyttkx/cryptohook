// CHSettingsVC.m — 设置（Hook 开关 / 采样率 / 数据清理）
#import "CHSettingsVC.h"
#import "CHTheme.h"

#define CFG_DIR  @"/var/mobile/Library/CryptoHook"
#define CFG_PATH [CFG_DIR stringByAppendingPathComponent:@"config.plist"]

@interface CHSetCell : UITableViewCell
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIView *bar;
@property (nonatomic, strong) UILabel *titleL;
@property (nonatomic, strong) UILabel *descL;
@property (nonatomic, strong) UISwitch *sw;
@property (nonatomic, copy) NSString *key;
@end

@implementation CHSetCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    self = [super initWithStyle:style reuseIdentifier:rid];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _card = [UIView new];
        [CHTheme strokeCard:_card];
        _card.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_card];

        _bar = [UIView new];
        _bar.layer.cornerRadius = 1;
        _bar.backgroundColor = CH_ACCENT;
        [CHTheme glow:_bar color:CH_ACCENT radius:4 opacity:0.85];
        _bar.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_bar];

        _titleL = [UILabel new];
        _titleL.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_titleL];

        _descL = [UILabel new];
        _descL.numberOfLines = 2;
        _descL.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_descL];

        _sw = [UISwitch new];
        _sw.onTintColor = CH_ACCENT;
        _sw.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_sw];

        [NSLayoutConstraint activateConstraints:@[
            [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:14],
            [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14],
            [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4],
            [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4],

            [_bar.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor],
            [_bar.topAnchor constraintEqualToAnchor:_card.topAnchor constant:10],
            [_bar.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-10],
            [_bar.widthAnchor constraintEqualToConstant:2],

            [_titleL.leadingAnchor constraintEqualToAnchor:_bar.trailingAnchor constant:12],
            [_titleL.topAnchor constraintEqualToAnchor:_card.topAnchor constant:11],
            [_titleL.trailingAnchor constraintLessThanOrEqualToAnchor:_sw.leadingAnchor constant:-10],

            [_descL.leadingAnchor constraintEqualToAnchor:_titleL.leadingAnchor],
            [_descL.trailingAnchor constraintLessThanOrEqualToAnchor:_sw.leadingAnchor constant:-10],
            [_descL.topAnchor constraintEqualToAnchor:_titleL.bottomAnchor constant:3],
            [_descL.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-11],

            [_sw.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
            [_sw.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
        ]];
    }
    return self;
}
- (void)configTitle:(NSString *)t desc:(NSString *)d on:(BOOL)on key:(NSString *)k {
    self.key = k;
    self.titleL.attributedText = [CHTheme tracked:t
        font:[CHTheme mono:13 weight:UIFontWeightSemibold] color:CH_TEXT spacing:0.4];
    self.descL.attributedText = [CHTheme tracked:d
        font:[CHTheme mono:10 weight:UIFontWeightRegular] color:CH_SUB spacing:0.2];
    self.sw.on = on;
}
@end

@interface CHSettingsVC () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSMutableDictionary *cfg;
@property (nonatomic, strong) NSArray *sections;
@end

@implementation CHSettingsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CH_BG;
    if (@available(iOS 13.0, *)) self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.title = @"设置";
    self.navigationController.navigationBar.tintColor = CH_ACCENT;

    // 读配置（没有就默认全开）
    NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:CFG_PATH];
    self.cfg = [NSMutableDictionary dictionaryWithDictionary:@{
        @"L1": @(disk[@"L1"] ? [disk[@"L1"] boolValue] : YES),
        @"L2": @(disk[@"L2"] ? [disk[@"L2"] boolValue] : YES),
        @"L3": @(disk[@"L3"] ? [disk[@"L3"] boolValue] : YES),
        @"L4": @(disk[@"L4"] ? [disk[@"L4"] boolValue] : YES),
        @"rate": disk[@"rate"] ?: @200,
    }];

    self.sections = @[
        @{@"title": @"HOOK 功能", @"rows": @[
            @{@"k": @"L1", @"t": @"系统加密 API", @"d": @"CCCrypt / CCHmac / CC_SHA / SecKey"},
            @{@"k": @"L2", @"t": @"明文字符串", @"d": @"捕获解密后的明文 + 调用来源"},
            @{@"k": @"L3", @"t": @"网络收发", @"d": @"请求体 / 响应体 / URL"},
            @{@"k": @"L4", @"t": @"自研算法", @"d": @"按调用栈反推的自研函数"},
        ]},
        @{@"title": @"数据", @"rows": @[
            @{@"k": @"_clear", @"t": @"清空所有日志", @"d": @"删除已收集的全部记录"},
            @{@"k": @"_path",  @"t": @"配置路径", @"d": CFG_PATH},
        ]},
        @{@"title": @"关于", @"rows": @[
            @{@"k": @"_ver",  @"t": @"CryptoHook", @"d": @"v1.0 · dyld interpose + ObjC hook"},
        ]},
    ];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.backgroundColor = [UIColor clearColor];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.rowHeight = UITableViewAutomaticDimension;
    self.table.estimatedRowHeight = 70;
    self.table.contentInset = UIEdgeInsetsMake(8, 0, 40, 0);
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.table];
    [NSLayoutConstraint activateConstraints:@[
        [self.table.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self saveCfg];
}

- (void)saveCfg {
    [[NSFileManager defaultManager] createDirectoryAtPath:CFG_DIR
        withIntermediateDirectories:YES attributes:nil error:nil];
    [self.cfg writeToFile:CFG_PATH atomically:YES];
    NSLog(@"[CryptoHook] cfg saved -> %@", CFG_PATH);
}

- (void)switchChanged:(UISwitch *)sw {
    // ★ 用 tag 反查行列（原来用 superview.superview 会拿到 contentView 导致崩溃）
    NSInteger sec = sw.tag / 100;
    NSInteger row = sw.tag % 100;
    if (sec < 0 || sec >= (NSInteger)self.sections.count) return;
    NSArray *rows = self.sections[sec][@"rows"];
    if (row < 0 || row >= (NSInteger)rows.count) return;
    NSString *k = rows[row][@"k"];
    if (k.length == 0) return;
    self.cfg[k] = @(sw.on);
    [self saveCfg];
}

#pragma mark - Table
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return self.sections.count; }

- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)s {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, t.bounds.size.width, 32)];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(22, 12, t.bounds.size.width - 40, 18)];
    l.attributedText = [CHTheme tracked:self.sections[s][@"title"]
        font:[CHTheme mono:11 weight:UIFontWeightSemibold] color:CH_ACCENT spacing:1.4];
    [v addSubview:l];
    return v;
}
- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s { return 32; }

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    return [self.sections[s][@"rows"] count];
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"set";
    CHSetCell *c = [t dequeueReusableCellWithIdentifier:cid];
    if (!c) c = [[CHSetCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
    NSDictionary *row = self.sections[ip.section][@"rows"][ip.row];
    NSString *k = row[@"k"];
    BOOL isSwitch = [@[@"L1", @"L2", @"L3", @"L4"] containsObject:k];
    [c configTitle:row[@"t"] desc:row[@"d"] on:[self.cfg[k] boolValue] key:k];
    c.sw.hidden = !isSwitch;
    if (isSwitch) {
        c.sw.tag = ip.section * 100 + ip.row;
        [c.sw removeTarget:self action:NULL forControlEvents:UIControlEventValueChanged];
        [c.sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    }
    c.bar.backgroundColor = isSwitch ? CH_ACCENT : CH_SUB;
    if (isSwitch) [CHTheme glow:c.bar color:CH_ACCENT radius:4 opacity:0.85];
    else c.bar.layer.shadowOpacity = 0;
    return c;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *row = self.sections[ip.section][@"rows"][ip.row];
    NSString *k = row[@"k"];
    if ([k isEqualToString:@"_clear"]) {
        UIAlertController *al = [UIAlertController alertControllerWithTitle:@"清空日志"
            message:@"删除所有 App 已收集的记录？不可恢复。" preferredStyle:UIAlertControllerStyleAlert];
        [al addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [al addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive
            handler:^(UIAlertAction *a){ [self clearAll]; }]];
        [self presentViewController:al animated:YES completion:nil];
    }
}

- (void)clearAll {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *dirs = @[@"/var/mobile/Library/CryptoHook", @"/tmp/CryptoHook"];
    NSInteger n = 0;
    for (NSString *d in dirs) {
        NSDirectoryEnumerator *e = [fm enumeratorAtPath:d];
        for (NSString *f in e) {
            if ([f hasSuffix:@".log"]) {
                [fm removeItemAtPath:[d stringByAppendingPathComponent:f] error:nil];
                n++;
            }
        }
    }
    // 沙盒里的
    NSString *home = NSHomeDirectory();
    if (home) {
        NSString *d = [home stringByAppendingPathComponent:@"Documents/CryptoHook"];
        for (NSString *f in [fm contentsOfDirectoryAtPath:d error:nil])
            if ([f hasSuffix:@".log"]) { [fm removeItemAtPath:[d stringByAppendingPathComponent:f] error:nil]; n++; }
    }
    UIAlertController *al = [UIAlertController alertControllerWithTitle:@"已清空"
        message:[NSString stringWithFormat:@"删除 %ld 个日志文件", (long)n]
        preferredStyle:UIAlertControllerStyleAlert];
    [al addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:al animated:YES completion:nil];
}

@end
