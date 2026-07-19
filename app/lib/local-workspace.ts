import type {
  NatalCalculationSettings,
  NatalPersonInput,
  NatalSnapshot,
} from "./interstellar-api";

const DATABASE_NAME = "interstellar-local-workspace-v1";
const DATABASE_VERSION = 1;
const LEGACY_PEOPLE_KEY = "interstellar.natal.people.v1";

const STORES = {
  people: "people",
  results: "natal-results",
  presets: "natal-presets",
} as const;

export type NatalPointGroupState = {
  core: boolean;
  angles: boolean;
  lunar: boolean;
  asteroids: boolean;
  lots: boolean;
  hamburg: boolean;
};

export type SavedPersonRecord = {
  id: string;
  person: NatalPersonInput;
  savedAt: string;
};

export type SavedNatalResult = {
  id: string;
  snapshot: NatalSnapshot;
  subjectName: string;
  person: NatalPersonInput;
  settings: NatalCalculationSettings;
  groups: NatalPointGroupState;
  technicalDocument: string;
  technicalDocumentHash: string;
  savedAt: string;
  retention: "until_deleted";
};

export type SavedNatalPreset = {
  id: string;
  name: string;
  settings: NatalCalculationSettings;
  groups: NatalPointGroupState;
  savedAt: string;
  retention: "until_deleted";
};

type WorkspaceStore = (typeof STORES)[keyof typeof STORES];

function ensureIndexedDb(): IDBFactory {
  if (typeof window === "undefined" || !window.indexedDB) {
    throw new Error("当前浏览器不支持 IndexedDB，本机工作区不可用");
  }
  return window.indexedDB;
}

function requestValue<T>(request: IDBRequest<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error ?? new Error("本机数据库请求失败"));
  });
}

function transactionDone(transaction: IDBTransaction): Promise<void> {
  return new Promise((resolve, reject) => {
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error ?? new Error("本机数据库事务失败"));
    transaction.onabort = () => reject(transaction.error ?? new Error("本机数据库事务已取消"));
  });
}

function openWorkspace(): Promise<IDBDatabase> {
  const indexedDb = ensureIndexedDb();
  return new Promise((resolve, reject) => {
    const request = indexedDb.open(DATABASE_NAME, DATABASE_VERSION);
    request.onupgradeneeded = () => {
      const database = request.result;
      for (const storeName of Object.values(STORES)) {
        if (!database.objectStoreNames.contains(storeName)) {
          database.createObjectStore(storeName, { keyPath: "id" });
        }
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error ?? new Error("无法打开本机工作区"));
  });
}

async function getAll<T>(storeName: WorkspaceStore): Promise<T[]> {
  const database = await openWorkspace();
  try {
    const transaction = database.transaction(storeName, "readonly");
    const values = await requestValue(transaction.objectStore(storeName).getAll() as IDBRequest<T[]>);
    await transactionDone(transaction);
    return values;
  } finally {
    database.close();
  }
}

async function put<T>(storeName: WorkspaceStore, value: T): Promise<void> {
  const database = await openWorkspace();
  try {
    const transaction = database.transaction(storeName, "readwrite");
    transaction.objectStore(storeName).put(value);
    await transactionDone(transaction);
  } finally {
    database.close();
  }
}

async function remove(storeName: WorkspaceStore, id: string): Promise<void> {
  const database = await openWorkspace();
  try {
    const transaction = database.transaction(storeName, "readwrite");
    transaction.objectStore(storeName).delete(id);
    await transactionDone(transaction);
  } finally {
    database.close();
  }
}

function stablePersonId(person: NatalPersonInput): string {
  return `person:${encodeURIComponent(person.displayName.trim())}:${person.localDate}:${person.localTime || "unknown"}`;
}

function uniqueId(prefix: string): string {
  const suffix = typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  return `${prefix}:${suffix}`;
}

export async function listSavedPeople(): Promise<SavedPersonRecord[]> {
  const records = await getAll<SavedPersonRecord>(STORES.people);
  return records.sort((a, b) => b.savedAt.localeCompare(a.savedAt));
}

export async function savePersonRecord(person: NatalPersonInput): Promise<SavedPersonRecord> {
  const record: SavedPersonRecord = {
    id: stablePersonId(person),
    person: structuredClone(person),
    savedAt: new Date().toISOString(),
  };
  await put(STORES.people, record);
  return record;
}

export async function deletePersonRecord(id: string): Promise<void> {
  await remove(STORES.people, id);
}

export async function listSavedNatalResults(): Promise<SavedNatalResult[]> {
  const records = await getAll<SavedNatalResult>(STORES.results);
  return records.sort((a, b) => b.savedAt.localeCompare(a.savedAt));
}

export async function saveNatalResult(
  input: Omit<SavedNatalResult, "id" | "savedAt" | "retention">,
): Promise<SavedNatalResult> {
  const record: SavedNatalResult = {
    ...structuredClone(input),
    id: `natal-result:${input.snapshot.id}`,
    savedAt: new Date().toISOString(),
    retention: "until_deleted",
  };
  await put(STORES.results, record);
  return record;
}

export async function deleteNatalResult(id: string): Promise<void> {
  await remove(STORES.results, id);
}

export async function listSavedNatalPresets(): Promise<SavedNatalPreset[]> {
  const records = await getAll<SavedNatalPreset>(STORES.presets);
  return records.sort((a, b) => b.savedAt.localeCompare(a.savedAt));
}

export async function saveNatalPreset(
  input: Omit<SavedNatalPreset, "id" | "savedAt" | "retention">,
): Promise<SavedNatalPreset> {
  const record: SavedNatalPreset = {
    ...structuredClone(input),
    id: uniqueId("natal-preset"),
    savedAt: new Date().toISOString(),
    retention: "until_deleted",
  };
  await put(STORES.presets, record);
  return record;
}

export async function deleteNatalPreset(id: string): Promise<void> {
  await remove(STORES.presets, id);
}

export async function clearLocalWorkspace(): Promise<void> {
  const database = await openWorkspace();
  try {
    const transaction = database.transaction(Object.values(STORES), "readwrite");
    for (const storeName of Object.values(STORES)) transaction.objectStore(storeName).clear();
    await transactionDone(transaction);
  } finally {
    database.close();
  }
}

export async function migrateLegacyPeopleFromLocalStorage(
  fallback: NatalPersonInput,
): Promise<number> {
  if (typeof window === "undefined") return 0;
  const raw = window.localStorage.getItem(LEGACY_PEOPLE_KEY);
  if (!raw) return 0;
  let parsed: Array<Partial<NatalPersonInput>>;
  try {
    const value = JSON.parse(raw) as unknown;
    if (!Array.isArray(value)) return 0;
    parsed = value;
  } catch {
    return 0;
  }
  for (const partial of parsed) {
    await savePersonRecord({ ...fallback, ...partial });
  }
  window.localStorage.removeItem(LEGACY_PEOPLE_KEY);
  return parsed.length;
}
