/**
 * Chapter progress as one segment per chapter: filled means read.
 *
 * Reading is marked by hand on the chapter itself, so a filled segment is a
 * completion the reader recorded, never one the app inferred. The count is
 * carried by the accessible label rather than printed beside the bar.
 */
export function SegmentedProgress({
  read,
  total,
  label,
}: {
  read: number;
  total: number;
  label: string;
}) {
  return (
    <div role="img" aria-label={label} className="flex gap-[var(--spacing-3xs)]">
      {Array.from({ length: total }, (_, i) => (
        <span
          key={i}
          aria-hidden
          className={`h-[6px] flex-1 rounded-round ${i < read ? "bg-action" : "bg-hairline"}`}
        />
      ))}
    </div>
  );
}
