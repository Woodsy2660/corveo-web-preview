/**
 * React Query hooks over the CorveoApi contract. Screens consume these,
 * never the api object directly, so caching and invalidation stay in one
 * place.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { getApi } from "./index";
import type { ConsentEventInput, IngestPayload, ProgramProgressRow } from "./types";

export const queryKeys = {
  readings: ["readings"] as const,
  trend: ["trend"] as const,
  consent: ["consent"] as const,
  progress: ["progress"] as const,
};

export function useReadings(limit = 50) {
  return useQuery({
    queryKey: [...queryKeys.readings, limit],
    queryFn: () => getApi().listReadings({ limit }),
  });
}

export function useTrend(sinceDay?: string) {
  return useQuery({
    queryKey: [...queryKeys.trend, sinceDay ?? "all"],
    queryFn: () => getApi().getTrend(sinceDay ? { sinceDay } : undefined),
  });
}

export function useConsentStatus() {
  return useQuery({
    queryKey: queryKeys.consent,
    queryFn: () => getApi().getConsentStatus(),
  });
}

export function useProgramProgress() {
  return useQuery({
    queryKey: queryKeys.progress,
    queryFn: () => getApi().getProgramProgress(),
  });
}

export function useRecordConsent() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (input: ConsentEventInput) => getApi().recordConsentEvent(input),
    onSuccess: () => qc.invalidateQueries({ queryKey: queryKeys.consent }),
  });
}

export function useIngestObservations() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (payload: IngestPayload) => getApi().ingestObservations(payload),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: queryKeys.readings });
      qc.invalidateQueries({ queryKey: queryKeys.trend });
    },
  });
}

export function useUpdateProgress() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (patch: Partial<ProgramProgressRow>) =>
      getApi().updateProgramProgress(patch),
    onSuccess: () => qc.invalidateQueries({ queryKey: queryKeys.progress }),
  });
}
