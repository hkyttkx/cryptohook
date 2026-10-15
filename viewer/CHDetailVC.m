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

#pragma mark - 高亮工具
/// 把 text 里所有 kw 命中处标成青绿 + 淡底
static NSAttributedString *chHighlight(NSString *text, NSString *kw,
                                       UIFont *font, UIColor *color, CGFloat spacing) {
    NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
    ps.lineBreakMode = NSLineBreakByCharWrapping;
    NSMutableAttributedString *as =
        [[NSMutableAttributedString alloc] initWithString:(text ?: @"")
            attributes:@{NSFontAttributeName: font,
                         NSForegroundColorAttributeName: color,
                         NSKernAttributeName: @(spacing),
                         NSParagraphStyleAttributeName: ps}];
    if (kw.length == 0 || text.length == 0) return as;
    NSRange search = NSMakeRange(0, text.length);
    NSInteger guard = 0;
    while (search.length > 0 && guard++ < 200) {
        NSRange hit = [text rangeOfString:kw options:NSCaseInsensitiveSearch range:search];
        if (hit.location == NSNotFound) break;
        [as addAttribute:NSForegroundColorAttributeName value:CH_ACCENT range:hit];
        [as addAttribute:NSBackgroundColorAttributeName
                   value:[CH_ACCENT colorWithAlphaComponent:0.22] range:hit];
        NSUInteger next = hit.location + MAX(hit.length, 1);
        if (next >= text.length) break;
        search = NSMakeRange(next, text.length - next);
    }
    return as;
}

#pragma mark - Cell
@interface CHRecCell : UITableViewCell
@property (nonatomic, strong) UIView      *card;
@property (nonatomic, strong) UIView      *bar;
@property (nonatomic, strong) UIImageView *ico;
@property (nonatomic, strong) UILabel     *tagL;      // LAYER 标签
@property (nonatomic, strong) UILabel     *algoL;     // 算法标签
@property (nonatomic, strong) UILabel     *titleL;
@property (nonatomic, strong) UILabel     *countL;    // ×N 角标
@property (nonatomic, strong) UILabel     *timeL;
@property (nonatomic, strong) UILabel     *subL;
@property (nonatomic, strong) UIView      *dataBox;
@property (nonatomic, strong) UILabel     *dataL;
@property (nonatomic, strong) UILabel     *dupL;      // 子项序号/时间
@property (nonatomic, assign) CGFloat      leadingShift;  // 子项缩进
@property (nonatomic, assign) BOOL         alphaDim;      // 子项变暗
- (void)configWith:(CHRecord *)r keyword:(NSString *)kw;
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

        _countL = [UILabel new];
        _countL.textAlignment = NSTextAlignmentCenter;
        _countL.layer.cornerRadius = 4;
        _countL.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
        _countL.clipsToBounds = NO;
        _countL.hidden = YES;
        _countL.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_countL];

        _dupL = [UILabel new];
        _dupL.hidden = YES;
        _dupL.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_dupL];

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

            [_countL.trailingAnchor constraintEqualToAnchor:_timeL.leadingAnchor constant:-6],
            [_countL.centerYAnchor constraintEqualToAnchor:_ico.centerYAnchor],
            [_countL.heightAnchor constraintEqualToConstant:14],
            [_countL.widthAnchor constraintGreaterThanOrEqualToConstant:24],

            [_titleL.leadingAnchor constraintEqualToAnchor:_algoL.trailingAnchor constant:6],
            [_titleL.centerYAnchor constraintEqualToAnchor:_ico.centerYAnchor],
            [_titleL.trailingAnchor constraintLessThanOrEqualToAnchor:_countL.leadingAnchor constant:-6],

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

- (void)configWith:(CHRecord *)r keyword:(NSString *)kw {
    UIColor *col = [CHTheme colorForLayer:r.layer];
    self.bar.backgroundColor = col;
    [CHTheme glow:self.bar color:col radius:4 opacity:0.85];

    self.ico.image = [UIImage systemImageNamed:[CHTheme symbolForLayer:r.layer]];
    self.ico.tintColor = col;

    self.tagL.attributedText = [CHTheme tracked:[CHTheme nameForLayer:r.layer]
        font:[CHTheme mono:9 weight:UIFontWeightBold] color:col spacing:1.0];

    // 算法标签（带操作方向：ENC·AES / DEC·AES / REQ / RESP）
    NSString *algo = [r algoTag];
    NSString *op   = [r opTag];
    NSString *badge = nil;
    if (op.length && algo.length)      badge = [NSString stringWithFormat:@"%@·%@", op, algo];
    else if (op.length)                badge = op;
    else if (algo.length)              badge = algo;
    if (badge.length) {
        self.algoL.hidden = NO;
        self.algoL.attributedText = [CHTheme tracked:badge
            font:[CHTheme mono:8.5 weight:UIFontWeightBold] color:col spacing:0.6];
        self.algoL.layer.borderColor = [col colorWithAlphaComponent:0.5].CGColor;
        self.algoL.backgroundColor = [col colorWithAlphaComponent:0.12];
    } else {
        self.algoL.hidden = YES;
    }

    self.titleL.attributedText = chHighlight(r.title, kw,
        [CHTheme mono:12.5 weight:UIFontWeightSemibold], CH_TEXT, 0.2);

    // ★ 聚合次数角标
    if (r.count > 1) {
        self.countL.hidden = NO;
        self.countL.attributedText = [CHTheme tracked:[NSString stringWithFormat:@"×%ld", (long)r.count]
            font:[CHTheme mono:9.5 weight:UIFontWeightBold] color:CH_ACCENT spacing:0.4];
        self.countL.layer.borderColor = [CH_ACCENT colorWithAlphaComponent:0.45].CGColor;
        self.countL.backgroundColor = [CH_ACCENT colorWithAlphaComponent:0.12];
        [CHTheme glow:self.countL color:CH_ACCENT radius:4 opacity:0.4];
    } else {
        self.countL.hidden = YES;
        self.countL.layer.shadowOpacity = 0;
    }

    self.subL.attributedText = chHighlight(r.subtitle ?: @"", kw,
        [CHTheme mono:10.5 weight:UIFontWeightRegular], CH_TEXT2, 0.1);

    static NSDateFormatter *df = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        df = [NSDateFormatter new];
        df.dateFormat = @"HH:mm:ss.SSS";
    });
    self.timeL.attributedText = [CHTheme tracked:[df stringFromDate:r.date]
        font:[CHTheme mono:9.5 weight:UIFontWeightRegular] color:CH_SUB spacing:0.1];

    // ★ 展开出来的子项：缩进 + 显示时间 + 变暗
    if (self.leadingShift > 0 || self.alphaDim) {
        self.dupL.hidden = NO;
        NSDateFormatter *tf = [NSDateFormatter new];
        tf.dateFormat = @"HH:mm:ss.SSS";
        self.dupL.attributedText = [CHTheme tracked:[NSString stringWithFormat:@"└ %@", [tf stringFromDate:r.date]]
            font:[CHTheme mono:9.5 weight:UIFontWeightRegular] color:CH_SUB spacing:0.2];
        self.alphaDim ? (self.card.alpha = 0.72) : (self.card.alpha = 1.0);
        // 数据区在小项里不显示（省空间）
        self.dataBox.hidden = YES;
        self.subL.hidden = YES;
        return;
    }
    self.dupL.hidden = YES;
    self.card.alpha = 1.0;
    self.subL.hidden = NO;

    NSString *data = r.detail;
    self.dataBox.hidden = (data.length == 0);
    self.dataL.attributedText = chHighlight(data ?: @"", kw,
        [CHTheme mono:10.5 weight:UIFontWeightRegular], CH_TEXT, 0.0);
}

@end

#pragma mark - 子项 Cell（紧凑一行，可点进详情）
@interface CHDupCell : UITableViewCell
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIView *bar;
@property (nonatomic, strong) UILabel *timeL;
@property (nonatomic, strong) UILabel *tagL;
@property (nonatomic, strong) UILabel *sumL;
@property (nonatomic, strong) UIImageView *arrow;
@end

@implementation CHDupCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    self = [super initWithStyle:style reuseIdentifier:rid];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _card = [UIView new];
        _card.backgroundColor = CH_BG2;
        _card.layer.cornerRadius = 8;
        _card.layer.cornerCurve = kCACornerCurveContinuous;
        _card.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
        _card.layer.borderColor = CH_LINE.CGColor;
        _card.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_card];

        _bar = [UIView new];
        _bar.layer.cornerRadius = 1;
        _bar.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_bar];

        _timeL = [UILabel new];
        _timeL.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_timeL];

        _tagL = [UILabel new];
        _tagL.textAlignment = NSTextAlignmentCenter;
        _tagL.layer.cornerRadius = 3;
        _tagL.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
        _tagL.clipsToBounds = YES;
        _tagL.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_tagL];

        _sumL = [UILabel new];
        _sumL.numberOfLines = 1;
        _sumL.lineBreakMode = NSLineBreakByTruncatingTail;
        _sumL.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_sumL];

        _arrow = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
        _arrow.tintColor = CH_SUB;
        _arrow.contentMode = UIViewContentModeScaleAspectFit;
        _arrow.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_arrow];

        [NSLayoutConstraint activateConstraints:@[
            // 左侧缩进 34（表示是从属关系）
            [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:34],
            [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14],
            [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:2],
            [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-2],

            [_bar.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:0],
            [_bar.topAnchor constraintEqualToAnchor:_card.topAnchor constant:7],
            [_bar.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-7],
            [_bar.widthAnchor constraintEqualToConstant:2],

            [_timeL.leadingAnchor constraintEqualToAnchor:_bar.trailingAnchor constant:9],
            [_timeL.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_timeL.widthAnchor constraintEqualToConstant:78],

            [_tagL.leadingAnchor constraintEqualToAnchor:_timeL.trailingAnchor constant:4],
            [_tagL.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_tagL.heightAnchor constraintEqualToConstant:13],
            [_tagL.widthAnchor constraintGreaterThanOrEqualToConstant:34],

            [_sumL.leadingAnchor constraintEqualToAnchor:_tagL.trailingAnchor constant:6],
            [_sumL.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_sumL.trailingAnchor constraintLessThanOrEqualToAnchor:_arrow.leadingAnchor constant:-6],

            [_arrow.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-8],
            [_arrow.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_arrow.widthAnchor constraintEqualToConstant:10],
            [_arrow.heightAnchor constraintEqualToConstant:10],
        ]];
    }
    return self;
}

- (void)configWith:(CHRecord *)r idx:(NSInteger)idx color:(UIColor *)col {
    UIColor *c = col ?: CH_SUB;
    self.bar.backgroundColor = c;
    self.bar.layer.shadowOpacity = 0;

    static NSDateFormatter *tf = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        tf = [NSDateFormatter new];
        tf.dateFormat = @"HH:mm:ss.SSS";
    });
    self.timeL.attributedText = [CHTheme tracked:[tf stringFromDate:r.date]
        font:[CHTheme mono:9.5 weight:UIFontWeightRegular] color:CH_SUB spacing:0.1];

    NSString *op = [r opTag] ?: r.layer;
    self.tagL.attributedText = [CHTheme tracked:op
        font:[CHTheme mono:8 weight:UIFontWeightBold] color:c spacing:0.3];
    self.tagL.layer.borderColor = [c colorWithAlphaComponent:0.45].CGColor;
    self.tagL.backgroundColor = [c colorWithAlphaComponent:0.12];

    NSString *sum = r.subtitle ?: @"";
    if (sum.length > 60) sum = [[sum substringToIndex:60] stringByAppendingString:@"…"];
    self.sumL.attributedText = [CHTheme tracked:sum
        font:[CHTheme mono:9.5 weight:UIFontWeightRegular] color:CH_TEXT2 spacing:0.0];

    self.arrow.tintColor = [c colorWithAlphaComponent:0.7];
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
@property (nonatomic, strong) NSTimer *ticker;      // 实时刷新
@property (nonatomic, assign) NSInteger timeRange;  // 0=全部 1=5分钟 2=1分钟
@property (nonatomic, assign) BOOL groupBySession;  // 会话配对
@property (nonatomic, strong) UIBarButtonItem *timeBtn;
@property (nonatomic, assign) BOOL searchBarActive;
@property (nonatomic, strong) NSMutableSet<NSString *> *expandedKeys;  // 哪些聚合项展开了
@property (nonatomic, strong) NSMutableArray<CHRecord *> *rows;        // 实际显示的行（含展开的子项）
@property (nonatomic, strong) NSMutableArray<NSNumber *> *rowIsDup;    // 并行：该行是否子项
@property (nonatomic, strong) NSMutableArray<NSNumber *> *rowDupIdx;   // 并行：子项序号
@end

@implementation CHDetailVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CH_BG;
    if (@available(iOS 13.0, *)) self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.filter = nil;
    self.keyword = nil;
    self.expandedKeys = [NSMutableSet set];
    self.rows = [NSMutableArray array];
    self.rowIsDup = [NSMutableArray array];
    self.rowDupIdx = [NSMutableArray array];

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
                      @[@"网络", @"L3"], @[@"自研", @"L4"], @[@"会话", @"SESS"]];
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

    // ★ 右上角「更多」：分享 / 清空本 App
    UIBarButtonItem *more = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"]
                style:UIBarButtonItemStylePlain target:self action:@selector(showMore)];
    more.tintColor = CH_ACCENT;
    self.navigationItem.rightBarButtonItem = more;

    // ★ 时间范围按钮（放右侧，避免被返回按钮挤掉）
    self.timeBtn = [[UIBarButtonItem alloc] initWithTitle:@"全部"
        style:UIBarButtonItemStylePlain target:self action:@selector(pickTimeRange)];
    self.timeBtn.tintColor = CH_ACCENT;
    self.navigationItem.rightBarButtonItems = @[self.navigationItem.rightBarButtonItem ?: [[UIBarButtonItem alloc] init],
                                                self.timeBtn];

    [self load];
    [self startTicker];
}

#pragma mark - 实时刷新
- (void)startTicker {
    self.ticker = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                  target:self
                                                selector:@selector(tick)
                                                userInfo:nil repeats:YES];
}

- (void)tick {
    // 只在最前台、没在滚动、没在搜索时刷新，避免打断操作
    if (!self.view.window) return;
    if (self.table.isDragging || self.table.isDecelerating) return;
    if (self.searchBarActive) return;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSArray *r = [CHScanner recordsForApp:self.app limit:8000 aggregate:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (r.count == self.allRecords.count) return;   // 没变化就不刷
            self.allRecords = r;
            [self applyFilter];
        });
    });
}

#pragma mark - 时间范围
- (void)pickTimeRange {
    UIAlertController *al = [UIAlertController alertControllerWithTitle:@"时间范围"
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *names = @[@"全部", @"最近 5 分钟", @"最近 1 分钟", @"最近 30 秒"];
    for (NSInteger i = 0; i < names.count; i++) {
        [al addAction:[UIAlertAction actionWithTitle:names[i]
            style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
            self.timeRange = i;
            self.timeBtn.title = (i == 0) ? @"全部" : names[i];
            [self applyFilter];
        }]];
    }
    [al addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if (al.popoverPresentationController) {
        al.popoverPresentationController.barButtonItem = self.timeBtn;
    }
    [self presentViewController:al animated:YES completion:nil];
}

- (void)paintChips {
    for (CHChip *c in self.chips) {
        BOOL sel;
        if ([c.key isEqualToString:@"SESS"]) sel = self.groupBySession;
        else sel = (c.key.length == 0 && self.filter.length == 0) ||
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
    if ([c.key isEqualToString:@"SESS"]) {
        // 「会话」是显示模式，跟分类互斥
        self.groupBySession = !self.groupBySession;
        if (self.groupBySession) self.filter = nil;   // 选会话 -> 清掉分类
    } else {
        self.filter = c.key.length ? c.key : nil;
        self.groupBySession = NO;                     // 选分类 -> 关掉会话
    }
    [self paintChips];
    [self applyFilter];
}

- (void)searchBar:(UISearchBar *)sb textDidChange:(NSString *)text {
    self.keyword = text.length ? text : nil;
    [self applyFilter];
}
- (void)searchBarTextDidBeginEditing:(UISearchBar *)sb { self.searchBarActive = YES; }
- (void)searchBarTextDidEndEditing:(UISearchBar *)sb { self.searchBarActive = NO; }
- (void)searchBarSearchButtonClicked:(UISearchBar *)sb {
    self.searchBarActive = NO;
    [sb resignFirstResponder];
}

- (void)applyFilter {
    NSString *f = self.filter, *kw = self.keyword;

    // 时间范围
    NSTimeInterval cutoff = 0;
    if (self.timeRange == 1) cutoff = [NSDate date].timeIntervalSince1970 - 300;
    else if (self.timeRange == 2) cutoff = [NSDate date].timeIntervalSince1970 - 60;
    else if (self.timeRange == 3) cutoff = [NSDate date].timeIntervalSince1970 - 30;

    NSMutableArray *out = [NSMutableArray array];
    for (CHRecord *r in self.allRecords) {
        if (cutoff > 0 && r.lastT > 0 && r.lastT < cutoff) continue;
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
    // ★ 会话归组：把同一调用点的记录聚到一起（连续显示）
    if (self.groupBySession) {
        [out sortUsingComparator:^NSComparisonResult(CHRecord *a, CHRecord *b) {
            NSString *ca = a.raw[@"caller"] ?: @"";
            NSString *cb = b.raw[@"caller"] ?: @"";
            NSComparisonResult r = [ca compare:cb];
            if (r != NSOrderedSame) return r;
            return a.t > b.t ? NSOrderedAscending : (a.t < b.t ? NSOrderedDescending : NSOrderedSame);
        }];
    }

    self.records = out;
    [self rebuildRows];
    self.empty.hidden = (out.count > 0);
    [self.table reloadData];
}

/// 依据展开状态，把 records 摊平成 rows（展开的项插入其子项）
- (void)rebuildRows {
    [self.rows removeAllObjects];
    [self.rowIsDup removeAllObjects];
    [self.rowDupIdx removeAllObjects];
    for (CHRecord *r in self.records) {
        [self.rows addObject:r];
        [self.rowIsDup addObject:@NO];
        [self.rowDupIdx addObject:@(-1)];
        if (r.count > 1 && [self.expandedKeys containsObject:r.dedupKey]) {
            // ★ 子项按时间正序（早 -> 晚）
            NSArray *sortedDups = [r.dups sortedArrayUsingComparator:^NSComparisonResult(CHRecord *a, CHRecord *b) {
                return a.t < b.t ? NSOrderedAscending : (a.t > b.t ? NSOrderedDescending : NSOrderedSame);
            }];
            NSInteger i = 0;
            for (CHRecord *d in sortedDups) {
                [self.rows addObject:d];
                [self.rowIsDup addObject:@YES];
                [self.rowDupIdx addObject:@(i++)];
            }
        }
    }
}

- (CHRecord *)rowRecord:(NSIndexPath *)ip {
    if (ip.row < (NSInteger)self.rows.count) return self.rows[ip.row];
    return nil;
}
- (BOOL)rowIsDupAt:(NSIndexPath *)ip {
    if (ip.row < (NSInteger)self.rowIsDup.count) return [self.rowIsDup[ip.row] boolValue];
    return NO;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.ticker invalidate]; self.ticker = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!self.ticker) [self startTicker];
}

- (void)load {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *r = [CHScanner recordsForApp:self.app limit:8000 aggregate:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allRecords = r;
            [self applyFilter];
            [self.refresh endRefreshing];
        });
    });
}

- (void)showMore {
    UIAlertController *al = [UIAlertController alertControllerWithTitle:nil
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [al addAction:[UIAlertAction actionWithTitle:@"导出记录 (.txt)"
                          style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *a){ [self exportAll]; }]];
    [al addAction:[UIAlertAction actionWithTitle:@"导出分析报告 (.md)"
                          style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *a){ [self exportReport]; }]];
    [al addAction:[UIAlertAction actionWithTitle:@"清空这个 App 的记录"
                          style:UIAlertActionStyleDestructive
                        handler:^(UIAlertAction *a){ [self confirmClearApp]; }]];
    [al addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if (al.popoverPresentationController) {
        al.popoverPresentationController.sourceView = self.view;
        al.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width - 30, 40, 1, 1);
    }
    [self presentViewController:al animated:YES completion:nil];
}

- (void)confirmClearApp {
    NSInteger total = self.allRecords.count;
    UIAlertController *al = [UIAlertController alertControllerWithTitle:@"清空记录"
        message:[NSString stringWithFormat:@"删除 %@ 的全部 %ld 条记录？不可恢复。",
                 self.app.name ?: @"该 App", (long)total]
        preferredStyle:UIAlertControllerStyleAlert];
    [al addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [al addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *a){
        NSInteger n = [CHScanner clearApp:self.app];
        self.allRecords = @[]; self.records = @[];
        self.empty.hidden = NO;
        [self.table reloadData];
        NSLog(@"[CryptoViewer] 清空 %ld 个日志文件", (long)n);
    }]];
    [self presentViewController:al animated:YES completion:nil];
}

- (void)exportAll {
    NSString *txt = [self buildText];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"%@_hook.txt", self.app.bid ?: @"records"]];
    [txt writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self shareFiles:@[[NSURL fileURLWithPath:path]]];
}

/// 生成可读的 txt 报告
- (NSString *)buildText {
    NSMutableString *s = [NSMutableString string];
    NSDateFormatter *df = [NSDateFormatter new];
    df.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";

    [s appendString:@"========================================\n"];
    [s appendFormat:@"  %@  ·  Hook 记录导出\n", self.app.name ?: @"App"];
    [s appendFormat:@"  Bundle ID : %@\n", self.app.bid ?: @"?"];
    [s appendFormat:@"  导出时间  : %@\n", [df stringFromDate:[NSDate date]]];
    [s appendFormat:@"  记录条数  : %ld\n", (long)self.records.count];
    [s appendString:@"========================================\n\n"];

    NSInteger idx = 0;
    for (CHRecord *r in self.records) {
        idx++;
        [s appendFormat:@"───────────────────────────────────────\n"];
        [s appendFormat:@"[%ld] %@  (%@)\n", (long)idx, r.title, r.layer];
        NSString *op = [r opTag], *algo = [r algoTag];
        if (op.length)   [s appendFormat:@"  操作    : %@\n", op];
        if (algo.length) [s appendFormat:@"  算法    : %@\n", algo];
        [s appendFormat:@"  时间    : %@\n", [df stringFromDate:r.date]];
        if (r.count > 1) [s appendFormat:@"  次数    : ×%ld\n", (long)r.count];

        NSDictionary *raw = r.raw;
        // 按语义顺序输出
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
            id v = raw[k];
            if (!v) continue;
            NSString *sv = [v isKindOfClass:[NSString class]] ? v : [v description];
            if (sv.length == 0) continue;
            [s appendFormat:@"  %-8s: %@\n", [names[k] UTF8String], sv];
        }
        NSArray *bt = raw[@"bt"];
        if ([bt isKindOfClass:[NSArray class]] && bt.count) {
            [s appendString:@"  调用栈  :\n"];
            for (NSInteger i = 0; i < (NSInteger)bt.count; i++)
                [s appendFormat:@"      %2ld  %@\n", (long)i, bt[i]];
        }
        [s appendString:@"\n"];
    }
    [s appendString:@"—— 由 AzbcpxTuT 导出 ——\n"];
    return s;
}

/// 生成 Markdown 分析报告
- (void)exportReport {
    NSDateFormatter *df = [NSDateFormatter new];
    df.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSMutableString *m = [NSMutableString string];

    [m appendFormat:@"# %@ — Hook 分析报告\n\n", self.app.name ?: @"App"];
    [m appendFormat:@"- **Bundle ID**: `%@`\n", self.app.bid ?: @"?"];
    [m appendFormat:@"- **导出时间**: %@\n", [df stringFromDate:[NSDate date]]];
    [m appendFormat:@"- **记录条数**: %ld\n", (long)self.records.count];
    [m appendString:@"- **工具**: AzbcpxTuT\n\n"];

    // ── ① 域名 / URL ──
    NSMutableOrderedSet *urls = [NSMutableOrderedSet orderedSet];
    for (CHRecord *r in self.records) {
        NSString *u = r.raw[@"url"];
        if ([u isKindOfClass:[NSString class]] && u.length) [urls addObject:u];
        NSString *t = r.raw[@"text"];
        if ([t isKindOfClass:[NSString class]] &&
            ([t hasPrefix:@"http"] || [t containsString:@".com"] || [t containsString:@".cn"]))
            [urls addObject:t];
    }
    if (urls.count) {
        [m appendString:@"## 域名 / URL\n\n```\n"];
        for (NSString *u in urls) [m appendFormat:@"%@\n", u];
        [m appendString:@"```\n\n"];
    }

    // ── ② 算法与密钥 ──
    NSMutableOrderedSet *algos = [NSMutableOrderedSet orderedSet];
    NSMutableOrderedSet *keys  = [NSMutableOrderedSet orderedSet];
    NSMutableOrderedSet *ivs   = [NSMutableOrderedSet orderedSet];
    for (CHRecord *r in self.records) {
        NSString *a = [r algoTag];
        if (a.length) [algos addObject:a];
        NSString *k = r.raw[@"key"];
        if ([k isKindOfClass:[NSString class]] && k.length) [keys addObject:k];
        NSString *v = r.raw[@"iv"];
        if ([v isKindOfClass:[NSString class]] && v.length) [ivs addObject:v];
    }
    [m appendString:@"## 加密算法\n\n"];
    if (algos.count) { for (NSString *a in algos) [m appendFormat:@"- `%@`\n", a]; }
    else [m appendString:@"- （无）\n"];
    [m appendString:@"\n"];

    if (keys.count) {
        [m appendString:@"## 密钥 KEY\n\n```\n"];
        for (NSString *k in keys) [m appendFormat:@"%@\n", k];
        [m appendString:@"```\n\n"];
    }
    if (ivs.count) {
        [m appendString:@"## 初始向量 IV\n\n```\n"];
        for (NSString *v in ivs) [m appendFormat:@"%@\n", v];
        [m appendString:@"```\n\n"];
    }

    // ── ③ Hook 点（调用栈）──
    NSMutableOrderedSet *hooks = [NSMutableOrderedSet orderedSet];
    for (CHRecord *r in self.records) {
        NSArray *bt = r.raw[@"bt"];
        if ([bt isKindOfClass:[NSArray class]] && bt.count) [hooks addObject:bt.firstObject];
        else if (r.raw[@"caller"]) [hooks addObject:r.raw[@"caller"]];
    }
    if (hooks.count) {
        [m appendString:@"## Hook 点（调用位置）\n\n```\n"];
        for (NSString *h in hooks) [m appendFormat:@"%@\n", h];
        [m appendString:@"```\n\n"];
    }

    // ── ④ 时间线（前 100 条）──
    [m appendString:@"## 时间线\n\n```\n"];
    NSInteger n = 0;
    for (CHRecord *r in self.records) {
        if (++n > 100) { [m appendString:@"...\n"]; break; }
        [m appendFormat:@"%@  [%@] %-16s %@\n",
         [df stringFromDate:r.date], r.layer, [[r title] UTF8String], r.subtitle ?: @""];
    }
    [m appendString:@"```\n\n"];

    [m appendString:@"---\n\n*由 AzbcpxTuT 自动生成*\n"];

    NSString *name = [NSString stringWithFormat:@"%@_report.md", self.app.bid ?: @"report"];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    [m writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self shareFiles:@[[NSURL fileURLWithPath:path]]];
}

- (void)shareFiles:(NSArray *)items {
    UIActivityViewController *av = [[UIActivityViewController alloc]
        initWithActivityItems:items applicationActivities:nil];
    if (av.popoverPresentationController) {
        av.popoverPresentationController.sourceView = self.view;
        av.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width - 30, 40, 1, 1);
    }
    [self presentViewController:av animated:YES completion:nil];
}

#pragma mark - Table
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.rows.count; }

- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)ip {
    if ([self rowIsDupAt:ip]) return 46;   // ★ 子项紧凑固定高
    return UITableViewAutomaticDimension;
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"rec";
    CHRecCell *c = [t dequeueReusableCellWithIdentifier:cid];
    if (!c) c = [[CHRecCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
    CHRecord *rec = [self rowRecord:ip];
    if ([self rowIsDupAt:ip]) {
        // ★ 子项走独立紧凑 cell
        static NSString *did = @"dup";
        CHDupCell *dc = [t dequeueReusableCellWithIdentifier:did];
        if (!dc) dc = [[CHDupCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:did];
        NSInteger di = (ip.row < (NSInteger)self.rowDupIdx.count) ? [self.rowDupIdx[ip.row] integerValue] : 0;
        [dc configWith:rec idx:di color:[CHTheme colorForLayer:rec.layer]];
        return dc;
    }
    [c configWith:rec keyword:self.keyword];
    c.leadingShift = 0;
    c.alphaDim = NO;
    return c;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    CHRecord *r = [self rowRecord:ip];
    if (!r) return;

    // 折叠态点聚合项 -> 就地展开；展开态再点 -> 收起
    if (![self rowIsDupAt:ip] && r.count > 1) {
        NSString *k = r.dedupKey;
        if ([self.expandedKeys containsObject:k]) [self.expandedKeys removeObject:k];
        else [self.expandedKeys addObject:k];
        [self rebuildRows];
        [t reloadData];
        return;
    }
    // 子项 / 单条 -> 进详情
    CHRecordDetailVC *d = [CHRecordDetailVC new];
    d.record = r;
    [self.navigationController pushViewController:d animated:YES];
}

#pragma mark - 删除
- (BOOL)tableView:(UITableView *)t canEditRowAtIndexPath:(NSIndexPath *)ip { return YES; }

- (void)tableView:(UITableView *)t
    commitEditingStyle:(UITableViewCellEditingStyle)style
     forRowAtIndexPath:(NSIndexPath *)ip {
    if (style != UITableViewCellEditingStyleDelete) return;
    CHRecord *r = [self rowRecord:ip];
    if (!r) return;
    NSInteger n = [CHScanner deleteRecords:@[r]];
    // 本地同步移除
    NSMutableArray *all = [self.allRecords mutableCopy];
    [all removeObject:r];
    self.allRecords = all;
    [self applyFilter];
    NSLog(@"[CryptoViewer] 删除记录 %ld 条(含聚合)", (long)n);
}

// 右键菜单也提供删除
- (UISwipeActionsConfiguration *)tableView:(UITableView *)t
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)ip {
    CHRecord *r = self.records[ip.row];
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
        title:@"删除" handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        [CHScanner deleteRecords:@[r]];
        NSMutableArray *arr = [self.records mutableCopy];
        [arr removeObjectAtIndex:ip.row];
        self.records = arr;
        [t deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationFade];
        done(YES);
    }];
    del.backgroundColor = CH_RED;
    return [UISwipeActionsConfiguration configurationWithActions:@[del]];
}

@end
