import * as Play from "../../games/cards/play";

/**
 * Indicates the czar has finished revealing the plays and is now picking a winner.
 */
export interface StartJudging {
  event: "StartJudging";
  /**
   * The plays that are to be judged. If the revealing stage was played, this won't be included as the data will have
   * been sent as a part of that phase.
   */
  plays?: Play.Revealed[];
}

export const of = (plays?: Play.Revealed[]): StartJudging => ({
  event: "StartJudging",
  plays,
});
