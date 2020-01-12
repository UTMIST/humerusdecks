import * as user from "../../user";

/**
 * An event for when connection state for a user changes.
 */
export type PlayerPresenceChanged = Away | Back;

interface Base {
  player: user.Id;
}

/**
 * A user temporarily leaves the game.
 */
export interface Away extends Base {
  event: "Away";
}

export const away = (id: user.Id): Away => ({
  event: "Away",
  player: id
});

/**
 * A user returns from being away.
 */
export interface Back extends Base {
  event: "Back";
}

export const back = (id: user.Id): Back => ({
  event: "Back",
  player: id
});
