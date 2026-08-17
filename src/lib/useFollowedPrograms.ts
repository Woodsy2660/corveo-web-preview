import { useCallback, useState } from "react";
import { CORE_PROGRAM_SLUG, loadFollowState, saveFollowState } from "@/lib/programs";

/**
 * Which programs the reader follows, and which one the tab opens on.
 *
 * Local state, not the API: `v_program_progress` has no program identifier,
 * so there is nowhere on the contract to persist this yet. See the note at
 * the top of lib/programs.ts.
 */
export function useFollowedPrograms() {
  const [state, setState] = useState(loadFollowState);

  const update = useCallback((following: string[], active: string) => {
    const next = { following, active };
    saveFollowState(next);
    setState(next);
  }, []);

  const follow = useCallback(
    (slug: string) => {
      if (state.following.includes(slug)) return;
      const following = [...state.following, slug];
      update(following, state.active || slug);
    },
    [state, update],
  );

  const unfollow = useCallback(
    (slug: string) => {
      // The core program is what the app is for; it cannot be dropped.
      if (slug === CORE_PROGRAM_SLUG) return;
      const following = state.following.filter((s) => s !== slug);
      const active = state.active === slug ? (following[0] ?? "") : state.active;
      update(following, active);
    },
    [state, update],
  );

  const setActive = useCallback(
    (slug: string) => update(state.following, slug),
    [state, update],
  );

  return {
    following: state.following,
    active: state.active,
    isFollowing: (slug: string) => state.following.includes(slug),
    follow,
    unfollow,
    setActive,
  };
}
