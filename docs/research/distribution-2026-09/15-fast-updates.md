# 15 — Fast updates: hotfix latency per platform and an operating model for Diceroll

Date: 2026-09-30. Scope: how fast Diceroll can push (a) a **content/data hotfix**, (b) a **code hotfix**,
and (c) **force players off a broken version** on every channel in the distribution-v2 design
(`docs/design/2026-09-29-distribution-v2.md` §6, §7.4, §12). The note ends with a recommended
operating model, what to automate and the open risks.

Marks: **[V]** verified at the linked primary source this session; **[V2]** practitioner or
second-hand source (linked); **[C]** computed here from stated assumptions; **[U]** uncertain,
inferred or unconfirmed.

---

## 0. Key findings

1. **Content fixes are fast everywhere except where the design makes them slow.** A signed
   `timestamp.jws` flip reaches the CDN edge in under a second (Cloudflare Instant Purge, <150 ms
   [V]). The limit is the client: §7.4 checks "**at most every 6 h**". A player mid-session can keep
   running crash-causing content for up to 6 h. Checking on launch/resume, on title return and
   every 15 min in the foreground costs almost nothing: under 5 M CDN requests a month at 100k MAU,
   inside Cloudflare's free tiers [C]. It cuts the typical latency to under 15 min.
2. **Code fixes are gated by stores and cannot beat about a day on iOS.** App Review in September 2026
   averages about 7 h waiting plus 2 h in review (Runway tracker) [V2]. Apple says "90% of
   submissions are reviewed in less than 24 hours" [V]. The tail is long, though: 5–16-day waits were
   reported in July and August 2026 [V2]. An approved version can take up to 24 h to appear [V], and
   auto-updates move the majority of users in about 2 days [V2]. Expedited review exists for
   "critical bug fix" cases (with reproduction steps) [V]. Practitioners report 4–24 h when it is
   granted, and fewer grants in 2026 [V2].
3. **Google Play is the fastest mobile store:**
   - Reviews average about 46 min (Runway, September 2026) [V2]. Google's own guidance is "up to 7
     days" [V].
   - You can **halt even a fully rolled-out release**, which serves the previous version to new and
     not-yet-updated users [V].
   - In-App Updates priority 5 plus the immediate flow reach active players at their next launch once
     Play sees the update. That takes a few hours [V2].
4. **Steam is the only store with a true rollback.** Setting an older build live on the default
   branch takes minutes (with a Steam Guard mobile confirmation [V]). Clients must download the
   current build before they can launch again [V]. Games played in the last 3 days update
   immediately [V].
5. **Other channels:**
   - **itch app:** a push is live on upload, and the app checks every 30 min [V].
   - **Flathub:** 1–2 h to publish after merge, then the user's software centre [V]/[U].
   - **Velopack direct:** as fast as our own check cadence plus the next restart.
   - **Web:** seconds for new page loads; open tabs need an in-game prompt.
6. **No new Apple mechanism forces updates** (checked WWDC26 coverage and the StoreKit surface; none
   found [V2]/[U]). The in-game `minSupported` card remains the only way. Neither store forbids an
   update gate. Play *does* forbid behaving differently for reviewers, so never detect review; keep
   `minSupported` ≤ the build under review instead [V].
7. **Kill switches are the real "minutes" lever for code bugs.** Both stores ban hidden, dormant or
   remotely *activated* features:
   - Apple 2.3.1(a) [V].
   - Play Deceptive Behavior: "Don't include undocumented or hidden features that are designed to be
     activated remotely" [V].

   Switches that only **disable, or choose among reviewed behaviours**, disclosed in the review
   notes, are the safe pattern. Bungie's disabled-items list and Fortnite's disabled features are
   precedents [V2].
8. **Silent push is not worth it.** On iOS it is low priority and throttled ("don't try to send more
   than two or three per hour"), and it is dropped if the app was force-quit [V]. FCM data messages
   are delayed in Doze, and high-priority messages that show no notification get deprioritized [V].
   APNs broadcast is Live-Activities-only [V]. Push would add SDKs, tokens, a server and privacy-label
   work to reach only backgrounded-but-alive apps, which the resume check already covers.

---

## 1. Latency table (platform × a/b/c)

Definitions:
- **Best:** the fastest plausible path to the first real players.
- **Typical:** the time until the majority of *active* players have it.
- **Worst:** a realistic bad case (not an outage).

"Content" assumes the recommended cadence of §6.2. Under today's 6 h cadence, add up to 6 h to every
"content" cell.

| Platform / channel | (a) Content / data hotfix | (b) Code hotfix | (c) Force off a broken version |
|---|---|---|---|
| **iOS/iPadOS App Store: CDN defs + timestamp (T0/T1)** | best **~2–5 min** (flip + purge + next check); typical **≤15 min** for in-session players, next launch for the rest; worst: players who stay offline (never blocked, by design) | best **~6–12 h** (expedited, granted same day; "up to 24 h" to appear; manual updaters and new installs first); typical **2–3 days** to the majority (≈7 h wait + 2 h review [V2], ≤24 h to appear [V], ~80% auto-updated in ~2 days [V2]); worst **1–3 weeks** (2026 backlog reports of 5–16 days, a rejection restarts the queue, phased release left on adds 7 days) | Store: **no rollback, no forced update**. Pause phased release (auto-updates only; manual updates still get it) in minutes [V]. Game: T0 kill switch in minutes; `minSupported` card/gate (users leave only when the fix is live, so the latency is (b)) |
| **iOS: Apple-hosted art pack fix (T2)** | best **~4–8 h** (fast review; "processed within minutes"; foreground `checkForUpdates()` [V]); typical **1–2 days** (review + "Processing for Distribution… within 24 hours" + "up to 24 hours to propagate" + device polling [V]); worst **1–2 weeks** (review backlog). Mitigate in minutes by remapping looks in defs (§5) | n/a | Archive removes *every* version of a pack (never do it); new pack version = new review |
| **TestFlight** | as App Store (same CDN path) | internal testers **minutes** after processing (≈22 min avg [V2]); external: beta review ≈8.5 h wait + 1.7 h [V2], later builds of a version "might not" need full review [V] | expire or stop testing the build |
| **Google Play** | as iOS (CDN) | best **~1–3 h** (review ≈46 min avg, min ≈0–10 min [V2]; publish "within a few minutes" [V]; in-app update visible after propagation, 15 min–hours [V2]); typical **12–48 h** to majority (Play checks "once a day"; auto-update needs Wi-Fi + charging + idle + not foreground [V, enterprise doc]; immediate in-app flow catches active players on launch); worst **7+ days** (extended review [V]) | **Halt** staged rollout (no more users) or **halt a fully rolled-out release** (previous version served to new and not-yet-updated users) in **minutes** [V]; players already on it need the fixed higher `versionCode` → immediate in-app update + gate (latency (b)) |
| **Android GitHub + Obtainium** | as iOS (CDN) | best **~1 h** (CI + release; Obtainium checks every 6 h by default [V2]); typical same day for Obtainium users; others at next launch (in-game card, manual install) | revoke in release doc → card; can't uninstall |
| **Steam (Win/Linux/Deck/mac)** | CDN defs (optional) as above, or packs-depot build: **~15–45 min** (upload + set live + download before next launch [V]) | best **~1 h** (CI + upload + set live with mobile confirmation [V]); typical: most *next launches* after set-live get it (recently played ≤3 days update immediately [V]; everyone must update before launching [V]); worst: offline mode, or a long running session (keeps the old build until exit) | **Set the previous build live: true rollback in minutes** [V]; running games can call `MarkContentCorrupt` + quit to force a verify/update [V] |
| **itch.io (itch app)** | CDN (optional) or `butler push`: live on upload [V] | best **~30–60 min** (CI + push; app checks at start-up and every 30 min, auto-updates [V]); direct downloads: in-game card only (wharf `latest` API [V]) | re-push the previous build → app users revert within ~30 min [C] |
| **Flathub** | bundled packs → a Flathub build (CDN defs optional) | best **~2–3 h** (merge → build → "published usually within 1–2 hours unless it is held in moderation" [V]); typical **1–3 days** to majority (GNOME Software auto-updates Flatpaks; Discover behaviour varies [V2]/[U]); worst: moderation hold if permissions/AppStream change [V], users who never update | revert commit → new build (hours); can't force |
| **GOG Galaxy** (later) | bundled (+ optional CDN) | best **~1 h** (self-publish to Master via Dev Portal, "without waiting for us" [V]); Galaxy update cadence [U] | publish the previous build; users can roll back in Galaxy [V] |
| **Epic** (later) | bundled (+ optional CDN) | "Bugfix" label: publish **without Epic review** [V]; minor/major updates need review, "2 or more days" [V] | label the previous binary Live [V]/[U] |
| **Direct desktop (Velopack)** | as iOS (CDN) | best **~1 h** (CI 20–40 min incl. notarization ≤15 min for 98% [V2] + YubiKey touch + client check + silent download + apply on exit); typical **~50% in 24 h, ~90% in a week** (auto-updating desktop analogue: Snap Store [V2]); worst: users who don't launch | revoke version in release document → client offers the fix, or a signed **downgrade** (`AllowVersionDowngrade` + explicit apply [V]); prefer roll-forward |
| **Web (R2 + index pointer)** | **seconds** for new loads (flip `index.html` + purge); open tabs at next timestamp check → "reload" prompt | same as content: **seconds–minutes**; itch HTML5 mirror: minutes (push a *folder*, not a zip [V2]) | point `index.html` back at the previous `/v/<build>/` in seconds; with a PWA service worker, old code can survive until **all tabs close** [V] (keep PWA off) |
| **Mac App Store** (later) | T0 kill switches via CDN timestamp (minutes); T1 defs ride an Apple-hosted `defs` pack (≈ iOS T2 latency) | as iOS | as iOS |

---

## 2. Platform details

### 2.1 Apple (iOS/iPadOS, TestFlight, Background Assets)

**Review times (2026).**
- **Apple's only number:** "On average, 90% of submissions are reviewed in less than 24 hours" [V]
  (<https://developer.apple.com/distribute/app-review/>).
- **Runway tracker, 26 September 2026:** waiting for review **7 h 2 m**, in review **2 h 21 m**,
  build processing **22 m**; TestFlight: waiting for beta review **8 h 32 m**, in beta review
  **1 h 39 m**. It is a truncated mean over Runway customers, skewed towards established apps shipping
  updates [V2] (<https://www.runway.team/appreviewtimes>).
- **Choicely, early September:** wait ≈11 h 19 m. 2026 monthly averages ranged from 5 h 25 m (June)
  to 14 h 35 m (February). Wednesday submissions were fastest [V2]
  (<https://www.choicely.com/tutorials/how-long-does-app-review-take>).
- **Tail:** Apple Community, July–August 2026: 16 days for a first review, 5 days for a small change,
  "7+ business days" per release [V2] (<https://discussions.apple.com/thread/256334290>).
  Submission volume rose ≈60% year on year in Q1 2026 (Appfigures via AppStoreReview) [V2]
  (<https://appstorereview.app/guides/app-store-review-queue-delays-2026>). Mac App Store reviews ran
  4–7+ days [V2] (<https://mjtsai.com/blog/2026/03/02/mac-app-store-review-times-increasing/>).

**Expedited review.**
- **Criteria:** "Critical Bug Fix: include the steps to reproduce the bug on the current version of
  your app", or an event-related app [V].
- **How:** the build must already be submitted. Then use
  <https://developer.apple.com/contact/app-store/?topic=expedite> [V].
- **Turnaround:**
  - When granted, 4–12 h (PTKD, May 2026) [V2]
    (<https://ptkd.com/journal/app-store-bug-fix-review-time>).
  - "Answer the same day or the next one, and the review lands within hours of that answer" [V2]
    (<https://vendredi-app.fr/blog/expedited-app-store-review/>).
  - One report moved to "In Review" "within a few hours" after a 6–7-day wait [V2].
- **Limits:** grants are reportedly rarer in 2026 [V2]. Repeated non-urgent requests risk future
  declines [V2].
- **Bonus rule:** "If you submit a bug fix update and additional issues are found during review, you
  have the option to resolve them with your next submission" (absent legal or safety concerns) [V].

**Phased release.**
- **Schedule:** 1/2/5/10/20/50/100% over 7 days, for users with automatic updates [V].
- **Pause:** up to 30 days in total, any number of times [V].
- **Release to all users:** "can release it to all users at any time once it has the Ready for
  Distribution status" [V].
- **Manual updates:** "can be manually downloaded from the App Store by anyone at any time" [V]
  (<https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases>).
- **API:** pause, resume and complete are available via `PATCH /v1/appStoreVersionPhasedReleases/{id}`
  (`PAUSED`/`ACTIVE`/`COMPLETE`) [V]
  (<https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-appstoreversionphasedreleases-_id_>).
- **For hotfixes:** don't phase (or complete immediately). For risky feature releases, phase so that
  a pause is available.

**Time to appear, and to reach devices.**
- "After your app is approved, it can take up to 24 hours to go live on the App Store" [V]
  (<https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/overview-of-publishing-your-app-on-the-app-store>).
- Apple documents no timing for app auto-updates [U]. Practitioner data:
  - Immediate release ≈**80% in about 2 days** (David Smith, 2019) [V2]
    (<https://www.david-smith.org/blog/2019/01/22/phased-vs-regular-update-adoption-rates/>).
  - TelemetryDeck customers (2023): "vast majority … within 48h" and "about 90% … in just under a
    week" [V2] (<https://telemetrydeck.com/blog/updated-apps-wwdc/>).
  - An in-app alert sped up the older curve: 50% in 3 days instead of 5, 80% in 6 days instead of 12
    [V2, 2011] (<http://blog.lolay.com/2011/09/app-upgrade-adoption.html>).
- A March 2026 forum thread reports an update not auto-installing after 48 h (unanswered) [V2]
  (<https://developer.apple.com/forums/thread/821243>).
- **Can you prompt?** Only with your own UI: open the product page via `itms-apps://` or
  `SKStoreProductViewController`. No StoreKit API reports or forces an update (see `04-apple.md` §7)
  [V earlier].
- **Nothing new in 2026:** WWDC26 coverage lists in-app-purchase review grouping and asset-system
  changes, and no update-enforcement API [V2]
  (<https://phiture.com/blog/wwdc26-updates/>, <https://pricepush.app/blog/wwdc-2026-app-store-changes>).
  Treat "no forced-update API on iOS 26/27" as [U]-high confidence.

**TestFlight.**
- Internal testers (up to 100) need no review [V].
- External testers: "The first build you submit requires a full review, but later builds for the same
  version might not." Up to six builds per 24 h go to TestFlight review [V]
  (<https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers>).
- Builds expire after 90 days [V] (<https://developer.apple.com/testflight/>).
- Use: verify a hotfix on real devices within about 30 min of CI. It is not a user-facing fix.

**Apple-hosted Background Assets.**
- **Statuses:** "Processing for Distribution: … will be ready for distribution within 24 hours"; a
  TestFlight pack stuck in Processing for more than 24 h "may" need Apple support [V]
  (<https://developer.apple.com/help/app-store-connect/reference/app-uploads/apple-hosted-asset-pack-statuses>).
- **Apple Frameworks Engineer, August 2026:**
  - updates "typically processed within minutes";
  - review "typically … under 24 hours";
  - "it can take 24 hours to propagate across all of the global App Store servers";
  - devices poll depending on "charging state, Wi-Fi … and how frequently a person uses the app";
  - in the foreground, `AssetPackManager.checkForUpdates()` forces the check [V]
    (<https://developer.apple.com/forums/thread/841373>).
- **Consequence:** an art fix via Apple-hosted packs takes **days, not minutes**. Crash-causing art
  must be neutralised through defs (remap the look to an embedded fallback) or a T0 `disable`, and
  corrected later in a new pack version.

**Forcing users off a version.**
- There is no store lever beyond pausing phased release.
- "Remove from sale" stops new downloads only; existing users keep the app and keep receiving
  updates [V] (<https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store/>).
- A **pre-approved "rollback build"** held in *Pending Developer Release* is possible in principle,
  but forum reports show it blocks the version train and can leave App Store Connect stuck [V2]
  (<https://developer.apple.com/forums/thread/132412>,
  <https://origin-devforums.apple.com/forums/thread/821386>). **Not recommended.**

**App Review and update gates.**
- No guideline forbids an "update required" screen [U: absence verified by reading 2.x]. Guideline
  2.1 requires reviewers to be able to exercise the app.
- Practical rule: the gate must never trigger for the build under review. Keep
  `minSupported ≤ submitted build`. Never detect "review mode", which Play forbids explicitly (§4).
- Common practice: hard-block only when verified online, never on a failed check, and never loop
  [V2] (<https://appmaster.io/blog/in-app-update-prompt-design-native-apps>).

### 2.2 Google Play, GitHub and Obtainium

**Review times.**
- Google: "Processing can take a few hours or up to seven days (or longer in exceptional cases)" [V]
  (<https://support.google.com/googleplay/android-developer/answer/9859654>).
- Runway, September 2026: average **46 min** (max 2 d 4 h, min 0 m); June–August averaged 46–48 min
  [V2] (<https://www.runway.team/playstorereviewtimes>).
- There is no expedite programme on Play [U: none found].
- After approval, **managed publishing** lets you "Publish changes"; the update "will be published on
  Google Play within a few minutes" [V].

**Staged rollouts.**
- The percentage never rises automatically [V].
- Halt: "no additional users will receive" it; "users who already received [it] … will remain on that
  version" [V].
- Resume at any percentage [V].
- To fix: "create and roll out a new release with a fixed app bundle" [V]
  (<https://support.google.com/googleplay/android-developer/answer/6346149>).
- **Halt a fully rolled-out release** (a recent addition; introduction date [U]). "The previous version of your app will
  become available to new users, and anyone not using the halted version", via the Console or the
  Publishing API. You can't halt a track's first release [V]
  (<https://support.google.com/googleplay/android-developer/answer/16285429>).
- There is no true rollback: version codes only go up [V2]
  (<https://vmobify.com/blog/google-play-release-controls>).

**In-App Updates.**
- `inAppUpdatePriority` 0–5, default 0. It is set only via the Publishing API "when rolling out a new
  release and cannot be changed later". The sample uses immediate when priority ≥ 4 [V]
  (<https://developer.android.com/guide/playcore/in-app-updates/kotlin-java>).
- On `RESULT_CANCELED`, the app decides what to do (continue or re-prompt). A stalled
  `DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS` is resumed in `onResume` [V].
- Play-installed builds only [V].
- **Propagation:**
  - "a few hours before the in-app update mechanism detects the new version" (Google consultant, via
    Stack Overflow) [V2] (<https://stackoverflow.com/questions/65626707>);
  - 2–12 h [V2] (<https://stackoverflow.com/questions/56118563>);
  - internal track ≈15–30 min [V2] (<https://xckevin.com/en/blog/android-google-play-in-app-update/>).

**Auto-update behaviour.**
- Enterprise docs (the same Play client) say that by default apps update when on Wi-Fi, **charging**,
  **idle**, and "not running in the foreground".
- "Google Play typically checks for app updates once a day, so it can take up to 24 hours before an
  app update is added to the update queue" [V]
  (<https://developers.google.com/android/management/control-app-updates>).
- Consumer settings add limited-mobile-data auto-updates [V]
  (<https://support.google.com/googleplay/answer/113412>).
- Consumer timing is otherwise [U], assumed similar.

**Developer verification.**
- Hotfix speed is unaffected once the package is registered: Play apps are auto-registered (99%) and
  the signing key doesn't change for a hotfix [V]
  (<https://developer.android.com/developer-verification/guides/faq>,
  <https://android-developers.googleblog.com/2026/06/android-developer-verification.html>).
- The risk is only for **unregistered** sideloaded apps once enforcement goes global in 2027: "updates
  to unregistered apps will fail" without ADB or the advanced flow [V].
- The Play-signed GitHub APK shares the registered key [U: confirm registration covers off-Play
  installs of the same key].

**Obtainium.**
- Default background check every 6 h (README) [V2] (<https://github.com/ImranR98/Obtainium>).
- The background job wakes every 15 min and checks only overdue apps [V2]
  (<https://github.com/ImranR98/Obtainium/issues/2236>).
- Unauthenticated GitHub API use is capped at 60 requests/h per IP [V2].

### 2.3 Steam, itch, Flathub, GOG, Epic

**Steam.**
- There is no review for updates after the store review (see `06-pc-stores.md`).
- "If a game is already released, and you choose to set a build live, anyone who owns the game will
  receive that update." A default-branch set-live needs "an additional authorization step" via the
  Steam Mobile Authenticator or SMS [V] (<https://partner.steamgames.com/doc/store/application/builds>).
- The `SetAppBuildLive` Web API exists. For a released app's `public` branch it returns 201 and waits
  for a mobile confirmation [V] (<https://partner.steamgames.com/doc/webapi/ISteamApps>).
- "Players who have your game installed will need to download each update before they can launch the
  game again" [V] (<https://partner.steamgames.com/doc/store/updates>).
- Scheduling:
  - "Only games played within the last 3 days will be updated immediately"; others are spread over
    off-peak time [V] (Valve, March 2020, <https://store.steampowered.com/news/posts/?enddate=1585670510>).
  - Since the December 2024 client, users can choose "let Steam decide" or "update on launch" [V2]
    (<https://www.gamingonlinux.com/2024/12/steam-beta-for-dec-11-brings-new-game-update-options-plus-a-new-downloader-style/>).
- `MarkContentCorrupt`: "If you detect the game is out-of-date … use MarkContentCorrupt to force a
  verify, show a message to the user, and then quit" [V]
  (<https://partner.steamgames.com/doc/api/ISteamApps>).
- **Rollback:** set an older build live (the same confirmation).

**itch.io.**
- "As soon as the upload finishes, the build is live." Optimised patches follow within about 30 min,
  and players are never blocked [V] (<https://itch.io/docs/butler/pushing.html>).
- "The itch app looks for game updates on start-up, and every 30 minutes" and updates automatically
  when there is a single candidate [V] (<https://itch.io/docs/itch/integrating/updates.html>).
- Direct downloads: `GET https://itch.io/api/1/x/wharf/latest` powers an in-game card [V].
- HTML5: push a folder (a zipped push kept serving the old build in one report) [V2]
  (<https://itch.io/t/3088103>).

**Flathub.**
- "An official build will be started on every merge … published usually within 1-2 hours unless it
  is held in moderation." A build is held if permissions or critical AppStream fields change [V]
  (<https://docs.flathub.org/docs/for-app-authors/maintenance>).
- Client side: GNOME Software auto-installs Flatpak updates when enabled [V2]
  (<https://blogs.gnome.org/hughsie/2018/08/08/gnome-software-and-automatic-updates/>). Discover's
  behaviour varies (bug reports) [V2]; Steam Deck desktop-mode cadence [U].
- The generative-AI policy (see `07-desktop-direct.md`) may restrict automating PRs. Whether it
  covers routine update PRs is [U].

**GOG.**
- "After your game is released on GOG, please feel free to publish any stable updates to the Master
  branch as soon as they are ready without waiting for us." Keep old builds published so Galaxy users
  can roll back [V] (<https://docs.gog.com/updates/>).
- Build Creator can't publish to public branches; publish from the Dev Portal [V]
  (<https://docs.gog.com/build-branches/>).

**Epic.**
- "If you select Bugfix … you can publish the artifact without putting it through review." Minor and
  major updates need review [V]
  (<https://dev.epicgames.com/docs/epic-games-store/store-presence/manage-artifacts>).
- Review "might take 2 or more days" [V]
  (<https://dev.epicgames.com/docs/epic-games-store/get-started/get-started-steps/submit-for-final-review>).

### 2.4 Direct desktop (Velopack)

**API pattern [V]** (<https://docs.velopack.io/integrating/overview>):
- `CheckForUpdatesAsync` reads `releases.{channel}.json`.
- `DownloadUpdatesAsync` fetches deltas, or the full package if the deltas fail.
- Then one of:
  - `ApplyUpdatesAndRestart` / `ApplyUpdatesAndExit`;
  - `WaitExitThenApplyUpdates` (waits up to 60 s for the app to exit);
  - auto-apply on the next start (only upgrades). Velopack recommends explicit apply.
- Downgrades need `AllowVersionDowngrade`, or a hand-built `UpdateInfo`, plus explicit apply [V]
  (<https://docs.velopack.io/integrating/specific-version>).

**Recommended client pattern (Diceroll):**
1. Check on launch and every 2 h in the session, piggy-backing on the timestamp check. The release
   document says whether a new core exists, so the Velopack feed is fetched only then.
2. Download silently, verified against the YubiKey-signed release document.
3. Apply on quit via `WaitExitThenApplyUpdates(silent)`, or on the next launch.
4. "Restart now" button only for `urgency ≥ recommended`.

**Latency:** the Snap Store (another auto-updater) sees "50% of users will update within 24 hours,
and 90% are updated within a week" [V2]
(<https://blog.popey.com/2023/10/ninety-percent-updated-in-a-week/>). Expect similar or better with
on-quit apply [U].

**Pipeline time:**
- Notarization targets 98% of submissions within 15 min, most under 5 min [V2]
  (WWDC21-10261 as quoted in <https://eclecticlight.co/2021/06/24/will-changes-to-notarization-make-any-difference/>).
- August 2026 forum reports of multi-hour hangs [V2]
  (<https://developer.apple.com/forums/topics/code-signing-topic>).
- The YubiKey touch for the release document is a human step (§7.5 of the design).

### 2.5 Web

- `index.html` (`no-cache`) points at the immutable `/v/<build>/`. A deploy is one object change plus
  a purge. Cloudflare Instant Purge runs in under 150 ms on all plans [V]
  (<https://blog.cloudflare.com/instant-purge-for-all/>). Free-plan purge limits: single-URL purge
  800 URLs/s; tag, prefix and hostname purges 5 requests/min [V]
  (<https://developers.cloudflare.com/cache/how-to/purge-cache/>).
- **New page loads get the fix immediately.** Open tabs keep the old wasm until reloaded. The
  in-game timestamp check (§6.2) must carry `web.minBuild` and prompt a reload at a safe point.
- **Service-worker pitfalls:**
  - an updated worker "will wait until the existing worker is controlling zero clients";
  - update checks happen on navigation (and bypass the HTTP cache after 24 h);
  - `skipWaiting()` risks mixing versions [V] (<https://web.dev/articles/service-worker-lifecycle>).

  Godot's PWA worker is cache-first (`08-web-cdn-delta.md` §A.2). **Keep PWA off**, as the design
  already recommends. If PWA is ever enabled, use `registration.update()` on the timestamp signal plus
  a "reload for update" prompt.

---

## 3. Check cadence, cost, battery and push

**Assumptions [C]:**
- DAU/MAU 0.2 (a typical casual/mid-core range; [U] for Diceroll);
- 2 sessions per DAU per day, 25 min each;
- checks only in the foreground;
- timestamp ≈ 2–4 KB (capped at 16 KiB);
- served from R2 behind a Cloudflare custom domain with `max-age=60`.

| Policy | Checks / DAU / day | Requests/month at 1k / 10k / 100k MAU |
|---|---|---|
| P0 today: launch, ≤ every 6 h | ~2 | 12k / 120k / 1.2M |
| **P1 recommended:** launch/resume + title return (≥5 min since last) + every 15 min in foreground | ~7 | 42k / 420k / **4.2M** |
| P2 incident mode (server hint 3 min) for 48 h | ~18 during the incident | +7k / +70k / +0.7M per incident |
| P3 always 5 min | ~12 | 72k / 720k / 7.2M |
| Stress: 100k MAU all daily, 2 h/day, 5 min | 24 | 72M |

**Money.**
- Cached CDN hits carry no request charge for a static R2 custom domain. R2 Class B ($0.36/M, 10M/month
  free) is billed only on cache misses [V] (<https://developers.cloudflare.com/r2/pricing/>). Cached
  requests don't count as R2 operations (Cloudflare Discord, via answeroverflow [V2]).
- With `max-age=60`, misses are ≤43,200 per month per caching location. Smart Tiered Cache collapses
  that to about one upper tier [V]
  (<https://developers.cloudflare.com/cache/interaction-cloudflare-products/r2/>). Without it, even 300
  PoPs give ≈13M misses, about **$1/month** [C].
- **Keep a Worker off the hot path:** Workers Free allows 100k requests/day. P1 at 100k MAU is
  ≈140k/day and would need Workers Paid ($5 for 10M, then $0.30/M) [V]
  (<https://developers.cloudflare.com/workers/platform/pricing/>).
- Egress: ≈4.2M × 3 KB ≈ 13 GB/month, free [C].

**Device.** About 21 KB/day per player at P1 (less with `ETag`/304) [C]. That is one small HTTPS
request every 15 min while the GPU is already busy: negligible battery [U]. Never poll in the
background.

**Silent push.** Not worth it:
- **iOS:**
  - background notifications are low priority and throttled: "don't try to send more than two or
    three per hour";
  - pure-silent pushes must use priority 5 and are throttled at APNs and on the device;
  - held notifications are discarded if the app is force-quit [V]
    (<https://developer.apple.com/forums/thread/827460>, Apple's "Pushing background updates"
    wording).
- **Broadcast:** "Broadcast push notifications are only available on Live Activities" [V]
  (<https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications>).
  iOS would therefore need per-device tokens and a server.
- **Android:** normal-priority FCM is delayed in Doze. High-priority messages that don't produce a
  visible notification "may be deprioritized" [V]
  (<https://firebase.google.com/docs/cloud-messaging/android/message-priority>).
- **Privacy:** Apple's "collect" means retaining data beyond servicing the request. Stored tokens or
  IP addresses must be declared by their use (for example as Device ID) [V]
  (<https://developer.apple.com/app-store/app-privacy-details/>). Push tokens aren't named explicitly
  [U]. Today's design (a static CDN fetch, no retained identifiers) keeps "Data Not Collected".
- **Value:** push helps only apps that are backgrounded but alive, and the resume check already
  covers them. **Verdict: no push.** Revisit only if a server-authoritative feature appears.

---

## 4. Kill switches and feature flags for code paths

**Policy text.**
- **Apple 2.3.1(a):** "Don't include any hidden, dormant, or undocumented features … All new
  features, functionality, and product changes must be described with specificity in the Notes for
  Review" [V].
- **Apple 2.5.2:** apps may not "download, install, or execute code which introduces or changes
  features or functionality" [V] (<https://developer.apple.com/app-store/review/guidelines/>).
- **Play, Deceptive Behavior > Behavior transparency** [V]
  (<https://support.google.com/googleplay/android-developer/answer/9888077>):
  - "Don't include undocumented or hidden features that are designed to be activated remotely or
    after a certain amount of time";
  - "Make sure your app behaves identically for a regular user and for a Google Play reviewer";
  - "Don't use techniques to detect the app review environment".

**Precedent.**
- Bungie keeps a public disabled-items list. A disabled item "cannot be equipped" or its perks don't
  work, with the message "This item is not currently available" [V2]
  (<https://help.bungie.net/hc/en-us/articles/23127843656596-Destiny-2-Disabled-Items-list>,
  <https://www.dexerto.com/destiny/destiny-2-disables-warlock-exotic-after-insane-bug-one-shots-the-witness-2990417/>).
- In September 2023 Bungie shipped a server-side disable within 24 h, ahead of the real fix [V2]
  (<https://exputer.com/news/games/destiny-2-game-breaking-bug-fix/>).
- Fortnite uses "Disabled Features" [V2] (<https://fortnite.fandom.com/wiki/Disabled_Features>).
- Fowler's "Ops Toggles / Kill Switches" guidance: short-lived, test both states, centralise toggle
  points [V] (<https://martinfowler.com/articles/feature-toggles.html>).

**Guardrails (recommended).**
1. **Disable-only or select-reviewed.** A switch may hide an entry point, disable a set, item, rule
   or mode, or pick between two implementations that *both ship and are both reviewed* (for example
   `rule_impl: v1|v2`). It may never enable something not otherwise reachable in the reviewed build.
2. **A registry compiled into the core** (`game/live/kill_switches.gd` or a JSON file):
   - id, description, the "off" behaviour, the affected core range, and a test that runs both states;
   - the client ignores unknown ids;
   - CI fails if Polaris or timestamp tooling references an id missing from the registry of the
     targeted cores.
3. **Scoped and self-expiring.** Each timestamp `kill` entry names `cores: "<1.4.2"` (or a
   distribution list) and an `until`. When the fixed core arrives, the switch stops applying
   automatically.
4. **Channel-wide only.** No per-user targeting (keeps §12.2's "no per-user remote config").
5. **Disclosed.** A standing line in the App Review notes and the Play declaration, for example: "The
   game fetches a signed configuration that can *disable* individual content or features for safety
   (for example if a bug is found). It never enables functionality absent from this build." Never
   gate on a review-environment check.
6. **Visible.** The player sees "Temporarily unavailable, fix coming", never a silent removal.
   Profile and run data for disabled things stay dormant (the design's "saves never drop unknown
   ids").

---

## 5. Urgent data fixes during a session or a run

Patterns observed:
- Many roguelikes discard or refuse in-progress runs across major updates (Ravenswatch 1.3/1.4:
  "any existing run in progress has been discarded") [V2]
  (<https://www.passtechgames.com/ravenswatch-news/the-hourglass-of-dreams-update-is-live/>).
- Others keep a **legacy branch** so a run can finish (Across the Obelisk, Cogmind on Steam) [V2]
  (<https://steamcommunity.com/app/1385380/discussions/0/4029096483735990787/>,
  <https://www.indiedb.com/games/cogmind/news/cogmind-beta-16-the-unchained>).
- Others guarantee "Nothing is rewritten underneath you" (Knights of Crystalis) [V2]
  (<https://devgb.itch.io/koc/devlog/1629049/version-1470-released>).
- Unreal's hotfix practice applies config and data overlays live where safe, and needs a restart for
  what loads at boot [V2] (<https://en.imzlp.com/posts/66804/>).

The design already pins a run's ruleset (§4.8) and never changes data mid-run (§12.2). For
**crash-causing** content, add a narrow exception:

- **Hotfix layer (T0/T1):** signed ops keyed by catalog `seq`, each touching a single id:
  `disable id`, `replace id → id`, `remap look id → fallback look` (embedded asset), and
  `clamp field [min,max]`.
  - It is applied to the live ContentDB **and** to pinned run views.
  - It is applied only at **safe points**: title, run start, map/between-room screen, after combat
    resolution, before shop or reward generation.
  - It is never applied inside combat resolution or a save write.
- **Run save records** `applied_hotfixes: [seq…]`. Replacements use the owning system's RNG stream
  only, so the map and other streams stay stable. A run touched by a hotfix is marked for fairness
  (dailies or leaderboards) and the player gets a one-line toast ("X was temporarily replaced by Y").
- **Packs:** Godot can't unmount, and the first-mounted file wins (`01`/`09` notes). In-session
  mitigation is therefore **reference remapping** (defs), not file replacement. Pack-level `disable`
  takes effect on the next boot, as in the design.
- **Crash-loop safe mode (local, no network needed):**
  1. Write `boot_state = starting` before mounting downloaded content, and `ok` after the title has
     been up for ~10 s.
  2. After two consecutive failed boots, boot **snapshot-only** (embedded content, cached trust
     documents ignored for mounting).
  3. Fetch the timestamp first, then re-plan.
  4. Do the same for loading a run save: after two crashes, offer "Continue with safe content" or
     "Abandon run" (with any start cost refunded).

  This covers the gap where a crash happens before the next check could deliver a switch.

---

## 6. Recommended "fast update" operating model for Diceroll

### 6.1 Principles

- **Minutes lane first, stores second.** Neutralise with T0 (switches, hotfix layer, gates) in
  minutes. Ship the real fix through the fastest lane each platform has, with no phasing for hotfixes.
- **Never block offline play,** except a verified hard gate for crash/data-loss/security (below).
- **Roll forward.** Only Steam, itch, GOG and Web get true rollback. Everywhere else the fix is a new,
  higher version.

### 6.2 Check cadence (replaces "at most every 6 h" in §7.4 step 2)

1. On launch, after the trust reload path and **before mounting downloaded content** (≤2 s timeout,
   then continue with cached documents).
2. On resume or focus-in (mobile `NOTIFICATION_APPLICATION_RESUMED`, desktop focus) if ≥5 min since
   the last check.
3. On title return and run end, if ≥5 min since the last check.
4. Every **15 min** in the foreground, ±20% jitter.
5. **Incident mode:** the timestamp carries `pollSeconds` (client clamps to 120–3600 s). Polaris sets
   180 s during an incident and clears it after 48 h.
6. Use `If-None-Match` with the `ETag`, and back off exponentially on errors.

Cache headers: timestamp `Cache-Control: public, max-age=60, stale-if-error=86400`. Every Polaris
publish purges its URL. Freshness semantics stay as designed (7-day expiry → `stale`).

### 6.3 Timestamp additions (all signed; unknown fields ignored)

- `urgent: bool` and `pollSeconds`.
- `kill: [{id, cores, dist?, until, msg}]`, the code-path switches (§4).
- `hotfix: {seq, ops[]}`, the data layer (§5), or a pointer to a tiny signed hotfix document.
- `gate: {dist: {min, mode: notice|soft|hard, after?}}`, where `after` = "only once the store offers
  ≥ min". Polaris sets `after` from the store watchers (§6.5) so a gate never dead-ends a player.
- `web: {minBuild}` for the open-tab reload prompt.

Gate modes:
- **notice:** a card.
- **soft:** a card at every launch, and the affected features killed.
- **hard:** no new runs until updated. Continue/export stays available. Use only when verified online
  and when the store reports the fix as available.

### 6.4 Hotfix lanes per platform

| Lane | Platforms | Mechanism | Latency |
|---|---|---|---|
| L0 switch | all (incl. Mac App Store, Flathub, itch, GOG, Steam: keep the tiny timestamp check on everywhere, even where CDN defs are off) | `pkey dist kill/disable/hotfix/gate` → re-sign + purge | ≤15 min in-session, immediate on launch |
| L1 data | all CDN-enabled | defs catalog, **urgent** = skip the ramp (bp=10000), still via beta canary (5–10 min) | 15–30 min |
| L2 art | CDN channels; Steam packs depot; Apple-hosted (reviewed) | new content-addressed pack | minutes (CDN/Steam), days (Apple) |
| L3 code | App Store | expedite template, phased **off**, submit; TestFlight internal first | ~1–3 days |
| L3 code | Play | production `completed`, `inAppUpdatePriority: 5`; halt the bad release | hours |
| L3 code | Steam / itch / GOG / Epic (bugfix label) | upload → set live / push / publish | ~1 h |
| L3 code | Velopack direct | release document (YubiKey) + feed, `urgency: required` | hours → a day |
| L3 code | Flathub | PR/commit by a human (AI policy [U]) | hours → days |
| L3 code | Web | pointer flip | seconds |

### 6.5 Runbooks (short form)

**R1: crash or exploit caused by content.**
1. `pkey dist incident start` (sets `pollSeconds=180`).
2. `disable` the set, or a `hotfix` op (remap or replace).
3. Verify through the CDN.
4. Fix the defs in the repo → urgent T1.
5. Apple-hosted art: submit a new pack version (normal review).
6. End the incident after 48 h.

**R2: code bug with a switchable feature.**
1. `kill` + soft gate.
2. Cherry-pick onto `release/x.y` → `core-hotfix.yml`.
3. App Store: submit + expedite request (template) + phased off.
4. Play: priority 5 at 100%; halt the bad release if it is still ramping.
5. Steam: set live.
6. Velopack: urgency required.
7. Web: flip.
8. When the store watchers see availability, move the gate to `soft`/`hard` per severity.
9. Remove the kill after the fixed core is past 90%, or at `until`.

**R3: code bug with no switch (for example a boot crash).**
- Safe mode catches pack-induced crashes. For core code, fall back to the store lanes.
- Steam/itch/GOG/Web: roll back immediately.
- Play: halt the full release.
- App Store: expedite (there is no rollback).

**R4: bad core release discovered during ramp.**
- App Store: pause phased (API).
- Play: halt.
- Steam: keep it on beta or set the previous build live.
- Velopack: pull from the release document.

### 6.6 What to automate (CI and Polaris)

- **Polaris CLI and console, phone-friendly, no hardware key:** `incident start|end`, `kill`,
  `disable`, `hotfix`, `gate`, `notice`. Each call re-signs the timestamp, purges the Cloudflare URL,
  then runs a canary fetch and verify from two regions. It needs only the low-privilege timestamp key
  (it can only stop things or choose among signed documents, as §7.5 intends).
- **`core-hotfix.yml`** (dispatch from `release/*`):
  - build all targets and smoke-test;
  - TestFlight internal;
  - App Store Connect: create the version, attach the build, "What's New", phased release off, submit;
    print a pre-filled expedite request (the form is manual);
  - Play `edits`: production `completed`, `inAppUpdatePriority: 5`;
  - Steam: `SetAppBuildLive` on public (returns 201; confirm on the phone);
  - `butler push`; Velopack feed plus a release-document request (YubiKey); Web flip;
  - open a Flathub PR draft for a human to submit.
- **Store watchers (Polaris cron, every 15 min):**
  - App Store Connect version state and the iTunes lookup per storefront (the lookup is unofficial and
    cached [U]);
  - Play `edits.tracks.get` state;
  - Steam live build id; Flathub build status.
  - They drive `gate.after` and post status to the incident issue.
- **Health signals without telemetry:**
  - Play Developer Reporting API `crashRate` by `versionCode`, hourly [V]
    (<https://developers.google.com/play/developer/reporting/reference/rest/v1beta1/vitals.crashrate/query>);
  - App Store Connect diagnostics [U: API coverage];
  - Steam and itch reviews and forums (manual).
  - Alerts go to the maintainer.
- **CI lints:** the kill-switch registry (both states tested, ids known to targeted cores); a
  hotfix-op validator against pinned run fixtures from the last N catalogs; `minSupported ≤ submitted
  build` before any App Store/Play submission.
- **Docs:** `docs/runbooks/hotfix.md` with R1–R4, the expedite template, the review-notes line, and an
  incident issue template.

### 6.7 Proposed design-doc edits

- **§7.4 step 2:** replace "at most every 6 h" with §6.2's cadence plus `pollSeconds`.
- **§12.1:**
  - T0's "minutes (next check)" becomes "≤15 min in-session, immediate on launch".
  - Add the `kill`, `hotfix` and `gate` fields.
- **§12.2:** add the crash-content exception (hotfix layer at safe points, recorded in the run save).
- **§12.3:** add the kill-switch registry and guardrails, crash-loop safe mode, and Play's "halt full
  release".
- **§6.1:** recommend phased release **off** for hotfixes and a standing review-notes line about
  disable-only switches.

---

## 7. Open risks

1. **App Review volatility (2026):** multi-day to multi-week tails and rationed expedites. The
   iOS code-fix latency is not under our control. Mitigation: switches for every risky feature,
   TestFlight external testing before release, phased release for feature (not hotfix) versions.
2. **Unswitchable code crashes** (boot, save load, core loop) can only be fixed through stores.
   Mitigations are safe mode and a check before mounting, but a core-code boot crash on iOS is a
   ≥1-day outage.
3. **Gate dead-ends:** raising `minSupported` before the store offers the fix, whether from
   propagation (up to 24 h Apple; hours Play) or staged rollouts, strands players. Hence `gate.after`
   driven by watchers, plus offline tolerance.
4. **Single maintainer:**
   - Steam default-branch set-live needs the phone.
   - Direct-desktop release documents need the YubiKey.
   - Expedite and Flathub steps are manual.
   - Keep L0 fully remote and phone-operable, and document delegation.
5. **Policy drift:** kill switches that grow into remote *enablement* would breach Apple 2.3.1/2.5.2
   and Play Behavior transparency. Enforce disable/select-only in code review and CI.
6. **Play In-App Updates specifics:** priority is immutable once set, and detection lags by hours.
   Set priority in CI from a severity input, and don't rely on it for the first hours.
7. **Apple-hosted packs:** there is no fast rollback, and archiving deletes every version. Always keep
   an embedded fallback look for every art id that can be remapped.
8. **Determinism and fairness:** hotfix ops change pinned runs. Keep ops tiny, per-system RNG, and
   flag affected runs.
9. **Evidence quality:** review-time trackers are self-selected (Runway) and adoption curves are old
   or anecdotal. Re-measure with our own store dashboards after launch. Consumer Play auto-update
   timing and Flathub/Galaxy/Epic client cadences are [U].
10. **Web PWA:** if enabled later, a waiting service worker can pin old code. Pair it with the
    timestamp-driven reload prompt.

---

## 8. Sources (primary first)

- Apple:
  - App Review: <https://developer.apple.com/distribute/app-review/>
  - Expedite form: <https://developer.apple.com/contact/app-store/?topic=expedite>
  - Guidelines: <https://developer.apple.com/app-store/review/guidelines/>
  - Phased release: <https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases>
  - Phased release API: <https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-appstoreversionphasedreleases-_id_>
  - Publishing overview (24 h): <https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/overview-of-publishing-your-app-on-the-app-store>
  - Release options: <https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option>
  - Availability: <https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store/>
  - TestFlight: <https://developer.apple.com/testflight/>
  - External testers: <https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers>
  - Asset pack statuses: <https://developer.apple.com/help/app-store-connect/reference/app-uploads/apple-hosted-asset-pack-statuses>
  - Background Assets latency (Apple engineer): <https://developer.apple.com/forums/thread/841373>
  - Background push throttling: <https://developer.apple.com/forums/thread/827460>
  - Broadcast push (Live Activities): <https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications>
  - Privacy details: <https://developer.apple.com/app-store/app-privacy-details/>
- Google:
  - Managed publishing: <https://support.google.com/googleplay/android-developer/answer/9859654>
  - Publishing overview: <https://support.google.com/googleplay/android-developer/answer/9859751>
  - Staged rollouts: <https://support.google.com/googleplay/android-developer/answer/6346149>
  - Halt a full release: <https://support.google.com/googleplay/android-developer/answer/16285429>
  - In-app updates: <https://developer.android.com/guide/playcore/in-app-updates>, <https://developer.android.com/guide/playcore/in-app-updates/kotlin-java>
  - Update behaviour: <https://developers.google.com/android/management/control-app-updates>, <https://support.google.com/googleplay/answer/113412>
  - Deceptive Behavior: <https://support.google.com/googleplay/android-developer/answer/9888077>
  - Developer verification: <https://developer.android.com/developer-verification/guides/faq>, <https://android-developers.googleblog.com/2026/06/android-developer-verification.html>
  - FCM priority: <https://firebase.google.com/docs/cloud-messaging/android/message-priority>
  - Reporting API: <https://developers.google.com/play/developer/reporting/reference/rest/v1beta1/vitals.crashrate/query>
- Valve:
  - Builds: <https://partner.steamgames.com/doc/store/application/builds>
  - Branches: <https://partner.steamgames.com/doc/store/application/branches>
  - Updates: <https://partner.steamgames.com/doc/store/updates>
  - Web API: <https://partner.steamgames.com/doc/webapi/ISteamApps>
  - SDK: <https://partner.steamgames.com/doc/api/ISteamApps>
  - Scheduling (2020): <https://store.steampowered.com/news/posts/?enddate=1585670510>
- itch:
  - Pushing: <https://itch.io/docs/butler/pushing.html>
  - App updates: <https://itch.io/docs/itch/integrating/updates.html>
- Flathub maintenance: <https://docs.flathub.org/docs/for-app-authors/maintenance>
- GOG:
  - Updates: <https://docs.gog.com/updates/>
  - Build branches: <https://docs.gog.com/build-branches/>
- Epic:
  - Manage artifacts: <https://dev.epicgames.com/docs/epic-games-store/store-presence/manage-artifacts>
  - Final review: <https://dev.epicgames.com/docs/epic-games-store/get-started/get-started-steps/submit-for-final-review>
- Velopack:
  - Integrating overview: <https://docs.velopack.io/integrating/overview>
  - Specific versions: <https://docs.velopack.io/integrating/specific-version>
- Cloudflare:
  - R2 pricing: <https://developers.cloudflare.com/r2/pricing/>
  - R2 cache: <https://developers.cloudflare.com/cache/interaction-cloudflare-products/r2/>
  - Purge: <https://developers.cloudflare.com/cache/how-to/purge-cache/>
  - Instant Purge: <https://blog.cloudflare.com/instant-purge-for-all/>
  - Workers pricing: <https://developers.cloudflare.com/workers/platform/pricing/>
- Web: <https://web.dev/articles/service-worker-lifecycle>
- Practitioner data:
  - Review times: Runway (<https://www.runway.team/appreviewtimes>, <https://www.runway.team/playstorereviewtimes>), Choicely, AppStoreReview, Michael Tsai, Apple Community thread 256334290
  - Expedite experiences: PTKD, Vendredi, ReplyArgus
  - Adoption: David Smith 2019, TelemetryDeck 2023, Lolay 2011, Alan Pope 2023
  - Play propagation: Stack Overflow 65626707 and 56118563, xckevin 2025
  - Kill-switch precedents: Bungie Help, Dexerto, eXputer, Fortnite wiki
  - Run-save handling: Ravenswatch, Across the Obelisk, Cogmind, Knights of Crystalis patch notes
  - Feature toggles: Fowler
  - Other: Obtainium README and issues; Unreal hot-update blog (imzlp)
