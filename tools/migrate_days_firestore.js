const admin = require('firebase-admin');

// Usage:
//  node migrate_days_firestore.js /path/to/serviceAccountKey.json
// or set env var GOOGLE_APPLICATION_CREDENTIALS to the JSON file path.

const args = process.argv.slice(2);

// Flags
const applyFlag = args.includes('--apply');
const dryRunFlag = args.includes('--dry-run');
const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || args.find((a) => !a.startsWith('--'));

if (!serviceAccountPath) {
  console.error('Error: provide path to service account JSON as first non-flag arg, or set GOOGLE_APPLICATION_CREDENTIALS');
  console.error('Usage: node migrate_days_firestore.js /path/to/sa.json [--dry-run] [--apply]');
  process.exit(1);
}

let serviceAccount;
try {
  serviceAccount = require(serviceAccountPath);
} catch (e) {
  console.error('Error loading service account JSON:', e.message);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const legacyToNew = { L: 'Lun', M: 'Mar', X: 'Mié', J: 'Jue', V: 'Vie', S: 'Sab', D: 'Dom' };
const newOrder = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sab', 'Dom'];

async function migrate() {
  console.log('Starting migration: mapping legacy single-letter day codes to 3-letter Spanish labels');

  const medsRef = db.collection('medications');
  const snapshot = await medsRef.get();
  console.log(`Found ${snapshot.size} documents in 'medications' collection`);

  let updated = 0;
  let skipped = 0;
  const toUpdate = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const days = Array.isArray(data.days) ? data.days : [];

    // Map each entry to the new label when possible
    const mapped = days.map((d) => {
      if (typeof d !== 'string') return d;
      const trimmed = d.trim();
      if (legacyToNew[trimmed]) return legacyToNew[trimmed];
      // Try single-char uppercase fallback (e.g., 'm' -> 'M')
      const upper = trimmed.charAt(0).toUpperCase();
      if (legacyToNew[upper]) return legacyToNew[upper];
      // If already in new format, keep as-is
      return trimmed;
    });

    // Remove duplicates while preserving order
    const unique = [];
    for (const item of mapped) {
      if (!unique.includes(item)) unique.push(item);
    }

    // Sort according to newOrder (weekday order)
    const sorted = newOrder.filter((d) => unique.includes(d));

    // If sorted is empty but unique had values (unknown labels), keep unique
    const finalDays = sorted.length > 0 ? sorted : unique;

    // Decide if update needed: compare stringified arrays
    const needsUpdate = JSON.stringify(finalDays) !== JSON.stringify(days);

    if (needsUpdate) {
      toUpdate.push({ id: doc.id, ref: doc.ref, old: days, next: finalDays });
    }
  }

  console.log(`Documents to update: ${toUpdate.length}`);

  if (toUpdate.length === 0) {
    console.log('Nothing to do. Exiting.');
    return;
  }

  if (dryRunFlag || !applyFlag) {
    console.log('Dry run mode (no changes will be written). Use --apply to perform updates.');
    for (const item of toUpdate) {
      console.log(`${item.id}: ${JSON.stringify(item.old)} -> ${JSON.stringify(item.next)}`);
    }
    console.log('Dry run complete. To apply changes re-run with --apply flag.');
    return;
  }

  // If we reach here, user requested apply
  for (const item of toUpdate) {
    try {
      await item.ref.update({
        days_old: item.old,
        days: item.next,
        days_migrated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      updated++;
      console.log(`Updated ${item.id}: ${JSON.stringify(item.old)} -> ${JSON.stringify(item.next)}`);
    } catch (err) {
      console.error(`Failed updating ${item.id}:`, err.message);
    }
  }

  console.log(`Migration complete. Updated: ${updated}, Skipped: ${snapshot.size - updated}`);
}

migrate().then(() => process.exit(0)).catch((err) => {
  console.error('Migration failed:', err);
  process.exit(2);
});
