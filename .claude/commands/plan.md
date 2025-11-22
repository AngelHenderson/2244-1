
### Plan: Add reward spinner to “New Tile Unlocked” modal

Goals:
- Show a looping multiplier spinner (2×, 3×, 4×, 5×, 4×, 3×, 2×) above the “claim” button when a tile is unlocked.
- Spinner sweeps left→right→left continuously until the player taps “Claim”.
- Claim button should apply the multiplier where appropriate (existing logic already multiplies rewards; spinner should feed that value).

Steps:
1. **Design spinner model/state**
   - Extend `GameStore` (or modal view model) to expose a selected multiplier and animation timer.
   - Defaults to 4× (center) but animates across the sequence.

2. **Implement UI component**
   - Create a reusable `RewardSpinnerView` (or adapt existing one) that renders the 7 multiplier slots, highlights the active slot, and animates the indicator bouncing left/right.
   - Use `TimelineView`/`Timer.publish` or SwiftUI animation to oscillate until stopped.

3. **Integrate into unlock modal (`RewardSpinnerView` / `MergeInfoBoard` equivalent)**
   - Insert spinner between “Already Claimed” text and claim button.
   - Bind spinner’s current multiplier to state.

4. **Claim flow hook-up**
   - When the player taps claim, stop the spinner animation and pass the multiplier to existing reward logic (currently uses fixed value; update to read spinner selection).
   - Ensure spinner resets when modal closes.

5. **QA**
   - Verify animation runs smoothly, stops on claim, and multiplier affects reward totals correctly.
