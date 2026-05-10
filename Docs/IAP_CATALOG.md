# App Store Connect IAP Catalog

This is the canonical list of in-app purchase product IDs the app expects.
**You must create each of these in App Store Connect** with the exact ID shown.
The app reads these from `IAPProduct.allProducts` (`Packages/GameCore/Sources/GameCore/Models/IAPProduct.swift:46`).

If a product is missing from ASC, the app's purchase flow for that item silently
fails (`PurchaseService.purchase(productID:)` returns `false` with `errorMessage =
"Product unavailable"`). The paywall sheet falls back to the static price hint.

## Product checklist (15 SKUs)

| Display name | Product ID | Type | Reference price | Notes |
|---|---|---|---|---|
| Remove Ads | `com.game2244.adfree` | Non-consumable | $4.99 | Permanent ad removal. Bundles below also grant this entitlement. |
| Coin Pouch | `com.game2244.coins.small` | Consumable | $0.99 | 500 coins |
| Coin Bag | `com.game2244.coins.medium` | Consumable | $3.99 | 2,500 coins (25% bonus) |
| Coin Chest | `com.game2244.coins.large` | Consumable | $9.99 | 10,000 coins (50% bonus) |
| Power-Up Pack | `com.game2244.powerup.bundle` | Consumable | $2.99 | 10 hammer, 10 swap, 20 undo, 5 shuffle, 5 magnet, 5 double |
| Cyberpunk Theme | `com.game2244.theme.cyberpunk` | Non-consumable | $1.99 | Premium music theme |
| Lo-Fi Theme | `com.game2244.theme.lofi` | Non-consumable | $1.99 | Premium music theme |
| Orchestral Theme | `com.game2244.theme.orchestral` | Non-consumable | $1.99 | Premium music theme |
| Starter Pack | `com.game2244.starter.pack` | Non-consumable | $4.99 | 1,000 coins + 5 hammer/swap, 10 undo, ad-free entitlement |
| Mega Bundle | `com.game2244.mega.bundle` | Non-consumable | $19.99 | 5,000 coins + all powerups + all 3 themes + ad-free |
| Auto-Claim Boosts Monthly | `com.game2244.boosts.autoclaim.monthly` | Auto-renewable subscription | $1.99/month | Active subscription unlocks the auto-claim boosts entitlement |
| Ultimate2244 Pro Monthly | `com.game2244.pro.monthly` | Auto-renewable subscription | $4.99/month | Active subscription unlocks Pro and suppresses ads |
| Ultimate2244 Pro Yearly | `com.game2244.pro.yearly` | Auto-renewable subscription | $39.99/year | Active subscription unlocks Pro and suppresses ads |
| Ultimate2244 Pro Family Monthly | `com.game2244.pro.family.monthly` | Auto-renewable subscription | $9.99/month | Active subscription unlocks Pro, suppresses ads, and is family-shareable |
| Ultimate2244 Pro Family Yearly | `com.game2244.pro.family.yearly` | Auto-renewable subscription | $79.99/year | Active subscription unlocks Pro, suppresses ads, and is family-shareable |

## Setup steps in App Store Connect

For each product:
1. **My Apps → 2244 → In-App Purchases → +**
2. Pick the right type (`Non-Consumable` or `Consumable` per the table).
3. Reference name: use the **Display name** column (visible only in ASC).
4. Product ID: paste the **exact** ID from the table — case-sensitive, must match.
5. Price tier: pick the tier matching the reference price column (or the closest tier; `IAPProduct.formattedPrice` is just a UI hint, App Store reports the real price).
6. App Store information → Display name and Description per the `IAPProduct` constants in `IAPProduct.swift`.
7. **Status → Ready to Submit** once review screenshots are uploaded.
8. Attach all 10 one-time IAP SKUs and all 5 subscription SKUs to the next app submission.

## StoreKit configuration file (for local testing without ASC)

The app target includes `2244/game2244/Configuration.storekit` with all 15
products from the table above, including the five auto-renewable subscriptions.
The shared `game2244` scheme points at this file for local simulator purchases.

This lets the paywall flow round-trip in the simulator before ASC is provisioned.

## Automated consistency check

Run this credential-free check before every release candidate:

```bash
node scripts/validate-launch-readiness.mjs
```

It verifies:

- every ID in this doc exists in `IAPProduct.allProducts`;
- every code product ID is documented here;
- `Configuration.storekit` contains exactly the canonical product set;
- shop JSON IDs are a subset of the canonical StoreKit catalog.

## Bundle entitlements

`Starter Pack` and `Mega Bundle` are wired to grant the included
`adFree` and `theme(...)` entitlements automatically — this is handled by
`PurchaseService.applyOwnership(for:)` reading
`IAPProduct.permanentEntitlementProductIDs`. No backend logic is required for that.

## Subscription entitlements

`PurchaseService` loads the five subscription IDs with the rest of the StoreKit
catalog. Active Pro subscriptions (`com.game2244.pro.monthly`,
`com.game2244.pro.yearly`, `com.game2244.pro.family.monthly`, and
`com.game2244.pro.family.yearly`) set `isProPurchased` and also make
`isAdFreePurchased` true while active. The auto-claim subscription
(`com.game2244.boosts.autoclaim.monthly`) sets `isAutoClaimBoostsPurchased`;
Pro also satisfies that flag. Subscription IDs are reconciled from
`Transaction.currentEntitlements` so expired subscriptions are removed from the
local active entitlement set.

Family subscription products must be created in the same `2244 Memberships`
subscription group and marked family-shareable in App Store Connect. In-app
member and invite screens are social/account management surfaces; entitlement
sharing itself relies on Apple's Family Sharing.

## Cloud receipt verification (optional, recommended)

The app currently trusts StoreKit's local `Transaction.verified` check. For
production hardening, consider deploying a Firebase Cloud Function that validates
the transaction's JWS signature server-side and writes `players/{uid}/purchases/{txn}`
on success. The `PurchaseService.onVerifiedPurchase` callback is the natural hook —
fire-and-forget the JWS to your function from there.

## Reward ledger & idempotency

Every IAP grant routes through `RewardLedgerStore.grant(...)`. The idempotency
key is `"\(transactionID):\(productID):\(itemIndex):\(itemType)"`, so retrying a
verified transaction (StoreKit will replay finished transactions on launch and
on `appStoreSync()`) cannot double-grant gems, power-ups, or the ad-free
entitlement. See `Packages/GameApp/Sources/GameApp/ShopStore.swift:284` for the
grant path.

## Sandbox purchase checklist

Manual App Store Connect validation still requires sandbox accounts:

1. Sign into a sandbox Apple ID on a simulator or device.
2. Run the `game2244` scheme with `Configuration.storekit` disabled when testing
   real sandbox products.
3. Buy each consumable: Coin Pouch, Coin Bag, Coin Chest, and Power-Up Pack.
   Confirm the reward appears exactly once after purchase and exactly once after
   a StoreKit transaction replay.
4. Buy Starter Pack and Mega Bundle. Confirm ad-free state, included fixed
   rewards, and premium music theme ownership.
5. Buy each music theme SKU from the paywall. Confirm ownership persists across
   force quit and restore.
6. Buy Auto-Claim Boosts Monthly, Pro Monthly, Pro Yearly, Pro Family Monthly,
   and Pro Family Yearly. Confirm active
   entitlements set the expected flags and expired/canceled subscriptions are
   removed after restore.
7. Tap Restore Purchases from Settings. Confirm non-consumable/subscription
   entitlements restore and consumable rewards are not duplicated locally.

## Paid bundles must remain deterministic

App Review treats randomized rewards behind a paid path as a "loot box" and
requires pre-purchase odds disclosure. None of the SKUs in this catalog are
randomized — every line item in `IAPProduct.allProducts` is a fixed quantity
(see `IAPProduct.swift`). If a future paid SKU adds randomized contents, either:

1. Remove the random component (preferred), or
2. Surface odds in the paywall before the purchase action, and document them
   here.
