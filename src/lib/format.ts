/** Date/number formatting — en-AU throughout. */

const dateFmt = new Intl.DateTimeFormat("en-AU", {
  day: "numeric",
  month: "short",
});

const dateTimeFmt = new Intl.DateTimeFormat("en-AU", {
  day: "numeric",
  month: "short",
  hour: "numeric",
  minute: "2-digit",
});

const fullDateFmt = new Intl.DateTimeFormat("en-AU", {
  day: "numeric",
  month: "long",
  year: "numeric",
});

export const fmtDate = (iso: string): string => dateFmt.format(new Date(iso));
export const fmtDateTime = (iso: string): string => dateTimeFmt.format(new Date(iso));
export const fmtFullDate = (iso: string): string => fullDateFmt.format(new Date(iso));

/** YYYY-MM-DD for a date N days ago (local). */
export function dayNDaysAgo(n: number, now = new Date()): string {
  const d = new Date(now);
  d.setDate(d.getDate() - n);
  return d.toISOString().slice(0, 10);
}

/** datetime-local input value for "now" (local time, minute precision). */
export function nowLocalInputValue(now = new Date()): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`;
}

/** IANA timezone + offset minutes for the ingest payload. */
export function localTzInfo(now = new Date()): { tz: string; offsetMinutes: number } {
  return {
    tz: Intl.DateTimeFormat().resolvedOptions().timeZone,
    offsetMinutes: -now.getTimezoneOffset(),
  };
}
