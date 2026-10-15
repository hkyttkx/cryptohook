// CHServices.m
#import "CHServices.h"
#import <objc/runtime.h>

// 私有 API：拿 App 图标（越狱环境可用）
@interface UIImage (CHPrivate)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bid format:(int)fmt scale:(CGFloat)scale;
@end

@interface CHScanner ()
/// 未聚合的原始记录
+ (NSArray<CHRecord *> *)rawRecordsForApp:(CHApp *)app limit:(NSInteger)limit;
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
    return [self recordsForApp:app limit:limit aggregate:NO];
}

+ (NSArray<CHRecord *> *)recordsForApp:(CHApp *)app limit:(NSInteger)limit aggregate:(BOOL)agg {
    NSArray *raw = [self rawRecordsForApp:app limit:limit];
    if (!agg) return raw;

    // ★ 去重聚合
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    NSMutableArray *order = [NSMutableArray array];
    for (CHRecord *r in raw) {
        NSString *k = r.dedupKey;
        CHRecord *ex = map[k];
        if (!ex) {
            r.count = 1;
            r.firstT = r.t;
            r.lastT  = r.t;
            r.dups   = [NSMutableArray array];
            map[k] = r;
            [order addObject:r];
        } else {
            ex.count += 1;
            if (r.t < ex.firstT) ex.firstT = r.t;
            if (r.t > ex.lastT) { ex.lastT = r.t; ex.t = r.t; ex.date = r.date; }
            if (ex.dups.count < 200) [ex.dups addObject:r];
        }
    }
    // 按最近活动倒序
    [order sortUsingComparator:^NSComparisonResult(CHRecord *a, CHRecord *b) {
        return a.lastT > b.lastT ? NSOrderedAscending
             : (a.lastT < b.lastT ? NSOrderedDescending : NSOrderedSame);
    }];
    return order;
}

+ (NSArray<CHRecord *> *)rawRecordsForApp:(CHApp *)app limit:(NSInteger)limit {
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *p in app.logFiles) {
        NSData *d = [NSData dataWithContentsOfFile:p];
        if (!d) continue;
        const uint8_t *bytes = d.bytes;
        NSUInteger len = d.length, start = 0;
        NSInteger lineNo = 0;
        NSInteger badLines = 0;
        for (NSUInteger i = 0; i <= len; i++) {
            if (i == len || bytes[i] == '\n') {
                if (i > start) {
                    NSData *line = [d subdataWithRange:NSMakeRange(start, i - start)];
                    id obj = nil;
                    @try {
                        obj = [NSJSONSerialization JSONObjectWithData:line options:0 error:nil];
                    } @catch (__unused NSException *e) { obj = nil; }
                    if ([obj isKindOfClass:[NSDictionary class]]) {
                        CHRecord *r = [CHRecord new];
                        r.raw = obj;
                        r.t = [obj[@"t"] doubleValue];
                        r.date = [NSDate dateWithTimeIntervalSince1970:r.t];
                        r.layer = obj[@"layer"] ?: @"?";
                        r.type  = obj[@"type"]  ?: @"?";
                        r.srcFile = p;
                        r.lineIdx = lineNo;
                        [out addObject:r];
                    } else {
                        badLines++;
                        // 前 3 条坏行打到控制台，便于诊断
                        if (badLines <= 3) {
                            NSString *txt = [[NSString alloc] initWithData:line encoding:NSUTF8StringEncoding];
                            NSLog(@"[CryptoViewer] 坏行 %@:%ld len=%lu head=%@",
                                  [p lastPathComponent], (long)lineNo,
                                  (unsigned long)line.length,
                                  txt.length > 120 ? [txt substringToIndex:120] : txt);
                        }
                    }
                }
                start = i + 1;
                lineNo++;
            }
        }
        if (badLines > 0) NSLog(@"[CryptoViewer] %@ 有 %ld 行无法解析", p, (long)badLines);
    }
    [out sortUsingComparator:^NSComparisonResult(CHRecord *a, CHRecord *b) {
        return a.t > b.t ? NSOrderedAscending : (a.t < b.t ? NSOrderedDescending : NSOrderedSame);
    }];
    if (limit > 0 && out.count > (NSUInteger)limit)
        return [out subarrayWithRange:NSMakeRange(0, limit)];
    return out;
}


#pragma mark - 删除
+ (BOOL)removeLines:(NSIndexSet *)lines fromFile:(NSString *)path {
    if (!path || !lines.count) return NO;
    NSData *d = [NSData dataWithContentsOfFile:path];
    if (!d) return NO;
    NSMutableData *out = [NSMutableData dataWithCapacity:d.length];
    const uint8_t *bytes = d.bytes;
    NSUInteger len = d.length, start = 0;
    NSInteger lineNo = 0;
    static const uint8_t nl = '\n';
    for (NSUInteger i = 0; i <= len; i++) {
        if (i == len || bytes[i] == '\n') {
            BOOL drop = [lines containsIndex:(NSUInteger)lineNo];
            if (!drop && i > start) [out appendBytes:(bytes + start) length:(i - start)];
            if (!drop && i > start) [out appendBytes:&nl length:1];
            start = i + 1;
            lineNo++;
        }
    }
    return [out writeToFile:path atomically:YES];
}

+ (BOOL)deleteRecord:(CHRecord *)rec {
    if (!rec || rec.srcFile.length == 0 || rec.lineIdx < 0) return NO;
    return [self removeLines:[NSIndexSet indexSetWithIndex:(NSUInteger)rec.lineIdx]
                    fromFile:rec.srcFile];
}

+ (NSInteger)deleteRecords:(NSArray<CHRecord *> *)recs {
    NSMutableDictionary<NSString *, NSMutableIndexSet *> *map = [NSMutableDictionary dictionary];
    void (^collect)(CHRecord *) = ^(CHRecord *r) {
        if (!r || r.srcFile.length == 0 || r.lineIdx < 0) return;
        NSMutableIndexSet *set = map[r.srcFile];
        if (!set) { set = [NSMutableIndexSet indexSet]; map[r.srcFile] = set; }
        [set addIndex:(NSUInteger)r.lineIdx];
    };
    NSInteger total = 0;
    for (CHRecord *r in recs) {
        collect(r);
        for (CHRecord *d in r.dups) collect(d);
        total++;
    }
    for (NSString *f in map) [self removeLines:map[f] fromFile:f];
    return total;
}

/// 列出该 App 的日志文件（供诊断/预览）
+ (NSArray<NSString *> *)rawLogPathsForApp:(CHApp *)app {
    return app.logFiles ?: @[];
}

/// 读取某个日志文件的原始文本（最多 20000 字符）
+ (NSString *)rawTextOfFile:(NSString *)path {
    NSData *d = [NSData dataWithContentsOfFile:path];
    if (!d) return @"(读取失败)";
    NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    if (!s) s = [NSString stringWithFormat:@"(非 UTF-8，%lu 字节)", (unsigned long)d.length];
    if (s.length > 20000) s = [[s substringToIndex:20000] stringByAppendingString:@"\n…(截断)"];
    return s;
}

+ (NSInteger)clearApp:(CHApp *)app {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSInteger n = 0;
    for (NSString *p in app.logFiles) {
        if ([fm removeItemAtPath:p error:nil]) n++;
    }
    return n;
}
@end
