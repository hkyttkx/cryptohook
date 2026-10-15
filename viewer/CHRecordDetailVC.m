// CHRecordDetailVC.m — 详情：分组 + 排序 + hex/ASCII 双显
#import "CHRecordDetailVC.h"
#import "CHTheme.h"

#pragma mark - 工具：hex -> ASCII
static NSString *hexToASCII(NSString *hex) {
    if (![hex isKindOfClass:[NSString class]] || hex.length < 2) return nil;
    NSMutableString *clean = [NSMutableString string];
    for (NSUInteger i = 0; i < hex.length; i++) {
        unichar c = [hex characterAtIndex:i];
        if ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))
            [clean appendFormat:@"%C", c];
        else if (c == 0x2026) break;   // 遇到省略号停止
    }
    if (clean.length < 2) return nil;
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i + 1 < clean.length; i += 2) {
        unsigned int v = 0;
        [[NSScanner scannerWithString:[clean substringWithRange:NSMakeRange(i, 2)]] scanHexInt:&v];
        unichar ch = (unichar)(v & 0xff);
        [out appendFormat:@"%C", (ch >= 32 && ch < 127) ? ch : (unichar)0x00B7];  // 不可打印 -> ·
    }
    return out;
}

#pragma mark - 字段卡片
@interface CHFieldView : UIView
@property (nonatomic, copy) NSString *fieldName;
@property (nonatomic, copy) NSString *fieldValue;
@property (nonatomic, strong) UILabel *nameL;
@property (nonatomic, strong) UILabel *valueL;
@property (nonatomic, strong) UIButton *dupBtn;
- (instancetype)initWithName:(NSString *)n value:(NSString *)v accent:(BOOL)accent;
@end

@implementation CHFieldView
- (instancetype)initWithName:(NSString *)n value:(NSString *)v accent:(BOOL)accent {
    self = [super init];
    if (self) {
        _fieldName = [n copy];
        _fieldValue = [v copy];
        self.backgroundColor = CH_CARD;
        self.layer.cornerRadius = 10;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
        self.layer.borderColor = CH_LINE.CGColor;

        _nameL = [UILabel new];
        _nameL.numberOfLines = 1;
        _nameL.attributedText = [CHTheme tracked:n
            font:[CHTheme mono:10 weight:UIFontWeightBold]
            color:(accent ? CH_ACCENT : CH_BLUE) spacing:1.2];
        _nameL.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_nameL];

        _dupBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [_dupBtn setImage:[UIImage systemImageNamed:@"doc.on.doc"] forState:UIControlStateNormal];
        _dupBtn.tintColor = CH_SUB;
        _dupBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [_dupBtn addTarget:self action:@selector(copyField) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_dupBtn];

        _valueL = [UILabel new];
        _valueL.numberOfLines = 0;
        _valueL.lineBreakMode = NSLineBreakByCharWrapping;
        _valueL.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_valueL];

        NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
        ps.lineSpacing = 4;
        ps.lineBreakMode = NSLineBreakByCharWrapping;
        _valueL.attributedText = [[NSAttributedString alloc] initWithString:v ?: @""
            attributes:@{NSFontAttributeName:[CHTheme mono:11.5 weight:UIFontWeightRegular],
                         NSForegroundColorAttributeName:CH_TEXT,
                         NSParagraphStyleAttributeName:ps}];

        [NSLayoutConstraint activateConstraints:@[
            [_nameL.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
            [_nameL.topAnchor constraintEqualToAnchor:self.topAnchor constant:10],
            [_nameL.trailingAnchor constraintLessThanOrEqualToAnchor:_dupBtn.leadingAnchor constant:-6],
            [_dupBtn.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
            [_dupBtn.centerYAnchor constraintEqualToAnchor:_nameL.centerYAnchor],
            [_dupBtn.widthAnchor constraintEqualToConstant:26],
            [_dupBtn.heightAnchor constraintEqualToConstant:26],
            [_valueL.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor constant:12],
            [_valueL.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
            [_valueL.topAnchor      constraintEqualToAnchor:_nameL.bottomAnchor constant:8],
            [_valueL.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor constant:-12],
        ]];
        [_valueL setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisVertical];
    }
    return self;
}
- (void)copyField {
    [[UIPasteboard generalPasteboard] setString:self.fieldValue ?: @""];
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    [self.dupBtn setImage:[UIImage systemImageNamed:@"checkmark"] forState:UIControlStateNormal];
    self.dupBtn.tintColor = CH_ACCENT;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.dupBtn setImage:[UIImage systemImageNamed:@"doc.on.doc"] forState:UIControlStateNormal];
        self.dupBtn.tintColor = CH_SUB;
    });
}
@end

#pragma mark - 分区标题
static UIView *makeSectionHeader(NSString *title, UIColor *col) {
    UIView *v = [[UIView alloc] init];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *bar = [UIView new];
    bar.backgroundColor = col;
    bar.layer.cornerRadius = 1.5;
    [CHTheme glow:bar color:col radius:4 opacity:0.8];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:bar];
    UILabel *l = [UILabel new];
    l.attributedText = [CHTheme tracked:title
        font:[CHTheme mono:11 weight:UIFontWeightBold] color:col spacing:1.8];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:l];
    [NSLayoutConstraint activateConstraints:@[
        [bar.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:16],
        [bar.centerYAnchor constraintEqualToAnchor:v.centerYAnchor],
        [bar.widthAnchor constraintEqualToConstant:3],
        [bar.heightAnchor constraintEqualToConstant:14],
        [l.leadingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:8],
        [l.centerYAnchor constraintEqualToAnchor:v.centerYAnchor],
        [l.trailingAnchor constraintLessThanOrEqualToAnchor:v.trailingAnchor constant:-16],
        [v.heightAnchor constraintEqualToConstant:34],
    ]];
    return v;
}

#pragma mark - VC
@interface CHRecordDetailVC ()
@property (nonatomic, strong) UIScrollView *scroll;
@end

@implementation CHRecordDetailVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CH_BG;
    if (@available(iOS 13.0, *)) self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    UIColor *col = [CHTheme colorForLayer:self.record.layer];
    self.navigationItem.titleView = ({
        UILabel *l = [UILabel new];
        l.attributedText = [CHTheme tracked:[CHTheme nameForLayer:self.record.layer]
            font:[CHTheme mono:13 weight:UIFontWeightBold] color:col spacing:1.6];
        l;
    });
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up"]
                style:UIBarButtonItemStylePlain target:self action:@selector(shareAll)];
    self.navigationItem.rightBarButtonItem.tintColor = CH_ACCENT;

    self.scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scroll.alwaysBounceVertical = YES;
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scroll];
    [NSLayoutConstraint activateConstraints:@[
        [self.scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    NSDictionary *r = self.record.raw;
    UIView *prev = nil;
    CGFloat W = [UIScreen mainScreen].bounds.size.width;
    NSMutableArray *stack = [NSMutableArray array];   // 按顺序堆叠的视图

    void (^addRaw)(UIView *) = ^(UIView *v) { if (v) [stack addObject:v]; };
    void (^addField)(NSString *, id, BOOL) = ^(NSString *n, id val, BOOL accent) {
        NSString *s = nil;
        if ([val isKindOfClass:[NSString class]]) s = val;
        else if (val) s = [val description];
        if (s.length == 0) return;
        [stack addObject:[[CHFieldView alloc] initWithName:n value:s accent:accent]];
    };
    void (^addData)(NSString *, NSString *) = ^(NSString *n, NSString *hex) {
        if (![hex isKindOfClass:[NSString class]] || hex.length < 2) return;
        NSString *asc = hexToASCII(hex);
        if (asc.length) {
            [stack addObject:[[CHFieldView alloc] initWithName:[n stringByAppendingString:@" · ASCII"]
                                    value:asc accent:NO]];
            [stack addObject:[[CHFieldView alloc] initWithName:[n stringByAppendingString:@" · HEX"]
                                    value:hex accent:NO]];
        } else {
            [stack addObject:[[CHFieldView alloc] initWithName:n value:hex accent:NO]];
        }
    };

    // ── ① 基础 ──
    addRaw(makeSectionHeader(@"基础", col));
    addField(@"类型", [NSString stringWithFormat:@"%@ · %@", self.record.layer, self.record.type], YES);
    NSString *algo = [self.record algoTag];
    if (algo.length) addField(@"算法", algo, YES);
    // 长度关系判型
    NSNumber *inL = r[@"inLen"], *outL = r[@"outLen"];
    if (inL && outL) {
        NSString *shape = nil;
        NSInteger a = inL.integerValue, b = outL.integerValue;
        if (a > 0 && a == b)            shape = @"in == out → 疑似流密码 (RC4 / CTR / 自研流)";
        else if (a > 0 && b >= ((a + 15) / 16) * 16 && b <= ((a + 15) / 16) * 16)
                                        shape = @"out = 16 对齐 → 疑似分组密码 + PKCS7 (AES-CBC)";
        else if (b == 16 || b == 20 || b == 32 || b == 64)
                                        shape = @"out 固定长度 → 疑似摘要 / HMAC";
        if (shape) addField(@"判型", shape, NO);
    }
    NSDateFormatter *df = [NSDateFormatter new];
    df.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    addField(@"时间", [df stringFromDate:self.record.date], NO);

    // ── ② 密钥材料 ──
    BOOL hasKeyMat = (r[@"key"] || r[@"iv"]);
    if (hasKeyMat) {
        addRaw(makeSectionHeader(@"密钥材料", CH_ACCENT));
        addField(@"KEY", r[@"key"], YES);
        addField(@"IV",  r[@"iv"],  YES);
        addField(@"HMAC KEY", r[@"key"] && r[@"mac"] ? r[@"key"] : nil, YES);
    }

    // ── ③ 数据 ──
    BOOL hasData = (r[@"text"] || r[@"inText"] || r[@"in"] || r[@"out"] || r[@"outText"]);
    if (hasData) {
        addRaw(makeSectionHeader(@"数据", CH_BLUE));
        // 明文优先
        NSString *plain = r[@"text"] ?: r[@"inText"];
        if (plain) addField(@"明文", plain, NO);
        if (r[@"outText"]) addField(@"解密结果", r[@"outText"], NO);
        // hex 数据（带 ASCII 双显）
        addData(@"密文 in",  r[@"in"]);
        addData(@"输出 out", r[@"out"]);
        addData(@"HMAC / MAC", r[@"mac"]);
        addData(@"哈希", r[@"hash"]);
        addData(@"数据", r[@"data"]);
        if (r[@"inLen"])  addField(@"输入长度", [NSString stringWithFormat:@"%@ 字节", r[@"inLen"]], NO);
        if (r[@"outLen"]) addField(@"输出长度", [NSString stringWithFormat:@"%@ 字节", r[@"outLen"]], NO);
    }

    // ── ④ 网络 ──
    if (r[@"url"] || r[@"method"] || r[@"status"] || r[@"reqText"] || r[@"respText"]) {
        addRaw(makeSectionHeader(@"网络", CH_ORANGE));
        addField(@"URL", r[@"url"], NO);
        addField(@"方法", r[@"method"], NO);
        if (r[@"status"]) addField(@"状态码", [NSString stringWithFormat:@"%@", r[@"status"]], NO);
        if (r[@"reqText"]) addField(@"请求体", r[@"reqText"], NO);
        else addData(@"请求体", r[@"req"]);
        if (r[@"respText"]) addField(@"响应体", r[@"respText"], NO);
        else addData(@"响应体", r[@"resp"]);
        if (r[@"error"]) addField(@"错误", r[@"error"], NO);
    }

    // ── ⑤ 调用栈 ──
    NSArray *bt = r[@"bt"];
    if ([bt isKindOfClass:[NSArray class]] && bt.count) {
        addRaw(makeSectionHeader(@"调用栈", CH_PURPLE));
        NSMutableString *s = [NSMutableString string];
        for (NSInteger i = 0; i < (NSInteger)bt.count; i++)
            [s appendFormat:@"%2ld  %@\n", (long)i, bt[i]];
        [stack addObject:[[CHFieldView alloc] initWithName:@"backtrace"
                                value:s accent:NO]];
    } else if (r[@"caller"]) {
        addRaw(makeSectionHeader(@"调用栈", CH_PURPLE));
        addField(@"调用者", r[@"caller"], NO);
    }

    // ── ⑥ 聚合历史 ──
    if (self.record.dups.count) {
        addRaw(makeSectionHeader(@"历史触发", CH_SUB));
        NSMutableString *s = [NSMutableString string];
        NSDateFormatter *tf = [NSDateFormatter new];
        tf.dateFormat = @"HH:mm:ss.SSS";
        [s appendFormat:@"共出现 %ld 次\n\n", (long)self.record.count];
        for (CHRecord *d in self.record.dups) [s appendFormat:@"%@\n", [tf stringFromDate:d.date]];
        [stack addObject:[[CHFieldView alloc] initWithName:@"时间列表" value:s accent:NO]];
    }

    // ── ⑦ 原始记录 ──
    addRaw(makeSectionHeader(@"原始记录", CH_SUB));
    NSData *jd = [NSJSONSerialization dataWithJSONObject:r
                    options:NSJSONWritingPrettyPrinted error:nil];
    NSString *json = [[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding];
    if (json) [stack addObject:[[CHFieldView alloc] initWithName:@"RAW JSON" value:json accent:NO]];

    // ── 布局 ──
    for (UIView *v in stack) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        [self.scroll addSubview:v];
        [NSLayoutConstraint activateConstraints:@[
            [v.leadingAnchor constraintEqualToAnchor:self.scroll.leadingAnchor constant:14],
            [v.widthAnchor constraintEqualToConstant:W - 28],
        ]];
        if (!prev) [v.topAnchor constraintEqualToAnchor:self.scroll.topAnchor constant:10].active = YES;
        else       [v.topAnchor constraintEqualToAnchor:prev.bottomAnchor constant:8].active = YES;
        prev = v;
    }
    if (prev) [prev.bottomAnchor constraintEqualToAnchor:self.scroll.bottomAnchor constant:-40].active = YES;
}

- (void)shareAll {
    NSData *jd = [NSJSONSerialization dataWithJSONObject:self.record.raw
                    options:NSJSONWritingPrettyPrinted error:nil];
    NSString *s = [NSString stringWithFormat:@"[%@][%@] %@\n\n%@",
                   self.record.layer, self.record.type, self.record.title,
                   [[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding]];
    UIActivityViewController *av = [[UIActivityViewController alloc]
        initWithActivityItems:@[s] applicationActivities:nil];
    [self presentViewController:av animated:YES completion:nil];
}

@end
