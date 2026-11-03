import { DEFAULT_CONFIG, ExtensionConfig, QueueItem } from './types';

const CONFIG_KEY = 'iap_ss_config';
const QUEUE_KEY = 'iap_ss_queue';
const HISTORY_KEY = 'iap_ss_history';

export async function getConfig(): Promise<ExtensionConfig> {
  const result = await chrome.storage.local.get(CONFIG_KEY);
  const stored = result[CONFIG_KEY];
  if (!stored) return DEFAULT_CONFIG;
  return { ...DEFAULT_CONFIG, ...stored };
}

export async function setConfig(config: ExtensionConfig): Promise<void> {
  await chrome.storage.local.set({ [CONFIG_KEY]: config });
}

export async function getQueue(): Promise<QueueItem[]> {
  const result = await chrome.storage.local.get(QUEUE_KEY);
  return (result[QUEUE_KEY] as QueueItem[]) || [];
}

export async function setQueue(queue: QueueItem[]): Promise<void> {
  await chrome.storage.local.set({ [QUEUE_KEY]: queue });
}

export async function updateQueueItem(localId: string, patch: Partial<QueueItem>): Promise<void> {
  const queue = await getQueue();
  const idx = queue.findIndex((q) => q.local_id === localId);
  if (idx === -1) return;
  queue[idx] = { ...queue[idx], ...patch };
  await setQueue(queue);
}

export async function pushHistory(item: QueueItem): Promise<void> {
  const result = await chrome.storage.local.get(HISTORY_KEY);
  const history: QueueItem[] = (result[HISTORY_KEY] as QueueItem[]) || [];
  history.unshift(item);
  // Limita a 200 items
  await chrome.storage.local.set({ [HISTORY_KEY]: history.slice(0, 200) });
}

export async function getHistory(): Promise<QueueItem[]> {
  const result = await chrome.storage.local.get(HISTORY_KEY);
  return (result[HISTORY_KEY] as QueueItem[]) || [];
}

export function uid(): string {
  return Math.random().toString(36).slice(2) + Date.now().toString(36);
}

// ------------------------------------------------------------
// Live log — persiste durante execução pra UI mostrar progresso
// ------------------------------------------------------------
const LIVE_LOG_KEY = 'iap_ss_live_log';

export interface LiveLogEntry {
  ts: number;
  level: 'info' | 'success' | 'error' | 'step';
  message: string;
  context?: any;
}

export async function pushLog(entry: Omit<LiveLogEntry, 'ts'>) {
  const result = await chrome.storage.local.get(LIVE_LOG_KEY);
  const log: LiveLogEntry[] = (result[LIVE_LOG_KEY] as LiveLogEntry[]) || [];
  log.unshift({ ...entry, ts: Date.now() });
  await chrome.storage.local.set({ [LIVE_LOG_KEY]: log.slice(0, 100) });
}

export async function getLog(): Promise<LiveLogEntry[]> {
  const result = await chrome.storage.local.get(LIVE_LOG_KEY);
  return (result[LIVE_LOG_KEY] as LiveLogEntry[]) || [];
}

export async function clearLog() {
  await chrome.storage.local.set({ [LIVE_LOG_KEY]: [] });
}
