// CHDetailVC.m — 记录流（深色科技风）
#import "CHDetailVC.h"
#import "CHServices.h"
#import "CHTheme.h"

#pragma mark - Cell
@interface CHRecCell : UITableViewCell
@property (nonatomic, strong) UIView      *card;
@property (nonatomic, strong) UIView      *bar;
@property (nonatomic, strong) UIImageView *ico;
@property (nonatomic, strong) UILabel     *tagL;       // LAYER 标签
@property (nonatomic, strong) UILabel     *titleL;
@property (nonatomic, strong) UILabel     *timeL;
@property (nonatomic, strong) UILabel     *subL;
@property (nonatomic, strong) UIView      *dataBox;
@property (nonatomic, strong) UILabel     *dataL;
- (void)configWith:(CHRecord *)r;
@end

@implementation CHRecCell

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
        _bar.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_bar];

        _ico = [UIImageView new];
        _ico.contentMode = UIViewContentModeScaleAspectFit;
        _ico.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_ico];

        _tagL = [UILabel new];
        _tagL.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_tagL];

        _titleL = [UILabel new];
        _titleL.numberOfLines = 1;
        _titleL.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_titleL];

        _timeL = [UILabel new];
        _timeL.textAlignment = NSTextAlignmentRight;
        _timeL.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_timeL];

        _subL = [UILabel new];
        _subL.numberOfLines = 2;
        _subL.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_subL];

        _dataBox = [UIView new];
        _dataBox.backgroundColor = CH_BG2;
        _dataBox.layer.cornerRadius = 7;
        _dataBox.layer.cornerCurve = kCACornerCurveContinuous;
        _dataBox.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
        _dataBox.layer.borderColor = CH_LINE.CGColor;
        _dataBox.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_dataBox];

        _dataL = [UILabel new];
        _dataL.numberOfLines = 5;
        _dataL.lineBreakMode = NSLineBreakByTruncatingTail;
        _dataL.translatesAutoresizingMaskIntoConstraints = NO;
        [_dataBox addSubview:_dataL];

        [NSLayoutConstraint activateConstraints:@[
            [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4],
            [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4],

            [_bar.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:0],
            [_bar.topAnchor constraintEqualToAnchor:_card.topAnchor constant:10],
            [_bar.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-10],
            [_bar.widthAnchor constraintEqualToConstant:2],

            [_ico.leadingAnchor constraintEqualToAnchor:_bar.trailingAnchor constant:12],
            [_ico.topAnchor constraintEqualToAnchor:_card.topAnchor constant:12],
            [_ico.widthAnchor constraintEqualToConstant:15],
            [_ico.heightAnchor constraintEqualToConstant:15],

            [_tagL.leadingAnchor constraintEqualToAnchor:_ico.trailingAnchor constant:7],
            [_tagL.centerYAnchor constraintEqualToAnchor:_ico.centerYAnchor],

            [_timeL.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
            [_timeL.centerYAnchor constraintEqualToAnchor:_ico.centerYAnchor],

            [_titleL.leadingAnchor constraintEqualToAnchor:_tagL.trailingAnchor constant:8],
            [_titleL.centerYAnchor constraintEqualToAnchor:_ico.centerYAnchor],
            [_titleL.trailingAnchor constraintLessThanOrEqualToAnchor:_timeL.leadingAnchor constant:-8],

            [_subL.leadingAnchor constraintEqualToAnchor:_ico.leadingAnchor],
            [_subL.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
            [_subL.topAnchor constraintEqualToAnchor:_ico.bottomAnchor constant:8],

            [_dataBox.leadingAnchor constraintEqualToAnchor:_ico.leadingAnchor],
            [_dataBox.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
            [_dataBox.topAnchor constraintEqualToAnchor:_subL.bottomAnchor constant:8],
            [_dataBox.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-12],

            [_dataL.leadingAnchor constraintEqualToAnchor:_dataBox.leadingAnchor constant:8],
            [_dataL.trailingAnchor constraintEqualToAnchor:_dataBox.trailingAnchor constant:-8],
            [_dataL.topAnchor constraintEqualToAnchor:_dataBox.topAnchor constant:7],
            [_dataL.bottomAnchor constraintEqualToAnchor:_dataBox.bottomAnchor constant:-7],
        ]];
    }
    return self;
}

- (void)configWith:(CHRecord *)r {
    UIColor *col = [CHTheme colorForLayer:r.layer];

    self.bar.backgroundColor = col;
    [CHTheme glow:self.bar color:col radius:4 opacity:0.85];

    self.ico.image = [UIImage systemImageNamed:[CHTheme symbolForLayer:r.layer]];
    self.ico.tintColor = col;

    self.tagL.attributedText = [CHTheme tracked:[CHTheme nameForLayer:r.layer]
        font:[CHTheme mono:9 weight:UIFontWeightBold] color:col spacing:1.0];

    self.titleL.attributedText = [CHTheme tracked:r.title
        font:[CHTheme mono:13 weight:UIFontWeightSemibold] color:CH_TEXT spacing:0.2];

    self.subL.attributedText = [CHTheme tracked:(r.subtitle ?: @"")
        font:[CHTheme mono:10.5 weight:UIFontWeightRegular] color:CH_TEXT2 spacing:0.1];

    static NSDateFormatter *df = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        df = [NSDateFormatter new];
        df.dateFormat = @"HH:mm:ss.SSS";
    });
    self.timeL.attributedText = [CHTheme tracked:[df stringFromDate:r.date]
        font:[CHTheme mono:10 weight:UIFontWeightRegular] color:CH_SUB spacing:0.1];

    NSString *data = r.detail;
    self.dataBox.hidden = (data.length == 0);
    self.dataL.attributedText = [CHTheme tracked:data ?: @""
        font:[CHTheme mono:10.5 weight:UIFontWeightRegular] color:CH_TEXT spacing:0.0];
}

@end

#pragma mark - VC
@interface CHDetailVC () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSArray<CHRecord *> *records;
@property (nonatomic, strong) UILabel *empty;
@property (nonatomic, strong) UIRefreshControl *refresh;
@end

@implementation CHDetailVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CH_BG;
    if (@available(iOS 13.0, *)) self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    self.navigationItem.titleView = ({
        UILabel *l = [UILabel new];
        l.attributedText = [CHTheme tracked:(self.app.name ?: @"RECORDS")
            font:[CHTheme mono:14 weight:UIFontWeightBold] color:CH_ACCENT spacing:1.4];
        l;
    });

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.backgroundColor = [UIColor clearColor];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.rowHeight = UITableViewAutomaticDimension;
    self.table.estimatedRowHeight = 130;
    self.table.contentInset = UIEdgeInsetsMake(8, 0, 40, 0);
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.table];
    [NSLayoutConstraint activateConstraints:@[
        [self.table.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    self.refresh = [UIRefreshControl new];
    self.refresh.tintColor = CH_ACCENT;
    [self.refresh addTarget:self action:@selector(load) forControlEvents:UIControlEventValueChanged];
    self.table.refreshControl = self.refresh;

    self.empty = [UILabel new];
    self.empty.numberOfLines = 0;
    self.empty.textAlignment = NSTextAlignmentCenter;
    self.empty.translatesAutoresizingMaskIntoConstraints = NO;
    NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
    ps.alignment = NSTextAlignmentCenter;
    ps.lineSpacing = 8;
    self.empty.attributedText = [[NSAttributedString alloc] initWithString:
        @"NO SIGNAL\n\n把 CryptoHook.dylib 注入这个 App\n然后启动它触发加解密"
        attributes:@{
            NSFontAttributeName: [CHTheme mono:12 weight:UIFontWeightMedium],
            NSForegroundColorAttributeName: CH_SUB,
            NSKernAttributeName: @(1.2),
            NSParagraphStyleAttributeName: ps
        }];
    [self.view addSubview:self.empty];
    [NSLayoutConstraint activateConstraints:@[
        [self.empty.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.empty.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-50],
        [self.empty.widthAnchor constraintEqualToConstant:290],
    ]];

    UIButton *exp = [UIButton buttonWithType:UIButtonTypeSystem];
    [exp setImage:[UIImage systemImageNamed:@"square.and.arrow.up"] forState:UIControlStateNormal];
    exp.tintColor = CH_ACCENT;
    [exp addTarget:self action:@selector(exportAll) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:exp];

    [self load];
}

- (void)load {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *r = [CHScanner recordsForApp:self.app limit:3000];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.records = r;
            self.empty.hidden = (r.count > 0);
            [self.table reloadData];
            [self.refresh endRefreshing];
        });
    });
}

- (void)exportAll {
    NSMutableString *s = [NSMutableString string];
    for (CHRecord *r in self.records)
        [s appendFormat:@"[%@][%@] %@\n  %@\n  %@\n\n", r.layer, r.type, r.title, r.subtitle, r.detail];
    UIActivityViewController *av = [[UIActivityViewController alloc]
        initWithActivityItems:@[s] applicationActivities:nil];
    [self presentViewController:av animated:YES completion:nil];
}

#pragma mark - Table
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.records.count; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"rec";
    CHRecCell *c = [t dequeueReusableCellWithIdentifier:cid];
    if (!c) c = [[CHRecCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
    [c configWith:self.records[ip.row]];
    return c;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    CHRecord *r = self.records[ip.row];
    NSData *j = [NSJSONSerialization dataWithJSONObject:r.raw
                    options:NSJSONWritingPrettyPrinted error:nil];
    NSString *txt = [[NSString alloc] initWithData:j encoding:NSUTF8StringEncoding];
    [[UIPasteboard generalPasteboard] setString:txt ?: @""];
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
}

@end
