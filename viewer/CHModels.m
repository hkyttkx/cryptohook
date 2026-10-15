// CHModels.m
#import "CHModels.h"

@implementation CHApp

- (NSArray<NSString *> *)logFiles {
    NSMutableArray *out = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray *dirs = [NSMutableArray array];

    // ① 越狱共享目录
    if (self.bid) [dirs addObject:[@"/var/mobile/Library/CryptoHook" stringByAppendingPathComponent:self.bid]];
    [dirs addObject:@"/var/mobile/Library/CryptoHook"];
    if (self.bid) [dirs addObject:[@"/tmp/CryptoHook" stringByAppendingPathComponent:self.bid]];
    // ② 目标 app 沙盒
    if (self.dataPath) {
        [dirs addObject:[self.dataPath stringByAppendingPathComponent:@"Documents/CryptoHook"]];
        if (self.bid) [dirs addObject:[[self.dataPath stringByAppendingPathComponent:@"Documents/CryptoHook"] stringByAppendingPathComponent:self.bid]];
    }

    for (NSString *d in dirs) {
        NSArray *items = [fm contentsOfDirectoryAtPath:d error:nil];
        for (NSString *f in items) {
            if ([f hasSuffix:@".log"]) {
                NSString *p = [d stringByAppendingPathComponent:f];
                if (![out containsObject:p]) [out addObject:p];
            }
        }
    }
    return out;
}

@end

@implementation CHRecord

// ★ 去重键（方案 C：按 type + 关键字段）
- (NSString *)dedupKey {
    NSDictionary *r = self.raw;
    NSString *t = self.type  ?: @"";
    NSString *l = self.layer ?: @"";
    if ([t isEqualToString:@"String"])
        return [NSString stringWithFormat:@"%@|%@|%@", l, t, r[@"text"] ?: @""];
    if ([t isEqualToString:@"CCCrypt"])
        return [NSString stringWithFormat:@"%@|%@|%@|%@|%@", l, t,
                r[@"op"], r[@"key"], r[@"inLen"]];
    if ([t isEqualToString:@"CCHmac"])
        return [NSString stringWithFormat:@"%@|%@|%@|%@", l, t, r[@"key"], r[@"dataLen"]];
    if ([t isEqualToString:@"CC_SHA256"])
        return [NSString stringWithFormat:@"%@|%@|%@", l, t, r[@"inLen"]];
    if ([t hasPrefix:@"HTTP"])
        return [NSString stringWithFormat:@"%@|%@|%@|%@", l, t,
                r[@"url"] ?: @"", r[@"status"] ?: (r[@"method"] ?: @"")];
    if ([t hasPrefix:@"SecKey"])
        return [NSString stringWithFormat:@"%@|%@|%@|%@", l, t, r[@"alg"], r[@"inLen"]];
    return [NSString stringWithFormat:@"%@|%@|%@", l, t, r.description];
}

- (NSString *)title {
    NSString *op = self.raw[@"op"];
    NSString *alg = nil;
    NSNumber *a = self.raw[@"alg"];
    if (a) {
        NSArray *names = @[@"AES", @"DES", @"3DES", @"CAST", @"RC4", @"RC2", @"Blowfish"];
        NSInteger i = a.integerValue;
        alg = (i >= 0 && i < (NSInteger)names.count) ? names[i] : [NSString stringWithFormat:@"alg%ld", (long)i];
    }
    if ([self.type isEqualToString:@"CCCrypt"]) {
        return [NSString stringWithFormat:@"CCCrypt · %@%@", op ?: @"", alg ? [@" " stringByAppendingString:alg] : @""];
    }
    if ([self.type isEqualToString:@"CCHmac"])   return @"HMAC";
    if ([self.type isEqualToString:@"CC_SHA256"]) return @"SHA-256";
    if ([self.type hasPrefix:@"SecKey"])          return self.type;
    if ([self.type isEqualToString:@"String"])    return @"明文字符串";
    if ([self.type hasPrefix:@"HTTP"])            return self.type;
    return self.type ?: @"?";
}

- (NSString *)subtitle {
    NSMutableArray *parts = [NSMutableArray array];
    if (self.raw[@"key"])  [parts addObject:[NSString stringWithFormat:@"key %@", [self.raw[@"key"] substringToIndex:MIN(16, [self.raw[@"key"] length])]]];
    if (self.raw[@"inLen"]) [parts addObject:[NSString stringWithFormat:@"in %@B", self.raw[@"inLen"]]];
    if (self.raw[@"outLen"])[parts addObject:[NSString stringWithFormat:@"out %@B", self.raw[@"outLen"]]];
    if (self.raw[@"url"])   [parts addObject:self.raw[@"url"]];
    if (self.raw[@"method"])[parts addObject:self.raw[@"method"]];
    if (self.raw[@"status"])[parts addObject:[NSString stringWithFormat:@"HTTP %@", self.raw[@"status"]]];
    if (self.raw[@"caller"])[parts addObject:self.raw[@"caller"]];
    return [parts componentsJoinedByString:@" · "];
}

- (NSString *)algoTag {
    NSNumber *a = self.raw[@"alg"];
    NSInteger i = a ? a.integerValue : -1;

    if ([self.type isEqualToString:@"CCCrypt"] || [self.type isEqualToString:@"CCCryptorCreate"]) {
        NSArray *n = @[@"AES", @"DES", @"3DES", @"CAST", @"RC4", @"RC2", @"Blowfish"];
        return (i >= 0 && i < (NSInteger)n.count) ? n[i] : nil;
    }
    if ([self.type isEqualToString:@"CCHmac"]) {
        NSArray *n = @[@"HMAC-SHA1", @"HMAC-MD5", @"HMAC-SHA256",
                       @"HMAC-SHA384", @"HMAC-SHA512", @"HMAC-SHA224"];
        return (i >= 0 && i < (NSInteger)n.count) ? n[i] : @"HMAC";
    }
    if ([self.type isEqualToString:@"CC_SHA256"]) return @"SHA256";
    if ([self.type rangeOfString:@"SecKey"].location != NSNotFound) {
        NSString *alg = self.raw[@"alg"];
        if ([alg containsString:@"RSA"])  return @"RSA";
        if ([alg containsString:@"EC"])   return @"ECDSA";
        if ([alg containsString:@"AES"])  return @"AES-GCM";
        return @"ASYM";
    }
    if ([self.type isEqualToString:@"PBKDF2"]) return @"PBKDF2";
    return nil;
}

- (NSString *)detail {
    NSMutableArray *lines = [NSMutableArray array];
    NSString *text = self.raw[@"inText"] ?: self.raw[@"outText"] ?: self.raw[@"text"] ?: self.raw[@"respText"] ?: self.raw[@"reqText"];
    if (text) [lines addObject:text];
    if (self.raw[@"iv"])  [lines addObject:[NSString stringWithFormat:@"IV  %@", self.raw[@"iv"]]];
    if (self.raw[@"in"])  [lines addObject:[NSString stringWithFormat:@"IN  %@", self.raw[@"in"]]];
    if (self.raw[@"out"]) [lines addObject:[NSString stringWithFormat:@"OUT %@", self.raw[@"out"]]];
    if (self.raw[@"data"])[lines addObject:[NSString stringWithFormat:@"DATA %@", self.raw[@"data"]]];
    if (self.raw[@"mac"]) [lines addObject:[NSString stringWithFormat:@"MAC %@", self.raw[@"mac"]]];
    if (self.raw[@"hash"])[lines addObject:[NSString stringWithFormat:@"SHA %@", self.raw[@"hash"]]];
    return [lines componentsJoinedByString:@"\n"];
}

@end
