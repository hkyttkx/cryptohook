// CHSettingsVC.m — 设置（保守写法：不用 superview、不用 statement expression）
#import "CHSettingsVC.h"
#import "CHTheme.h"
#import "CHServices.h"
#import "CHModels.h"

#define CFG_DIR  @"/var/mobile/Library/CryptoHook"
#define CFG_PATH [CFG_DIR stringByAppendingPathComponent:@"config.plist"]

// 行索引常量 —— 直接在 switchChanged 里按 tag 判断，不查表
enum { ROW_L1 = 0, ROW_L2 = 1, ROW_L3 = 2, ROW_L4 = 3 };

static NSString *const kTitles[] = {
    @"系统加密 API", @"明文字符串", @"网络收发", @"自研算法", NULL
};
static NSString *const kDescs[] = {
    @"CCCrypt / CCHmac / CC_SHA / SecKey",
    @"捕获解密后的明文 + 调用来源",
    @"请求体 / 响应体 / URL",
    @"按调用栈反推的自研函数",
    NULL
};
static NSString *const kKeys[] = { @"L1", @"L2", @"L3", @"L4", NULL };

@interface CHSettingsVC () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSMutableDictionary *cfg;
@end

@implementation CHSettingsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CH_BG;
    if (@available(iOS 13.0, *)) self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.title = @"设置";
    self.navigationController.navigationBar.tintColor = CH_ACCENT;

    // 读配置
    NSMutableDictionary *c = [NSMutableDictionary dictionary];
    NSDictionary *disk = nil;
    @try { disk = [NSDictionary dictionaryWithContentsOfFile:CFG_PATH]; } @catch (NSException *e) {}
    for (int i = 0; kKeys[i]; i++) {
        BOOL on = YES;
        if (disk && [disk objectForKey:kKeys[i]]) on = [disk[kKeys[i]] boolValue];
        c[kKeys[i]] = @(on);
    }
    c[@"rate"] = disk[@"rate"] ?: @200;
    self.cfg = c;

    // ── 个人卡片（圆形头像 + 介绍）──
    CGFloat W = [UIScreen mainScreen].bounds.size.width;
    UIView *head = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 170)];
    head.backgroundColor = [UIColor clearColor];

    CGFloat S = 76;
    UIView *avatarWrap = [[UIView alloc] initWithFrame:CGRectMake((W - S) / 2, 14, S, S)];
    [CHTheme glow:avatarWrap color:CH_ACCENT radius:12 opacity:0.40];

    UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, S, S)];
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.clipsToBounds = YES;
    avatar.layer.cornerRadius = S / 2.0;
    avatar.layer.cornerCurve = kCACornerCurveCircular;
    avatar.layer.borderWidth = 1.5;
    avatar.layer.borderColor = [CH_ACCENT colorWithAlphaComponent:0.55].CGColor;
    UIImage *img = [UIImage imageNamed:@"splash"];
    if (!img) {
        NSString *p = [[NSBundle mainBundle] pathForResource:@"splash" ofType:@"jpg"];
        if (p) img = [UIImage imageWithContentsOfFile:p];
    }
    avatar.image = img;
    [avatarWrap addSubview:avatar];
    [head addSubview:avatarWrap];

    UILabel *slogan = [[UILabel alloc] initWithFrame:CGRectMake(20, S + 22, W - 40, 24)];
    slogan.textAlignment = NSTextAlignmentCenter;
    slogan.attributedText = [CHTheme tracked:@"Az 大哥 bcpx 牛逼"
        font:[CHTheme mono:15 weight:UIFontWeightBold] color:CH_ACCENT spacing:1.6];
    [head addSubview:slogan];

    UILabel *by = [[UILabel alloc] initWithFrame:CGRectMake(20, S + 48, W - 40, 18)];
    by.textAlignment = NSTextAlignmentCenter;
    by.attributedText = [CHTheme tracked:@"AzbcpxTuT v1.0 · 通用加解密透视工具"
        font:[CHTheme mono:9.5 weight:UIFontWeightMedium] color:CH_SUB spacing:1.2];
    [head addSubview:by];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.backgroundColor = CH_BG;
    self.table.rowHeight = 62;
    self.table.separatorColor = CH_LINE;
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.table];
    self.table.tableHeaderView = head;
    self.table.contentInset = UIEdgeInsetsMake(0, 0, 40, 0);
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
    @try {
        NSFileManager *fm = [NSFileManager defaultManager];
        // ① 共享目录（有权限的 App 能读到）
        [fm createDirectoryAtPath:CFG_DIR withIntermediateDirectories:YES attributes:nil error:nil];
        [self.cfg writeToFile:CFG_PATH atomically:YES];

        // ② ★ 关键：写到每个已注入 App 的沙盒 —— dylib 真正能读的地方
        NSArray *apps = [CHScanner allApps];
        NSInteger n = 0;
        for (CHApp *a in apps) {
            if (a.dataPath.length == 0) continue;
            if (a.recordCount == 0) continue;          // 只给"注入过"的 App 写（有记录=注入过）
            NSString *d = [a.dataPath stringByAppendingPathComponent:@"Documents/CryptoHook"];
            if (![fm createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:nil]) continue;
            if ([self.cfg writeToFile:[d stringByAppendingPathComponent:@"config.plist"] atomically:YES]) n++;
            // 顺带缓存目录也放一份（有些 App 只允许写 Caches）
            NSString *d2 = [a.dataPath stringByAppendingPathComponent:@"Library/Caches/CryptoHook"];
            if ([fm createDirectoryAtPath:d2 withIntermediateDirectories:YES attributes:nil error:nil])
                [self.cfg writeToFile:[d2 stringByAppendingPathComponent:@"config.plist"] atomically:YES];
        }
        NSLog(@"[CryptoHook] cfg saved -> %@ (并写入 %ld 个 App 沙盒)", CFG_PATH, (long)n);
    } @catch (NSException *e) {
        NSLog(@"[CryptoHook] saveCfg 失败: %@", e);
    }
}

// ★ 最保守：只按 tag 判断，不访问任何视图层级
- (void)switchChanged:(UISwitch *)sw {
    @try {
        NSInteger r = sw.tag;
        if (r < 0 || r > 3) return;
        self.cfg[kKeys[r]] = @(sw.on);
        [self saveCfg];
    } @catch (NSException *e) {
        NSLog(@"[CryptoHook] switchChanged 异常: %@", e);
    }
}

#pragma mark - Table
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 3; }

- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    if (s == 0) return @"HOOK 功能";
    if (s == 1) return @"数据";
    return @"关于";
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    if (s == 0) return 4;
    if (s == 1) return 3;   // 导出 dylib / 清空日志 / 配置路径
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"s";
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:cid];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
    c.backgroundColor = CH_CARD;
    c.textLabel.textColor = CH_TEXT;
    c.detailTextLabel.textColor = CH_SUB;
    c.textLabel.font = [CHTheme mono:13 weight:UIFontWeightSemibold];
    c.detailTextLabel.font = [CHTheme mono:10 weight:UIFontWeightRegular];
    c.accessoryView = nil;
    c.accessoryType = UITableViewCellAccessoryNone;
    c.selectionStyle = UITableViewCellSelectionStyleDefault;

    if (ip.section == 0) {
        c.textLabel.text = kTitles[ip.row];
        c.detailTextLabel.text = kDescs[ip.row];
        UISwitch *sw = [UISwitch new];
        sw.onTintColor = CH_ACCENT;
        sw.tag = ip.row;
        NSNumber *v = self.cfg[kKeys[ip.row]];
        sw.on = v ? v.boolValue : YES;
        [sw removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView = sw;
        c.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (ip.section == 1) {
        if (ip.row == 0) {
            c.textLabel.text = @"导出 CryptoHook.dylib";
            c.detailTextLabel.text = @"复制到 Documents 并分享（用于注入目标 App）";
            c.textLabel.textColor = CH_ACCENT;
        } else if (ip.row == 1) {
            c.textLabel.text = @"清空所有日志";
            c.detailTextLabel.text = @"删除已收集的全部记录";
        } else {
            c.textLabel.text = @"配置路径";
            c.detailTextLabel.text = CFG_PATH;
        }
    } else {
        c.textLabel.text = @"AzbcpxTuT";
        c.detailTextLabel.text = @"v1.0 · dyld interpose + ObjC hook";
        c.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return c;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != 1) return;
    if (ip.row == 0) { [self exportDylib]; return; }
    if (ip.row == 1) {
        UIAlertController *al = [UIAlertController alertControllerWithTitle:@"清空日志"
            message:@"删除所有 App 已收集的记录？不可恢复。"
            preferredStyle:UIAlertControllerStyleAlert];
        [al addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [al addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive
            handler:^(UIAlertAction *a){ [self clearAll]; }]];
        [self presentViewController:al animated:YES completion:nil];
    }
}

#pragma mark - 导出 dylib（直接分享，不落地保存）
- (void)exportDylib {
    @try {
        NSString *src = [[NSBundle mainBundle] pathForResource:@"CryptoHook" ofType:@"dylib"];
        if (!src)
            src = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"CryptoHook.dylib"];
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:src]) {
            [self toast:@"包里找不到 CryptoHook.dylib"];
            return;
        }

        // 只放临时目录（系统会自动清理），不做"保存"
        NSString *tmpDir = NSTemporaryDirectory();
        NSString *dst = [tmpDir stringByAppendingPathComponent:@"CryptoHook.dylib"];
        [fm removeItemAtPath:dst error:nil];
        NSError *err = nil;
        if (![fm copyItemAtPath:src toPath:dst error:&err]) {
            [self toast:[NSString stringWithFormat:@"准备失败: %@", err.localizedDescription]];
            return;
        }

        // ★ 直接弹分享（跟系统分享一样）
        NSMutableArray *items = [NSMutableArray arrayWithObject:[NSURL fileURLWithPath:dst]];
        // 附一份当前配置，便于别人拿到同样的默认开关
        NSString *cfgTmp = [tmpDir stringByAppendingPathComponent:@"CryptoHook-config.plist"];
        if ([self.cfg writeToFile:cfgTmp atomically:YES])
            [items addObject:[NSURL fileURLWithPath:cfgTmp]];

        UIActivityViewController *av = [[UIActivityViewController alloc]
            initWithActivityItems:items applicationActivities:nil];
        if (av.popoverPresentationController) {
            av.popoverPresentationController.sourceView = self.view;
            av.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2,
                                                                     self.view.bounds.size.height/2, 1, 1);
        }
        [self presentViewController:av animated:YES completion:nil];
    } @catch (NSException *e) {
        [self toast:[NSString stringWithFormat:@"异常: %@", e.reason]];
    }
}

- (void)toast:(NSString *)msg {
    UIAlertController *al = [UIAlertController alertControllerWithTitle:@"导出"
        message:msg preferredStyle:UIAlertControllerStyleAlert];
    [al addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:al animated:YES completion:nil];
}

- (void)clearAll {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSInteger n = 0;
    for (NSString *d in @[@"/var/mobile/Library/CryptoHook", @"/tmp/CryptoHook"]) {
        NSDirectoryEnumerator *e = [fm enumeratorAtPath:d];
        for (NSString *f in e) {
            if ([f hasSuffix:@".log"]) {
                [fm removeItemAtPath:[d stringByAppendingPathComponent:f] error:nil];
                n++;
            }
        }
    }
    NSString *home = NSHomeDirectory();
    if (home) {
        NSString *d = [home stringByAppendingPathComponent:@"Documents/CryptoHook"];
        for (NSString *f in [fm contentsOfDirectoryAtPath:d error:nil])
            if ([f hasSuffix:@".log"]) {
                [fm removeItemAtPath:[d stringByAppendingPathComponent:f] error:nil]; n++;
            }
    }
    UIAlertController *al = [UIAlertController alertControllerWithTitle:@"已清空"
        message:[NSString stringWithFormat:@"删除 %ld 个日志文件", (long)n]
        preferredStyle:UIAlertControllerStyleAlert];
    [al addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:al animated:YES completion:nil];
}

@end
