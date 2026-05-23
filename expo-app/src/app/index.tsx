import { useEffect, useState } from 'react';
import { Pressable, StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { addMessageListener, sendMessage, useSharedState } from 'expo-brownfield';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';

// Custom Vault Inspector screen showing native ↔ RN bidirectional state via
// expo-brownfield. KeePassium (native) publishes mock vault state on launch;
// this screen subscribes to it reactively and can ask native to re-roll the
// session token via the messaging channel.

export default function VaultInspector() {
  const [vaultName] = useSharedState<string>('vaultName');
  const [entryCount] = useSharedState<number>('entryCount');
  const [sessionToken] = useSharedState<string>('sessionToken');
  const [lastUnlocked] = useSharedState<string>('lastUnlocked');
  const [reRollCount, setReRollCount] = useState(0);

  useEffect(() => {
    // Observe native acknowledgments — for logging only.
    const sub = addMessageListener((event) => {
      if (event?.type === 'TOKEN_REROLLED') {
        setReRollCount((n) => n + 1);
      }
    });
    return () => sub.remove();
  }, []);

  useEffect(() => {
    // Brownfield demo helper: fire a few re-rolls automatically so the
    // recording shows the round-trip (RN sendMessage → native re-rolls
    // state → useSharedState reactively updates → ack increments counter)
    // without needing UI automation. Disable by setting __DEMO_AUTO_REROLL__
    // to false on a real run.
    const __DEMO_AUTO_REROLL__ = true;
    if (!__DEMO_AUTO_REROLL__) return;
    const timers = [
      setTimeout(() => sendMessage({ type: 'REROLL_TOKEN' }), 4500),
      setTimeout(() => sendMessage({ type: 'REROLL_TOKEN' }), 7500),
    ];
    return () => timers.forEach(clearTimeout);
  }, []);

  const handleReRoll = () => {
    sendMessage({ type: 'REROLL_TOKEN' });
  };

  return (
    <ThemedView style={styles.container}>
      <SafeAreaView style={styles.safeArea}>
        <ThemedView style={styles.headerCard}>
          <ThemedText type="code" style={styles.eyebrow}>
            EXPO BROWNFIELD
          </ThemedText>
          <ThemedText type="title" style={styles.title}>
            Vault Inspector
          </ThemedText>
          <ThemedText type="small" style={styles.subtitle}>
            Live state shared with KeePassium (native) — no refresh needed.
          </ThemedText>
        </ThemedView>

        <ThemedView type="backgroundElement" style={styles.stateCard}>
          <Row label="Vault" value={vaultName ?? '…'} />
          <Divider />
          <Row label="Entries" value={entryCount != null ? `${entryCount}` : '…'} />
          <Divider />
          <Row label="Last unlocked" value={shortTime(lastUnlocked)} />
          <Divider />
          <Row label="Session token" value={shortToken(sessionToken)} mono />
        </ThemedView>

        <Pressable onPress={handleReRoll} style={({ pressed }) => [styles.button, pressed && styles.buttonPressed]}>
          <ThemedText type="defaultSemiBold" style={styles.buttonText}>
            🔁 Re-roll session token
          </ThemedText>
        </Pressable>

        <ThemedText type="small" style={styles.footer}>
          Re-rolls this session: <ThemedText type="defaultSemiBold">{reRollCount}</ThemedText>
        </ThemedText>
      </SafeAreaView>
    </ThemedView>
  );
}

function Row({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <ThemedView style={styles.row}>
      <ThemedText type="small" style={styles.rowLabel}>
        {label}
      </ThemedText>
      <ThemedText type={mono ? 'code' : 'defaultSemiBold'} style={styles.rowValue} numberOfLines={1}>
        {value}
      </ThemedText>
    </ThemedView>
  );
}

function Divider() {
  return <ThemedView style={styles.divider} />;
}

function shortToken(token: string | undefined) {
  if (!token) return '…';
  return `${token.slice(0, 8)}…${token.slice(-4)}`;
}

function shortTime(iso: string | undefined) {
  if (!iso) return '…';
  try {
    return new Date(iso).toLocaleTimeString();
  } catch {
    return iso;
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
    paddingHorizontal: Spacing.four,
    paddingVertical: Spacing.four,
    gap: Spacing.four,
  },
  headerCard: {
    gap: Spacing.two,
    paddingTop: Spacing.four,
  },
  eyebrow: {
    opacity: 0.6,
  },
  title: {
    fontWeight: '700',
  },
  subtitle: {
    opacity: 0.7,
  },
  stateCard: {
    borderRadius: Spacing.four,
    paddingVertical: Spacing.two,
    paddingHorizontal: Spacing.three,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: Spacing.three,
    gap: Spacing.three,
  },
  rowLabel: {
    opacity: 0.6,
  },
  rowValue: {
    flexShrink: 1,
    textAlign: 'right',
  },
  divider: {
    height: StyleSheet.hairlineWidth,
    opacity: 0.15,
    backgroundColor: '#000',
  },
  button: {
    backgroundColor: '#2563EB',
    paddingVertical: Spacing.three,
    paddingHorizontal: Spacing.four,
    borderRadius: Spacing.three,
    alignItems: 'center',
  },
  buttonPressed: {
    opacity: 0.8,
  },
  buttonText: {
    color: '#FFFFFF',
  },
  footer: {
    textAlign: 'center',
    opacity: 0.5,
  },
});
