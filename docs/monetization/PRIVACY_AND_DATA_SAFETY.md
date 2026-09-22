# Privacy wording and Play Data safety for monetization

Drafted in PR 7b. **Not live.** The in-app policy (`lib/core/legal/legal_content.dart`), the website copy in `docs/site` and the Play Data safety form describe only what the released app does. Monetization processing doesn't happen until activation. These texts go live in PR 8, in the same release that turns a cohort on, and follow the decisions below. Publishing them earlier would describe processing that isn't happening. Leaving them out after activation would hide processing that is.

The no-ads statement stays true: monetization adds no ads, third-party analytics or tracking SDKs.

## Decisions (22 Sep 2026)

The operator is in Czechia, so EU law (GDPR, the ePrivacy Directive as implemented in Czech law) sets the rules. The same rules apply to learners everywhere. One standard is simpler to run and audit, and it meets or exceeds what most other jurisdictions require.

1. **Billing records after account deletion: kept only while restorable, then 30 days.** A deleted account's purchase stays without its account ID only while Google Play could still restore it (active, grace, on hold, paused or cancelled but paid). It is deleted 30 days after it expires or is revoked, or 30 days after creation if it never completed. `cleanup_privacy_records` does this on every worker run.
   - **Why this is enough (GDPR Art. 5(1)(c) and (e)):** Google Play is the merchant of record and handles payment, refunds and chargebacks. Czechify's bookkeeping documents are Google's payout and tax reports, not per-learner purchase rows. They are kept outside this database for the statutory periods: 5 years for accounting records (§ 31 of Act 563/1991 on accounting) and 10 years for VAT documents (§ 35 of Act 235/2004 on VAT). Confirm both periods with your accountant; they concern the payout reports, not this database.
2. **Referral lesson summaries: 90 days after the invitation is decided.** "Decided" means both rewards were settled, the claim was rejected, or the referrer's account was deleted. Summaries are also deleted 90 days after the campaign ends. The reward record that explains a granted unit stays while the unit does; it holds no learning detail. The same run deletes the existing-user snapshot 90 days after its claim window closes, and rows that are only operational after 30 days: notification dedupe, expired purchase intents, finished billing jobs, and audit rows of deleted accounts.
3. **Play Integrity: opt-in, and declared in Data safety.** A Play Integrity request reads information from the device: attestation, app and licence details (see [Google's data handling notes](https://developer.android.com/google/play/integrity/terms)). EU law allows that only with consent unless it is strictly necessary for a service the user asked for: ePrivacy Art. 5(3), in Czechia § 89(3) of Act 127/2005 on electronic communications. Invitations work without it, so it isn't strictly necessary.
   - The invite screen has a switch, **off until the learner turns it on**. Withdrawing is as easy as giving it, and the choice and its time are recorded per account.
   - Without consent the app never asks Google Play and sends the receipt to support review instead.
   - Google leaves the Data safety answer to the developer, so the transparent choice is to declare it (table below).

## In-app policy additions (English; Czech to follow the approved text)

**New section: "Subscriptions"**

> If you subscribe, Google Play handles the payment. Czechify never receives your card or bank details. We receive and store what's needed to give you access and to restore it:
> - the subscription you chose and its plan;
> - Google's purchase token, encrypted;
> - the subscription's state, renewal and end date;
> - when we last checked it with Google.
>
> We also send Google Play a pseudonymous code derived from your account, so a purchase can be matched to the right Czechify account. This is processed to provide the subscription you bought (GDPR Article 6(1)(b)).
>
> If you restore a purchase that belongs to another Czechify account, for example one you deleted, support can move it to your account after checking your Google Play order. To decide, support sees both accounts' email addresses and the purchase, never your payment details. The case is deleted 90 days after the decision.
>
> Deleting your Czechify account doesn't cancel a Google Play subscription. Cancel it in Google Play under Payments & subscriptions. After deletion, a record of the purchase without your account ID is kept only while Google Play could still restore it, and deleted 30 days after it ends.

**New section: "Inviting friends"**

> If you invite a friend with your code, or join with someone's code, we record which accounts the invitation connects. We also record a summary of each lesson the invited friend completes: the lesson, which exercises were answered or skipped, and when. This shows that the friend really learned before a unit is given to the person who invited them.
>
> If you turn on "Check this phone with Google Play", the app asks Google Play Integrity to confirm the app is genuine and was installed from Google Play. This reads information from your device, so it only happens with your consent (Article 6(1)(a)). You can turn it off at any time. We keep only the result ("verified" or "needs review"), never the token. If it's off, support checks your lessons by hand instead.
>
> Neither side sees the other's account, email or learning details. The person who invited you sees only "Friend 1: first unit complete" style progress.
>
> This is processed under Article 6(1)(b) to run the program you joined, and under Article 6(1)(f) to prevent abuse. Lesson summaries are deleted 90 days after the invitation is decided, or 90 days after the campaign ends. If either account is deleted, that account's details go with it. Units the other person already earned stay theirs.

**New section: "AI chat subscription"**

> To enforce the daily limit and avoid charging you twice, we record each tutor request's time, the number of words (tokens) used and its estimated cost. Records never include the message text. So a reply isn't lost when your connection drops, it is stored encrypted for 24 hours and then deleted. A content-free record that the request happened is kept for 7 days.

**New section: "Learners from before subscriptions"**

> When subscriptions start, we take a one-time copy of the lesson progress already synced to accounts created before that date. From it we decide which units each learner keeps for good. If you learned offline, you can send this device's record of lessons from before that date once, within 30 days. Larger claims are checked by support. The copy is deleted 90 days after the claim period ends; the units you keep stay.

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
| Device or other IDs | Yes, only with the learner's consent | No (Google processes it for Czechify) | Fraud prevention, security and compliance | Play Integrity device attestation for invited learners. Processed ephemerally: only the verdict is kept. Optional. |

"Data is encrypted in transit" and "users can request deletion" remain Yes.

## Apple App Privacy

Not affected until an iOS purchase flow exists. The release inventory keeps iOS on the legacy policy.
