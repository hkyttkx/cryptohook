// CryptoHook.m — 通用加解密透视 dylib
// 架构（五层）：
//   L1 系统 API       interpose: CCCrypt/CCHmac/CC_SHA*/SecKey*
//   L2 明文字符串  ★  hook: NSString/CFString 创建 + 调用栈
//   L3 网络收发       hook: NSURLSession dataTaskWithRequest:
//   L4 自研函数       用 L2 的调用栈反推地址 -> MSHookFunction（v3）
//   L5 分类器         长度/熵判型（v3）
// 日志：JSON 行，双写（沙盒 Documents + 共享目录），带限流

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <CommonCrypto/CommonCrypto.h>
#include <CommonCrypto/CommonHMAC.h>
#include <Security/Security.h>
#include <execinfo.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <pthread.h>
#include <mach/mach_time.h>
#include <mach/vm_map.h>
#include <mach/mach.h>
#include <mach/vm_region.h>

// ── 开源 hook 引擎 ──
#include "third_party/fishhook.h"          // facebook/fishhook：重绑定 __la_symbol_ptr

// ElleKit / CydiaSubstrate 提供的 inline hook（能打无符号的自研函数）
typedef void *(*MSHookFunction_t)(void *symbol, void *replace, void **result);
static MSHookFunction_t gMSHookFunction = NULL;

// 自检标志（自检期间产生的记录会标记出来）
static volatile int gSelfTest = 0;
static volatile int gInterposeHits = 0;   // interpose 被触发次数
static volatile int gFishhookHits  = 0;   // fishhook 被触发次数


// ============================================================
// 配置（由 CryptoViewer 写入；dylib 优先读【自己沙盒】，其次共享目录）
// ============================================================
static NSDictionary *gCfg = nil;
static unsigned long gDropCount = 0;   // 被黑名单丢弃的条数
static uint64_t gCfgTick = 0;
static double   gTickScale = 0;
static BOOL     gSlowStack = NO;

static NSArray<NSString *> *cfgPaths(void) {
    NSMutableArray *a = [NSMutableArray array];
    // ★ 1) 自己沙盒 —— TrollStore 注入的 App 一定能读写这里
    NSString *home = NSHomeDirectory();
    if (home) {
        [a addObject:[home stringByAppendingPathComponent:@"Documents/CryptoHook/config.plist"]];
        [a addObject:[home stringByAppendingPathComponent:@"Library/Caches/CryptoHook/config.plist"]];
    }
    // 2) 共享目录（若 App 恰好有权限）
    [a addObject:@"/var/mobile/Library/CryptoHook/config.plist"];
    [a addObject:@"/tmp/CryptoHook/config.plist"];
    return a;
}

static void cfgRefresh(void) {
    uint64_t now = mach_absolute_time();
    if (gTickScale == 0) {
        mach_timebase_info_data_t tb; mach_timebase_info(&tb);
        gTickScale = (double)tb.numer / tb.denom / 1e9;
    }
    // 每 3 秒最多重读一次
    if (gCfg && (now - gCfgTick) * gTickScale < 3.0) return;
    gCfgTick = now;
    @try {
        for (NSString *p in cfgPaths()) {
            NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:p];
            if (d && [d isKindOfClass:[NSDictionary class]] && d.count) {
                gCfg = d;
                return;
            }
        }
        gCfg = @{};
    } @catch (NSException *e) {
        gCfg = @{};
    }
}

static BOOL cfgOn(NSString *key) {
    cfgRefresh();
    gSlowStack = [gCfg[@"slowStack"] boolValue];
    NSNumber *v = gCfg[key];
    if (v) return v.boolValue;
    // 默认：L1（系统加密，频率最高）默认关；其余默认开
    if ([key isEqualToString:@"L1"]) return NO;
    return YES;
}
static int cfgRate(void) {
    cfgRefresh();
    NSNumber *v = gCfg[@"rate"];
    return v ? v.intValue : 50;
}

// ============================================================
// 日志层
// ============================================================
static FILE *gFp = NULL;
static NSString *gAppId = nil;
static pthread_mutex_t gLock = PTHREAD_MUTEX_INITIALIZER;
static unsigned long gBytes = 0;
static NSString *gSession = nil;

#define MAX_FILE_BYTES (16UL * 1024 * 1024)   // 单文件上限 16MB，超出滚动

static void logSetup(void) {
    if (gFp) return;
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown";
    gAppId = [bid copy];

    NSDateFormatter *f = [NSDateFormatter new];
    f.dateFormat = @"yyyyMMdd_HHmmss";
    gSession = [f stringFromDate:[NSDate date]];

    NSString *file = [NSString stringWithFormat:@"session_%@.log", gSession];

    // 候选路径：① 自己沙盒（一定有权限） ② 共享目录（越狱最好）
    NSMutableArray *dirs = [NSMutableArray array];
    NSString *home = NSHomeDirectory();
    if (home) [dirs addObject:[home stringByAppendingPathComponent:@"Documents/CryptoHook"]];
    [dirs addObject:@"/var/mobile/Library/CryptoHook"];
    [dirs addObject:@"/tmp/CryptoHook"];

    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *d in dirs) {
        [fm createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *d2 = [d stringByAppendingPathComponent:gAppId];
        [fm createDirectoryAtPath:d2 withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *p = [d2 stringByAppendingPathComponent:file];
        FILE *fp = fopen(p.UTF8String, "a");
        if (fp) { gFp = fp; NSLog(@"[CryptoHook] log -> %@", p); break; }
    }
    if (!gFp) NSLog(@"[CryptoHook] 无法创建日志文件");
}

static void logJSON(NSDictionary *rec) {
    if (!rec) return;
    @try {
    pthread_mutex_lock(&gLock);
    logSetup();
    if (gFp) {
        if (gBytes > MAX_FILE_BYTES) {
            // 滚动：关闭旧文件，换名重开
            fclose(gFp); gFp = NULL; gBytes = 0;
            logSetup();
        }
        NSData *j = [NSJSONSerialization dataWithJSONObject:rec options:0 error:nil];
        if (j) {
            fwrite(j.bytes, 1, j.length, gFp);
            fputc('\n', gFp);
            // ★ 每条都刷盘（之前省掉这步导致日志文件全空）
            fflush(gFp);
            gBytes += j.length + 1;
        }
    }
    pthread_mutex_unlock(&gLock);
    } @catch (__unused NSException *e) {}
}

// 噪声抑制：同类记录最多 N 条/秒
static BOOL rateGate(const char *key, int perSec) {
    static NSMutableDictionary *cnt = nil;
    static uint64_t lastT = 0;
    static pthread_mutex_t l2 = PTHREAD_MUTEX_INITIALIZER;
    uint64_t now = mach_absolute_time();
    static double s2t = 0;
    if (s2t == 0) { mach_timebase_info_data_t tb; mach_timebase_info(&tb); s2t = (double)tb.numer / tb.denom / 1e9; }
    BOOL pass = YES;
    pthread_mutex_lock(&l2);
    if (!cnt) cnt = [NSMutableDictionary new];
    if ((now - lastT) * s2t >= 1.0) { [cnt removeAllObjects]; lastT = now; }
    NSString *k = @(key);
    int c = [[cnt objectForKey:k] intValue];
    if (c >= perSec) pass = NO;
    else [cnt setObject:@(c+1) forKey:k];
    pthread_mutex_unlock(&l2);
    return pass;
}

// ============================================================
// 工具
// ============================================================
static NSString *hexStr(const void *p, size_t n, size_t cap) {
    if (!p || !n) return @"";
    const uint8_t *b = p;
    size_t lim = n > cap ? cap : n;
    NSMutableString *s = [NSMutableString stringWithCapacity:lim*2];
    for (size_t i = 0; i < lim; i++) [s appendFormat:@"%02x", b[i]];
    if (n > lim) [s appendFormat:@"…(%luB)", (unsigned long)n];
    return s;
}
static NSString *tryUTF8(const void *p, size_t n) {
    if (!p || !n || n > 8192) return nil;
    NSString *s = [[NSString alloc] initWithBytes:p length:n encoding:NSUTF8StringEncoding];
    if (!s || s.length == 0) return nil;
    // 排除全是二进制噪音
    unichar c = [s characterAtIndex:0];
    if (c < 0x09) return nil;
    return s;
}
// 前向声明（base 里要用，定义在后面）
static NSArray<NSString *> *fullBacktrace(int skip);

static NSMutableDictionary *base(NSString *layer, NSString *type) {
    NSMutableDictionary *d = [@{
        @"t":  @([NSDate date].timeIntervalSince1970),
        @"pid":@(getpid()),
        @"app":gAppId ?: @"?",
        @"layer":layer,
        @"type":type
    } mutableCopy];
    // ★ 调用栈：默认不采集（backtrace+dladdr 极慢，是卡死主因）
    //    仅在 cfg 里开了 slowStack 时才做
    if (gSlowStack) {
        @try {
            NSArray *bt = fullBacktrace(3);
            if (bt.count) { d[@"bt"] = bt; d[@"caller"] = bt.firstObject; }
        } @catch (__unused NSException *e) {}
    }
    return d;
}
// ★ 黑名单过滤（由 App 写入 config.plist，可加可删）
//   excludeTypes   : 按 type 精确匹配        ["HTTP.response", "CCCrypt", ...]
//   excludeUrls    : URL 包含即丢（子串）     ["data-track.yingxiong.com", ...]
//   excludeCallers : 调用点包含即丢           ["DSOverlay_PresentFrame", ...]
//   excludeKeywords: 任意字段包含即丢         ["analytics", ...]
static BOOL cfgExcluded(NSDictionary *rec) {
    cfgRefresh();
    if (gCfg.count == 0) return NO;

    // 1) type 精确
    NSArray *types = gCfg[@"excludeTypes"];
    if ([types isKindOfClass:[NSArray class]] && types.count) {
        NSString *t = rec[@"type"];
        if (t && [types containsObject:t]) { gDropCount++; return YES; }
    }
    // 2) URL 子串
    NSArray *urls = gCfg[@"excludeUrls"];
    if ([urls isKindOfClass:[NSArray class]] && urls.count) {
        NSString *u = rec[@"url"];
        if ([u isKindOfClass:[NSString class]] && u.length) {
            for (NSString *p in urls) {
                if (![p isKindOfClass:[NSString class]] || p.length == 0) continue;
                if ([u rangeOfString:p options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    gDropCount++; return YES;
                }
            }
        }
    }
    // 3) 调用点子串
    NSArray *callers = gCfg[@"excludeCallers"];
    if ([callers isKindOfClass:[NSArray class]] && callers.count) {
        NSString *c = rec[@"caller"];
        NSArray *bt = rec[@"bt"];
        if ([c isKindOfClass:[NSString class]] && c.length) {
            for (NSString *p in callers) {
                if (![p isKindOfClass:[NSString class]] || p.length == 0) continue;
                if ([c rangeOfString:p options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    gDropCount++; return YES;
                }
                if ([bt isKindOfClass:[NSArray class]]) {
                    for (NSString *f in bt)
                        if ([f rangeOfString:p options:NSCaseInsensitiveSearch].location != NSNotFound) {
                            gDropCount++; return YES;
                        }
                }
            }
        }
    }
    // 4) 关键词（任意字段）
    NSArray *kws = gCfg[@"excludeKeywords"];
    if ([kws isKindOfClass:[NSArray class]] && kws.count) {
        NSString *hay = [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@",
                         rec[@"type"] ?: @"", rec[@"url"] ?: @"", rec[@"text"] ?: @"",
                         rec[@"inText"] ?: @"", rec[@"caller"] ?: @"", rec[@"src"] ?: @""];
        if (hay.length) {
            for (NSString *kw in kws) {
                if (![kw isKindOfClass:[NSString class]] || kw.length == 0) continue;
                if ([hay rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    gDropCount++; return YES;
                }
            }
        }
    }
    return NO;
}

static void emit(NSMutableDictionary *rec) {
    @try {
        if (gSelfTest) rec[@"selftest"] = @YES;
        if (cfgExcluded(rec)) return;   // ★ 命中过滤规则，直接丢
        logJSON(rec);
        // ★ 不再 NSLog（写系统日志很慢，改成配置开关）
        cfgRefresh();
        if ([gCfg[@"syslog"] boolValue]) NSLog(@"[CryptoHook] %@", rec);
    } @catch (__unused NSException *e) {}
}

// 调用栈：完整帧列表（过滤系统库噪音），返回字符串数组
static NSArray<NSString *> *fullBacktrace(int skip) {
    @try {
    void *bt[64];
    int n = backtrace(bt, 64);
    if (n <= 0) return nil;
    NSMutableArray *out = [NSMutableArray array];
    for (int i = skip; i < n && out.count < 12; i++) {
        Dl_info info;
        if (!dladdr(bt[i], &info) || !info.dli_fname) continue;
        NSString *f = @(info.dli_fname);
        // 系统库只保留前 2 帧作为上下文，其余跳过
        BOOL sys = [f containsString:@"/System/"] || [f containsString:@"/usr/lib/"];
        if (sys && out.count > 2) continue;
        NSString *sym = info.dli_sname ? @(info.dli_sname) : @"?";
        // 计算文件内偏移（便于 IDA 定位）
        unsigned long off = (unsigned long)((uintptr_t)bt[i] - (uintptr_t)info.dli_fbase);
        [out addObject:[NSString stringWithFormat:@"%@ +0x%lx @%p %@",
                        sym, off, bt[i], [f lastPathComponent]]];
    }
    return out.count ? out : nil;
    } @catch (__unused NSException *e) { return nil; }
}

// 摘要：第一个非系统帧（兼容旧的 caller 字段）
static NSString *callerOutsideSystem(int skip) {
    NSArray *frames = fullBacktrace(skip);
    for (NSString *f in frames) {
        if (![f containsString:@"/System/"] && ![f containsString:@"/usr/lib/"])
            return f;
    }
    return frames.firstObject;
}

// ============================================================
// CCCryptorRef 缓存：把 Create 时的 KEY/IV 带到后续 Update
// ============================================================
static NSMutableDictionary *gRefMap = nil;
static pthread_mutex_t gRefLock = PTHREAD_MUTEX_INITIALIZER;

static void refStore(void *ref, NSDictionary *info) {
    if (!ref || !info) return;
    pthread_mutex_lock(&gRefLock);
    if (!gRefMap) gRefMap = [NSMutableDictionary new];
    if (gRefMap.count > 512) [gRefMap removeAllObjects];   // 防泄漏
    gRefMap[[NSValue valueWithPointer:ref]] = info;
    pthread_mutex_unlock(&gRefLock);
}
static NSDictionary *refLoad(void *ref) {
    if (!ref) return nil;
    pthread_mutex_lock(&gRefLock);
    NSDictionary *d = gRefMap ? gRefMap[[NSValue valueWithPointer:ref]] : nil;
    pthread_mutex_unlock(&gRefLock);
    return d;
}
static void refDrop(void *ref) {
    if (!ref) return;
    pthread_mutex_lock(&gRefLock);
    if (gRefMap) [gRefMap removeObjectForKey:[NSValue valueWithPointer:ref]];
    pthread_mutex_unlock(&gRefLock);
}

// ============================================================
// L1：系统加密 API（dyld interpose）
// ============================================================
#define DYLD_INTERPOSE(_rep,_old) \
  __attribute__((used)) static struct { const void* r; const void* o; } \
  _i_##_old __attribute__((section("__DATA,__interpose"))) = { (const void*)_rep, (const void*)_old };

static CCCryptorStatus my_CCCrypt(CCOperation op, CCAlgorithm alg, CCOptions opt,
    const void *key, size_t keyLen, const void *iv,
    const void *in, size_t inLen, void *out, size_t outAvail, size_t *moved) {
    __sync_fetch_and_add(&gInterposeHits, 1);        // ★ 计数（证明确实被调到）
    CCCryptorStatus r = CCCrypt(op,alg,opt,key,keyLen,iv,in,inLen,out,outAvail,moved);
    if (!cfgOn(@"L1")) return r;                       // ★ 开关
    if (rateGate("CCCrypt", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"CCCrypt");
        d[@"op"]  = (op == kCCEncrypt) ? @"ENC" : @"DEC";
        d[@"alg"] = @(alg);
        d[@"opt"] = @(opt);
        d[@"key"] = hexStr(key, keyLen, 128);
        if (iv) d[@"iv"] = hexStr(iv, 32, 32);
        d[@"in"]  = hexStr(in, inLen, 4096);
        d[@"inLen"] = @(inLen);
        NSString *t = tryUTF8(in, inLen); if (t) d[@"inText"] = t;
        if (out && moved && *moved) {
            d[@"out"] = hexStr(out, *moved, 4096);
            d[@"outLen"] = @(*moved);
            NSString *o = tryUTF8(out, *moved); if (o) d[@"outText"] = o;
        }
        d[@"rc"] = @((int)r);
        emit(d);
    }
    return r;
}
DYLD_INTERPOSE(my_CCCrypt, CCCrypt)

static CCCryptorStatus my_CCCryptorCreate(CCOperation op, CCAlgorithm alg, CCOptions opt,
    const void *key, size_t keyLen, const void *iv, CCCryptorRef *ref) {
    if (!cfgOn(@"L1")) return CCCryptorCreate(op,alg,opt,key,keyLen,iv,ref);
    CCCryptorStatus r = CCCryptorCreate(op,alg,opt,key,keyLen,iv,ref);
    // ★ 保存这段会话的 KEY/IV，供后续 Update 使用
    NSDictionary *info = @{
        @"op":  (op==kCCEncrypt)?@"ENC":@"DEC",
        @"alg": @(alg),
        @"opt": @(opt),
        @"key": hexStr(key, keyLen, 128),
        @"iv":  iv ? hexStr(iv, 16, 32) : @""
    };
    if (ref && *ref) refStore((void *)*ref, info);
    if (cfgOn(@"L1") && rateGate("CCCreate", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"CCCryptorCreate");
        [d addEntriesFromDictionary:info];
        emit(d);
    }
    return r;
}
DYLD_INTERPOSE(my_CCCryptorCreate, CCCryptorCreate)

static CCCryptorStatus my_CCCryptorUpdate(CCCryptorRef ref, const void *in, size_t inLen,
    void *out, size_t outAvail, size_t *moved) {
    CCCryptorStatus r = CCCryptorUpdate(ref,in,inLen,out,outAvail,moved);
    if (!cfgOn(@"L1")) return r;
    if (rateGate("CCUpdate", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"CCCryptorUpdate");
        // ★ 补上本次会话的 KEY/IV（来自 Create）
        NSDictionary *info = refLoad((void *)ref);
        if (info) [d addEntriesFromDictionary:info];
        d[@"in"] = hexStr(in, inLen, 4096);
        d[@"inLen"] = @(inLen);
        if (out && moved && *moved) { d[@"out"] = hexStr(out, *moved, 4096); d[@"outLen"] = @(*moved); }
        emit(d);
    }
    return r;
}

static void my_CCCryptorRelease(CCCryptorRef ref) {
    if (ref) refDrop((void *)ref);
    CCCryptorRelease(ref);
}
DYLD_INTERPOSE(my_CCCryptorRelease, CCCryptorRelease)
DYLD_INTERPOSE(my_CCCryptorUpdate, CCCryptorUpdate)

static void my_CCHmac(CCHmacAlgorithm alg, const void *key, size_t keyLen,
                      const void *data, size_t dataLen, void *out) {
    if (!cfgOn(@"L1")) { CCHmac(alg,key,keyLen,data,dataLen,out); return; }
    if (rateGate("CCHmac", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"CCHmac");
        d[@"alg"] = @(alg);
        d[@"key"] = hexStr(key, keyLen, 128);
        d[@"data"] = hexStr(data, dataLen, 4096);
        d[@"dataLen"] = @(dataLen);
        size_t dl = (alg==kCCHmacAlgSHA256)?32:(alg==kCCHmacAlgSHA1)?20:(alg==kCCHmacAlgSHA512)?64:16;
        if (out) d[@"mac"] = hexStr(out, dl, dl);
        emit(d);
    }
    CCHmac(alg,key,keyLen,data,dataLen,out);
}
DYLD_INTERPOSE(my_CCHmac, CCHmac)

static void my_CC_SHA256(const void *data, CC_LONG len, unsigned char *md) {
    if (!cfgOn(@"L1")) { CC_SHA256(data,len,md); return; }
    if (rateGate("SHA256", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"CC_SHA256");
        d[@"in"] = hexStr(data, len, 4096);
        d[@"inLen"] = @(len);
        NSString *t = tryUTF8(data, len); if (t) d[@"inText"] = t;
        CC_SHA256(data,len,md);
        if (md) d[@"hash"] = hexStr(md, 32, 32);
        emit(d);
        return;
    }
    CC_SHA256(data,len,md);
}
DYLD_INTERPOSE(my_CC_SHA256, CC_SHA256)

static CFDataRef my_SecKeyCreateEncryptedData(SecKeyRef key, SecKeyAlgorithm alg,
                                              CFDataRef data, CFErrorRef *err) {
    if (!cfgOn(@"L1")) return SecKeyCreateEncryptedData(key,alg,data,err);
    if (rateGate("SecEnc", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"SecKeyEncrypt");
        d[@"alg"] = (__bridge id)alg ?: @"?";
        d[@"in"] = hexStr(CFDataGetBytePtr(data), CFDataGetLength(data), 4096);
        d[@"inLen"] = @(CFDataGetLength(data));
        NSString *t = tryUTF8(CFDataGetBytePtr(data), CFDataGetLength(data)); if (t) d[@"inText"] = t;
        emit(d);
    }
    return SecKeyCreateEncryptedData(key,alg,data,err);
}
DYLD_INTERPOSE(my_SecKeyCreateEncryptedData, SecKeyCreateEncryptedData)

static CFDataRef my_SecKeyCreateDecryptedData(SecKeyRef key, SecKeyAlgorithm alg,
                                              CFDataRef data, CFErrorRef *err) {
    if (!cfgOn(@"L1")) return SecKeyCreateDecryptedData(key,alg,data,err);
    if (rateGate("SecDec", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"SecKeyDecrypt");
        d[@"alg"] = (__bridge id)alg ?: @"?";
        d[@"in"] = hexStr(CFDataGetBytePtr(data), CFDataGetLength(data), 4096);
        d[@"inLen"] = @(CFDataGetLength(data));
        emit(d);
    }
    CFDataRef out = SecKeyCreateDecryptedData(key,alg,data,err);
    if (out && rateGate("SecDecOut", 50)) {
        NSMutableDictionary *d = base(@"L1", @"SecKeyDecrypt.out");
        d[@"out"] = hexStr(CFDataGetBytePtr(out), CFDataGetLength(out), 4096);
        NSString *t = tryUTF8(CFDataGetBytePtr(out), CFDataGetLength(out)); if (t) d[@"outText"] = t;
        emit(d);
    }
    return out;
}
DYLD_INTERPOSE(my_SecKeyCreateDecryptedData, SecKeyCreateDecryptedData)

// ===== 老 API：SecKeyEncrypt / SecKeyDecrypt（RSA 常用）=====
static OSStatus my_SecKeyEncrypt(SecKeyRef key, SecPadding pad,
    const uint8_t *plain, size_t plainLen, uint8_t *cipher, size_t *cipherLen) {
    if (cfgOn(@"L1") && rateGate("SecKeyEnc", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"SecKeyEncrypt");
        d[@"alg"] = [NSString stringWithFormat:@"RSA/pad%u", pad];
        d[@"inLen"] = @(plainLen);
        d[@"in"] = hexStr(plain, plainLen, 4096);
        NSString *t = tryUTF8(plain, plainLen); if (t) d[@"inText"] = t;
        emit(d);
    }
    OSStatus r = SecKeyEncrypt(key, pad, plain, plainLen, cipher, cipherLen);
    if (cfgOn(@"L1") && cipher && cipherLen && rateGate("SecKeyEncOut", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"SecKeyEncrypt.out");
        d[@"outLen"] = @(*cipherLen);
        d[@"out"] = hexStr(cipher, *cipherLen, 4096);
        emit(d);
    }
    return r;
}
DYLD_INTERPOSE(my_SecKeyEncrypt, SecKeyEncrypt)

static OSStatus my_SecKeyDecrypt(SecKeyRef key, SecPadding pad,
    const uint8_t *cipher, size_t cipherLen, uint8_t *plain, size_t *plainLen) {
    if (cfgOn(@"L1") && rateGate("SecKeyDec", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"SecKeyDecrypt");
        d[@"alg"] = [NSString stringWithFormat:@"RSA/pad%u", pad];
        d[@"inLen"] = @(cipherLen);
        d[@"in"] = hexStr(cipher, cipherLen, 4096);
        emit(d);
    }
    OSStatus r = SecKeyDecrypt(key, pad, cipher, cipherLen, plain, plainLen);
    if (cfgOn(@"L1") && plain && plainLen && rateGate("SecKeyDecOut", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"SecKeyDecrypt.out");
        d[@"outLen"] = @(*plainLen);
        d[@"out"] = hexStr(plain, *plainLen, 4096);
        NSString *t = tryUTF8(plain, *plainLen); if (t) d[@"outText"] = t;
        emit(d);
    }
    return r;
}
DYLD_INTERPOSE(my_SecKeyDecrypt, SecKeyDecrypt)

// ===== 签名 / 验签 =====
static Boolean my_SecKeyVerifySignature(SecKeyRef key, SecKeyAlgorithm alg,
    CFDataRef signedData, CFDataRef sig, CFErrorRef *err) {
    if (cfgOn(@"L1") && rateGate("SecVerify", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"SecKeyVerifySignature");
        d[@"alg"] = (__bridge id)alg ?: @"?";
        d[@"inLen"] = @(CFDataGetLength(signedData));
        d[@"in"] = hexStr(CFDataGetBytePtr(signedData), CFDataGetLength(signedData), 4096);
        d[@"sig"] = hexStr(CFDataGetBytePtr(sig), CFDataGetLength(sig), 512);
        emit(d);
    }
    return SecKeyVerifySignature(key, alg, signedData, sig, err);
}
DYLD_INTERPOSE(my_SecKeyVerifySignature, SecKeyVerifySignature)

// ===== 摘要：MD5 / SHA1 / SHA512 / CCDigest =====
static void my_CC_MD5(const void *data, CC_LONG len, unsigned char *md) {
    if (cfgOn(@"L1") && rateGate("MD5", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"CC_MD5");
        d[@"inLen"] = @(len);
        d[@"in"] = hexStr(data, len, 4096);
        NSString *t = tryUTF8(data, len); if (t) d[@"inText"] = t;
        CC_MD5(data, len, md);
        if (md) d[@"hash"] = hexStr(md, 16, 16);
        emit(d);
        return;
    }
    CC_MD5(data, len, md);
}
DYLD_INTERPOSE(my_CC_MD5, CC_MD5)

static void my_CC_SHA1(const void *data, CC_LONG len, unsigned char *md) {
    if (cfgOn(@"L1") && rateGate("SHA1", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"CC_SHA1");
        d[@"inLen"] = @(len);
        d[@"in"] = hexStr(data, len, 4096);
        NSString *t = tryUTF8(data, len); if (t) d[@"inText"] = t;
        CC_SHA1(data, len, md);
        if (md) d[@"hash"] = hexStr(md, 20, 20);
        emit(d);
        return;
    }
    CC_SHA1(data, len, md);
}
DYLD_INTERPOSE(my_CC_SHA1, CC_SHA1)

static void my_CC_SHA512(const void *data, CC_LONG len, unsigned char *md) {
    if (cfgOn(@"L1") && rateGate("SHA512", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"CC_SHA512");
        d[@"inLen"] = @(len);
        d[@"in"] = hexStr(data, len, 4096);
        CC_SHA512(data, len, md);
        if (md) d[@"hash"] = hexStr(md, 64, 64);
        emit(d);
        return;
    }
    CC_SHA512(data, len, md);
}
DYLD_INTERPOSE(my_CC_SHA512, CC_SHA512)


// ============================================================
// L2：明文字符串（明文的必经之路）★ 核心
// ============================================================
// ★ 性能关键：C 层关键词表（strstr 比 rangeOfString: 快得多）
static const char *kStrKw[] = {
    "http", "://", ".com", ".cn", ".net", "api", "token", "session",
    "nonce", "sign", "encrypt", "decrypt", "secret", "auth", "card",
    "device", "expire", "licen", "MD5", "SHA", "RC4", "AES", "RSA", "HMAC", NULL
};

static void recordString(const char *tag, NSString *s) {
    if (!s) return;
    // ① 先看开关（最便宜）
    if (!cfgOn(@"L2")) return;
    // ② 长度快筛
    NSUInteger len = s.length;
    if (len < 6 || len > 4096) return;
    // ③ 采样门（先挡住大部分，避免后面的开销）
    if (!rateGate("str", cfgRate())) return;
    // ④ 最后才做关键词（C 层 strstr）
    const char *cs = s.UTF8String;
    if (!cs) return;
    BOOL hit = NO;
    for (int i = 0; kStrKw[i]; i++) {
        if (strstr(cs, kStrKw[i])) { hit = YES; break; }
    }
    if (!hit) return;
    NSMutableDictionary *d = base(@"L2", @"String");
    d[@"src"] = @(tag);
    d[@"text"] = s.length > 512 ? [s substringToIndex:512] : s;
    NSString *c = callerOutsideSystem(4);
    if (c) d[@"caller"] = c;
    emit(d);
}

// ★ L2 开关缓存（避免每次字符串创建都读配置）
static BOOL     gL2On = YES;
static uint64_t gL2Tick = 0;

static inline BOOL l2EnabledFast(void) {
    uint64_t now = mach_absolute_time();
    if (gTickScale == 0) {
        mach_timebase_info_data_t tb; mach_timebase_info(&tb);
        gTickScale = (double)tb.numer / tb.denom / 1e9;
    }
    if ((now - gL2Tick) * gTickScale > 2.0) {   // 每 2 秒刷新
        gL2On = cfgOn(@"L2");
        gL2Tick = now;
    }
    return gL2On;
}

static NSString * (*o_stringWithUTF8String)(id, SEL, const char *);
static NSString * my_stringWithUTF8String(id self, SEL _cmd, const char *s) {
    NSString *r = o_stringWithUTF8String(self, _cmd, s);
    // ★ 快速门：先看缓存开关（几个指令），再决定要不要做后续检查
    if (s && l2EnabledFast()) recordString("+[NSString stringWithUTF8String:]", r);
    return r;
}

static NSDictionary *g_L2_Hooked = nil;

static void installL2(void) {
    Class c = objc_getClass("NSString");
    if (!c) return;
    // 类方法 stringWithUTF8String: 实际在元类上
    Class meta = object_getClass(c);
    Method m = class_getClassMethod(c, @selector(stringWithUTF8String:));
    if (m) {
        o_stringWithUTF8String = (void *)method_getImplementation(m);
        method_setImplementation(m, (IMP)my_stringWithUTF8String);
        NSLog(@"[CryptoHook] L2 hooked +[NSString stringWithUTF8String:]");
    }
    (void)meta; (void)g_L2_Hooked;
}

// ============================================================
// L3：网络收发（密文的必经之路）
// ============================================================
typedef NSURLSessionDataTask *(*DataTaskIMP)(id, SEL, NSURLRequest *, void (^)(NSData *, NSURLResponse *, NSError *));
static DataTaskIMP o_dataTask = NULL;

static NSURLSessionDataTask *my_dataTask(id self, SEL _cmd, NSURLRequest *req,
                                         void (^completion)(NSData *, NSURLResponse *, NSError *)) {
    if (!o_dataTask) return nil;                        // 兜底：原方法未拿到就不接管
    if (!cfgOn(@"L3")) return o_dataTask(self, _cmd, req, completion);
    if (rateGate("http", cfgRate())) {
        NSMutableDictionary *d = base(@"L3", @"HTTP.request");
        d[@"url"] = req.URL.absoluteString ?: @"?";
        d[@"method"] = req.HTTPMethod ?: @"GET";
        NSData *body = req.HTTPBody;
        if (body) {
            d[@"reqLen"] = @(body.length);
            d[@"req"] = hexStr(body.bytes, body.length, 4096);
            NSString *t = tryUTF8(body.bytes, body.length); if (t) d[@"reqText"] = t;
        }
        // 关键请求头
        NSMutableDictionary *h = [NSMutableDictionary dictionary];
        for (NSString *k in @[@"Content-Type", @"User-Agent", @"Authorization"]) {
            NSString *v = [req valueForHTTPHeaderField:k];
            if (v) h[k] = v;
        }
        if (h.count) d[@"headers"] = h;
        emit(d);
    }
    if (!completion) return o_dataTask(self, _cmd, req, completion);

    void (^wrap)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (rateGate("httpResp", 60)) {
            NSMutableDictionary *d = base(@"L3", @"HTTP.response");
            d[@"url"] = resp.URL.absoluteString ?: req.URL.absoluteString;
            d[@"status"] = @([(NSHTTPURLResponse *)resp statusCode]);
            if (data) {
                d[@"respLen"] = @(data.length);
                d[@"resp"] = hexStr(data.bytes, data.length, 4096);
                NSString *t = tryUTF8(data.bytes, data.length); if (t) d[@"respText"] = t;
            }
            if (err) d[@"error"] = err.localizedDescription;
            emit(d);
        }
        completion(data, resp, err);
    };
    return o_dataTask(self, _cmd, req, [wrap copy]);
}

static void installL3(void) {
    Class c = objc_getClass("NSURLSession");
    if (!c) return;
    Method m = class_getInstanceMethod(c, @selector(dataTaskWithRequest:completionHandler:));
    if (m) {
        o_dataTask = (DataTaskIMP)method_getImplementation(m);
        method_setImplementation(m, (IMP)my_dataTask);
        NSLog(@"[CryptoHook] L3 hooked -[NSURLSession dataTaskWithRequest:completionHandler:]");
    }
}

// ============================================================
// L4：密钥暴力搜索（扫描本进程内存，找能解开指定密文的 AES key）
//   Viewer 写 scan_request.plist -> dylib 扫描 -> 写 scan_result.plist
// ============================================================
#define SCAN_REQ  @"/var/mobile/Library/CryptoHook/scan_request.plist"
#define SCAN_RES  @"/var/mobile/Library/CryptoHook/scan_result.plist"

static NSData *hexToDataLocal(NSString *hex) {
    if (![hex isKindOfClass:[NSString class]] || hex.length < 2) return nil;
    NSMutableData *d = [NSMutableData data];
    for (NSUInteger i = 0; i + 1 < hex.length; i += 2) {
        unsigned int v = 0;
        if (![[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(i, 2)]]
              scanHexInt:&v]) break;
        uint8_t b = (uint8_t)v;
        [d appendBytes:&b length:1];
    }
    return d.length ? d : nil;
}

// 判断解出来的东西"像不像明文"
static BOOL looksLikePlaintext(NSData *d) {
    if (d.length < 4) return NO;
    const uint8_t *b = d.bytes;
    NSUInteger printable = 0, limit = MIN(d.length, 128);
    for (NSUInteger i = 0; i < limit; i++) {
        uint8_t c = b[i];
        if ((c >= 32 && c < 127) || c == '\n' || c == '\r' || c == '\t') printable++;
    }
    if (printable * 100 / limit >= 85) return YES;      // 85% 可打印 = 明文
    // 或者开头是 JSON
    if (b[0] == '{' || b[0] == '[') return YES;
    return NO;
}

static void doScanKey(NSDictionary *req) {
    NSString *ctHex = req[@"cipherHex"];
    NSArray *tryAlgs = req[@"algs"] ?: @[@(kCCAlgorithmAES)];
    NSMutableArray *found = [NSMutableArray array];
    unsigned long scannedMB = 0;
    BOOL stop = NO;

    NSData *ctFull = hexToDataLocal(ctHex);
    if (!ctFull.length) return;

    // ★ 若原数据是 base64 文本（QBL 的响应），先解 base64
    if ([req[@"maybeBase64"] boolValue]) {
        NSString *txt = [[NSString alloc] initWithData:ctFull encoding:NSUTF8StringEncoding];
        if (txt.length) {
            // 去掉引号和空白
            NSMutableString *clean = [NSMutableString string];
            for (NSUInteger i = 0; i < txt.length; i++) {
                unichar c = [txt characterAtIndex:i];
                if ((c>='A'&&c<='Z')||(c>='a'&&c<='z')||(c>='0'&&c<='9')||c=='+'||c=='/'||c=='=') {
                    if (c == '=') break;      // base64 结束
                    [clean appendFormat:@"%C", c];
                }
            }
            // 补 padding
            while (clean.length % 4) [clean appendString:@"="];
            NSData *dec = [[NSData alloc] initWithBase64EncodedString:clean options:0];
            if (dec.length >= 16) {
                NSLog(@"[CryptoHook] base64 解码 %lu -> %lu 字节",
                      (unsigned long)ctFull.length, (unsigned long)dec.length);
                ctFull = dec;
            }
        }
    }

    // 密文可能是 IV(16)+CT 或纯 CT —— 两种都试
    NSMutableArray *ctCands = [NSMutableArray array];
    [ctCands addObject:ctFull];
    if (ctFull.length > 16)
        [ctCands addObject:[ctFull subdataWithRange:NSMakeRange(16, ctFull.length - 16)]];

    // 遍历可读内存区域
    mach_port_t task = mach_task_self();
    vm_address_t a = 0;
    vm_size_t s = 0;
    natural_t depth = 0;

    while (!stop) {
        struct vm_region_submap_info_64 sub;
        mach_msg_type_number_t cnt = VM_REGION_SUBMAP_INFO_COUNT_64;
        kern_return_t kr = vm_region_recurse_64(task, &a, &s, &depth,
                                                (vm_region_info_t)&sub, &cnt);
        if (kr != KERN_SUCCESS) break;
        if ((sub.protection & VM_PROT_READ) && s > 4096 && s < (256UL * 1024 * 1024)) {
            scannedMB += s / (1024 * 1024);
            const uint8_t *p = (const uint8_t *)a;
            for (vm_size_t off = 0; off + 32 <= s && !stop; off += 4) {
                for (NSNumber *algN in tryAlgs) {
                    CCAlgorithm alg = (CCAlgorithm)algN.intValue;
                    for (int klen = 16; klen <= 32 && !stop; klen += 16) {
                        const uint8_t *keyp = p + off;
                        for (NSData *ct in ctCands) {
                            if (ct.length < 32) continue;
                            uint8_t iv[16];
                            memcpy(iv, ct.bytes, 16);
                            const uint8_t *cdata = ct.bytes + 16;
                            size_t clen = ct.length - 16;
                            if (clen % 16) continue;
                            size_t outCap = clen + 32;
                            uint8_t *out = malloc(outCap);
                            if (!out) continue;
                            size_t moved = 0;
                            CCCryptorStatus st = CCCrypt(kCCDecrypt, alg,
                                kCCOptionPKCS7Padding, keyp, klen, iv,
                                cdata, clen, out, outCap, &moved);
                            if (st == kCCSuccess && moved > 0) {
                                NSData *plain = [NSData dataWithBytes:out length:moved];
                                if (looksLikePlaintext(plain)) {
                                    NSString *kh = hexStr(keyp, klen, 64);
                                    [found addObject:@{
                                        @"key": (kh.length >= (NSUInteger)(klen*2))
                                               ? [kh substringToIndex:klen*2] : kh,
                                        @"keyLen": @(klen),
                                        @"alg": @(alg),
                                        @"plainHex": hexStr(plain.bytes, plain.length, 256),
                                        @"plainText": tryUTF8(plain.bytes, plain.length) ?: @"",
                                        @"addr": [NSString stringWithFormat:@"0x%llx",
                                                  (unsigned long long)a + off]
                                    }];
                                    if (found.count >= 8) stop = YES;
                                }
                            }
                            free(out);
                            if (stop) break;
                        }
                    }
                }
            }
        }
        a += s;
    }

    NSMutableDictionary *res = [NSMutableDictionary dictionary];
    res[@"t"] = @([NSDate date].timeIntervalSince1970);
    res[@"scannedMB"] = @(scannedMB);
    res[@"results"] = found;
    res[@"done"] = @YES;
    [res writeToFile:SCAN_RES atomically:YES];
    NSLog(@"[CryptoHook] 扫描完成 %luMB，命中 %lu", scannedMB, (unsigned long)found.count);
}

// 轮询 scan_request.plist
static void checkScanRequest(void) {
    NSDictionary *req = [NSDictionary dictionaryWithContentsOfFile:SCAN_REQ];
    if (!req || ![req[@"cipherHex"] isKindOfClass:[NSString class]]) return;
    // 已处理过（用 nonce 去重）
    NSString *nonce = req[@"nonce"];
    static NSString *lastNonce = nil;
    if (nonce && [nonce isEqualToString:lastNonce]) return;
    lastNonce = nonce;
    NSLog(@"[CryptoHook] 收到扫描请求");
    dispatch_async(dispatch_get_global_queue(0, 0), ^{ doScanKey(req); });
}

// ============================================================
// 初始化
// ============================================================
// ============================================================
// Hook 引擎安装 + 自检
// ============================================================
static void installMSHook(void) {
    // 从已加载的插件里找 MSHookFunction（ElleKit 提供）
    gMSHookFunction = (MSHookFunction_t)dlsym(RTLD_DEFAULT, "MSHookFunction");
    if (!gMSHookFunction) {
        void *h = dlopen("/usr/lib/libsubstrate.dylib", RTLD_NOW);
        if (h) gMSHookFunction = (MSHookFunction_t)dlsym(h, "MSHookFunction");
    }
    if (!gMSHookFunction) {
        void *h = dlopen("/var/jb/usr/lib/libellekit.dylib", RTLD_NOW);
        if (h) gMSHookFunction = (MSHookFunction_t)dlsym(h, "MSHookFunction");
    }
    NSLog(@"[CryptoHook] MSHookFunction = %s", gMSHookFunction ? "可用" : "未找到");
}

/// 用 fishhook 再绑一次（补 interpose 在 dlsym 缓存场景的失效）
static CCCryptorStatus (*fh_CCCrypt)(CCOperation, CCAlgorithm, CCOptions,
    const void*, size_t, const void*, const void*, size_t, void*, size_t, size_t*);
static CCCryptorStatus my_CCCrypt_fh(CCOperation op, CCAlgorithm alg, CCOptions opt,
    const void *key, size_t keyLen, const void *iv,
    const void *in, size_t inLen, void *out, size_t outAvail, size_t *moved) {
    __sync_fetch_and_add(&gFishhookHits, 1);         // ★ 计数
    CCCryptorStatus r = fh_CCCrypt(op,alg,opt,key,keyLen,iv,in,inLen,out,outAvail,moved);
    if (cfgOn(@"L1") && !gSelfTest && rateGate("fhCCCrypt", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"CCCrypt");
        d[@"src"] = @"fishhook";
        d[@"op"]  = (op == kCCEncrypt) ? @"ENC" : @"DEC";
        d[@"alg"] = @(alg);
        d[@"key"] = hexStr(key, keyLen, 128);
        if (iv) d[@"iv"] = hexStr(iv, 16, 32);
        d[@"inLen"] = @(inLen);
        d[@"in"] = hexStr(in, inLen, 4096);
        if (out && moved && *moved) {
            d[@"outLen"] = @(*moved);
            d[@"out"] = hexStr(out, *moved, 4096);
        }
        emit(d);
    }
    return r;
}

static void installFishhook(void) {
    struct rebinding rb[] = {
        {"CCCrypt", (void *)my_CCCrypt_fh, (void **)&fh_CCCrypt},
    };
    int rc = rebind_symbols(rb, 1);
    NSLog(@"[CryptoHook] fishhook rebind CCCrypt rc=%d (0=成功)", rc);
}

/// 自检：自己调一次 CCCrypt，看链路是否通
static void selfTestHooks(void) {
    gSelfTest = 1;
    uint8_t key[16] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
    uint8_t iv[16]  = {0};
    const char *pt = "CRYPTOHOOK-SELFTEST";
    uint8_t out[64]; size_t moved = 0;
    CCCrypt(kCCEncrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding,
            key, 16, iv, pt, strlen(pt), out, sizeof(out), &moved);
    gSelfTest = 0;

    // 写一份诊断结果
    NSMutableDictionary *d = base(@"SYS", @"selftest");
    d[@"interpose"] = @(gInterposeHits);
    d[@"fishhook"]  = @(gFishhookHits);
    d[@"mshook"]    = gMSHookFunction ? @"ok" : @"none";
    d[@"pid"]       = @(getpid());
    d[@"bundle"]    = [[NSBundle mainBundle] bundleIdentifier] ?: @"?";
    NSString *verdict;
    if (gInterposeHits > 0 || gFishhookHits > 0)
        verdict = @"hook 链路正常";
    else
        verdict = @"⚠️ interpose 未生效（可能需要 inline hook 或换注入目标）";
    d[@"verdict"] = verdict;
    emit(d);
    NSLog(@"[CryptoHook] 自检: interpose=%d fishhook=%d mshook=%s -> %@",
          gInterposeHits, gFishhookHits, gMSHookFunction ? "yes" : "no", verdict);
}

__attribute__((constructor))
static void ch_init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSLog(@"[CryptoHook] ===== loaded pid=%d =====", getpid());
        NSMutableDictionary *d = base(@"SYS", @"hello");
        d[@"bundle"] = [[NSBundle mainBundle] bundleIdentifier] ?: @"?";
        d[@"version"] = @"MVP2";
        emit(d);
        installMSHook();      // 探查 inline hook 可用性
        installFishhook();    // 补 dyp 缓存场景
        installL2();
        installL3();
        // 延迟再自检（等所有 constructor 跑完）
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5*NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ selfTestHooks(); });
        // ★ 每 2 秒检查一次扫描请求
        dispatch_source_t st = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                                     dispatch_get_global_queue(0, 0));
        dispatch_source_set_timer(st, dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC),
                                  2*NSEC_PER_SEC, 1*NSEC_PER_SEC);
        dispatch_source_set_event_handler(st, ^{ checkScanRequest(); });
        dispatch_resume(st);
        // ★ 每 2 秒批量刷盘一次（替代每次 fflush）
        dispatch_source_t t = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                                     dispatch_get_global_queue(0, 0));
        dispatch_source_set_timer(t, dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC),
                                  2*NSEC_PER_SEC, 1*NSEC_PER_SEC);
        dispatch_source_set_event_handler(t, ^{
            pthread_mutex_lock(&gLock);
            if (gFp) fflush(gFp);
            pthread_mutex_unlock(&gLock);
        });
        dispatch_resume(t);
        NSLog(@"[CryptoHook] L1 interpose installed (CCCrypt/CCHmac/CC_SHA256/SecKey*)");
    });
}
