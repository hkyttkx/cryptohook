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

// ============================================================
// 配置（由 CryptoViewer 写入，dylib 启动时读）
// ============================================================
static NSDictionary *gCfg = nil;
static NSDate *gCfgTime = nil;

#define CFG_PATH @"/var/mobile/Library/CryptoHook/config.plist"

static void cfgRefresh(void) {
    // 最多每 5 秒重读一次，允许 App 里改完立刻生效
    if (gCfg && gCfgTime && -[gCfgTime timeIntervalSinceNow] < 5.0) return;
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:CFG_PATH];
    gCfg = d ?: @{};
    gCfgTime = [NSDate date];
}
static BOOL cfgOn(NSString *key) {
    cfgRefresh();
    NSNumber *v = gCfg[key];
    return v ? v.boolValue : YES;   // 默认全开
}
static int cfgRate(void) {
    cfgRefresh();
    NSNumber *v = gCfg[@"rate"];
    return v ? v.intValue : 200;
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
            fflush(gFp);
            gBytes += j.length + 1;
        }
    }
    pthread_mutex_unlock(&gLock);
}

// 噪声抑制：同类记录最多 N 条/秒
static BOOL rateGate(const char *key, int perSec) {
    static NSMutableDictionary *cnt = nil;
    static NSTimeInterval last = 0;
    static pthread_mutex_t l2 = PTHREAD_MUTEX_INITIALIZER;
    BOOL pass = YES;
    pthread_mutex_lock(&l2);
    if (!cnt) cnt = [NSMutableDictionary new];
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    if (now - last >= 1.0) { [cnt removeAllObjects]; last = now; }
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
static NSDictionary *base(NSString *layer, NSString *type) {
    return [@{
        @"t":  @([NSDate date].timeIntervalSince1970),
        @"pid":@(getpid()),
        @"app":gAppId ?: @"?",
        @"layer":layer,
        @"type":type
    } mutableCopy];
}
static void emit(NSMutableDictionary *rec) {
    logJSON(rec);
    NSLog(@"[CryptoHook] %@", rec);
}

// 调用栈：找第一个"非系统库"的帧（自研函数候选）
static NSString *callerOutsideSystem(int skip) {
    void *bt[48];
    int n = backtrace(bt, 48);
    for (int i = skip; i < n; i++) {
        Dl_info info;
        if (dladdr(bt[i], &info) && info.dli_fname) {
            NSString *f = @(info.dli_fname);
            if ([f containsString:@"/System/"] || [f containsString:@"/usr/lib/"]) continue;
            return [NSString stringWithFormat:@"%s+%ld @%p (in %@)",
                    info.dli_sname ?: "?", (long)0, bt[i],
                    [f lastPathComponent]];
        }
    }
    return nil;
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
    CCCryptorStatus r = CCCrypt(op,alg,opt,key,keyLen,iv,in,inLen,out,outAvail,moved);
    if (!cfgOn(@"L1")) return r;                       // ★ 开关
    if (rateGate("CCCrypt", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"CCCrypt");
        d[@"op"]  = (op == kCCEncrypt) ? @"ENC" : @"DEC";
        d[@"alg"] = @(alg);
        d[@"opt"] = @(opt);
        d[@"key"] = hexStr(key, keyLen, 64);
        if (iv) d[@"iv"] = hexStr(iv, 16, 16);
        d[@"in"]  = hexStr(in, inLen, 128);
        d[@"inLen"] = @(inLen);
        NSString *t = tryUTF8(in, inLen); if (t) d[@"inText"] = t;
        if (out && moved && *moved) {
            d[@"out"] = hexStr(out, *moved, 128);
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
    if (rateGate("CCCreate", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"CCCryptorCreate");
        d[@"op"] = (op==kCCEncrypt)?@"ENC":@"DEC";
        d[@"alg"] = @(alg);
        d[@"key"] = hexStr(key, keyLen, 64);
        if (iv) d[@"iv"] = hexStr(iv, 16, 16);
        emit(d);
    }
    return CCCryptorCreate(op,alg,opt,key,keyLen,iv,ref);
}
DYLD_INTERPOSE(my_CCCryptorCreate, CCCryptorCreate)

static CCCryptorStatus my_CCCryptorUpdate(CCCryptorRef ref, const void *in, size_t inLen,
    void *out, size_t outAvail, size_t *moved) {
    CCCryptorStatus r = CCCryptorUpdate(ref,in,inLen,out,outAvail,moved);
    if (!cfgOn(@"L1")) return r;
    if (rateGate("CCUpdate", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"CCCryptorUpdate");
        d[@"in"] = hexStr(in, inLen, 128);
        d[@"inLen"] = @(inLen);
        if (out && moved && *moved) { d[@"out"] = hexStr(out, *moved, 128); d[@"outLen"] = @(*moved); }
        emit(d);
    }
    return r;
}
DYLD_INTERPOSE(my_CCCryptorUpdate, CCCryptorUpdate)

static void my_CCHmac(CCHmacAlgorithm alg, const void *key, size_t keyLen,
                      const void *data, size_t dataLen, void *out) {
    if (!cfgOn(@"L1")) { CCHmac(alg,key,keyLen,data,dataLen,out); return; }
    if (rateGate("CCHmac", cfgRate())) {
        NSMutableDictionary *d = base(@"L1", @"CCHmac");
        d[@"alg"] = @(alg);
        d[@"key"] = hexStr(key, keyLen, 64);
        d[@"data"] = hexStr(data, dataLen, 128);
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
        d[@"in"] = hexStr(data, len, 96);
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
        d[@"in"] = hexStr(CFDataGetBytePtr(data), CFDataGetLength(data), 128);
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
        d[@"in"] = hexStr(CFDataGetBytePtr(data), CFDataGetLength(data), 128);
        d[@"inLen"] = @(CFDataGetLength(data));
        emit(d);
    }
    CFDataRef out = SecKeyCreateDecryptedData(key,alg,data,err);
    if (out && rateGate("SecDecOut", 50)) {
        NSMutableDictionary *d = base(@"L1", @"SecKeyDecrypt.out");
        d[@"out"] = hexStr(CFDataGetBytePtr(out), CFDataGetLength(out), 128);
        NSString *t = tryUTF8(CFDataGetBytePtr(out), CFDataGetLength(out)); if (t) d[@"outText"] = t;
        emit(d);
    }
    return out;
}
DYLD_INTERPOSE(my_SecKeyCreateDecryptedData, SecKeyCreateDecryptedData)

// ============================================================
// L2：明文字符串（明文的必经之路）★ 核心
// ============================================================
static BOOL looksInteresting(NSString *s) {
    if (s.length < 4) return NO;
    if (s.length > 4096) return NO;
    static NSArray *kw = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        kw = @[@"http", @"://", @".cn", @".com", @".net", @".io", @".site",
               @"api", @"key", @"token", @"session", @"nonce", @"sig",
               @"enc", @"dec", @"seal", @"aad", @"secret", @"auth",
               @"{", @"}", @"card", @"device", @"expire", @"license",
               @"|", @"MD5", @"SHA", @"RC4", @"AES", @"RSA", @"HMAC"];
    });
    for (NSString *k in kw) if ([s rangeOfString:k].location != NSNotFound) return YES;
    return NO;
}

static void recordString(const char *tag, NSString *s) {
    if (!s || !looksInteresting(s)) return;
    if (!cfgOn(@"L2")) return;
    if (!rateGate("str", cfgRate())) return;
    NSMutableDictionary *d = base(@"L2", @"String");
    d[@"src"] = @(tag);
    d[@"text"] = s.length > 512 ? [s substringToIndex:512] : s;
    NSString *c = callerOutsideSystem(4);
    if (c) d[@"caller"] = c;
    emit(d);
}

static NSString * (*o_stringWithUTF8String)(id, SEL, const char *);
static NSString * my_stringWithUTF8String(id self, SEL _cmd, const char *s) {
    NSString *r = o_stringWithUTF8String(self, _cmd, s);
    if (s) recordString("+[NSString stringWithUTF8String:]", r);
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
            d[@"req"] = hexStr(body.bytes, body.length, 192);
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
                d[@"resp"] = hexStr(data.bytes, data.length, 192);
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
// 初始化
// ============================================================
__attribute__((constructor))
static void ch_init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSLog(@"[CryptoHook] ===== loaded pid=%d =====", getpid());
        NSMutableDictionary *d = base(@"SYS", @"hello");
        d[@"bundle"] = [[NSBundle mainBundle] bundleIdentifier] ?: @"?";
        d[@"version"] = @"MVP2";
        emit(d);
        installL2();
        installL3();
        NSLog(@"[CryptoHook] L1 interpose installed (CCCrypt/CCHmac/CC_SHA256/SecKey*)");
    });
}
