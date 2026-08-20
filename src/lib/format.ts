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

const timeFmt = new Intl.DateTimeFormat("en-AU", {
  hour: "numeric",
  minute: "2-digit",
});

export const fmtDate = (iso: string): string => dateFmt.format(new Date(iso));
export const fmtDateTime = (iso: string): string => dateTimeFmt.format(new Date(iso));
export const fmtFullDate = (iso: string): string => fullDateFmt.format(new Date(iso));
/** Time of day alone — for "Updated 7:14 am", where the date is implied. */
export const fmtTime = (iso: string): string => timeFmt.format(new Date(iso));

/** Local calendar day (YYYY-MM-DD) of a Date or ISO timestamp. */
export function localDay(value: Date | string): string {
  const d = typeof value === "string" ? new Date(value) : value;
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** YYYY-MM-DD for a date N days ago, in the user's local calendar. */
export function dayNDaysAgo(n: number, now = new Date()): string {
  const d = new Date(now);
  d.setDate(d.getDate() - n);
  return localDay(d);
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
