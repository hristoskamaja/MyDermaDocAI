// Shared constants and helpers for the Track section.

export const AREAS = ['forehead', 'nose', 'left_cheek', 'right_cheek', 'chin', 'jawline'];
export const SCAN_AREAS = [...AREAS, 'neck', 'chest', 'back', 'arms', 'other'];
export const FOOD_TAGS = ['dairy', 'sugar', 'fried', 'alcohol', 'caffeine', 'water'];

// Custom food tags: limits mirror the backend (tracking/constants.py).
export const MAX_FOOD_TAGS = 12;
export const MAX_CUSTOM_FOOD_LENGTH = 30;
const CUSTOM_FOOD_RE = /^[\p{L}\p{N}]+(?:[ '-][\p{L}\p{N}]+)*$/u;

// Lowercase, trimmed, single-spaced; returns '' when the text is not allowed.
export function normalizeFoodTag(raw) {
    const tag = String(raw || '').normalize('NFC').trim().replace(/\s+/g, ' ').toLowerCase();
    return tag.length <= MAX_CUSTOM_FOOD_LENGTH && CUSTOM_FOOD_RE.test(tag) ? tag : '';
}

// Fixed tags are translated; custom tags are shown as the user typed them.
export const foodLabel = (t, key) => (FOOD_TAGS.includes(key) ? t(`track.food.${key}`) : key);

export const SLEEP_QUALITIES = ['poor', 'okay', 'great'];
export const CYCLE_PHASES = ['menstrual', 'follicular', 'ovulation', 'luteal'];
export const STEP_TYPES = ['cleanse', 'treat', 'hydrate', 'protect'];
export const TIME_OF_DAY = ['AM', 'PM', 'BOTH'];
export const SEVERITY_KEYS = ['clear', 'mild', 'moderate', 'severe'];
export const METRICS = ['sleep', 'stress', 'acne'];

// Replaces {name} placeholders in a translated string.
export function fmt(text, vars = {}) {
    return String(text).replace(/\{(\w+)\}/g, (_, key) => (vars[key] !== undefined ? vars[key] : `{${key}}`));
}

// Local calendar date as YYYY-MM-DD (not UTC, so late-evening check-ins land on the right day).
export function toISODate(date = new Date()) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
}

export function daysAgoISO(days) {
    const date = new Date();
    date.setDate(date.getDate() - days);
    return toISODate(date);
}

// "2026-11-08" -> "Nov 8" in the active UI language.
export function shortDate(iso, lang) {
    if (!iso) return '';
    const [y, m, d] = iso.split('-').map(Number);
    return new Date(y, m - 1, d).toLocaleDateString(lang === 'mk' ? 'mk-MK' : 'en-US', { month: 'short', day: 'numeric' });
}

export function longDate(iso, lang) {
    if (!iso) return '';
    const [y, m, d] = iso.split('-').map(Number);
    return new Date(y, m - 1, d).toLocaleDateString(lang === 'mk' ? 'mk-MK' : 'en-US', {
        weekday: 'short', day: 'numeric', month: 'short',
    });
}

// Maps a severity level from the API to a CSS modifier.
export function levelClass(level) {
    return ['clear', 'mild', 'moderate', 'severe'].includes(level) ? `tr-level--${level}` : 'tr-level--none';
}

export function apiErrorText(err, fallback) {
    const data = err?.response?.data;
    if (!data) return fallback;
    if (typeof data.detail === 'string') return data.detail;
    const first = typeof data === 'object' ? Object.values(data)[0] : null;
    if (Array.isArray(first) && typeof first[0] === 'string') return first[0];
    if (typeof first === 'string') return first;
    return fallback;
}
