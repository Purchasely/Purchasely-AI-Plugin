# Purchasely SDK — Architecture Patterns

Recommended architecture patterns for production-grade Purchasely SDK integrations.

---

## PurchaselyWrapper Pattern

**Never call the Purchasely SDK directly from ViewModels, Screens, or UI code.** Wrap all SDK calls in a dedicated `PurchaselyWrapper` class/singleton.

### Benefits
- Single point of control — easy to swap or remove the SDK
- Screens/Views have zero SDK imports — clean separation
- Easier to test (mock the wrapper, not the SDK)
- Type-safe result types (`FetchResult`, `DisplayResult`) instead of raw SDK enums
- SDK init, interceptor, and events are all encapsulated

### Wrapper Responsibilities

| Category | Methods |
|----------|---------|
| **Init & Lifecycle** | `initialize()`, `restart()`, `close()`, `closeDisplayedPresentation()` |
| **Interceptor** | Internal paywall actions interceptor (LOGIN, NAVIGATE, PURCHASE, RESTORE) |
| **Events** | Internal event listener/delegate |
| **Presentations** | `loadPresentation()`, `display()`, `getView()` / `getController()` |
| **User Attributes** | `setUserAttribute()`, `incrementUserAttribute()` |
| **User Management** | `userLogin()`, `userLogout()`, `anonymousUserId` |
| **Purchases** | `restoreAllProducts()`, `synchronize()`, `signPromotionalOffer()` |
| **Consent** | `revokeDataProcessingConsent()` |
| **Info** | `sdkVersion`, `isDeeplinkHandled()` |

### Platform Implementations

**Android (Kotlin):**
- Singleton via DI (Koin/Hilt): `PurchaselyWrapper(premiumManager, runningModeRepo, ...)`
- ViewModels receive it via constructor injection
- App entry point calls `wrapper.initialize(application, apiKey, logLevel)`

**iOS (Swift):**
- Singleton: `PurchaselyWrapper.shared` conforming to `PurchaselyWrapping` protocol
- ViewModels accept `PurchaselyWrapping` via init with default `.shared`
- App entry point calls `wrapper.initialize(apiKey:, appUserId:, logLevel:, onReady:)`
- `MockPurchaselyWrapper` in tests implements the protocol

---

## Observer Mode: Reactive Purchase Decoupling

In **Observer mode**, the app handles purchases natively (StoreKit 2 / Play Billing). The recommended architecture completely decouples the billing service from the Purchasely SDK.

### Architecture

```
PurchaselyWrapper (orchestrator)          PurchaseManager (pure billing)
    │                                           │
    │ PURCHASE (observer mode)                  │
    │   → emit PurchaseRequest ──────────────►  │
    │                                           │ Execute native billing
    │                                           │ (StoreKit 2 / Play Billing)
    │   ◄──────────────────────────────────── │
    │   TransactionResult (.success)             │
    │                                           │
    │ synchronize()                              │
    │ processAction(false)                       │
    │ premiumManager.refreshPremiumStatus()      │
```

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Communication | Reactive flows | Total decoupling, PurchaseManager has zero SDK knowledge |
| Actions via flow | PURCHASE and RESTORE only | LOGIN/NAVIGATE are simple UI actions |
| synchronize() caller | PurchaselyWrapper | PurchaseManager stays pure billing |
| processAction storage | Single pending property | One purchase at a time from paywall |

### Types

**Android (Kotlin):**
```kotlin
data class PurchaseRequest(val activity: Activity, val productId: String, val offerToken: String)
data object RestoreRequest
sealed class TransactionResult { Success, Cancelled, Error(message), Idle }
```
Communication via `SharedFlow`.

**iOS (Swift):**
```swift
struct PurchaseRequest { let productId: String }
enum TransactionResult { case success, cancelled, error(String?), idle }
```
Communication via Combine `PassthroughSubject`.

### PurchaseManager Rules
- **Zero Purchasely/SDK imports** — pure native billing service
- Observes purchase/restore requests from reactive channels
- Emits `TransactionResult` back through reactive channels
- Android: takes `billingClientFactory` lambda for testability
- iOS: takes injected closures for `anonymousUserId` and `signPromotionalOffer`

### Wrapper Orchestration

The wrapper stores `pendingProcessAction` when emitting a request. On `TransactionResult`:

| Result | Actions |
|--------|---------|
| Success | synchronize() → processAction(false) → premiumManager.refreshPremiumStatus() |
| Cancelled | processAction(false) |
| Error | processAction(false) |
| Idle | ignore |

---

## Testability

### Protocol-Based Mocking (iOS)
- `PurchaselyWrapping` protocol abstracts the wrapper
- ViewModels accept protocol type, production code uses `.shared`
- Tests inject `MockPurchaselyWrapper`

### DI-Based Mocking (Android)
- `PurchaselyWrapper` injected via Koin/Hilt constructor
- Tests use MockK: `mockk<PurchaselyWrapper>(relaxed = true)`

### PurchaseManager Testability
- Android: `billingClientFactory` parameter allows mock BillingClient injection
- iOS: Injected closures replace direct SDK calls
