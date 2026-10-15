// CHServices.m
#import "CHServices.h"
#import <objc/runtime.h>

// 私有 API：拿 App 图标（越狱环境可用）
@interface UIImage (CHPrivate)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bid format:(int)fmt scale:(CGFloat)scale;
@end

@implementation CHScanner

#pragma mark - 图标
+ (UIImage *)iconForBundlePath:(NSString *)bundlePath bid:(NSString *)bid {
    // ① 常见图标文件名（覆盖绝大多数 App）
    NSArray *names = @[
        @"AppIcon60x60@3x.png", @"AppIcon60x60@2x.png",
        @"AppIcon76x76@2x~ipad.png", @"AppIcon83.5x83.5@2x~ipad.png",
        @"Icon-60@3x.png", @"Icon-60@2x.png",
        @"Icon-76@2x.png", @"Icon-83.5@2x.png",
        @"Icon@3x.png", @"Icon@2x.png", @"Icon.png",
    ];
    if (bundlePath.length) {
        for (NSString *n in names) {
            UIImage *img = [UIImage imageWithContentsOfFile:
                            [bundlePath stringByAppendingPathComponent:n]];
            if (img) return img;
        }
        // ② 从 Info.plist 的 CFBundleIcons 解析真实文件名
        NSDictionary *pl = [NSDictionary dictionaryWithContentsOfFile:
                            [bundlePath stringByAppendingPathComponent:@"Info.plist"]];
        NSArray *cands = nil;
        NSDictionary *primary = pl[@"CFBundleIcons"][@"CFBundlePrimaryIcon"];
        if (primary[@"CFBundleIconFiles"]) cands = primary[@"CFBundleIconFiles"];
        if (!cands && pl[@"CFBundleIconFiles"]) cands = pl[@"CFBundleIconFiles"];
        if ([cands isKindOfClass:[NSArray class]]) {
            for (NSString *base in [cands reverseObjectEnumerator]) {
                for (NSString *sfx in @[@"@3x.png", @"@2x.png", @".png", @""]) {
                    NSString *p = [bundlePath stringByAppendingPathComponent:
                                   [base stringByAppendingString:sfx]];
                    UIImage *img = [UIImage imageWithContentsOfFile:p];
                    if (img) return img;
                }
            }
        }
    }
    // ③ 私有 API 兜底
    if (bid.length) {
        @try {
            UIImage *img = [UIImage _applicationIconImageForBundleIdentifier:bid format:2 scale:3.0];
            if ([img isKindOfClass:[UIImage class]]) return img;
        } @catch (__unused NSException *e) {}
    }
    return nil;
}

#pragma mark - App 枚举
+ (NSArray<CHApp *> *)allApps {
    NSMutableArray *out = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];

    Class LS = NSClassFromString(@"LSApplicationWorkspace");
    if (LS) {
        id ws = [LS performSelector:@selector(defaultWorkspace)];
        NSArray *all = [ws performSelector:@selector(allApplications)];
        for (id proxy in all) {
            @try {
                NSString *bid = [proxy performSelector:@selector(bundleIdentifier)];
                if (!bid || [seen containsObject:bid]) continue;
                [seen addObject:bid];

                CHApp *a = [CHApp new];
                a.bid  = bid;
                a.name = [proxy performSelector:@selector(localizedName)] ?: bid;
                NSURL *burl = [proxy performSelector:@selector(bundleURL)];
                a.bundlePath = burl.path;
                NSURL *durl = [proxy performSelector:@selector(dataContainerURL)];
                a.dataPath = durl.path;
                a.icon = [self iconForBundlePath:a.bundlePath bid:bid];
                a.recordCount = [self countForApp:a];
                [out addObject:a];
            } @catch (NSException *e) {}
        }
    }

    // 兜底：扫容器
    if (out.count == 0) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *base = @"/var/containers/Bundle/Application";
        for (NSString *u in [fm contentsOfDirectoryAtPath:base error:nil]) {
            NSString *appDir = [base stringByAppendingPathComponent:u];
            for (NSString *e in [fm contentsOfDirectoryAtPath:appDir error:nil]) {
                if (![e hasSuffix:@".app"]) continue;
                NSString *p = [appDir stringByAppendingPathComponent:e];
                NSDictionary *pl = [NSDictionary dictionaryWithContentsOfFile:
                                    [p stringByAppendingPathComponent:@"Info.plist"]];
                NSString *bid = pl[@"CFBundleIdentifier"];
                if (!bid || [seen containsObject:bid]) continue;
                [seen addObject:bid];
                CHApp *a = [CHApp new];
                a.bid = bid;
                a.name = pl[@"CFBundleDisplayName"] ?: pl[@"CFBundleName"] ?: e;
                a.bundlePath = p;
                a.icon = [self iconForBundlePath:p bid:bid];
                a.recordCount = [self countForApp:a];
                [out addObject:a];
            }
        }
    }

    [out sortUsingComparator:^NSComparisonResult(CHApp *a, CHApp *b) {
        if (a.recordCount != b.recordCount)
            return a.recordCount > b.recordCount ? NSOrderedAscending : NSOrderedDescending;
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
    return out;
}

#pragma mark - 记录读取
+ (NSInteger)countForApp:(CHApp *)app {
    NSInteger n = 0;
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *p in app.logFiles) {
        NSNumber *sz = [fm attributesOfItemAtPath:p error:nil][NSFileSize];
        if (sz) n += MAX(1, sz.integerValue / 200);
    }
    return n;
}

+ (NSArray<CHRecord *> *)recordsForApp:(CHApp *)app limit:(NSInteger)limit {
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *p in app.logFiles) {
        NSData *d = [NSData dataWithContentsOfFile:p];
        if (!d) continue;
        const uint8_t *bytes = d.bytes;
        NSUInteger len = d.length, start = 0;
        for (NSUInteger i = 0; i <= len; i++) {
            if (i == len || bytes[i] == '\n') {
                if (i > start) {
                    NSData *line = [d subdataWithRange:NSMakeRange(start, i - start)];
                    id obj = [NSJSONSerialization JSONObjectWithData:line options:0 error:nil];
                    if ([obj isKindOfClass:[NSDictionary class]]) {
                        CHRecord *r = [CHRecord new];
                        r.raw = obj;
                        r.t = [obj[@"t"] doubleValue];
                        r.date = [NSDate dateWithTimeIntervalSince1970:r.t];
                        r.layer = obj[@"layer"] ?: @"?";
                        r.type  = obj[@"type"]  ?: @"?";
                        [out addObject:r];
                    }
                }
                start = i + 1;
            }
        }
    }
    [out sortUsingComparator:^NSComparisonResult(CHRecord *a, CHRecord *b) {
        return a.t > b.t ? NSOrderedAscending : (a.t < b.t ? NSOrderedDescending : NSOrderedSame);
    }];
    if (limit > 0 && out.count > (NSUInteger)limit)
        return [out subarrayWithRange:NSMakeRange(0, limit)];
    return out;
}

@end
