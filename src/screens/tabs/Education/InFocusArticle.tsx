import { useNavigate, useParams } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { APP } from "@/copy/app";
import { SAFETY } from "@/copy/safety";
import { findInFocusArticle } from "@/copy/library-placeholder";

/**
 * In Focus reading view — the publication's long reads, on the same article
 * template as a program chapter (content-type label, serif title, standfirst,
 * meta pairs, sans section headings, body, disclaimer). No read-tracking:
 * these are editorial, not curriculum, so there is no "mark as read".
 */
function MetaPair({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-[2px]">
      <span
        className="text-ink-tertiary"
        style={{ fontSize: "var(--text-body-sm)", fontWeight: 500 }}
      >
        {label}
      </span>
      <span style={{ fontSize: "var(--text-body-base)" }}>{value}</span>
    </div>
  );
}

export function InFocusArticle() {
  const { slug } = useParams();
  const navigate = useNavigate();
  const c = APP.inFocus;
  const article = findInFocusArticle(slug);

  if (!article) {
    return (
      <Screen title={c.notFound}>
        <Button onClick={() => navigate("/app/education")}>{c.back}</Button>
      </Screen>
    );
  }

  return (
    <Screen overline={c.overline} title={article.title} className="step-enter">
      {article.excerpt ? (
        <p
          className="pb-[var(--spacing-sm)] text-ink-secondary"
          style={{
            fontSize: "var(--text-body-lg)",
            lineHeight: "var(--leading-body-relaxed)",
          }}
        >
          {article.excerpt}
        </p>
      ) : null}

      <div className="flex flex-wrap gap-x-[var(--spacing-lg)] gap-y-[var(--spacing-xs)] border-y border-hairline py-[var(--spacing-sm)]">
        {article.displayReadingTime ? (
          <MetaPair
            label={APP.chapter.metaReadTime}
            value={APP.chapter.metaReadTimeValue(article.readMinutes)}
          />
        ) : null}
        <MetaPair label={APP.chapter.metaReview} value={article.reviewStatus} />
      </div>

      <Card className="mt-[var(--spacing-md)]">
        <p className="text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
          {article.emptyReaderMessage}
        </p>
      </Card>

      <p
        className="mt-[var(--spacing-md)] border-t border-hairline pt-[var(--spacing-sm)] text-ink-tertiary"
        style={{ fontSize: "var(--text-body-sm)" }}
      >
        {SAFETY.educationNote}
      </p>
    </Screen>
  );
}
