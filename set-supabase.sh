#!/bin/sh
# Usage: ./set-supabase.sh https://xxxx.supabase.co sb_publishable_xxx
[ -z "$2" ] && { echo "Usage: $0 <url> <publishable_key>"; exit 1; }
cd "$(dirname "$0")/app/src/main/assets/web" || exit 1
for f in *.js *.html; do
  sed -i "s#https://YOUR-NEW-PROJECT.supabase.co#$1#g; s#YOUR_NEW_PUBLISHABLE_KEY#$2#g" "$f"
done
echo "Done."
