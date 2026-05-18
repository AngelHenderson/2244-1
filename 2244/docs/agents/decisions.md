# Agent Decisions

## Recent Decisions (Recovered Session)

1. **"Winner Energy" Persona**:
   - Decided that NPC competitive comments should not sound surprised ("Are you kidding?") or empathetic ("That's rough"). They must project cocky, dismissive, "winner energy" ("That's adorable", "How embarrassing", "Nice try", "Watch this").
   
2. **Persistence Split**:
   - Interactions (likes/comments) must be applied to the correct underlying cache. NPC posts live in the daily `feedCacheKey`, while user-created posts live in `userPostsKey`. Functions modifying feed state must check both.

3. **Strict 55% Competitiveness**:
   - Decided to force the `isCompetitive` flag to `true` 55% of the time in `generateContextualReply`. Contextual replies shouldn't blindly match the tone of non-competitive event posts if it means dragging the total feed competitiveness below the target 55% ratio.

4. **Wiping Stale User Post JSON**:
   - Decided to bump `userPostsKey` to `.v2` because old generated comments from before the template rewrite were permanently embedded in the saved JSON of persistent user posts.

5. **Universal Higher Milestone References**:
   - Decided that *all* competitive comments, even for non-milestone posts (e.g. streaks, timed challenges, quests) or generic fallbacks, should include a taunt referencing a strictly higher milestone. The logic scans the original post's `message` for a base milestone to anchor this jump. If none is found, it defaults to `11n` to guarantee a higher milestone is always cited.
