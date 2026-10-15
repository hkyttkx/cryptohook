// CHSplashVC.m — 启动页：圆形头像 + 文字
#import "CHSplashVC.h"
#import "CHTheme.h"
#import <QuartzCore/QuartzCore.h>

@interface CHSplashVC ()
@property (nonatomic, strong) UIView *avatarWrap;
@property (nonatomic, strong) UIImageView *avatar;
@property (nonatomic, strong) CAGradientLayer *glowLayer;
@property (nonatomic, strong) UILabel *titleL;
@property (nonatomic, strong) UILabel *subL;
@property (nonatomic, strong) UIView *bar;
@property (nonatomic, strong) UIView *track;
@end

@implementation CHSplashVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CH_BG;
    if (@available(iOS 13.0, *)) self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    // 顶部微光（直接挂在 self.view.layer 上，避免多余视图层级）
    self.glowLayer = [CAGradientLayer layer];
    self.glowLayer.colors = @[(__bridge id)[CH_ACCENT colorWithAlphaComponent:0.10].CGColor,
                              (__bridge id)[CH_BG colorWithAlphaComponent:0.0].CGColor];
    self.glowLayer.startPoint = CGPointMake(0.5, 0);
    self.glowLayer.endPoint   = CGPointMake(0.5, 1);
    [self.view.layer addSublayer:self.glowLayer];

    // ── 圆形头像 ──
    CGFloat S = 132;
    self.avatarWrap = [UIView new];
    self.avatarWrap.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.avatarWrap];
    // 发光放在外层容器（avatar 自己 clipsToBounds 会裁掉阴影）
    [CHTheme glow:self.avatarWrap color:CH_ACCENT radius:16 opacity:0.40];

    self.avatar = [[UIImageView alloc] init];
    self.avatar.contentMode = UIViewContentModeScaleAspectFill;
    self.avatar.clipsToBounds = YES;
    self.avatar.layer.cornerRadius = S / 2.0;
    self.avatar.layer.cornerCurve = kCACornerCurveCircular;
    self.avatar.layer.borderWidth = 2.0;
    self.avatar.layer.borderColor = [CH_ACCENT colorWithAlphaComponent:0.55].CGColor;
    self.avatar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.avatarWrap addSubview:self.avatar];

    UIImage *img = [UIImage imageNamed:@"splash"];
    if (!img) {
        NSString *p = [[NSBundle mainBundle] pathForResource:@"splash" ofType:@"jpg"];
        if (p) img = [UIImage imageWithContentsOfFile:p];
    }
    self.avatar.image = img;

    [NSLayoutConstraint activateConstraints:@[
        [self.avatarWrap.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.avatarWrap.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-70],
        [self.avatarWrap.widthAnchor constraintEqualToConstant:S],
        [self.avatarWrap.heightAnchor constraintEqualToConstant:S],
        [self.avatar.topAnchor constraintEqualToAnchor:self.avatarWrap.topAnchor],
        [self.avatar.bottomAnchor constraintEqualToAnchor:self.avatarWrap.bottomAnchor],
        [self.avatar.leadingAnchor constraintEqualToAnchor:self.avatarWrap.leadingAnchor],
        [self.avatar.trailingAnchor constraintEqualToAnchor:self.avatarWrap.trailingAnchor],
    ]];

    // ── 文字 ──
    self.titleL = [UILabel new];
    self.titleL.textAlignment = NSTextAlignmentCenter;
    self.titleL.alpha = 0.0;
    self.titleL.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.titleL];

    self.subL = [UILabel new];
    self.subL.textAlignment = NSTextAlignmentCenter;
    self.subL.alpha = 0.0;
    self.subL.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.subL];

    // ── 进度条 ──
    self.track = [UIView new];
    self.track.backgroundColor = [CH_LINE colorWithAlphaComponent:0.6];
    self.track.layer.cornerRadius = 1.5;
    self.track.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.track];

    self.bar = [UIView new];
    self.bar.backgroundColor = CH_ACCENT;
    self.bar.layer.cornerRadius = 1.5;
    [CHTheme glow:self.bar color:CH_ACCENT radius:6 opacity:0.9];
    self.bar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.bar];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleL.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.titleL.topAnchor constraintEqualToAnchor:self.avatarWrap.bottomAnchor constant:28],

        [self.subL.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.subL.topAnchor constraintEqualToAnchor:self.titleL.bottomAnchor constant:10],

        [self.track.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.track.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-70],
        [self.track.widthAnchor constraintEqualToConstant:120],
        [self.track.heightAnchor constraintEqualToConstant:3],

        [self.bar.leadingAnchor constraintEqualToAnchor:self.track.leadingAnchor],
        [self.bar.centerYAnchor constraintEqualToAnchor:self.track.centerYAnchor],
        [self.bar.heightAnchor constraintEqualToConstant:3],
        [self.bar.widthAnchor constraintEqualToConstant:0],
    ]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.glowLayer.frame = CGRectMake(0, 0, self.view.bounds.size.width, 300);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self animate];
}

- (void)animate {
    // 头像：淡入 + 轻微放大
    self.avatar.alpha = 0.0;
    self.avatar.transform = CGAffineTransformMakeScale(0.85, 0.85);
    [UIView animateWithDuration:0.55 delay:0.05
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.avatar.alpha = 1.0;
        self.avatar.transform = CGAffineTransformIdentity;
    } completion:nil];

    // 标题：字距收窄
    self.titleL.attributedText = [CHTheme tracked:@"AzbcpxTuT"
        font:[CHTheme mono:22 weight:UIFontWeightBold] color:CH_ACCENT spacing:8.0];
    self.subL.attributedText = [CHTheme tracked:@"通用加解密透视工具"
        font:[CHTheme mono:10 weight:UIFontWeightMedium] color:CH_SUB spacing:2.4];

    [UIView animateWithDuration:0.7 delay:0.35 options:UIViewAnimationOptionCurveEaseOut
                     animations:^{ self.titleL.alpha = 1.0; self.subL.alpha = 1.0; } completion:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.9*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [UIView transitionWithView:self.titleL duration:0.5
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            self.titleL.attributedText = [CHTheme tracked:@"AzbcpxTuT"
                font:[CHTheme mono:22 weight:UIFontWeightBold] color:CH_ACCENT spacing:1.8];
        } completion:nil];
    });

    // 进度条
    for (NSLayoutConstraint *c in self.bar.constraints) {
        if (c.firstAttribute == NSLayoutAttributeWidth) c.constant = 120;
    }
    [UIView animateWithDuration:1.7 delay:0.1 options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{ [self.view layoutIfNeeded]; } completion:nil];

    // 收尾
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.05*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{
            self.view.alpha = 0.0;
            self.avatar.transform = CGAffineTransformMakeScale(0.94, 0.94);
        } completion:^(BOOL f){ if (self.onFinish) self.onFinish(); }];
    });
}

@end
