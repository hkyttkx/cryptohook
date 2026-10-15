// CHSplashVC.m — 启动动画：图片缓推 + 标题字距展开 + 扫描线
#import "CHSplashVC.h"
#import "CHTheme.h"

@interface CHSplashVC ()
@property (nonatomic, strong) UIImageView *hero;
@property (nonatomic, strong) UIView *shade;
@property (nonatomic, strong) UILabel *titleL;
@property (nonatomic, strong) UILabel *subL;
@property (nonatomic, strong) UIView *scanLine;
@property (nonatomic, strong) UIView *bar;
@end

@implementation CHSplashVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CH_BG;
    if (@available(iOS 13.0, *)) self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    // ── 主图（用户提供的那张） ──
    self.hero = [[UIImageView alloc] initWithFrame:self.view.bounds];
    self.hero.contentMode = UIViewContentModeScaleAspectFill;
    self.hero.clipsToBounds = YES;
    self.hero.alpha = 0.0;
    UIImage *img = [UIImage imageNamed:@"splash"];
    if (!img) {
        // 兜底：bundle 根目录的同名文件
        NSString *p = [[NSBundle mainBundle] pathForResource:@"splash" ofType:@"jpg"];
        if (p) img = [UIImage imageWithContentsOfFile:p];
    }
    self.hero.image = img;
    self.hero.transform = CGAffineTransformMakeScale(1.12, 1.12);
    [self.view addSubview:self.hero];

    // ── 底部渐变遮罩（压暗，让文字可读） ──
    self.shade = [[UIView alloc] initWithFrame:self.view.bounds];
    CAGradientLayer *gl = [CAGradientLayer layer];
    gl.frame = self.shade.bounds;
    gl.colors = @[(__bridge id)[CH_BG colorWithAlphaComponent:0.25].CGColor,
                  (__bridge id)[CH_BG colorWithAlphaComponent:0.55].CGColor,
                  (__bridge id)CH_BG.CGColor];
    gl.locations = @[@0.0, @0.55, @1.0];
    [self.shade.layer addSublayer:gl];
    [self.view addSubview:self.shade];

    // ── 底部标题 ──
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

    // ── 扫描线（科技感） ──
    self.scanLine = [UIView new];
    self.scanLine.backgroundColor = [CH_ACCENT colorWithAlphaComponent:0.9];
    self.scanLine.translatesAutoresizingMaskIntoConstraints = NO;
    self.scanLine.alpha = 0.0;
    [CHTheme glow:self.scanLine color:CH_ACCENT radius:8 opacity:1.0];
    [self.view addSubview:self.scanLine];

    // ── 进度条 ──
    UIView *track = [UIView new];
    track.backgroundColor = [CH_LINE colorWithAlphaComponent:0.6];
    track.layer.cornerRadius = 1.5;
    track.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:track];

    self.bar = [UIView new];
    self.bar.backgroundColor = CH_ACCENT;
    self.bar.layer.cornerRadius = 1.5;
    self.bar.translatesAutoresizingMaskIntoConstraints = NO;
    [CHTheme glow:self.bar color:CH_ACCENT radius:6 opacity:0.9];
    [self.view addSubview:self.bar];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleL.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.titleL.bottomAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:76],

        [self.subL.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.subL.topAnchor constraintEqualToAnchor:self.titleL.bottomAnchor constant:10],

        [self.scanLine.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scanLine.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scanLine.heightAnchor constraintEqualToConstant:1],
        [self.scanLine.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:30],

        [track.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [track.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-56],
        [track.widthAnchor constraintEqualToConstant:132],
        [track.heightAnchor constraintEqualToConstant:3],

        [self.bar.leadingAnchor constraintEqualToAnchor:track.leadingAnchor],
        [self.bar.centerYAnchor constraintEqualToAnchor:track.centerYAnchor],
        [self.bar.heightAnchor constraintEqualToConstant:3],
        [self.bar.widthAnchor constraintEqualToConstant:0],
    ]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self animate];
}

- (void)animate {
    // ① 图片淡入 + 缓慢推近
    [UIView animateWithDuration:1.1 delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.hero.alpha = 1.0;
        self.hero.transform = CGAffineTransformIdentity;
    } completion:nil];

    // ② 标题：淡入 + 字距从宽收窄
    self.titleL.attributedText = [CHTheme tracked:@"CRYPTOHOOK"
        font:[CHTheme mono:24 weight:UIFontWeightBold] color:CH_ACCENT spacing:10.0];
    self.subL.attributedText = [CHTheme tracked:@"GENERIC CRYPTO INTERCEPTOR"
        font:[CHTheme mono:9.5 weight:UIFontWeightMedium] color:CH_SUB spacing:2.2];
    [UIView animateWithDuration:0.9 delay:0.35 options:UIViewAnimationOptionCurveEaseOut
                     animations:^{ self.titleL.alpha = 1.0; self.subL.alpha = 1.0; } completion:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [UIView transitionWithView:self.titleL duration:0.6
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            self.titleL.attributedText = [CHTheme tracked:@"CRYPTOHOOK"
                font:[CHTheme mono:24 weight:UIFontWeightBold] color:CH_ACCENT spacing:1.5];
        } completion:nil];
    });

    // ③ 扫描线扫过
    self.scanLine.alpha = 1.0;
    self.scanLine.transform = CGAffineTransformMakeTranslation(0, -180);
    [UIView animateWithDuration:1.5 delay:0.2
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{ self.scanLine.transform = CGAffineTransformMakeTranslation(0, 180); }
                     completion:^(BOOL f){ self.scanLine.alpha = 0.0; }];

    // ④ 进度条
    UIView *track = self.bar.superview;
    [self.bar.constraints enumerateObjectsUsingBlock:^(NSLayoutConstraint *c, NSUInteger i, BOOL *stop) {
        if (c.firstAttribute == NSLayoutAttributeWidth) c.constant = 132;
    }];
    (void)track;
    [UIView animateWithDuration:2.0 delay:0.15 options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{ [self.view layoutIfNeeded]; } completion:nil];

    // ⑤ 收尾
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.45*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.35 animations:^{
            self.view.alpha = 0.0;
            self.hero.transform = CGAffineTransformMakeScale(1.06, 1.06);
        } completion:^(BOOL f){
            if (self.onFinish) self.onFinish();
        }];
    });
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.hero.frame = self.view.bounds;
    self.shade.frame = self.view.bounds;
    for (CALayer *l in self.shade.layer.sublayers) l.frame = self.shade.bounds;
}

@end
