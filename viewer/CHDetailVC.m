// CHDetailVC.m — 记录流（按 layer 染色，点击复制）
#import "CHDetailVC.h"
#import "CHServices.h"
#import "CHTheme.h"

@interface CHRecCell : UITableViewCell
@property (nonatomic, strong) UIView *bar;       // 左侧竖条（layer 色）
@property (nonatomic, strong) UIImageView *ico;
@property (nonatomic, strong) UILabel *titleL;
@property (nonatomic, strong) UILabel *subL;
@property (nonatomic, strong) UILabel *detailL;
@property (nonatomic, strong) UILabel *timeL;
@end

@implementation CHRecCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [CHTheme card];
        self.selectionStyle = UITableViewCellSelectionStyleDefault;

        _bar = [UIView new];
        _bar.layer.cornerRadius = 1.5;
        _bar.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_bar];

        _ico = [UIImageView new];
        _ico.contentMode = UIViewContentModeScaleAspectFit;
        _ico.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_ico];

        _titleL = [UILabel new];
        _titleL.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _titleL.textColor = [CHTheme text];
        _titleL.numberOfLines = 1;
        _titleL.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_titleL];

        _timeL = [UILabel new];
        _timeL.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightRegular];
        _timeL.textColor = [CHTheme sub];
        _timeL.textAlignment = NSTextAlignmentRight;
        _timeL.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_timeL];

        _subL = [UILabel new];
        _subL.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        _subL.textColor = [CHTheme sub];
        _subL.numberOfLines = 2;
        _subL.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_subL];

        _detailL = [UILabel new];
        _detailL.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
        _detailL.textColor = [CHTheme text];
        _detailL.numberOfLines = 6;
        _detailL.lineBreakMode = NSLineBreakByTruncatingTail;
        _detailL.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_detailL];

        [NSLayoutConstraint activateConstraints:@[
            [_bar.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:6],
            [_bar.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
            [_bar.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
            [_bar.widthAnchor constraintEqualToConstant:3],

            [_ico.leadingAnchor constraintEqualToAnchor:_bar.trailingAnchor constant:10],
            [_ico.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
            [_ico.widthAnchor constraintEqualToConstant:18],
            [_ico.heightAnchor constraintEqualToConstant:18],

            [_titleL.leadingAnchor constraintEqualToAnchor:_ico.trailingAnchor constant:8],
            [_titleL.centerYAnchor constraintEqualToAnchor:_ico.centerYAnchor],
            [_titleL.trailingAnchor constraintLessThanOrEqualToAnchor:_timeL.leadingAnchor constant:-8],

            [_timeL.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_timeL.centerYAnchor constraintEqualToAnchor:_ico.centerYAnchor],

            [_subL.leadingAnchor constraintEqualToAnchor:_titleL.leadingAnchor],
            [_subL.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_subL.topAnchor constraintEqualToAnchor:_ico.bottomAnchor constant:6],

            [_detailL.leadingAnchor constraintEqualToAnchor:_titleL.leadingAnchor],
            [_detailL.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_detailL.topAnchor constraintEqualToAnchor:_subL.bottomAnchor constant:6],
            [_detailL.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
        ]];
    }
    return self;
}
@end

@interface CHDetailVC () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSArray<CHRecord *> *records;
@property (nonatomic, strong) UILabel *empty;
@property (nonatomic, strong) UIRefreshControl *refresh;
@end

@implementation CHDetailVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.app.name ?: @"记录";
    self.view.backgroundColor = [CHTheme bg];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.backgroundColor = [CHTheme bg];
    self.table.rowHeight = UITableViewAutomaticDimension;
    self.table.estimatedRowHeight = 120;
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.table];
    [NSLayoutConstraint activateConstraints:@[
        [self.table.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    self.refresh = [UIRefreshControl new];
    [self.refresh addTarget:self action:@selector(load) forControlEvents:UIControlEventValueChanged];
    self.table.refreshControl = self.refresh;

    // 空状态
    self.empty = [UILabel new];
    self.empty.text = @"暂无记录\n\n把 CryptoHook.dylib 注入这个 App\n然后启动它触发加解密";
    self.empty.numberOfLines = 0;
    self.empty.textAlignment = NSTextAlignmentCenter;
    self.empty.textColor = [CHTheme sub];
    self.empty.font = [UIFont systemFontOfSize:15];
    self.empty.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.empty];
    [NSLayoutConstraint activateConstraints:@[
        [self.empty.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.empty.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-40],
        [self.empty.widthAnchor constraintEqualToConstant:280],
    ]];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up"]
                style:UIBarButtonItemStylePlain
               target:self action:@selector(exportAll)];

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
    for (CHRecord *r in self.records) {
        [s appendFormat:@"[%@] %@\n  %@\n  %@\n\n", r.layer, r.title, r.subtitle, r.detail];
    }
    UIActivityViewController *av = [[UIActivityViewController alloc]
        initWithActivityItems:@[s] applicationActivities:nil];
    [self presentViewController:av animated:YES completion:nil];
}

#pragma mark - Table
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    return self.records.count;
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"rec";
    CHRecCell *c = [t dequeueReusableCellWithIdentifier:cid];
    if (!c) c = [[CHRecCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
    CHRecord *r = self.records[ip.row];

    UIColor *col = [CHTheme colorForLayer:r.layer];
    c.bar.backgroundColor = col;
    c.ico.image = [UIImage systemImageNamed:[CHTheme symbolForLayer:r.layer]];
    c.ico.tintColor = col;
    c.titleL.text = r.title;
    c.subL.text = r.subtitle;
    c.detailL.text = r.detail;
    c.detailL.hidden = (r.detail.length == 0);

    static NSDateFormatter *df = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        df = [NSDateFormatter new];
        df.dateFormat = @"HH:mm:ss.SSS";
    });
    c.timeL.text = [df stringFromDate:r.date];
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
