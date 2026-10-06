/*
 * One shared client name is used by the legacy pages (`db`) and by the
 * authentication pages (`supabaseClient`).  Keeping both aliases here
 * prevents pages loaded from the same static bundle from silently using
 * different clients.
 */
const SUPABASE_URL =
    "https://YOUR-NEW-PROJECT.supabase.co";

const SUPABASE_KEY =
    "YOUR_NEW_PUBLISHABLE_KEY";

let db = null;
let supabaseClient = null;

function initializeSupabase() {

    if (!window.supabase) {

        console.error(
            "Supabase JavaScript library was not loaded."
        );

        return false;
    }

    db = window.supabase.createClient(
        SUPABASE_URL,
        SUPABASE_KEY
    );

    supabaseClient = db;

    console.log(
        "SUPABASE CLIENT CREATED SUCCESSFULLY"
    );

    return true;
}

initializeSupabase();