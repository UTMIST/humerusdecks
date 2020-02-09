import * as Actions from "./../actions";
import * as Like from "./player/like";
import * as Submit from "./player/submit";
import * as TakeBack from "./player/take-back";

/**
 * An action only the czar can perform.
 */
export type Player = Submit.Submit | TakeBack.TakeBack | Like.Like;

export const actions = new Actions.PassThroughGroup(
  Submit.actions,
  TakeBack.actions,
  Like.actions
);
