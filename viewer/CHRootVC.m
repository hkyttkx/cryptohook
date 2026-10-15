// CHRootVC.m — App 列表（深色科技风）
#import "CHRootVC.h"
#import "CHServices.h"
#import "CHModels.h"
#import "CHTheme.h"
#import "CHDetailVC.h"

#pragma mark - Cell
@interface CHAppCell : UITableViewCell
@property (nonatomic, strong) UIView      *card;
@property (nonatomic, strong) UIView      *bar;        // 左侧霓虹竖条
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel     *nameLabel;
@property (nonatomic, strong) UILabel     *bidLabel;
@property (nonatomic, strong) UILabel     *badge;
- (void)setBadgeText:(NSString *)t;
@end

@implementation CHAppCell

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

        _iconView = [UIImageView new];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.layer.cornerRadius = 10;
        _iconView.layer.cornerCurve = kCACornerCurveContinuous;
        _iconView.clipsToBounds = YES;
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_iconView];

        _nameLabel = [UILabel new];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_nameLabel];

        _bidLabel = [UILabel new];
        _bidLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        _bidLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_bidLabel];

        _badge = [UILabel new];
        _badge.textAlignment = NSTextAlignmentCenter;
        _badge.layer.cornerRadius = 9;
        _badge.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
        _badge.clipsToBounds = NO;
        _badge.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_badge];

        [NSLayoutConstraint activateConstraints:@[
            [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4],
            [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4],

            [_bar.leadingAnchor  constraintEqualToAnchor:_card.leadingAnchor constant:0],
            [_bar.topAnchor      constraintEqualToAnchor:_card.topAnchor constant:12],
            [_bar.bottomAnchor   constraintEqualToAnchor:_card.bottomAnchor constant:-12],
            [_bar.widthAnchor    constraintEqualToConstant:2],

            [_iconView.leadingAnchor constraintEqualToAnchor:_bar.trailingAnchor constant:12],
            [_iconView.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_iconView.widthAnchor  constraintEqualToConstant:40],
            [_iconView.heightAnchor constraintEqualToConstant:40],

            [_nameLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
            [_nameLabel.topAnchor     constraintEqualToAnchor:_iconView.topAnchor constant:0],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_badge.leadingAnchor constant:-10],

            [_bidLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_bidLabel.topAnchor     constraintEqualToAnchor:_nameLabel.bottomAnchor constant:4],
            [_bidLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_badge.leadingAnchor constant:-10],

            [_badge.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
            [_badge.centerYAnchor  constraintEqualToAnchor:_card.centerYAnchor],
            [_badge.widthAnchor    constraintGreaterThanOrEqualToConstant:36],
            [_badge.heightAnchor   constraintEqualToConstant:20],
        ]];
    }
    return self;
}

- (void)configWith:(CHApp *)a {
    self.nameLabel.attributedText = [CHTheme tracked:a.name
        font:[CHTheme mono:15 weight:UIFontWeightSemibold]
        color:CH_TEXT spacing:0.4];
    self.bidLabel.attributedText = [CHTheme tracked:a.bid
        font:[CHTheme mono:10.5 weight:UIFontWeightRegular]
        color:CH_SUB spacing:0.2];

    BOOL hooked = a.recordCount > 0;
    self.bar.backgroundColor = hooked ? CH_ACCENT : CH_LINE;
    if (hooked) [CHTheme glow:self.bar color:CH_ACCENT radius:4 opacity:0.9];
    else self.bar.layer.shadowOpacity = 0;

    if (a.icon) {
        self.iconView.image = a.icon;
        self.iconView.layer.borderWidth = 0;
    } else {
        self.iconView.image = [UIImage systemImageNamed:@"square.grid.2x2"];
        self.iconView.tintColor = CH_SUB;
        self.iconView.backgroundColor = CH_BG2;
    }
    [self setBadgeText:hooked ? [NSString stringWithFormat:@"%ld", (long)a.recordCount] : nil];
}

- (void)setBadgeText:(NSString *)t {
    if (t.length == 0) { self.badge.hidden = YES; return; }
    self.badge.hidden = NO;
    self.badge.attributedText = [CHTheme tracked:t
        font:[CHTheme mono:11 weight:UIFontWeightBold]
        color:CH_ACCENT spacing:0.5];
    self.badge.layer.borderColor = [CH_ACCENT colorWithAlphaComponent:0.5].CGColor;
    self.badge.backgroundColor = [CH_ACCENT colorWithAlphaComponent:0.10];
    [CHTheme glow:self.badge color:CH_ACCENT radius:5 opacity:0.5];
}
@end

#pragma mark - VC
@interface CHRootVC () <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UIRefreshControl *refresh;
@property (nonatomic, strong) UISearchController *search;
@property (nonatomic, strong) NSArray<CHApp *> *hooked;
@property (nonatomic, strong) NSArray<CHApp *> *others;
@property (nonatomic, copy)   NSString *keyword;
@end

@implementation CHRootVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CH_BG;
    if (@available(iOS 13.0, *)) self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    // 标题（等宽 + 字距）
    self.navigationItem.titleView = ({
        UILabel *l = [UILabel new];
        l.attributedText = [CHTheme tracked:@"CRYPTOHOOK"
            font:[CHTheme mono:15 weight:UIFontWeightBold] color:CH_ACCENT spacing:2.0];
        l;
    });

    // 顶部渐变光晕（用 CAGradientLayer 作 layerClass，避免 mask 白条）
    CHGradientView *halo = [CHGradientView new];
    halo.translatesAutoresizingMaskIntoConstraints = NO;
    halo.userInteractionEnabled = NO;
    CAGradientLayer *gl = (CAGradientLayer *)halo.layer;
    gl.colors = @[(__bridge id)[CH_ACCENT colorWithAlphaComponent:0.13].CGColor,
                  (__bridge id)[CH_ACCENT colorWithAlphaComponent:0.03].CGColor,
                  (__bridge id)[CH_BG colorWithAlphaComponent:0.0].CGColor];
    gl.locations = @[@0.0, @0.45, @1.0];
    gl.startPoint = CGPointMake(0.5, 0);
    gl.endPoint   = CGPointMake(0.5, 1);
    [self.view addSubview:halo];
    [NSLayoutConstraint activateConstraints:@[
        [halo.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [halo.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [halo.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [halo.heightAnchor constraintEqualToConstant:220],
    ]];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.backgroundColor = [UIColor clearColor];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.rowHeight = 74;
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
    [self.refresh addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
    self.table.refreshControl = self.refresh;

    self.search = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.search.searchResultsUpdater = self;
    self.search.obscuresBackgroundDuringPresentation = NO;
    self.search.searchBar.placeholder = @"搜索 App";
    self.search.searchBar.tintColor = CH_ACCENT;
    if (@available(iOS 13.0, *)) {
        self.search.searchBar.searchTextField.backgroundColor = CH_CARD;
        self.search.searchBar.searchTextField.textColor = CH_TEXT;
        self.search.searchBar.searchTextField.font = [CHTheme mono:13 weight:UIFontWeightRegular];
    }
    self.navigationItem.searchController = self.search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;

    [self reload];
}

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self reload]; }

- (void)reload {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *all = [CHScanner allApps];
        NSMutableArray *h = [NSMutableArray array], *o = [NSMutableArray array];
        NSString *kw = self.keyword;
        for (CHApp *a in all) {
            if (kw.length) {
                BOOL m = [[a.name lowercaseString] containsString:[kw lowercaseString]] ||
                         [[a.bid  lowercaseString] containsString:[kw lowercaseString]];
                if (!m) continue;
            }
            NSMutableArray *dest = (a.recordCount > 0) ? h : o;
            [dest addObject:a];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.hooked = h; self.others = o;
            [self.table reloadData];
            [self.refresh endRefreshing];
        });
    });
}

- (void)updateSearchResultsForSearchController:(UISearchController *)sc {
    self.keyword = sc.searchBar.text;
    [self reload];
}

#pragma mark - Table
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 2; }

- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)s {
    NSString *txt = (s == 0)
        ? (self.hooked.count ? [NSString stringWithFormat:@"● 已拦截 · %lu", (unsigned long)self.hooked.count] : nil)
        : (self.others.count ? [NSString stringWithFormat:@"○ 其他应用 · %lu", (unsigned long)self.others.count] : nil);
    if (!txt) return nil;
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, t.bounds.size.width, 34)];
    v.backgroundColor = [UIColor clearColor];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(22, 12, t.bounds.size.width - 40, 20)];
    l.attributedText = [CHTheme tracked:txt
        font:[CHTheme mono:11 weight:UIFontWeightSemibold]
        color:(s == 0 ? CH_ACCENT : CH_SUB) spacing:1.2];
    [v addSubview:l];
    return v;
}
- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s { return 34; }

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    return s == 0 ? self.hooked.count : self.others.count;
}
- (CHApp *)appAt:(NSIndexPath *)ip {
    return ip.section == 0 ? self.hooked[ip.row] : self.others[ip.row];
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"app";
    CHAppCell *c = [t dequeueReusableCellWithIdentifier:cid];
    if (!c) c = [[CHAppCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
    [c configWith:[self appAt:ip]];
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    CHApp *a = [self appAt:ip];
    CHDetailVC *d = [CHDetailVC new];
    d.app = a;
    [self.navigationController pushViewController:d animated:YES];
}

@end
