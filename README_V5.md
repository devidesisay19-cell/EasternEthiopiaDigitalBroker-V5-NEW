# EEDB V5 – quick start

V5 uses applicationId `com.easterneethiopia.digitalbroker.v5`, so the OLD APK keeps working and installs side by side.

## What changed (existing design kept)
- First launch: **select your city**. Home shows only that city's Property, Jobs, Marketplace and Cars. "All Cities" removed; city chip on Home to switch.
- **Brokers strip** on Home (Call / WhatsApp / Verified) and `broker-profile.html` with their listings. **No limit of brokers per city.**
- Photo limit is 5 for Property, Marketplace and Cars (Property was 15).
- Old Supabase URL/key replaced by placeholders (7 files).

## Steps (new Supabase project)
1. Create a new Supabase project (Auth: for testing you may disable "Confirm email").
2. SQL Editor - run IN THIS ORDER:
   1. `SUPABASE_V5_BASE_1_TABLES.sql`   (tables, triggers - written from the app code)
   2. `SUPABASE_FINAL_V4.sql`           (marketplace, cars, roles, storage, reports)
   3. `SUPABASE_V5_BASE_2_POLICIES.sql` (RLS for properties/jobs/etc + contact RPCs)
   4. `SUPABASE_V5_BROKERS.sql`         (brokers + monthly payments)
   5. `SUPABASE_V5_SEED_LOCATIONS.sql`  (Dire Dawa, Harar, Jigjiga, Chiro)
3. `./set-supabase.sh https://xxxx.supabase.co sb_publishable_xxx`
4. Sign up in the app, then make yourself super admin:
   `update public.profiles set role='super_admin' where id='<YOUR-UUID>';`
5. Add brokers (no limit per city; user must have signed up first):
   `select eedb_add_broker('<user_uuid>','<city_uuid>','Name','09...');`
6. Monthly payment: `select eedb_confirm_broker_payment('<broker_uuid>', 500, 'telebirr', 'ref', 1);`
7. Android Studio: open V5 folder > Build > Generate Signed APK.

## Honest notes
- The base schema was reconstructed from the app code, not from your old database. Compare with the old project (or run a schema-only dump) if something fails with "column does not exist" and send me the error.
- Not run on a real Postgres here: run part by part and send me any SQL error.
- Only Super Admin/city admins can feature a property (`is_featured`) - owners cannot self-feature.
- Woreda/area lists are empty: add them to `locations` if the post form requires them.
- No admin screen yet for brokers/payments (SQL only).
- Broker linking: `owner_id` (properties), `employer_id` (jobs), `seller_id` (marketplace, cars) = broker's `user_id`.
- Not compiled here: build and test in Android Studio.
