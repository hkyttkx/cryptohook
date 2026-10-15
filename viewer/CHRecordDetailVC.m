// CHRecordDetailVC.m — 全屏详情：分段展示 + 每段可复制 + 整体分享
#import "CHRecordDetailVC.h"
#import "CHTheme.h"

@interface CHFieldView : UIView
@property (nonatomic, copy) NSString *fieldName;
@property (nonatomic, copy) NSString *fieldValue;
@property (nonatomic, strong) UILabel *nameL;
@property (nonatomic, strong) UITextView *valueTV;
@property (nonatomic, strong) UIButton *dupBtn;
- (instancetype)initWithName:(NSString *)n value:(NSString *)v;
- (CGFloat)heightForWidth:(CGFloat)w;
@end

@implementation CHFieldView

- (instancetype)initWithName:(NSString *)n value:(NSString *)v {
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
        _nameL.attributedText = [CHTheme tracked:n
            font:[CHTheme mono:10 weight:UIFontWeightBold] color:CH_ACCENT spacing:1.2];
        _nameL.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_nameL];

        _dupBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [_dupBtn setImage:[UIImage systemImageNamed:@"doc.on.doc"] forState:UIControlStateNormal];
        _dupBtn.tintColor = CH_SUB;
        _dupBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [_dupBtn addTarget:self action:@selector(copyField) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_dupBtn];

        _valueTV = [UITextView new];
        _valueTV.editable = NO;
        _valueTV.scrollEnabled = NO;
        _valueTV.backgroundColor = [UIColor clearColor];
        _valueTV.textContainerInset = UIEdgeInsetsZero;
        _valueTV.textContainer.lineFragmentPadding = 0;
        _valueTV.font = [CHTheme mono:11.5 weight:UIFontWeightRegular];
        _valueTV.textColor = CH_TEXT;
        _valueTV.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_valueTV];

        // 等宽排版 + 自动换行
        NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
        ps.lineSpacing = 3;
        ps.lineBreakMode = NSLineBreakByCharWrapping;
        _valueTV.attributedText = [[NSAttributedString alloc] initWithString:v ?: @""
            attributes:@{NSFontAttributeName:[CHTheme mono:11.5 weight:UIFontWeightRegular],
                         NSForegroundColorAttributeName:CH_TEXT,
                         NSParagraphStyleAttributeName:ps}];

        [NSLayoutConstraint activateConstraints:@[
            [_nameL.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
            [_nameL.topAnchor constraintEqualToAnchor:self.topAnchor constant:10],

            [_dupBtn.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
            [_dupBtn.centerYAnchor constraintEqualToAnchor:_nameL.centerYAnchor],
            [_dupBtn.widthAnchor constraintEqualToConstant:26],
            [_dupBtn.heightAnchor constraintEqualToConstant:26],

            [_valueTV.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
            [_valueTV.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
            [_valueTV.topAnchor constraintEqualToAnchor:_nameL.bottomAnchor constant:7],
            [_valueTV.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12],
        ]];
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

- (CGFloat)heightForWidth:(CGFloat)w {
    CGSize sz = [self.valueTV sizeThatFits:CGSizeMake(w - 24, CGFLOAT_MAX)];
    return 10 + 14 + 7 + sz.height + 12;
}

@end

#pragma mark -

@interface CHRecordDetailVC ()
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) NSArray<CHFieldView *> *fields;
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
                style:UIBarButtonItemStylePlain
               target:self action:@selector(shareAll)];
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

    // 组装字段（只放有值的）
    NSMutableArray *fs = [NSMutableArray array];
    NSDictionary *r = self.record.raw;
    NSString *algo = [self.record algoTag];

    void (^add)(NSString *, NSString *) = ^(NSString *n, NSString *v) {
        if (v.length == 0) return;
        [fs addObject:[[CHFieldView alloc] initWithName:n value:v]];
    };

    add(@"类型", [NSString stringWithFormat:@"%@ · %@", self.record.layer, self.record.type]);
    if (algo.length) add(@"算法", algo);
    add(@"时间", [NSString stringWithFormat:@"%@", self.record.date]);
    add(@"操作", r[@"op"]);
    add(@"KEY", r[@"key"]);
    add(@"IV", r[@"iv"]);
    add(@"明文 (inText)", r[@"inText"] ?: r[@"text"]);
    add(@"密文 (in)", r[@"in"]);
    add(@"密文长度", r[@"inLen"] ? [NSString stringWithFormat:@"%@ 字节", r[@"inLen"]] : nil);
    add(@"解密结果 (outText)", r[@"outText"]);
    add(@"输出 (out)", r[@"out"]);
    add(@"输出长度", r[@"outLen"] ? [NSString stringWithFormat:@"%@ 字节", r[@"outLen"]] : nil);
    add(@"HMAC", r[@"mac"]);
    add(@"哈希", r[@"hash"]);
    add(@"数据", r[@"data"]);
    add(@"调用者", r[@"caller"]);
    add(@"URL", r[@"url"]);
    add(@"方法", r[@"method"]);
    add(@"状态", r[@"status"] ? [NSString stringWithFormat:@"%@", r[@"status"]] : nil);
    add(@"请求体", r[@"reqText"] ?: r[@"req"]);
    add(@"响应体", r[@"respText"] ?: r[@"resp"]);
    add(@"错误", r[@"error"]);

    // 完整原始 JSON（最后一个，最全）
    NSData *jd = [NSJSONSerialization dataWithJSONObject:r options:NSJSONWritingPrettyPrinted error:nil];
    NSString *json = [[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding];
    add(@"完整记录 (RAW JSON)", json);

    self.fields = fs;

    UIView *prev = nil;
    CGFloat W = [UIScreen mainScreen].bounds.size.width;
    for (CHFieldView *f in fs) {
        f.translatesAutoresizingMaskIntoConstraints = NO;
        [self.scroll addSubview:f];
        [NSLayoutConstraint activateConstraints:@[
            [f.leadingAnchor constraintEqualToAnchor:self.scroll.leadingAnchor constant:14],
            [f.widthAnchor constraintEqualToConstant:W - 28],
        ]];
        if (!prev) [f.topAnchor constraintEqualToAnchor:self.scroll.topAnchor constant:12].active = YES;
        else       [f.topAnchor constraintEqualToAnchor:prev.bottomAnchor constant:10].active = YES;
        prev = f;
    }
    if (prev)
        [prev.bottomAnchor constraintEqualToAnchor:self.scroll.bottomAnchor constant:-40].active = YES;
    self.scroll.contentSize = CGSizeMake(W, MAX(600, fs.count * 100));
}

- (void)shareAll {
    NSString *s = [NSString stringWithFormat:@"[%@][%@] %@\n\n%@",
                   self.record.layer, self.record.type, self.record.title,
                   [[NSString alloc] initWithData:
                    [NSJSONSerialization dataWithJSONObject:self.record.raw
                        options:NSJSONWritingPrettyPrinted error:nil]
                    encoding:NSUTF8StringEncoding]];
    UIActivityViewController *av = [[UIActivityViewController alloc]
        initWithActivityItems:@[s] applicationActivities:nil];
    [self presentViewController:av animated:YES completion:nil];
}

@end
