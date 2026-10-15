// CHRecordDetailVC.m — 详情：分组 + 排序 + hex/ASCII 双显
#import "CHRecordDetailVC.h"
#import "CHTheme.h"
#include <CommonCrypto/CommonCrypto.h>

#pragma mark - 工具：hex -> ASCII
// ── 编码转换工具 ──
static NSData *hexToData(NSString *hex) {
    if (![hex isKindOfClass:[NSString class]] || hex.length < 2) return nil;
    NSMutableString *clean = [NSMutableString string];
    for (NSUInteger i = 0; i < hex.length; i++) {
        unichar c = [hex characterAtIndex:i];
        if ((c>='0'&&c<='9')||(c>='a'&&c<='f')||(c>='A'&&c<='F')) [clean appendFormat:@"%C", c];
        else if (c == 0x2026) break;
    }
    if (clean.length < 2) return nil;
    NSMutableData *d = [NSMutableData dataWithCapacity:clean.length/2];
    for (NSUInteger i = 0; i + 1 < clean.length; i += 2) {
        unsigned int v = 0;
        [[NSScanner scannerWithString:[clean substringWithRange:NSMakeRange(i, 2)]] scanHexInt:&v];
        uint8_t b = (uint8_t)(v & 0xff);
        [d appendBytes:&b length:1];
    }
    return d;
}
static NSString *hexToBase64(NSString *hex) {
    NSData *d = hexToData(hex);
    return d.length ? [d base64EncodedStringWithOptions:0] : nil;
}
static NSString *hexToASCII(NSString *hex) {
    NSData *d = hexToData(hex);
    if (!d.length) return nil;
    NSMutableString *o = [NSMutableString string];
    const uint8_t *b = d.bytes;
    for (NSUInteger i = 0; i < d.length; i++)
        [o appendFormat:@"%C", (b[i]>=32 && b[i]<127) ? (unichar)b[i] : (unichar)0x00B7];
    return o;
}
static NSString *textToHex(NSString *s) {
    if (![s isKindOfClass:[NSString class]] || s.length == 0) return nil;
    NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding];
    if (!d.length) return nil;
    NSMutableString *o = [NSMutableString stringWithCapacity:d.length*2];
    const uint8_t *b = d.bytes;
    for (NSUInteger i = 0; i < d.length; i++) [o appendFormat:@"%02x", b[i]];
    return o;
}

#pragma mark - 字段卡片
@interface CHFieldView : UIView
@property (nonatomic, copy) NSString *fieldName;
@property (nonatomic, copy) NSString *fieldValue;
@property (nonatomic, strong) UILabel *nameL;
@property (nonatomic, strong) UILabel *valueL;
@property (nonatomic, strong) UITextView *valueTV;   // 长文本用（可滚动）
@property (nonatomic, strong) UIButton *dupBtn;
- (instancetype)initWithName:(NSString *)n value:(NSString *)v color:(UIColor *)color;
@end

@implementation CHFieldView
- (instancetype)initWithName:(NSString *)n value:(NSString *)v color:(UIColor *)color {
    self = [super init];
    if (self) {
        if (!color) color = CH_TEXT2;
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
            color:color spacing:1.2];
        _nameL.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_nameL];

        _dupBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [_dupBtn setImage:[UIImage systemImageNamed:@"doc.on.doc"] forState:UIControlStateNormal];
        _dupBtn.tintColor = CH_SUB;
        _dupBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [_dupBtn addTarget:self action:@selector(copyField) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_dupBtn];

        BOOL isLong = (v.length > 400);   // 长文本 -> 可滚动，避免撑爆布局

        NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
        ps.lineSpacing = 3;
        ps.lineBreakMode = NSLineBreakByCharWrapping;

        if (!isLong) {
            _valueL = [UILabel new];
            _valueL.numberOfLines = 0;
            _valueL.lineBreakMode = NSLineBreakByCharWrapping;
            _valueL.translatesAutoresizingMaskIntoConstraints = NO;
            [self addSubview:_valueL];
            _valueL.attributedText = [[NSAttributedString alloc] initWithString:v ?: @""
                attributes:@{NSFontAttributeName:[CHTheme mono:10 weight:UIFontWeightRegular],
                             NSForegroundColorAttributeName:CH_TEXT,
                             NSParagraphStyleAttributeName:ps}];
        } else {
            _valueTV = [UITextView new];
            _valueTV.editable = NO;
            _valueTV.scrollEnabled = YES;
            _valueTV.backgroundColor = [UIColor clearColor];
            _valueTV.textContainerInset = UIEdgeInsetsZero;
            _valueTV.textContainer.lineFragmentPadding = 0;
            _valueTV.translatesAutoresizingMaskIntoConstraints = NO;
            [self addSubview:_valueTV];
            _valueTV.attributedText = [[NSAttributedString alloc] initWithString:v ?: @""
                attributes:@{NSFontAttributeName:[CHTheme mono:10 weight:UIFontWeightRegular],
                             NSForegroundColorAttributeName:CH_TEXT,
                             NSParagraphStyleAttributeName:ps}];
            [_valueTV.heightAnchor constraintEqualToConstant:150].active = YES;
        }

        [NSLayoutConstraint activateConstraints:@[
            [_nameL.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
            [_nameL.topAnchor constraintEqualToAnchor:self.topAnchor constant:10],
            [_nameL.trailingAnchor constraintLessThanOrEqualToAnchor:_dupBtn.leadingAnchor constant:-6],
            [_dupBtn.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
            [_dupBtn.centerYAnchor constraintEqualToAnchor:_nameL.centerYAnchor],
            [_dupBtn.widthAnchor constraintEqualToConstant:26],
            [_dupBtn.heightAnchor constraintEqualToConstant:26],
        ]];
        UIView *body = _valueTV ?: _valueL;
        [NSLayoutConstraint activateConstraints:@[
            [body.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor constant:12],
            [body.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
            [body.topAnchor      constraintEqualToAnchor:_nameL.bottomAnchor constant:7],
            [body.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor constant:-11],
        ]];
        if (_valueL) [_valueL setContentCompressionResistancePriority:UILayoutPriorityRequired
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
    UIBarButtonItem *more = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"]
                style:UIBarButtonItemStylePlain target:self action:@selector(showActions)];
    more.tintColor = CH_ACCENT;
    self.navigationItem.rightBarButtonItem = more;

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
    void (^addField)(NSString *, id, UIColor *) = ^(NSString *n, id val, UIColor *color) {
        NSString *s = nil;
        if ([val isKindOfClass:[NSString class]]) s = val;
        else if (val) s = [val description];
        if (s.length == 0) return;
        [stack addObject:[[CHFieldView alloc] initWithName:n value:s color:color]];
    };
    // ★ 数据三编码：HEX / Base64 / 文本
    void (^addData)(NSString *, NSString *, UIColor *) = ^(NSString *n, NSString *hex, UIColor *color) {
        if (![hex isKindOfClass:[NSString class]] || hex.length < 2) return;
        [stack addObject:[[CHFieldView alloc] initWithName:[n stringByAppendingString:@" · HEX"]
                                value:hex color:color]];
        NSString *b64 = hexToBase64(hex);
        if (b64.length) [stack addObject:[[CHFieldView alloc]
                                initWithName:[n stringByAppendingString:@" · Base64"]
                                value:b64 color:color]];
        NSString *asc = hexToASCII(hex);
        if (asc.length) [stack addObject:[[CHFieldView alloc]
                                initWithName:[n stringByAppendingString:@" · 文本"]
                                value:asc color:color]];
    };
    // 文本类字段：文本 / HEX / Base64
    void (^addText)(NSString *, NSString *, UIColor *) = ^(NSString *n, NSString *v, UIColor *color) {
        if (![v isKindOfClass:[NSString class]] || v.length == 0) return;
        [stack addObject:[[CHFieldView alloc] initWithName:[n stringByAppendingString:@" · 文本"]
                                value:v color:color]];
        NSString *h = textToHex(v);
        if (h.length) [stack addObject:[[CHFieldView alloc] initWithName:[n stringByAppendingString:@" · HEX"]
                                value:h color:color]];
        NSData *d = [v dataUsingEncoding:NSUTF8StringEncoding];
        if (d.length) [stack addObject:[[CHFieldView alloc] initWithName:[n stringByAppendingString:@" · Base64"]
                                value:[d base64EncodedStringWithOptions:0] color:color]];
    };

    // ── ① 基础 ──
    addRaw(makeSectionHeader(@"基础", col));
    addField(@"类型", [NSString stringWithFormat:@"%@ · %@", self.record.layer, self.record.type], CH_TEXT2);
    NSString *op = [self.record opTag];
    if (op.length) addField(@"操作", op, CH_ORANGE);
    NSString *algo = [self.record algoTag];
    if (algo.length) addField(@"算法", algo, CH_ACCENT);
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
        if (shape) addField(@"判断结果", shape, CH_PURPLE);
    }
    NSDateFormatter *df = [NSDateFormatter new];
    df.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    addField(@"时间", [df stringFromDate:self.record.date], CH_SUB);

    // ── ② 密钥 KEY（独立分组）──
    if (r[@"key"] && [r[@"key"] length] > 0) {
        addRaw(makeSectionHeader(@"密钥 KEY", CH_ACCENT));
        addData(@"KEY", r[@"key"], CH_ACCENT);
    }

    // ── ③ 初始向量 IV（独立分组）──
    if (r[@"iv"] && [r[@"iv"] length] > 0) {
        addRaw(makeSectionHeader(@"初始向量 IV", CH_BLUE));
        addData(@"IV", r[@"iv"], CH_BLUE);
    }

    // ── ③ 原始数据（输入）──
    BOOL hasIn = (r[@"text"] || r[@"inText"] || r[@"in"] || r[@"reqText"] || r[@"req"] ||
                  r[@"data"] || r[@"hash"]);
    if (hasIn) {
        addRaw(makeSectionHeader(@"原始数据（输入 in）", CH_BLUE));
        NSString *plain = r[@"text"] ?: r[@"inText"];
        if (plain) addText(@"明文", plain, CH_ACCENT);
        addData(@"密文", r[@"in"], CH_ORANGE);
        addData(@"请求体", r[@"reqText"] ? nil : r[@"req"], CH_ORANGE);
        addData(@"数据", r[@"data"], CH_TEXT2);
        if (r[@"inLen"]) addField(@"输入长度", [NSString stringWithFormat:@"%@ 字节", r[@"inLen"]], CH_SUB);
    }

    // ── ④ 结果数据（输出）──
    NSString *outPlain = r[@"outText"] ?: r[@"respText"];
    BOOL hasOut = (outPlain || r[@"out"] || r[@"mac"] || r[@"resp"]);
    if (hasOut) {
        addRaw(makeSectionHeader(@"结果数据（输出 out）", CH_ACCENT));
        if (outPlain) addText(@"明文", outPlain, CH_ACCENT);
        addData(@"解密结果", r[@"out"], CH_ACCENT);
        addData(@"HMAC", r[@"mac"], CH_PURPLE);
        addData(@"响应体", r[@"respText"] ? nil : r[@"resp"], CH_ORANGE);
        if (r[@"outLen"]) addField(@"输出长度", [NSString stringWithFormat:@"%@ 字节", r[@"outLen"]], CH_SUB);
    }

    // ── ⑤ 网络 ──
    if (r[@"url"] || r[@"method"] || r[@"status"] || r[@"error"]) {
        addRaw(makeSectionHeader(@"网络", CH_ORANGE));
        addField(@"URL", r[@"url"], CH_ORANGE);
        addField(@"方法", r[@"method"], CH_ORANGE);
        if (r[@"status"]) addField(@"状态码", [NSString stringWithFormat:@"%@", r[@"status"]], CH_ORANGE);
        if (r[@"error"]) addField(@"错误", r[@"error"], CH_RED);
    }

    // ── ⑤ 调用栈 ──
    NSArray *bt = r[@"bt"];
    if ([bt isKindOfClass:[NSArray class]] && bt.count) {
        addRaw(makeSectionHeader(@"调用栈", CH_PURPLE));
        NSMutableString *s = [NSMutableString string];
        for (NSInteger i = 0; i < (NSInteger)bt.count; i++)
            [s appendFormat:@"%2ld  %@\n", (long)i, bt[i]];
        [stack addObject:[[CHFieldView alloc] initWithName:@"backtrace"
                                value:s color:CH_PURPLE]];
    } else if (r[@"caller"]) {
        addRaw(makeSectionHeader(@"调用栈", CH_PURPLE));
        addField(@"调用者", r[@"caller"], CH_PURPLE);
    }

    // ── ⑥ 聚合历史 ──
    if (self.record.dups.count) {
        addRaw(makeSectionHeader(@"历史触发", CH_SUB));
        NSMutableString *s = [NSMutableString string];
        NSDateFormatter *tf = [NSDateFormatter new];
        tf.dateFormat = @"HH:mm:ss.SSS";
        [s appendFormat:@"共出现 %ld 次\n\n", (long)self.record.count];
        for (CHRecord *d in self.record.dups) [s appendFormat:@"%@\n", [tf stringFromDate:d.date]];
        [stack addObject:[[CHFieldView alloc] initWithName:@"时间列表" value:s color:CH_PURPLE]];
    }

    // ── ⑦ 本地复算 ──
    NSString *vr = [self recompute];
    if (vr.length) {
        addRaw(makeSectionHeader(@"本地复算", CH_ACCENT));
        BOOL ok = [vr hasPrefix:@"✓"];
        [stack addObject:[[CHFieldView alloc] initWithName:(ok ? @"验证结果" : @"验证结果")
                                value:vr color:(ok ? CH_ACCENT : CH_RED)]];
    }

    // ── ⑦ 原始记录 ──
    addRaw(makeSectionHeader(@"原始记录", CH_SUB));
    NSData *jd = [NSJSONSerialization dataWithJSONObject:r
                    options:NSJSONWritingPrettyPrinted error:nil];
    NSString *json = [[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding];
    if (json) [stack addObject:[[CHFieldView alloc] initWithName:@"RAW JSON" value:json color:CH_TEXT2]];

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

#pragma mark - 本地复算验证
/// 用记录里的 KEY/IV 自己跑一遍，跟记录结果比对
- (NSString *)recompute {
    NSDictionary *r = self.record.raw;
    NSData *inD  = hexToData(r[@"in"]);
    NSData *keyD = hexToData(r[@"key"]);
    NSData *ivD  = hexToData(r[@"iv"]);
    NSData *outD = hexToData(r[@"out"]);
    if (!inD.length || !keyD.length) return nil;

    NSNumber *algN = r[@"alg"], *optN = r[@"opt"], *opN = r[@"op"];
    CCAlgorithm alg = algN ? (CCAlgorithm)algN.intValue : kCCAlgorithmAES;
    CCOptions   opt = optN ? (CCOptions)optN.intValue   : 0;
    BOOL isEnc = [opN isEqual:@"ENC"];
    CCOperation op = isEnc ? kCCEncrypt : kCCDecrypt;

    size_t cap = inD.length + 64;
    void *buf = calloc(1, cap);
    if (!buf) return nil;
    size_t moved = 0;
    CCCryptorStatus st = CCCrypt(op, alg, opt,
                                 keyD.bytes, keyD.length,
                                 ivD.length ? ivD.bytes : NULL,
                                 inD.bytes, inD.length,
                                 buf, cap, &moved);
    if (st != kCCSuccess) {
        free(buf);
        NSArray *errs = @[@"参数错误", @"缓冲区不足", @"对齐错误",
                          @"解码失败", @"解码失败", @"内存不足", @"参数错误"];
        NSString *en = (st >= 0 && st < (CCCryptorStatus)errs.count) ? errs[st] : @"未知";
        return [NSString stringWithFormat:@"✗ 复算失败 (code %d · %@)", (int)st, en];
    }
    NSData *out = [NSData dataWithBytes:buf length:moved];
    free(buf);

    NSMutableString *msg = [NSMutableString string];
    NSString *dir = isEnc ? @"加密" : @"解密";
    [msg appendFormat:@"%@ %lu 字节 → %lu 字节\n\n", dir,
                     (unsigned long)inD.length, (unsigned long)out.length];
    if (outD.length) {
        if ([out isEqualToData:outD]) {
            [msg appendFormat:@"✓ 复算通过\n用记录中的 KEY/IV %@一遍，结果与记录的输出完全一致。\n\n复算结果(HEX):\n%@",
                             dir, [out base64EncodedStringWithOptions:0] ? [self hexOf:out] : @""];
        } else {
            [msg appendFormat:@"✗ 不一致\n复算得到 %lu 字节，与记录中的输出不同。\n可能原因：分组不对 / KEY/IV 来自别的调用 / 记录被截断。\n\n复算(HEX):\n%@\n\n记录(HEX):\n%@",
                             (unsigned long)out.length, [self hexOf:out], [self hexOf:outD]];
        }
    } else {
        [msg appendFormat:@"（记录中没有输出可比对，下面是复算结果）\n\n%@", [self hexOf:out]];
    }
    return msg;
}

- (NSString *)hexOf:(NSData *)d {
    if (!d.length) return @"(空)";
    NSMutableString *o = [NSMutableString stringWithCapacity:d.length * 2];
    const uint8_t *b = d.bytes;
    NSUInteger lim = MIN(d.length, 512);
    for (NSUInteger i = 0; i < lim; i++) [o appendFormat:@"%02x", b[i]];
    if (d.length > lim) [o appendFormat:@"…(%luB)", (unsigned long)d.length];
    return o;
}

#pragma mark - 操作菜单
- (void)showActions {
    UIAlertController *al = [UIAlertController alertControllerWithTitle:nil message:nil
        preferredStyle:UIAlertControllerStyleActionSheet];

    [al addAction:[UIAlertAction actionWithTitle:@"分享这条记录 (.txt)"
                          style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *a){ [self shareAll]; }]];

    // ── 过滤选项（按内容特征加黑名单）──
    NSDictionary *r = self.record.raw;
    NSString *t = self.record.type;
    NSString *u = r[@"url"];
    NSString *c = r[@"caller"];

    if (t.length) {
        [al addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"过滤掉类型「%@」", t]
                              style:UIAlertActionStyleDestructive
                            handler:^(UIAlertAction *a){ [self addExclude:@"excludeTypes" value:t]; }]];
    }
    if ([u isKindOfClass:[NSString class]] && u.length) {
        NSURL *uu = [NSURL URLWithString:u];
        NSString *host = uu.host ?: u;
        [al addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"过滤掉域名「%@」", host]
                              style:UIAlertActionStyleDestructive
                            handler:^(UIAlertAction *a){ [self addExclude:@"excludeUrls" value:host]; }]];
    }
    if ([c isKindOfClass:[NSString class]] && c.length) {
        // 取调用点的函数名部分（去掉 +0x... 和 @0x...）
        NSString *sym = c;
        NSRange r1 = [sym rangeOfString:@" +0x"];
        if (r1.location != NSNotFound) sym = [sym substringToIndex:r1.location];
        if (sym.length) {
            [al addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"过滤掉调用点「%@」", sym]
                                  style:UIAlertActionStyleDestructive
                                handler:^(UIAlertAction *a){ [self addExclude:@"excludeCallers" value:sym]; }]];
        }
    }

    [al addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if (al.popoverPresentationController) al.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:al animated:YES completion:nil];
}

/// 加一条黑名单（写入共享 config.plist）
- (void)addExclude:(NSString *)key value:(NSString *)v {
    NSString *path = @"/var/mobile/Library/CryptoHook/config.plist";
    NSMutableDictionary *cfg = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
    NSMutableArray *arr = [NSMutableArray arrayWithArray:cfg[key] ?: @[]];
    if (![arr containsObject:v]) [arr addObject:v];
    // 同时写共享目录 + 该 App 沙盒（让 dylib 读得到）
    cfg[key] = arr;
    [[NSFileManager defaultManager] createDirectoryAtPath:@"/var/mobile/Library/CryptoHook"
        withIntermediateDirectories:YES attributes:nil error:nil];
    [cfg writeToFile:path atomically:YES];
    // 同步到该 App 沙盒
    NSString *home = NSHomeDirectory();
    if (home) {
        NSString *d = [home stringByAppendingPathComponent:@"Documents/CryptoHook"];
        [[NSFileManager defaultManager] createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:nil];
        [cfg writeToFile:[d stringByAppendingPathComponent:@"config.plist"] atomically:YES];
    }
    UIAlertController *ok = [UIAlertController alertControllerWithTitle:@"已过滤"
        message:[NSString stringWithFormat:@"%@ 已加入黑名单，之后不再记录。\n可在「设置 → 过滤规则」里移除。", v]
        preferredStyle:UIAlertControllerStyleAlert];
    [ok addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:ok animated:YES completion:nil];
}

- (void)shareAll {
    NSString *txt = [self buildSingleText];
    NSDateFormatter *tf = [NSDateFormatter new];
    tf.dateFormat = @"HHmmss";
    NSString *fn = [NSString stringWithFormat:@"hook_%@_%@.txt", self.record.type, [tf stringFromDate:self.record.date]];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:fn];
    [txt writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    UIActivityViewController *av = [[UIActivityViewController alloc]
        initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    if (av.popoverPresentationController) {
        av.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }
    [self presentViewController:av animated:YES completion:nil];
}

/// 单条记录 -> 可读 txt
- (NSString *)buildSingleText {
    NSDateFormatter *df = [NSDateFormatter new];
    df.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    NSMutableString *s = [NSMutableString string];
    NSDictionary *r = self.record.raw;

    [s appendString:@"========================================\n"];
    [s appendFormat:@"  %@  (%@)\n", self.record.title, self.record.layer];
    [s appendString:@"========================================\n\n"];
    [s appendFormat:@"记录类型 : %@\n", self.record.type];
    NSString *op = [self.record opTag], *alg = [self.record algoTag];
    if (op.length)   [s appendFormat:@"操作     : %@\n", op];
    if (alg.length)  [s appendFormat:@"算法     : %@\n", alg];
    [s appendFormat:@"时间     : %@\n", [df stringFromDate:self.record.date]];
    if (self.record.count > 1) [s appendFormat:@"出现次数 : ×%ld\n", (long)self.record.count];
    [s appendString:@"\n"];

    NSArray *order = @[@"key", @"iv", @"text", @"inText", @"in", @"inLen",
                       @"outText", @"out", @"outLen", @"mac", @"hash", @"data",
                       @"url", @"method", @"status", @"reqText", @"req",
                       @"respText", @"resp", @"error", @"src", @"caller"];
    NSDictionary *names = @{
        @"key":@"KEY", @"iv":@"IV", @"text":@"明文", @"inText":@"明文",
        @"in":@"密文/输入", @"inLen":@"输入长度", @"outText":@"解密结果",
        @"out":@"输出", @"outLen":@"输出长度", @"mac":@"HMAC", @"hash":@"HASH",
        @"data":@"数据", @"url":@"URL", @"method":@"方法", @"status":@"状态码",
        @"reqText":@"请求体", @"req":@"请求体", @"respText":@"响应体",
        @"resp":@"响应体", @"error":@"错误", @"src":@"来源", @"caller":@"调用者"
    };
    for (NSString *k in order) {
        id v = r[k];
        if (!v) continue;
        NSString *sv = [v isKindOfClass:[NSString class]] ? v : [v description];
        if (sv.length == 0) continue;
        [s appendFormat:@"%-9s: %@\n", [names[k] UTF8String], sv];
    }

    // 复算结果
    NSString *vr = [self recompute];
    if (vr.length) {
        [s appendString:@"\n─── 本地复算 ───\n"];
        [s appendFormat:@"%@\n", vr];
    }

    // 调用栈
    NSArray *bt = r[@"bt"];
    if ([bt isKindOfClass:[NSArray class]] && bt.count) {
        [s appendString:@"\n─── 调用栈 ───\n"];
        for (NSInteger i = 0; i < (NSInteger)bt.count; i++)
            [s appendFormat:@"%2ld  %@\n", (long)i, bt[i]];
    }

    // 原始 JSON
    NSData *jd = [NSJSONSerialization dataWithJSONObject:r options:NSJSONWritingPrettyPrinted error:nil];
    if (jd) {
        [s appendString:@"\n─── 原始 JSON ───\n"];
        [s appendString:[[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding] ?: @""];
        [s appendString:@"\n"];
    }
    [s appendString:@"\n—— 由 AzbcpxTuT 导出 ——\n"];
    return s;
}

@end
