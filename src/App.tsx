import { Navigate, Outlet, Route, Routes } from "react-router";
import { TabBar } from "@/components/ui/TabBar";
import { useJourney } from "@/lib/journey/state";
import { Welcome } from "@/screens/journey/Onboarding/Welcome";
import { Intro } from "@/screens/journey/Onboarding/Intro";
import { Signup } from "@/screens/journey/Signup/Signup";
import { Consent } from "@/screens/journey/Consent/Consent";
import { Connect } from "@/screens/journey/HealthKitAuth/Connect";
import { HealthAuth } from "@/screens/journey/HealthKitAuth/HealthAuth";
import { FirstCapture } from "@/screens/journey/FirstCapture/FirstCapture";
import { Result } from "@/screens/journey/FirstCapture/Result";
import { Cadence } from "@/screens/journey/FirstCapture/Cadence";
import { Record } from "@/screens/tabs/Record/Record";
import { ManualEntry } from "@/screens/tabs/Record/ManualEntry";
import { Program } from "@/screens/tabs/Program/Program";
import { Education } from "@/screens/tabs/Education/Education";
import { PulseViewer } from "@/screens/tabs/Education/PulseViewer";
import { InFocusArticle } from "@/screens/tabs/Education/InFocusArticle";
import { Chapter } from "@/screens/tabs/Program/Chapter";
import { ProgramBrowse } from "@/screens/tabs/Program/ProgramIndex";
import { ProgramDetail } from "@/screens/tabs/Program/ProgramDetail";
import { Settings } from "@/screens/settings/Settings";
import { About } from "@/screens/settings/About";
import { YourData } from "@/screens/settings/YourData";
import { ValidatedCuffs } from "@/screens/settings/ValidatedCuffs";
import { BehindTheScenes } from "@/screens/behind/BehindTheScenes";

/** /app/* requires a completed journey; /journey/* bounces back once done. */
function RequireJourneyComplete() {
  const { journeyComplete } = useJourney();
  return journeyComplete ? <Outlet /> : <Navigate to="/journey/welcome" replace />;
}

function JourneyOnly() {
  const { journeyComplete } = useJourney();
  return journeyComplete ? <Navigate to="/app/record" replace /> : <Outlet />;
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
        element={<Navigate to={journeyComplete ? "/app/record" : "/journey/welcome"} replace />}
      />

      <Route element={<JourneyOnly />}>
        <Route path="/journey/welcome" element={<Welcome />} />
        <Route path="/journey/intro" element={<Intro />} />
        <Route path="/journey/signup" element={<Signup />} />
        <Route path="/journey/consent" element={<Consent />} />
        <Route path="/journey/connect" element={<Connect />} />
        <Route path="/journey/health-auth" element={<HealthAuth />} />
        <Route path="/journey/capture" element={<FirstCapture />} />
        <Route path="/journey/result" element={<Result />} />
        <Route path="/journey/cadence" element={<Cadence />} />
      </Route>

      <Route element={<RequireJourneyComplete />}>
        {/* Everything a tab leads to keeps the bar, with that tab lit: a
            chapter, an article, the library are places, never dead ends. */}
        <Route element={<TabsLayout />}>
          <Route path="/app/record" element={<Record />} />
          <Route path="/app/program" element={<Program />} />
          <Route path="/app/program/browse" element={<ProgramBrowse />} />
          <Route path="/app/program/:slug" element={<ProgramDetail />} />
          <Route path="/app/program/:slug/:week" element={<Chapter />} />
          <Route path="/app/education" element={<Education />} />
          <Route path="/app/education/in-focus/:slug" element={<InFocusArticle />} />
        </Route>
        {/* Tasks and overlays, not places: these close rather than go back. */}
        <Route path="/app/education/pulse/:slug" element={<PulseViewer />} />
        <Route path="/app/add" element={<ManualEntry />} />
        <Route path="/app/settings" element={<Settings />} />
        <Route path="/app/settings/about" element={<About />} />
        <Route path="/app/settings/data" element={<YourData />} />
        <Route path="/app/cuffs" element={<ValidatedCuffs />} />
        {/* Readings and Trend merged into Record; the shared web preview is
            bookmarked, so the old paths keep working. */}
        <Route path="/app/readings" element={<Navigate to="/app/record" replace />} />
        <Route path="/app/trend" element={<Navigate to="/app/record" replace />} />
      </Route>

      {/* Presentation surface, outside the journey guards: it explains the
          machinery rather than being part of the product flow. */}
      <Route path="/behind" element={<BehindTheScenes />} />

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
