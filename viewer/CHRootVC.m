// CHRootVC.m — App 列表（已 Hook 分组置顶）
#import "CHRootVC.h"
#import "CHServices.h"
#import "CHModels.h"
#import "CHTheme.h"
#import "CHDetailVC.h"

@interface CHAppCell : UITableViewCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *bidLabel;
@property (nonatomic, strong) UILabel *badge;
@end

@implementation CHAppCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        _iconView = [UIImageView new];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.layer.cornerRadius = 11;
        _iconView.layer.cornerCurve = kCACornerCurveContinuous;
        _iconView.clipsToBounds = YES;
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_iconView];

        _nameLabel = [UILabel new];
        _nameLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        _nameLabel.textColor = [CHTheme text];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_nameLabel];

        _bidLabel = [UILabel new];
        _bidLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        _bidLabel.textColor = [CHTheme sub];
        _bidLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        _bidLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_bidLabel];

        _badge = [UILabel new];
        _badge.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        _badge.textColor = [UIColor whiteColor];
        _badge.backgroundColor = [CHTheme accent];
        _badge.textAlignment = NSTextAlignmentCenter;
        _badge.layer.cornerRadius = 11;
        _badge.layer.cornerCurve = kCACornerCurveContinuous;
        _badge.clipsToBounds = YES;
        _badge.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_badge];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:44],
            [_iconView.heightAnchor constraintEqualToConstant:44],

            [_nameLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
            [_nameLabel.topAnchor constraintEqualToAnchor:_iconView.topAnchor constant:1],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_badge.leadingAnchor constant:-8],

            [_bidLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_bidLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:3],
            [_bidLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_badge.leadingAnchor constant:-8],

            [_badge.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
            [_badge.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_badge.widthAnchor constraintGreaterThanOrEqualToConstant:34],
            [_badge.heightAnchor constraintEqualToConstant:22],
        ]];
    }
    return self;
}
- (void)setBadgeText:(NSString *)t {
    self.badge.text = t;
    self.badge.hidden = (t.length == 0);
}
@end

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
    self.title = @"CryptoHook";
    self.view.backgroundColor = [CHTheme bg];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.backgroundColor = [CHTheme bg];
    self.table.rowHeight = 68;
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.table];
    [NSLayoutConstraint activateConstraints:@[
        [self.table.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    self.refresh = [UIRefreshControl new];
    [self.refresh addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
    self.table.refreshControl = self.refresh;

    self.search = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.search.searchResultsUpdater = self;
    self.search.obscuresBackgroundDuringPresentation = NO;
    self.search.searchBar.placeholder = @"搜索 App 名称或 Bundle ID";
    self.navigationItem.searchController = self.search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;

    [self reload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
}

- (void)reload {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *all = [CHScanner allApps];
        NSMutableArray *h = [NSMutableArray array], *o = [NSMutableArray array];
        NSString *kw = self.keyword;
        for (CHApp *a in all) {
            if (kw.length) {
                BOOL m = [[a.name lowercaseString] containsString:[kw lowercaseString]] ||
                         [[a.bid lowercaseString] containsString:[kw lowercaseString]];
                if (!m) continue;
            }
            (a.recordCount > 0 ? h : o).addObject(a];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.hooked = h;
            self.others = o;
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

- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    if (s == 0) return self.hooked.count ? [NSString stringWithFormat:@"已 Hook · %lu", (unsigned long)self.hooked.count] : nil;
    return self.others.count ? [NSString stringWithFormat:@"其他 App · %lu", (unsigned long)self.others.count] : nil;
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    return s == 0 ? self.hooked.count : self.others.count;
}

- (CHApp *)appAtIndexPath:(NSIndexPath *)ip {
    return ip.section == 0 ? self.hooked[ip.row] : self.others[ip.row];
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"app";
    CHAppCell *c = [t dequeueReusableCellWithIdentifier:cid];
    if (!c) c = [[CHAppCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
    CHApp *a = [self appAtIndexPath:ip];
    c.nameLabel.text = a.name;
    c.bidLabel.text = a.bid;
    c.iconView.image = a.icon ?: [UIImage systemImageNamed:@"app.dashed"];
    c.iconView.tintColor = [CHTheme sub];
    [c setBadgeText:a.recordCount > 0 ? [NSString stringWithFormat:@"%ld", (long)a.recordCount] : nil];
    return c;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    CHApp *a = [self appAtIndexPath:ip];
    CHDetailVC *d = [CHDetailVC new];
    d.app = a;
    [self.navigationController pushViewController:d animated:YES];
}

@end
