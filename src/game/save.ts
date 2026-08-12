const KEY = "jj-night-brawl-profile-v1";
export const SAVE_VERSION = 2;
export const SLOT_COUNT = 3;

export type PlayMode = "story" | "endless";
export type CharacterId = "jj" | "andrew" | "han";

export interface SaveSlot {
  updatedAt: number;
  mode: PlayMode;
  characterId: CharacterId;
  wave: number;
  score: number;
  hasGun: boolean;
  hp: number;
  maxHp: number;
  specialMeter: number;
  stageName: string;
}

export interface Profile {
  version: number;
  settings: { muted: boolean };
  records: {
    highScore: number;
    playtimeSec: number;
    enemiesDefeated: number;
    wavesCleared: number;
    storyClears: number;
    bestEndlessWave: number;
  };
  achievements: Record<string, number>;
  shop: {
    cred: number;
    levels: Record<string, number>;
    ownedChars: CharacterId[];
  };
  unlocks: {
    stages: number[];
    gallery: string[];
    endings: string[];
  };
  slots: Array<SaveSlot | null>;
  lastSlot: number | null;
  feedback: Array<{ at: number; text: string }>;
}

export const CHARACTERS: Record<
  CharacterId,
  { name: string; role: string; blurb: string; hue: number; hp: number; speed: number }
> = {
  jj: {
    name: "JJ",
    role: "Punk lead",
    blurb: "Noise as resistance. Story lead.",
    hue: 0,
    hp: 100,
    speed: 1,
  },
  andrew: {
    name: "Andrew",
    role: "Scene coder",
    blurb: "Faster hands. Types through the night.",
    hue: 0,
    hp: 92,
    speed: 1.08,
  },
  han: {
    name: "Han",
    role: "Cat-ear chaos",
    blurb: "Phone out, fists ready.",
    hue: 0,
    hp: 96,
    speed: 1.12,
  },
};

export const STAGES = [
  { id: 1, name: "The Pit", sub: "DIY alley" },
  { id: 2, name: "Street Fair", sub: "Authenticity booths" },
  { id: 3, name: "Community Center", sub: "Rebrand night" },
  { id: 4, name: "Parking Lot Rally", sub: "Costume rebellion" },
  { id: 5, name: "Chain Store", sub: "Takeover night" },
];

export const SHOP_ITEMS = [
  { id: "tape", name: "Knuckle Tape", blurb: "+ punch damage", max: 3, prices: [180, 360, 720] },
  { id: "toes", name: "Steel Toes", blurb: "+ kick damage", max: 3, prices: [200, 400, 800] },
  { id: "boots", name: "Worn Boots", blurb: "+ move speed", max: 3, prices: [220, 440, 880] },
  { id: "amp", name: "Amp Mod", blurb: "Special fills faster", max: 3, prices: [260, 520, 980] },
  { id: "kit", name: "Patch Kit", blurb: "+ max HP", max: 3, prices: [240, 480, 900] },
] as const;

export const ACHIEVEMENTS = [
  { id: "first_blood", name: "First Blood", desc: "Drop your first foe" },
  { id: "wave_three", name: "Not a Focus Group", desc: "Clear wave 3" },
  { id: "packing_heat", name: "Packin' Heat", desc: "Unlock the gun" },
  { id: "street_cleared", name: "Street Cleared", desc: "Finish Story Mode" },
  { id: "ten_k", name: "Scene Cred", desc: "Score 10,000 in one run" },
  { id: "shopaholic", name: "Support Local", desc: "Buy something at the shop" },
  { id: "endless_five", name: "No Future?", desc: "Reach Endless wave 5" },
  { id: "full_roster", name: "The Band", desc: "Unlock every character" },
] as const;

function migrateChars(list?: string[]): CharacterId[] {
  const mapped = (list ?? ["jj"]).map((id) => {
    if (id === "ash") return "andrew";
    if (id === "rex") return "han";
    return id as CharacterId;
  });
  const allowed: CharacterId[] = ["jj", "andrew", "han"];
  const next = allowed.filter((id) => mapped.includes(id));
  if (!next.includes("jj")) next.unshift("jj");
  if (!next.includes("andrew")) next.push("andrew");
  if (!next.includes("han")) next.push("han");
  return next;
}

function defaults(): Profile {
  return {
    version: SAVE_VERSION,
    settings: { muted: false },
    records: {
      highScore: 0,
      playtimeSec: 0,
      enemiesDefeated: 0,
      wavesCleared: 0,
      storyClears: 0,
      bestEndlessWave: 0,
    },
    achievements: {},
    shop: { cred: 120, levels: {}, ownedChars: ["jj", "andrew", "han"] },
    unlocks: { stages: [1], gallery: ["jjIdle"], endings: [] },
    slots: [null, null, null],
    lastSlot: null,
    feedback: [],
  };
}

function migrate(raw: Profile): Profile {
  const d = defaults();
  const slots = Array.from({ length: SLOT_COUNT }, (_, i) => {
    const s = raw.slots?.[i] ?? null;
    if (!s) return null;
    const id = s.characterId === ("ash" as CharacterId) ? "andrew" : s.characterId === ("rex" as CharacterId) ? "han" : s.characterId;
    return { ...s, characterId: id };
  });
  return {
    ...d,
    ...raw,
    version: SAVE_VERSION,
    settings: { ...d.settings, ...raw.settings },
    records: { ...d.records, ...raw.records },
    achievements: { ...raw.achievements },
    shop: {
      cred: raw.shop?.cred ?? d.shop.cred,
      levels: { ...raw.shop?.levels },
      ownedChars: migrateChars(raw.shop?.ownedChars),
    },
    unlocks: {
      stages: raw.unlocks?.stages?.length ? raw.unlocks.stages : [1],
      gallery: raw.unlocks?.gallery ?? d.unlocks.gallery,
      endings: raw.unlocks?.endings ?? [],
    },
    slots,
    lastSlot: raw.lastSlot ?? null,
    feedback: raw.feedback ?? [],
  };
}

export function loadProfile(): Profile {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return defaults();
    return migrate(JSON.parse(raw) as Profile);
  } catch {
    return defaults();
  }
}

export function saveProfile(p: Profile) {
  try {
    localStorage.setItem(KEY, JSON.stringify(p));
  } catch {
    /* quota / private mode */
  }
}

export function lastPlayedSlot(p: Profile): SaveSlot | null {
  if (p.lastSlot != null && p.slots[p.lastSlot]) return p.slots[p.lastSlot];
  const filled = p.slots.filter(Boolean) as SaveSlot[];
  if (!filled.length) return null;
  return filled.sort((a, b) => b.updatedAt - a.updatedAt)[0]!;
}

export function stageName(wave: number) {
  return STAGES[Math.min(STAGES.length, Math.max(1, wave)) - 1]?.name ?? `Wave ${wave}`;
}

export function upgradeBonuses(p: Profile) {
  const lv = p.shop.levels;
  return {
    punch: (lv.tape ?? 0) * 2,
    kick: (lv.toes ?? 0) * 2,
    speed: 1 + (lv.boots ?? 0) * 0.06,
    special: 1 + (lv.amp ?? 0) * 0.15,
    hp: (lv.kit ?? 0) * 12,
  };
}

export function unlockAchievement(p: Profile, id: string) {
  if (p.achievements[id]) return false;
  p.achievements[id] = Date.now();
  return true;
}

export function formatWhen(ts: number) {
  try {
    return new Date(ts).toLocaleString(undefined, {
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
    });
  } catch {
    return "—";
  }
}
