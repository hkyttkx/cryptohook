// CHDetailVC.m — 记录流（搜索 + 分类筛选 + 算法标注）
#import "CHDetailVC.h"
#import "CHServices.h"
#import "CHTheme.h"
#import "CHRecordDetailVC.h"

#pragma mark - 筛选 Chip
@interface CHChip : UIButton
@property (nonatomic, copy) NSString *key;   // 过滤键
@end
@implementation CHChip
@end

#pragma mark - Cell
@interface CHRecCell : UITableViewCell
@property (nonatomic, strong) UIView      *card;
@property (nonatomic, strong) UIView      *bar;
@property (nonatomic, strong) UIImageView *ico;
@property (nonatomic, strong) UILabel     *tagL;      // LAYER 标签
@property (nonatomic, strong) UILabel     *algoL;     // 算法标签
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

        _algoL = [UILabel new];
        _algoL.textAlignment = NSTextAlignmentCenter;
        _algoL.layer.cornerRadius = 4;
        _algoL.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
        _algoL.clipsToBounds = YES;
        _algoL.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_algoL];

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
            [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:14],
            [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14],
            [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4],
            [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4],

            [_bar.leadingAnchor  constraintEqualToAnchor:_card.leadingAnchor constant:0],
            [_bar.topAnchor      constraintEqualToAnchor:_card.topAnchor constant:10],
            [_bar.bottomAnchor   constraintEqualToAnchor:_card.bottomAnchor constant:-10],
            [_bar.widthAnchor    constraintEqualToConstant:2],

            [_ico.leadingAnchor constraintEqualToAnchor:_bar.trailingAnchor constant:12],
            [_ico.topAnchor     constraintEqualToAnchor:_card.topAnchor constant:12],
            [_ico.widthAnchor   constraintEqualToConstant:14],
            [_ico.heightAnchor  constraintEqualToConstant:14],

            [_tagL.leadingAnchor constraintEqualToAnchor:_ico.trailingAnchor constant:6],
            [_tagL.centerYAnchor constraintEqualToAnchor:_ico.centerYAnchor],

            [_algoL.leadingAnchor constraintEqualToAnchor:_tagL.trailingAnchor constant:6],
            [_algoL.centerYAnchor constraintEqualToAnchor:_ico.centerYAnchor],
            [_algoL.heightAnchor  constraintEqualToConstant:14],
            [_algoL.widthAnchor   constraintGreaterThanOrEqualToConstant:30],

            [_timeL.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
            [_timeL.centerYAnchor  constraintEqualToAnchor:_ico.centerYAnchor],

            [_titleL.leadingAnchor constraintEqualToAnchor:_algoL.trailingAnchor constant:6],
            [_titleL.centerYAnchor constraintEqualToAnchor:_ico.centerYAnchor],
            [_titleL.trailingAnchor constraintLessThanOrEqualToAnchor:_timeL.leadingAnchor constant:-8],

            [_subL.leadingAnchor  constraintEqualToAnchor:_ico.leadingAnchor],
            [_subL.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
            [_subL.topAnchor      constraintEqualToAnchor:_ico.bottomAnchor constant:8],

            [_dataBox.leadingAnchor  constraintEqualToAnchor:_ico.leadingAnchor],
            [_dataBox.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
            [_dataBox.topAnchor      constraintEqualToAnchor:_subL.bottomAnchor constant:8],
            [_dataBox.bottomAnchor   constraintEqualToAnchor:_card.bottomAnchor constant:-12],

            [_dataL.leadingAnchor  constraintEqualToAnchor:_dataBox.leadingAnchor constant:8],
            [_dataL.trailingAnchor constraintEqualToAnchor:_dataBox.trailingAnchor constant:-8],
            [_dataL.topAnchor      constraintEqualToAnchor:_dataBox.topAnchor constant:7],
            [_dataL.bottomAnchor   constraintEqualToAnchor:_dataBox.bottomAnchor constant:-7],
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

    // 算法标签
    NSString *algo = [r algoTag];
    if (algo.length) {
        self.algoL.hidden = NO;
        self.algoL.attributedText = [CHTheme tracked:algo
            font:[CHTheme mono:8.5 weight:UIFontWeightBold] color:col spacing:0.6];
        self.algoL.layer.borderColor = [col colorWithAlphaComponent:0.5].CGColor;
        self.algoL.backgroundColor = [col colorWithAlphaComponent:0.12];
    } else {
        self.algoL.hidden = YES;
    }

    self.titleL.attributedText = [CHTheme tracked:r.title
        font:[CHTheme mono:12.5 weight:UIFontWeightSemibold] color:CH_TEXT spacing:0.2];

    self.subL.attributedText = [CHTheme tracked:(r.subtitle ?: @"")
        font:[CHTheme mono:10.5 weight:UIFontWeightRegular] color:CH_TEXT2 spacing:0.1];

    static NSDateFormatter *df = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        df = [NSDateFormatter new];
        df.dateFormat = @"HH:mm:ss.SSS";
    });
    self.timeL.attributedText = [CHTheme tracked:[df stringFromDate:r.date]
        font:[CHTheme mono:9.5 weight:UIFontWeightRegular] color:CH_SUB spacing:0.1];

    NSString *data = r.detail;
    self.dataBox.hidden = (data.length == 0);
    self.dataL.attributedText = [CHTheme tracked:data ?: @""
        font:[CHTheme mono:10.5 weight:UIFontWeightRegular] color:CH_TEXT spacing:0.0];
}

@end

#pragma mark - VC
@interface CHDetailVC () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSArray<CHRecord *> *allRecords;
@property (nonatomic, strong) NSArray<CHRecord *> *records;   // 过滤后
@property (nonatomic, strong) UILabel *empty;
@property (nonatomic, strong) UIRefreshControl *refresh;
@property (nonatomic, strong) UIScrollView *chipBar;
@property (nonatomic, copy)   NSString *filter;   // nil=全部
@property (nonatomic, copy)   NSString *keyword;
@property (nonatomic, strong) NSMutableArray<CHChip *> *chips;
@end

@implementation CHDetailVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CH_BG;
    if (@available(iOS 13.0, *)) self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.filter = nil;
    self.keyword = nil;

    self.navigationItem.titleView = ({
        UILabel *l = [UILabel new];
        l.attributedText = [CHTheme tracked:(self.app.name ?: @"RECORDS")
            font:[CHTheme mono:13 weight:UIFontWeightBold] color:CH_ACCENT spacing:1.4];
        l;
    });

    // ── 搜索栏 ──
    UISearchBar *sb = [UISearchBar new];
    sb.delegate = self;
    sb.placeholder = @"搜索 key / 明文 / URL / 算法";
    sb.searchBarStyle = UISearchBarStyleMinimal;
    sb.tintColor = CH_ACCENT;
    sb.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:sb];
    if (@available(iOS 13.0, *)) {
        sb.searchTextField.backgroundColor = CH_CARD;
        sb.searchTextField.textColor = CH_TEXT;
        sb.searchTextField.font = [CHTheme mono:12 weight:UIFontWeightRegular];
        sb.searchTextField.layer.cornerRadius = 9;
        sb.searchTextField.layer.borderWidth = 1.0/[UIScreen mainScreen].scale;
        sb.searchTextField.layer.borderColor = CH_LINE.CGColor;
    }

    // ── 分类 Chip 栏 ──
    self.chipBar = [UIScrollView new];
    self.chipBar.showsHorizontalScrollIndicator = NO;
    self.chipBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.chipBar];

    self.chips = [NSMutableArray array];
    NSArray *defs = @[@[@"全部", @""], @[@"加密", @"L1"], @[@"明文", @"L2"],
                      @[@"网络", @"L3"], @[@"自研", @"L4"]];
    CGFloat x = 14;
    for (NSArray *d in defs) {
        CHChip *c = [CHChip buttonWithType:UIButtonTypeCustom];
        c.key = d[1];
        [c setAttributedTitle:[CHTheme tracked:d[0]
                font:[CHTheme mono:11 weight:UIFontWeightSemibold] color:CH_SUB spacing:0.8]
                     forState:UIControlStateNormal];
        c.titleLabel.font = [CHTheme mono:11 weight:UIFontWeightSemibold];
        c.layer.cornerRadius = 13;
        c.layer.borderWidth = 1.0/[UIScreen mainScreen].scale;
        c.layer.borderColor = CH_LINE.CGColor;
        c.backgroundColor = CH_CARD;
        c.contentEdgeInsets = UIEdgeInsetsMake(5, 12, 5, 12);
        [c sizeToFit];
        CGRect f = c.frame;
        f.origin = CGPointMake(x, 8);
        f.size.height = 26;
        c.frame = f;
        [c addTarget:self action:@selector(chipTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.chipBar addSubview:c];
        [self.chips addObject:c];
        x += f.size.width + 8;
    }
    self.chipBar.contentSize = CGSizeMake(x + 6, 42);
    [self paintChips];

    // ── 表 ──
    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.backgroundColor = [UIColor clearColor];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.rowHeight = UITableViewAutomaticDimension;
    self.table.estimatedRowHeight = 120;
    self.table.contentInset = UIEdgeInsetsMake(6, 0, 40, 0);
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.table];

    [NSLayoutConstraint activateConstraints:@[
        [sb.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [sb.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [sb.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.chipBar.topAnchor constraintEqualToAnchor:sb.bottomAnchor constant:2],
        [self.chipBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.chipBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.chipBar.heightAnchor constraintEqualToConstant:42],

        [self.table.topAnchor constraintEqualToAnchor:self.chipBar.bottomAnchor],
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
        attributes:@{NSFontAttributeName:[CHTheme mono:12 weight:UIFontWeightMedium],
                     NSForegroundColorAttributeName:CH_SUB,
                     NSKernAttributeName:@(1.2),
                     NSParagraphStyleAttributeName:ps}];
    [self.view addSubview:self.empty];
    [NSLayoutConstraint activateConstraints:@[
        [self.empty.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.empty.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-40],
        [self.empty.widthAnchor constraintEqualToConstant:290],
    ]];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up"]
                style:UIBarButtonItemStylePlain target:self action:@selector(exportAll)];
    self.navigationItem.rightBarButtonItem.tintColor = CH_ACCENT;

    [self load];
}

- (void)paintChips {
    for (CHChip *c in self.chips) {
        BOOL sel = (c.key.length == 0 && self.filter.length == 0) ||
                   (c.key.length && [c.key isEqualToString:self.filter]);
        UIColor *col = sel ? CH_ACCENT : CH_SUB;
        c.layer.borderColor = (sel ? [CH_ACCENT colorWithAlphaComponent:0.6] : CH_LINE).CGColor;
        c.backgroundColor = sel ? [CH_ACCENT colorWithAlphaComponent:0.12] : CH_CARD;
        [c setAttributedTitle:[CHTheme tracked:c.titleLabel.text ?: @""
                font:[CHTheme mono:11 weight:UIFontWeightSemibold] color:col spacing:0.8]
                     forState:UIControlStateNormal];
    }
}

- (void)chipTapped:(CHChip *)c {
    self.filter = c.key.length ? c.key : nil;
    [self paintChips];
    [self applyFilter];
}

- (void)searchBar:(UISearchBar *)sb textDidChange:(NSString *)text {
    self.keyword = text.length ? text : nil;
    [self applyFilter];
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)sb { [sb resignFirstResponder]; }

- (void)applyFilter {
    NSString *f = self.filter, *kw = self.keyword;
    NSMutableArray *out = [NSMutableArray array];
    for (CHRecord *r in self.allRecords) {
        if (f.length && ![r.layer isEqualToString:f]) continue;
        if (kw.length) {
            NSMutableString *hay = [NSMutableString string];
            [hay appendString:r.raw[@"text"] ?: @""];
            [hay appendString:r.raw[@"key"]  ?: @""];
            [hay appendString:r.raw[@"url"]  ?: @""];
            [hay appendString:r.raw[@"inText"] ?: @""];
            [hay appendString:r.raw[@"outText"] ?: @""];
            [hay appendString:r.raw[@"respText"] ?: @""];
            [hay appendString:r.raw[@"reqText"] ?: @""];
            [hay appendString:r.title];
            [hay appendString:r.raw[@"alg"] ? [NSString stringWithFormat:@"alg%@", r.raw[@"alg"]] : @""];
            if ([[hay lowercaseString] rangeOfString:[kw lowercaseString]].location == NSNotFound) continue;
        }
        [out addObject:r];
    }
    self.records = out;
    self.empty.hidden = (out.count > 0);
    [self.table reloadData];
}

- (void)load {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *r = [CHScanner recordsForApp:self.app limit:5000];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allRecords = r;
            [self applyFilter];
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
    // push 全屏详情（大内容也能看全 / 复制 / 分享）
    CHRecordDetailVC *d = [CHRecordDetailVC new];
    d.record = r;
    [self.navigationController pushViewController:d animated:YES];
}

@end
