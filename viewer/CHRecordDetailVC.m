// CHRecordDetailVC.m — 全屏详情（UILabel 版，修字段空白）
#import "CHRecordDetailVC.h"
#import "CHTheme.h"

@interface CHFieldView : UIView
@property (nonatomic, copy) NSString *fieldName;
@property (nonatomic, copy) NSString *fieldValue;
@property (nonatomic, strong) UILabel *nameL;
@property (nonatomic, strong) UILabel *valueL;
@property (nonatomic, strong) UIButton *dupBtn;
- (instancetype)initWithName:(NSString *)n value:(NSString *)v;
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
        _nameL.numberOfLines = 1;
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

        // ★ UILabel 多行 —— Auto Layout 下高度可靠
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

        // 抗压缩：让值优先撑开
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

#pragma mark -

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
        initWithImage:[UIImage imageNamed:@"square.and.arrow.up"] ?: nil
                style:UIBarButtonItemStylePlain target:self action:@selector(shareAll)];
    self.navigationItem.rightBarButtonItem.image = [UIImage systemImageNamed:@"square.and.arrow.up"];
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
    NSString *algo = [self.record algoTag];
    NSMutableArray *fs = [NSMutableArray array];

    void (^add)(NSString *, id) = ^(NSString *n, id v) {
        NSString *s = nil;
        if ([v isKindOfClass:[NSString class]]) s = v;
        else if (v) s = [v description];
        if (s.length == 0) return;
        [fs addObject:[[CHFieldView alloc] initWithName:n value:s]];
    };

    add(@"类型", [NSString stringWithFormat:@"%@ · %@", self.record.layer, self.record.type]);
    if (algo.length) add(@"算法", algo);
    add(@"时间", [self.record.date description]);
    add(@"操作", r[@"op"]);
    add(@"KEY", r[@"key"]);
    add(@"IV", r[@"iv"]);
    // ★ 明文：L2 用 text，L1 用 inText
    add(@"明文内容", r[@"text"] ?: r[@"inText"]);
    add(@"密文 (in)", r[@"in"]);
    add(@"密文长度", r[@"inLen"]);
    add(@"解密结果", r[@"outText"]);
    add(@"输出 (out)", r[@"out"]);
    add(@"输出长度", r[@"outLen"]);
    add(@"HMAC", r[@"mac"]);
    add(@"哈希", r[@"hash"]);
    add(@"数据", r[@"data"]);
    add(@"来源", r[@"src"]);
    add(@"调用者", r[@"caller"]);
    add(@"URL", r[@"url"]);
    add(@"方法", r[@"method"]);
    add(@"状态", r[@"status"]);
    add(@"请求体", r[@"reqText"] ?: r[@"req"]);
    add(@"响应体", r[@"respText"] ?: r[@"resp"]);
    add(@"错误", r[@"error"]);

    NSData *jd = [NSJSONSerialization dataWithJSONObject:r
                    options:NSJSONWritingPrettyPrinted error:nil];
    add(@"完整记录 (RAW JSON)",
        [[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding]);

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
