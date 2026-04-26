# App Store Connect IAP Catalog

This is the canonical list of in-app purchase product IDs the app expects.
**You must create each of these in App Store Connect** with the exact ID shown.
The app reads these from `IAPProduct.allProducts` (`Packages/GameCore/Sources/GameCore/Models/IAPProduct.swift:46`).

If a product is missing from ASC, the app's purchase flow for that item silently
fails (`PurchaseService.purchase(productID:)` returns `false` with `errorMessage =
"Product unavailable"`). The paywall sheet falls back to the static price hint.

## Product checklist (10 SKUs)

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

## Setup steps in App Store Connect

For each product:
1. **My Apps → 2244 → In-App Purchases → +**
2. Pick the right type (`Non-Consumable` or `Consumable` per the table).
3. Reference name: use the **Display name** column (visible only in ASC).
4. Product ID: paste the **exact** ID from the table — case-sensitive, must match.
5. Price tier: pick the tier matching the reference price column (or the closest tier; `IAPProduct.formattedPrice` is just a UI hint, App Store reports the real price).
6. App Store information → Display name and Description per the `IAPProduct` constants in `IAPProduct.swift`.
7. **Status → Ready to Submit** once review screenshots are uploaded.
8. Attach all 10 SKUs to the next app submission.

## StoreKit configuration file (for local testing without ASC)

Until the SKUs are live in ASC, you can simulate them with a `Configuration.storekit`
file in the app target:

1. Xcode → File → New → File → StoreKit Configuration File.
2. Name it `Configuration.storekit`, save under `2244/game2244/`.
3. Add each product from the table above with the same product ID.
4. Edit the active scheme → Run → Options → StoreKit Configuration → pick the file.

This lets the paywall flow round-trip in the simulator before ASC is provisioned.

## Bundle entitlements

`Starter Pack` and `Mega Bundle` are wired to grant the included
`adFree` and `theme(...)` entitlements automatically — this is handled by
`PurchaseService.applyOwnership(for:)` reading
`IAPProduct.permanentEntitlementProductIDs`. No backend logic is required for that.

## Cloud receipt verification (optional, recommended)

The app currently trusts StoreKit's local `Transaction.verified` check. For
production hardening, consider deploying a Firebase Cloud Function that validates
the transaction's JWS signature server-side and writes `players/{uid}/purchases/{txn}`
on success. The `PurchaseService.onVerifiedPurchase` callback is the natural hook —
fire-and-forget the JWS to your function from there.
