# Presentation Cache — Universal Optional Pattern

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

> This is a **recommended optional pattern** — not part of the SDK contract. The SDK works correctly without it. The cache is purely an app-side optimisation against a known SDK behaviour.

## The problem

`Purchasely.fetchPresentation(...)` hits the network on every call. If you display the same placement repeatedly (`onAppear` / `onViewWillAppear` firing multiple times, sheet/back navigation, recomposition, etc.), each call:

1. Round-trips to Purchasely servers.
2. **For flow placements**, accumulates a `flowSteps` entry in the SDK's internal `FlowsManager`.

A known SDK quirk: when only one visible step remains and gets dismissed, a stuck `PLYWindow` (iOS) / overlay (Android) can intercept touches and freeze the UI. The same behaviour can manifest on cross-platform SDKs since they bridge to the native ones.

## The pattern

Wrap your fetches in an **app-side cache keyed by `placementId[/contentId]`**. Reuse the cached `PLYPresentation` rather than re-fetching.

### When to invalidate

The cached presentation can become stale. Invalidate (clear all entries) when any of these happen:

- **User attribute changed** — audience targeting may now resolve differently. iOS exposes `PLYUserAttributeDelegate`; on Android / cross-platform you invalidate manually after `setUserAttribute(...)` calls.
- **`synchronize()` succeeded** — subscription state may have changed, which affects audience.
- **SDK mode change** (Full ↔ Observer) — the session is reset.
- **User login or logout** — the entire user identity changed.

Invalidation is intentionally coarse-grained (clear-all) because the SDK doesn't expose attribute→audience dependencies.

> Purchasely SDK 6.x is expected to add native placement-level caching — when it ships, remove the app-side cache.

## Skeleton implementations

### iOS (Swift) — `actor` for thread-safety

```swift
actor PresentationCache {
    static let shared = PresentationCache()
    private var cache: [String: PLYPresentation] = [:]

    func get(_ key: String) -> PLYPresentation? { cache[key] }
    func set(_ key: String, _ p: PLYPresentation) { cache[key] = p }
    func invalidateAll() { cache.removeAll() }
}

// Wire user-attribute invalidation
class AttrDelegate: NSObject, PLYUserAttributeDelegate {
    func onUserAttributeSet(key: String, type: PLYUserAttributeType, value: Any, source: PLYUserAttributeSource) {
        Task { await PresentationCache.shared.invalidateAll() }
    }
    func onUserAttributeRemoved(key: String, source: PLYUserAttributeSource) {
        Task { await PresentationCache.shared.invalidateAll() }
    }
}
Purchasely.setUserAttributeDelegate(AttrDelegate())
```

### Android (Kotlin)

```kotlin
object PresentationCache {
    private val cache = mutableMapOf<String, PLYPresentation>()
    @Synchronized fun get(key: String) = cache[key]
    @Synchronized fun set(key: String, p: PLYPresentation) { cache[key] = p }
    @Synchronized fun invalidateAll() = cache.clear()
}
// Invalidate manually after attribute changes / synchronize / login / logout.
// The Android SDK does not (yet) expose a user-attribute delegate as public API.
```

### React Native (TypeScript)

```ts
const cache = new Map<string, any>();

export const presentationCache = {
  get: (key: string) => cache.get(key),
  set: (key: string, p: any) => cache.set(key, p),
  invalidateAll: () => cache.clear(),
};

// Hook into your user-attribute and synchronize wrappers:
async function setUserAttribute(key: string, value: any) {
  Purchasely.setStringAttribute(key, value);
  presentationCache.invalidateAll();
}
```

### Flutter (Dart)

```dart
class PresentationCache {
  PresentationCache._();
  static final instance = PresentationCache._();

  final _cache = <String, PLYPresentation>{};

  PLYPresentation? get(String key) => _cache[key];
  void set(String key, PLYPresentation p) => _cache[key] = p;
  void invalidateAll() => _cache.clear();
}
```

### Cordova (JavaScript)

```js
const presentationCache = (() => {
  const m = new Map();
  return {
    get: k => m.get(k),
    set: (k, v) => m.set(k, v),
    invalidateAll: () => m.clear(),
  };
})();
```

## Fetch-or-cache wrapper

The pattern is identical on every platform:

```text
fetchOrCached(placementId):
    cached = cache.get(placementId)
    if cached: return cached
    fresh = await Purchasely.fetchPresentation(placementId)
    cache.set(placementId, fresh)
    return fresh
```

Always combine this with the [presentation-types.md](presentation-types.md) guard — cache the fetched presentation regardless of type, but only **display** `NORMAL` / `FALLBACK`.

## See also

- [presentation-types.md](presentation-types.md) — the type guard you must apply to every fetched presentation
- [user-attributes-targeting.md](user-attributes-targeting.md) — why attribute changes invalidate the cache
