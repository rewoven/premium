# Scanner paywall — for `rewoven/app` (private)

The mobile app's clothing scanner currently lets every user scan
unlimited garment labels. Premium changes that to **5 free scans per
month, unlimited for premium**.

This file is the patch you (or I, with repo access) apply to the private
`rewoven/app` repo.

## 1. Add a helper

Create `services/premium.ts`:

```ts
import { supabase } from '@/lib/supabase';

const FREE_SCANS_PER_MONTH = 5;

export type ScanGate =
  | { ok: true; remaining: number | null }      // null = unlimited
  | { ok: false; reason: 'limit_reached'; used: number; limit: number };

export async function checkScanQuota(userId: string): Promise<ScanGate> {
  // 1. Premium users skip the quota entirely
  const { data: profile } = await supabase
    .from('profiles')
    .select('is_premium')
    .eq('id', userId)
    .maybeSingle();

  if (profile?.is_premium) return { ok: true, remaining: null };

  // 2. Count this calendar month's scans
  const startOfMonth = new Date();
  startOfMonth.setDate(1);
  startOfMonth.setHours(0, 0, 0, 0);

  const { count, error } = await supabase
    .from('fabric_scans')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .gte('created_at', startOfMonth.toISOString());

  if (error) {
    // Fail open in dev — fail closed in prod is also reasonable.
    return { ok: true, remaining: FREE_SCANS_PER_MONTH };
  }

  const used = count ?? 0;
  if (used >= FREE_SCANS_PER_MONTH) {
    return { ok: false, reason: 'limit_reached', used, limit: FREE_SCANS_PER_MONTH };
  }

  return { ok: true, remaining: FREE_SCANS_PER_MONTH - used };
}
```

## 2. Use it in the Scan tab

In `app/(tabs)/scan.tsx`, before triggering the actual scan / label
analysis, call the gate:

```ts
import { checkScanQuota } from '@/services/premium';
import { Linking, Alert } from 'react-native';

const onScanPressed = async () => {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) { /* prompt login */ return; }

  const gate = await checkScanQuota(user.id);
  if (!gate.ok) {
    Alert.alert(
      'Free limit reached',
      `You've used your ${gate.limit} free scans this month. ` +
      `Subscribe to Rewoven Premium for unlimited scans, the curriculum, ` +
      `and the multiplayer quiz — $4.99/month.`,
      [
        { text: 'Maybe later', style: 'cancel' },
        { text: 'Get Premium', onPress: () => Linking.openURL('https://premium.rewovenapp.com') }
      ]
    );
    return;
  }

  // Show "X free scans remaining" badge if we want
  startScan();
};
```

## 3. (Optional) Surface the remaining count in the UI

In the scan tab header, you can show the count whenever the user is
non-premium so they know where they stand:

```tsx
const [scansLeft, setScansLeft] = useState<number | null>(null);

useEffect(() => {
  (async () => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;
    const gate = await checkScanQuota(user.id);
    setScansLeft(gate.ok ? gate.remaining : 0);
  })();
}, []);

// In the header:
{scansLeft !== null && (
  <Text style={styles.quotaBadge}>
    {scansLeft} free scan{scansLeft === 1 ? '' : 's'} left this month
  </Text>
)}
```

## 4. Dependencies

The `profiles` table needs the new columns from the
`priv/supabase_migration.sql` migration in this repo. Run that once in
the Supabase SQL editor before shipping the app update.

## Why client-side?

For $4.99/mo with kids and parents, client-side gating + Supabase RLS on
`fabric_scans` (so users can only see their own rows) is plenty of
protection. If you ever want hard server-side enforcement, move scan
analysis behind the `analyze-label` Supabase Edge Function and check
`is_premium` + month count there before processing.
