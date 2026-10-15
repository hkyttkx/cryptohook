# CryptoHook — 通用 iOS 加解密 Hook dylib

越狱设备上透视任意 app / 外挂的加解密过程。**手机上即可用，不需要电脑、不需要 Frida。**

## 原理

用 **dyld interpose**（`__DATA,__interpose` 段）hook C 函数，用 **ObjC runtime** 扫描自研加解密方法。

选 interpose 而不是 fishhook 的原因：fishhook 改 `__la_symbol_ptr`，**有现成的反制方案**（`anti-fishhook`）；interpose 是 Apple 官方机制，在 dyld 绑定阶段生效，更底层。

## 覆盖范围

### ① Apple 对称加密（CommonCrypto）
- `CCCrypt` — 一次性加解密（最常用，微信/绝大多数 app 都走这个）
- `CCCryptorCreate` / `CCCryptorUpdate` / `CCCryptorFinal` — 流式加解密

### ② Apple HMAC / 摘要
- `CCHmac`
- `CC_SHA256` / `CC_MD5`
- `CCKeyDerivationPBKDF` — PBKDF2 密钥派生

### ③ Apple 非对称（Security.framework）
- `SecKeyCreateEncryptedData` / `SecKeyCreateDecryptedData` — RSA/EC 加解密

### ④ 目标 app / 外挂自研方法
按方法名关键词扫描（`decrypt` `encrypt` `aes` `rsa` `hmac` `cipher` `crypto` `derive` `nonce` `sign` `digest` `md5` `sha` `crypt` `key`），列出命中清单。

> MVP1 的 ④ 只**列出**方法（含签名 `enc=`），MVP2 再做参数级 hook。

## 输出

```
/var/mobile/Library/Logs/CryptoHook.log
```
（fallback：`/tmp/CryptoHook.log`），同时走 NSLog。

每条记录格式：

```
=== CCCrypt op=0 alg=0 opt=1 keyLen=32 inLen=1024
  KEY=a1b2c3...
  IV =000102...
  IN =7b226b65...
  INTEXT={"key":"abc"}
  OUT=...
  OUTTEXT={...}
  rc=0
```

## 用法

1. 下载 `dist/CryptoHook.dylib`
2. 用它注入目标 app（TrollStore / ElleKit / 巨魔注入器）
3. 打开 app 触发加解密
4. 看日志：

```bash
tail -f /var/mobile/Library/Logs/CryptoHook.log
```

## 构建

推代码到 `main` 即自动编译（GitHub Actions，macOS runner + Xcode SDK），产物提交到 `dist/`。

## 已知限制

- **interpose 对已缓存的函数指针无效**：若目标用 `dlsym` 取了函数地址并缓存在全局变量里（少数加固 app 会这么做），interpose 拦不住，需要改用 fishhook 或 inline hook。
- **Swift Crypto / CryptoKit**：走的是 Swift 层的 `AES.GCM` 等，最终多数仍落到 CommonCrypto，能被拦到；但如果用 Swift 纯软件实现则拦不到。
- **加壳 app**：dylib 本身的 string/objc 元数据可能被加密，`scanObjC` 的 ④ 部分可能扫不到。
