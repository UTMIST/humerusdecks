import * as Source from "../games/cards/source";
import * as Rules from "../games/rules";

/**
 * Configuration for a lobby.
 */
export interface Config {
  version: Version;
  rules: Rules.Rules;
  public: boolean;
  password?: string;
  decks: ConfiguredSource[];
}

export type Version = number;

export interface Public {
  version: string;
  rules: Rules.Public;
  public?: boolean;
  password?: string;
  decks: ConfiguredSource[];
}

/**
 * A deck source in the configuration.
 */
export type ConfiguredSource = SummarisedSource | FailedSource;

/**
 * A deck source that is loading or has loaded.
 */
export interface SummarisedSource {
  source: Source.External;
  summary?: Source.Summary;
}

/**
 * The reason a deck could not be loaded.
 */
export type FailReason = "SourceFailure" | "NotFound";

/**
 * A deck source that has failed to load.
 */
export interface FailedSource {
  source: Source.External;
  failure: FailReason;
}

export const isFailed = (source: ConfiguredSource): source is FailedSource =>
  source.hasOwnProperty("failure");

export const censor = (config: Config): Public => ({
  version: config.version.toString(),
  rules: Rules.censor(config.rules),
  decks: config.decks,
  ...(config.public ? { public: true } : {}),
  ...(config.password !== undefined ? { password: config.password } : {})
});
