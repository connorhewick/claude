# iOS Security Patterns

Implement Keychain, biometric auth, ATS/pinning, and secure credential handling for production iOS apps with explicit threat-model reasoning.

---

## Overview

iOS security work is mostly *choosing the right shelf for each secret and the right gate for each action* — then resisting the urge to add theater. The platform already gives you strong primitives (Keychain, Data Protection, ATS, Secure Enclave); your job is to use them with the correct protection classes and to be honest about what each measure defends against. Every recommendation here is framed as: what attacker does this stop, and what does it cost in operability? A measure you can't articulate a threat for is complexity, not security.

## Core Concepts

**Storage is a spectrum of attacker effort, not safe/unsafe.** `UserDefaults` is a plaintext plist readable from any device backup or jailbroken device — fine for a theme preference, indefensible for a token. Files get Data Protection classes (`.completeFileProtection` encrypts at rest, keyed to passcode) — right for bulk sensitive *data*. Keychain is hardware-backed, survives app deletion (configurable), supports access control (`kSecAttrAccessible*`, biometric-gated items) — the only correct home for *secrets*: tokens, passwords, keys. The deciding question is "what happens if an attacker with the device, a backup, or a filesystem dump reads this?"

**Keychain accessibility is a real decision, not boilerplate.** `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` is the default you should justify deviating from: unavailable while locked, never migrates via backup to another device. Background-refresh apps may need `.afterFirstUnlockThisDeviceOnly`. Dropping `ThisDeviceOnly` means the secret rides along in encrypted backups and device migrations — sometimes desired (user convenience), sometimes a compliance violation (device-bound credentials). Choose per item, in writing.

**Biometrics gate; they don't encrypt — unless you bind them via the Keychain.** `LAContext.evaluatePolicy` returns a Bool: a jailbroken device or a tampered binary can skip it. It's UX-grade gating for actions the server will still authorize. For real cryptographic binding, store the secret as a Keychain item with `SecAccessControlCreateWithFlags(..., .biometryCurrentSet)` — then the Secure Enclave releases the item only after biometry, and enrolling a new fingerprint invalidates it. Use `.deviceOwnerAuthentication` (biometry *or* passcode) for login-grade gates so users with failed Face ID aren't locked out; reserve `.deviceOwnerAuthenticationWithBiometrics` + `.biometryCurrentSet` for high-value items where new-enrollment invalidation is the point.

**ATS is the floor; pinning is an opt-in trade.** ATS (on by default) enforces TLS 1.2+, forward secrecy, and certificate validity. Every `NSAllowsArbitraryLoads` exception is a finding in any security review — scope exceptions per-domain and document why. Certificate pinning defends against *compromised or coerced CAs* and corporate MITM proxies — a real but narrow threat. Its cost is brutal: pin to a leaf cert and a routine renewal bricks your app's networking until users update. If you pin, pin the **SPKI (public key) of an intermediate or your own CA, ship a backup pin, and build a kill switch/remote config** before shipping. Many apps are better served by ATS + token binding than by pinning they can't operate.

**Secrets don't belong in the binary.** API keys in source or `Info.plist` are extractable with `strings` in seconds; obfuscation only raises effort slightly. Hierarchy of honesty: (1) keep the secret server-side and proxy the call; (2) deliver short-lived credentials post-authentication; (3) if a key must ship, treat it as *public* and enforce limits server-side (quotas, bundle-ID checks, attestation via `DCAppAttestService`). Never grade an embedded key as "secure."

**PII leaks through side doors.** Crash reporters upload breadcrumbs and logs; `print`/default-privacy `os_log` interpolations are visible in sysdiagnoses; screenshots of sensitive screens persist in the app switcher snapshot. Use `os.Logger` with `\(value, privacy: .private)`, scrub crash-reporter metadata, and overlay/blur sensitive views on `willResignActive`.

**Jailbreak detection is friction, not a boundary.** On a jailbroken device the OS guarantees are gone — detection (suspicious paths, sandbox-escape writes, `fork()` success) is trivially hookable. It's worth adding only as a *risk signal* for high-compliance apps (banking, PCI-DSS) feeding server-side risk scoring — never as the thing your security depends on. Same for tamper checks: prefer Apple's App Attest, which the server verifies, over client-side self-checks.

**Randomness:** `SecRandomCopyBytes` or `SystemRandomNumberGenerator` (which uses it) for anything security-relevant — never seed your own.

## Decision Framework

Where does this value live?

| Value | Store | Protection |
|---|---|---|
| UI prefs, feature flags, non-sensitive cache | `UserDefaults` / plain files | None needed |
| Auth tokens, refresh tokens, passwords, private keys | **Keychain** | `whenUnlockedThisDeviceOnly` default; `afterFirstUnlock...` only if background access proven necessary |
| High-value secret (payment credential, signing key) | Keychain + `SecAccessControl` | `.biometryCurrentSet` (+ Secure Enclave for keys via `kSecAttrTokenIDSecureEnclave`) |
| Bulk sensitive documents / database | File / SQLite / Core Data store | `.completeFileProtection` (or `.completeUntilFirstUserAuthentication` if background reads needed) |
| Third-party API key | Server-side proxy if at all possible | If shipped: assume public, enforce server-side limits + App Attest |

Gate or bind?

- Action the *server* authorizes anyway (open app, view balance) → `LAContext` gate with `.deviceOwnerAuthentication`.
- Secret that must be cryptographically unreleasable without biometry → Keychain item with `SecAccessControl(.biometryCurrentSet)`.

Pin or not?

- Threat includes coerced CAs / hostile networks for high-value data (banking, health) **and** you control cert rotation + have remote kill switch → pin SPKI of intermediate + backup pin.
- Otherwise → ATS defaults, zero exceptions, short-lived tokens.

## Workflow

1. **Read the existing code.** Inventory current storage (`grep` for `UserDefaults`, `kSecClass`, hardcoded keys/`Bearer `, `NSAllowsArbitraryLoads` in Info.plist), auth flow, crash/logging SDKs, and compliance context (payments → PCI-DSS, health → HIPAA-adjacent, finance → SOX audit trails).
2. **Classify every stored value** against the storage table above; list each item with its chosen shelf and accessibility class. This list *is* the design artifact.
3. **Migrate misplaced secrets** to Keychain (read old location → write Keychain → delete old → never write old again). Remember Keychain items survive app reinstall — decide whether first-launch should purge them.
4. **Implement the Keychain wrapper** (pattern below) — one small, tested type; no third-party dependency needed for simple needs.
5. **Add biometric gating/binding** where the threat model calls for it, with a passcode fallback decision made explicitly.
6. **Review the transport layer**: ATS exceptions justified or deleted; pinning decision documented with rotation plan (implementation hooks live in `ios-networking.md`'s session delegate).
7. **Sweep side channels**: logging privacy levels, crash-report scrubbing, app-switcher snapshot, pasteboard use (`UIPasteboard` with `localOnly`/expiry for sensitive copies).
8. **Verify against the Quality Checklist**, and run the app once from a fresh install to confirm Keychain residue and protection classes behave as intended.

## Patterns

### Keychain wrapper (the 80% case)

```swift
struct KeychainStore {
    enum KeychainError: Error { case notFound, unexpectedStatus(OSStatus) }
    let service = "com.example.app"

    func save(_ data: Data, account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    func read(account: String) throws -> Data {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        switch SecItemCopyMatching(query as CFDictionary, &result) {
        case errSecSuccess: return result as! Data
        case errSecItemNotFound: throw KeychainError.notFound
        case let status: throw KeychainError.unexpectedStatus(status)
        }
    }
}
```

### Biometric-bound Keychain item (binding, not just gating)

```swift
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    .biometryCurrentSet,        // new fingerprint/face enrollment invalidates the item
    nil
)!
let attributes: [CFString: Any] = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrService: "com.example.app",
    kSecAttrAccount: "payment-credential",
    kSecValueData: secret,
    kSecAttrAccessControl: access,   // mutually exclusive with kSecAttrAccessible in the add
]
// Reading this item triggers the Face ID prompt automatically via the LAContext in kSecUseAuthenticationContext.
```

### Biometric gate for an action (UX-grade)

```swift
func authenticate(reason: String) async throws {
    let context = LAContext()
    context.localizedCancelTitle = "Use Passcode Later"
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
        throw error ?? LAError(.biometryNotAvailable)   // decide fallback explicitly, don't crash
    }
    try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    // Bool gate only — a compromised device can bypass this. Server must still authorize.
}
```

### Privacy-aware logging

```swift
import os
let logger = Logger(subsystem: "com.example.app", category: "auth")
logger.info("Login succeeded for user \(userID, privacy: .private(mask: .hash))")
// Never: print("token: \(token)") — print() output lands in sysdiagnoses and CI logs.
```

### App-switcher snapshot cover

```swift
// In the scene delegate / App lifecycle observer:
func sceneWillResignActive(_ scene: UIScene) {
    guard let window = (scene as? UIWindowScene)?.keyWindow else { return }
    let cover = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    cover.frame = window.bounds
    cover.tag = 0xC0FE
    window.addSubview(cover)          // iOS snapshots AFTER this — switcher shows the blur
}

func sceneDidBecomeActive(_ scene: UIScene) {
    (scene as? UIWindowScene)?.keyWindow?.viewWithTag(0xC0FE)?.removeFromSuperview()
}
```

### Jailbreak signal (risk input, never a boundary)

```swift
func deviceRiskSignals() -> [String] {
    var signals: [String] = []
    if FileManager.default.fileExists(atPath: "/Applications/Cydia.app") { signals.append("cydia") }
    if (try? "x".write(toFile: "/private/jb_probe", atomically: true, encoding: .utf8)) != nil {
        try? FileManager.default.removeItem(atPath: "/private/jb_probe")
        signals.append("sandbox-escape")
    }
    return signals   // sent to the server as ONE input to its risk model — never gates locally;
}                    // every check here is hookable. Prefer DCAppAttestService for real attestation.
```

### File protection for bulk data

```swift
try data.write(to: url, options: [.completeFileProtection, .atomic])
// Or for an existing store directory:
try FileManager.default.setAttributes(
    [.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
// .complete = unreadable while device locked; use .completeUntilFirstUserAuthentication
// only if background processing must read it.
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| Token visible in device backup / plist dump | Stored in `UserDefaults` "temporarily" | Move to Keychain with `ThisDeviceOnly` accessibility; delete the old default |
| User stays logged in after app deletion + reinstall | Keychain items survive uninstall by design | On first launch (`UserDefaults` install flag), purge stale Keychain items deliberately |
| Background refresh crashes with `errSecInteractionNotAllowed` | Secret stored `whenUnlocked` but read while device locked | Use `.afterFirstUnlockThisDeviceOnly` for that one item — not as a global default |
| App-wide outage after certificate renewal | Pinned the leaf certificate | Pin intermediate/CA SPKI hashes, ship a backup pin, add remote kill switch; rehearse rotation |
| "Biometrics secured" feature bypassed on jailbroken device | `evaluatePolicy` Bool treated as encryption | Bind via Keychain `SecAccessControl(.biometryCurrentSet)`; server authorizes regardless |
| API key extracted and abused | Key embedded in binary, graded as secret | Proxy server-side or treat as public: quotas, bundle checks, App Attest |
| PII in crash dashboards | Default `os_log` privacy / breadcrumbs with emails | `privacy: .private`, scrub crash-reporter user metadata, audit breadcrumb calls |
| Sensitive screen visible in app switcher | No snapshot handling | Overlay a blur/cover view on `willResignActive`, remove on `didBecomeActive` |
| Users locked out after re-enrolling Face ID | `.biometryCurrentSet` invalidated the item, no recovery path | Expected behavior — design re-authentication (password/server) to re-provision the item |
| ATS exception "to make staging work" ships to prod | `NSAllowsArbitraryLoads` global flag | Per-domain exception in debug configs only; CI check that release Info.plist has no exceptions |

## Quality Checklist

- [ ] No token, password, or key in `UserDefaults`, plist, or source — grep proves it
- [ ] Every Keychain item has an explicitly chosen accessibility class; `ThisDeviceOnly` unless backup migration is a documented requirement
- [ ] Release Info.plist contains zero ATS exceptions (or each one is per-domain, justified in writing)
- [ ] If pinning: SPKI pins (not leaf certs), backup pin shipped, rotation runbook + kill switch exist
- [ ] Biometric flows distinguish gating (`LAContext`) from binding (`SecAccessControl`) and each use is the intended one
- [ ] Biometry fallback decided explicitly: passcode allowed, or lockout path designed
- [ ] Keychain residue after reinstall handled deliberately (purge or keep — chosen, not accidental)
- [ ] Sensitive files written with `.completeFileProtection` (or documented weaker class with reason)
- [ ] Logs use `os.Logger` privacy annotations; crash reporter scrubbed of PII; no `print` of payloads
- [ ] App-switcher snapshot covered for sensitive screens; sensitive pasteboard writes use `localOnly` + expiry
- [ ] All security-relevant randomness from `SecRandomCopyBytes`/system RNG
- [ ] Jailbreak/tamper checks (if any) feed server-side risk decisions — nothing client-side is a trust boundary
- [ ] Compliance mapping done where applicable (PCI-DSS: no PAN storage client-side; SOX: auth events auditable server-side)
