import { Navigate, Outlet, Route, Routes } from "react-router";
import { TabBar } from "@/components/ui/TabBar";
import { useJourney } from "@/lib/journey/state";
import { Welcome } from "@/screens/journey/Onboarding/Welcome";
import { Signup } from "@/screens/journey/Signup/Signup";
import { Consent } from "@/screens/journey/Consent/Consent";
import { Connect } from "@/screens/journey/HealthKitAuth/Connect";
import { HealthAuth } from "@/screens/journey/HealthKitAuth/HealthAuth";
import { FirstCapture } from "@/screens/journey/FirstCapture/FirstCapture";
import { Result } from "@/screens/journey/FirstCapture/Result";
import { Cadence } from "@/screens/journey/FirstCapture/Cadence";
import { Readings } from "@/screens/tabs/Readings/Readings";
import { ManualEntry } from "@/screens/tabs/Readings/ManualEntry";
import { Trend } from "@/screens/tabs/Trend/Trend";
import { Program } from "@/screens/tabs/Program/Program";
import { Settings } from "@/screens/settings/Settings";
import { ValidatedCuffs } from "@/screens/settings/ValidatedCuffs";
import { BrandLab } from "@/screens/lab/BrandLab";

/** /app/* requires a completed journey; /journey/* bounces back once done. */
function RequireJourneyComplete() {
  const { journeyComplete } = useJourney();
  return journeyComplete ? <Outlet /> : <Navigate to="/journey/welcome" replace />;
}

function JourneyOnly() {
  const { journeyComplete } = useJourney();
  return journeyComplete ? <Navigate to="/app/readings" replace /> : <Outlet />;
}

function TabsLayout() {
  return (
    <>
      <Outlet />
      <TabBar />
    </>
  );
}

export function App() {
  const { journeyComplete } = useJourney();

  return (
    <Routes>
      <Route
        path="/"
        element={<Navigate to={journeyComplete ? "/app/readings" : "/journey/welcome"} replace />}
      />

      <Route element={<JourneyOnly />}>
        <Route path="/journey/welcome" element={<Welcome />} />
        <Route path="/journey/signup" element={<Signup />} />
        <Route path="/journey/consent" element={<Consent />} />
        <Route path="/journey/connect" element={<Connect />} />
        <Route path="/journey/health-auth" element={<HealthAuth />} />
        <Route path="/journey/capture" element={<FirstCapture />} />
        <Route path="/journey/result" element={<Result />} />
        <Route path="/journey/cadence" element={<Cadence />} />
      </Route>

      <Route element={<RequireJourneyComplete />}>
        <Route element={<TabsLayout />}>
          <Route path="/app/readings" element={<Readings />} />
          <Route path="/app/trend" element={<Trend />} />
          <Route path="/app/program" element={<Program />} />
        </Route>
        <Route path="/app/add" element={<ManualEntry />} />
        <Route path="/app/settings" element={<Settings />} />
        <Route path="/app/cuffs" element={<ValidatedCuffs />} />
      </Route>

      {/* Internal design exploration — unlinked; remove before submission. */}
      <Route path="/lab" element={<BrandLab />} />

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
