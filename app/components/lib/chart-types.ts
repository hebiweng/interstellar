export type ResultTab = "basic" | "signs" | "houses" | "aspects" | "structure" | "classical" | "technical";
export type CalculationTab = "features" | "planets" | "houses" | "firdaria" | "profections" | "lots" | "stars" | "fortune_zr" | "spirit_zr" | "mirrors" | "degrees" | "rays" | "midpoints";
export type CurrentSkyResultTab = "features" | "planets" | "houses" | "lots" | "stars" | "mirrors" | "degrees" | "rays" | "midpoints" | "aspects" | "events";
export type TransitResultTab = "overview" | "features" | "planets" | "houses" | "lots" | "stars" | "mirrors" | "degrees" | "rays" | "midpoints" | "aspects" | "cross_aspects" | "reference_houses";
export type SecondaryResultTab = "overview" | "features" | "planets" | "houses" | "lots" | "stars" | "mirrors" | "degrees" | "rays" | "midpoints" | "aspects" | "cross_aspects" | "reference_houses";
export type ChartView = "professional" | "compact" | "aspect_grid";
export type ThemeMode = "dark" | "light";
export type EntryPointId = "technique" | "topic" | "intent" | "object" | "personal" | "context";
export type TechniqueId = "natal" | "transits" | "current_sky" | "secondary_progressions" | "tertiary_progressions" | "solar_return" | "lunar_return" | "solar_arc" | "firdaria" | "annual_profections" | "relocation" | "dragon_head" | "dodecatemoria" | "tridecatemoria";
export type InterpretationTarget = {
  type: "point" | "house" | "aspect" | "structure" | "classical";
  id: string;
  title: string;
  fact: string;
  facts?: string[];
  resultPath?: string;
};
