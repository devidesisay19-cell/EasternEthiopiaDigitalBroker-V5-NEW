# Eastern Ethiopia Digital Broker - V6 (Business Edition)

Android app (Kotlin + AndroidX WebView + `WebViewAssetLoader`) with a Supabase backend.
Buy / sell / rent property, cars and goods, post and find jobs, with city admins, agents,
customer leads, a payments ledger and a read-only investor overview.

- Package `com.easterneethiopia.digitalbroker` - version **6.0.0** (code 60)
- compileSdk / targetSdk 36, minSdk 24, JDK 17
- Backend: Supabase project (URL + publishable key are in `app/src/main/assets/web/supabase.js`
  and the page scripts; the publishable key is meant to be public - security is enforced by RLS)

## Roles
| Role | What they do |
|---|---|
| super_admin | everything; creates city admins, agents, investors; payments; reports |
| city_admin | reviews listings/jobs of own city(ies); assigns agents; confirms payments; sees city leads |
| agent | takes leads in own city, posts listings, records payments (pending until confirmed) |
| investor | read-only aggregated overview (`investor-dashboard.html`) |
| owner / renter / job_seeker / employer | normal users (the only roles available at sign-up) |

Super Admin changes roles in Admin dashboard -> Users. Agents can also be added in
`agents-leads.html` by the city admin of that city.

## Pages added in V5/V6
`agent-dashboard.html`, `agents-leads.html`, `payments.html`, `investor-dashboard.html`,
`lead-widget.js` (call-back form), `offline-banner.js`, `privacy.html`, `terms.html`.

## 1. Database (new Supabase project)
Run in **SQL Editor**, in this order, each file fully:
1. `database/01_base_schema.sql`
2. `database/02_SUPABASE_FINAL_V4.sql` (marketplace, cars, storage buckets + policies, reports)
3. `database/03_v6_business.sql` (agents, leads, payments, investor role/overview)

Then: Authentication -> Providers -> Email -> turn **Confirm email OFF** (sign-up writes the
profile from the app). Create one account in the app, then promote it:
`update public.profiles set role='super_admin' where id='<AUTH-UUID>';`
Add regions / zones / cities in Admin dashboard -> Locations.

> The three files were reassembled from the migrations that were applied to the working
> project. Run them once on a fresh free Supabase project and click through the app before
> going live. `database/superseded/` holds old patches kept only for history.
> `database/99_DEMO_DATA_CLEANUP.sql` removes demo users/listings/payments.

If you create a new Supabase project, replace the URL and key in: `supabase.js`, `app-core.js`,
and the pages that create a client (search for `supabase.co` in `app/src/main/assets/web`).

## City selection
On first launch `city-gate.js` shows a full-screen "Select your city" list (cities come from the `locations`
table, type = city). The choice is remembered (localStorage `eedb_city`) and applied to listings, jobs,
marketplace and cars on the home page. A floating "Change city" button lets users switch or see all cities.

## Loading speed
- Startup: login check and locations load at the same time; listings load only for the chosen city; properties query limited to the 150 newest.
- `<link rel="preconnect">` to Supabase and the CDN on every page.
- `MainActivity` downloads the pinned supabase-js file once, keeps it in app storage and serves it from disk
  (faster start, works offline after the first run). Hardware layer for the WebView.
- Photos: upload small images (about 1 MB or less) - large photos are the biggest cause of slow lists.

## 2. Build
- **GitHub Actions** (fastest): push to `main` -> debug APK, also published as a direct download on the
  repository **Releases** page (`latest-debug`). Open that link on the phone and install.
  Actions -> *Android Build* -> *Run workflow* -> tick **release** -> Releases page `latest-release`
  (signed APK + AAB) and artifact `EEDB-release-APK-AAB`. Private repo: only you can open the links.
  For Play Store add secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`
  (without them a temporary key is generated: fine for demos, not for Play).
- **Android Studio**: open this folder, Build -> Generate Signed Bundle / APK.
- Keep the release keystore safe; losing it means you cannot update the app on Play.

## 3. Before real launch
See `PLAY_STORE_CHECKLIST.md` (privacy policy URL, store listing, data-safety answers, screenshots)
and run `database/99_DEMO_DATA_CLEANUP.sql`.

## Payments
Manual ledger (cash / bank / Telebirr / CBE Birr recorded by agents and admins). No online
gateway yet; Chapa or Telebirr API can be added later on top of the `payments` table.
