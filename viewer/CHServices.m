// CHServices.m
#import "CHServices.h"
#import <objc/runtime.h>

@implementation CHScanner

#pragma mark - App 枚举（LSApplicationWorkspace 私有 API）
+ (NSArray<CHApp *> *)allApps {
    NSMutableArray *out = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];

    Class LS = NSClassFromString(@"LSApplicationWorkspace");
    if (LS) {
        id ws = [LS performSelector:@selector(defaultWorkspace)];
        NSArray *all = [ws performSelector:@selector(allApplications)];
        for (id proxy in all) {
            @try {
                NSString *bid  = [proxy performSelector:@selector(bundleIdentifier)];
                if (!bid || [seen containsObject:bid]) continue;
                [seen addObject:bid];

                CHApp *a = [CHApp new];
                a.bid  = bid;
                a.name = [proxy performSelector:@selector(localizedName)] ?: bid;
                NSURL *burl = [proxy performSelector:@selector(bundleURL)];
                a.bundlePath = burl.path;
                NSURL *durl = [proxy performSelector:@selector(dataContainerURL)];
                a.dataPath = durl.path;

                // 图标（v2 variant）
                id iconData = [proxy performSelector:@selector(iconDataForVariant:) withObject:@(2)];
                if ([iconData isKindOfClass:[NSData class]])
                    a.icon = [UIImage imageWithData:iconData];

                a.recordCount = [self countForApp:a];
                [out addObject:a];
            } @catch (NSException *e) {}
        }
    }

    // 兜底：扫容器目录（拿不到 LSApplicationProxy 时）
    if (out.count == 0) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *base = @"/var/containers/Bundle/Application";
        for (NSString *u in [fm contentsOfDirectoryAtPath:base error:nil]) {
            NSString *appDir = [base stringByAppendingPathComponent:u];
            for (NSString *e in [fm contentsOfDirectoryAtPath:appDir error:nil]) {
                if (![e hasSuffix:@".app"]) continue;
                NSString *p = [appDir stringByAppendingPathComponent:e];
                NSString *info = [p stringByAppendingPathComponent:@"Info.plist"];
                NSDictionary *pl = [NSDictionary dictionaryWithContentsOfFile:info];
                NSString *bid = pl[@"CFBundleIdentifier"];
                if (!bid || [seen containsObject:bid]) continue;
                [seen addObject:bid];
                CHApp *a = [CHApp new];
                a.bid = bid;
                a.name = pl[@"CFBundleDisplayName"] ?: pl[@"CFBundleName"] ?: e;
                a.bundlePath = p;
                a.recordCount = [self countForApp:a];
                [out addObject:a];
            }
        }
    }

    // 排序：有记录的在前，然后按名字
    [out sortUsingComparator:^NSComparisonResult(CHApp *a, CHApp *b) {
        if (a.recordCount != b.recordCount) return a.recordCount > b.recordCount ? NSOrderedAscending : NSOrderedDescending;
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
    return out;
}

#pragma mark - 记录读取
+ (NSInteger)countForApp:(CHApp *)app {
    NSInteger n = 0;
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *p in app.logFiles) {
        NSDictionary *attr = [fm attributesOfItemAtPath:p error:nil];
        NSNumber *sz = attr[NSFileSize];
        // 粗估：平均每条 200B
        if (sz) n += MAX(1, sz.integerValue / 200);
    }
    return n;
}

+ (NSArray<CHRecord *> *)recordsForApp:(CHApp *)app limit:(NSInteger)limit {
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *p in app.logFiles) {
        NSData *d = [NSData dataWithContentsOfFile:p];
        if (!d) continue;
        // 逐行 JSON
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
                        r.type = obj[@"type"] ?: @"?";
                        [out addObject:r];
                    }
                }
                start = i + 1;
            }
        }
    }
    // 时间倒序
    [out sortUsingComparator:^NSComparisonResult(CHRecord *a, CHRecord *b) {
        return a.t > b.t ? NSOrderedAscending : (a.t < b.t ? NSOrderedDescending : NSOrderedSame);
    }];
    if (limit > 0 && out.count > (NSUInteger)limit)
        return [out subarrayWithRange:NSMakeRange(0, limit)];
    return out;
}

@end
