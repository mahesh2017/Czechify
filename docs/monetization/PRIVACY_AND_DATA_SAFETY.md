# Privacy wording and Play Data safety for monetization

Drafted in PR 7b. **Not live.** The in-app policy (`lib/core/legal/legal_content.dart`), the website copy in `docs/site` and the Play Data safety form describe only what the released app does. Monetization processing doesn't happen until activation. These texts go live in PR 8, in the same release that turns a cohort on, after the open decisions below are settled. Publishing them earlier would describe processing that isn't happening. Leaving them out after activation would hide processing that is.

The no-ads statement stays true: monetization adds no ads, third-party analytics or tracking SDKs.

## Open decisions before activation

1. **Billing record retention.** When an account is deleted, its purchases stay as ownerless records, so a later verified Store restore can be reconciled (7c). How long they're kept, and which fields, must match real accounting, tax and dispute obligations. The contract forbids guessing a legal period in code. Choose the period, then fill in `[RETENTION]` below.
2. **Referral receipt retention.** The contract proposes 90 days after a claim's final decision for the per-exercise records. `cleanup_referral_records` doesn't purge receipts yet. Confirm 90 days and add the purge before the campaign opens.
3. **Play Integrity in Data safety.** Integrity verdicts aren't device identifiers and aren't stored. Google's current guidance on whether the API adds a Data safety category must be checked at submission time.

## In-app policy additions (English; Czech to follow the approved text)

**New section: "Subscriptions"**

> If you subscribe, Google Play handles the payment. Czechify never receives your card or bank details. We receive and store what's needed to give you access and to restore it:
> - the subscription you chose and its plan;
> - Google's purchase token, encrypted;
> - the subscription's state, renewal and end date;
> - when we last checked it with Google.
>
> We also send Google Play a pseudonymous code derived from your account, so a purchase can be matched to the right Czechify account. This is processed to provide the subscription you bought (GDPR Article 6(1)(b)) and to meet accounting obligations (Article 6(1)(c)).
>
> Deleting your Czechify account doesn't cancel a Google Play subscription. Cancel it in Google Play under Payments & subscriptions. After deletion, a record of the purchase without your account ID is kept for [RETENTION] so a restore can be matched and accounting and dispute obligations met.

**New section: "Inviting friends"**

> If you invite a friend with your code, or join with someone's code, we record which accounts the invitation connects. We also record a summary of each lesson the invited friend completes: the lesson, which exercises were answered or skipped, and when. This shows that the friend really learned before a unit is given to the person who invited them.
>
> To keep the program fair, the app asks Google Play Integrity to confirm the app is genuine and was installed from Google Play. We keep only the result ("verified" or "needs review"), never the token.
>
> Neither side sees the other's account, email or learning details. The person who invited you sees only "Friend 1: first unit complete" style progress.
>
> This is processed under Article 6(1)(b) to run the program you joined, and under Article 6(1)(f) to prevent abuse. Lesson summaries are deleted [90 days] after the invitation is decided. If either account is deleted, that account's details go with it. Units the other person already earned stay theirs.

**New section: "AI chat subscription"**

> To enforce the daily limit and avoid charging you twice, we record each tutor request's time, the number of words (tokens) used and its estimated cost. Records never include the message text. So a reply isn't lost when your connection drops, it is stored encrypted for 24 hours and then deleted. A content-free record that the request happened is kept for 7 days.

**New section: "Learners from before subscriptions"**

> When subscriptions start, we take a one-time copy of the lesson progress already synced to accounts created before that date. From it we decide which units each learner keeps for good. If you learned offline, you can send this device's record of lessons from before that date once, within 30 days. Larger claims are checked by support. This copy is kept while it explains the units you keep.

**Changes to existing sections**

- "What we process and why": add purchase records, referral participation, lesson summaries and AI request records, with the purposes above.
- "Recipients and transfers": add Google Play, which processes payments and purchase verification, and Play Integrity.
- "Retention and deletion": add the periods above, and that deletion doesn't cancel a Store subscription.
- "Your rights": the export includes your subscriptions, invitations, rewards, AI allowance and legacy claim. It doesn't include purchase tokens or anything about other learners.

## Play Data safety changes

| Data type | Collected | Shared | Purpose | Notes |
|---|---|---|---|---|
| Financial info → Purchase history | Yes | No | App functionality, Account management | Product, state and validity per account. No payment details; Google Play processes payment. |
| App activity → App interactions | Yes (already declared as learning progress) | No | App functionality, Fraud prevention | Referral lesson summaries for invited learners. |
| App activity → Other user-generated content | Unchanged | | | AI message text is not stored server-side; request records hold counts only. |

"Data is encrypted in transit" and "users can request deletion" remain Yes. Recheck the Play Integrity row (open decision 3).

## Apple App Privacy

Not affected until an iOS purchase flow exists. The release inventory keeps iOS on the legacy policy.
