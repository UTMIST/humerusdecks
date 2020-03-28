import uuid from "uuid";
import { Response } from "./card";

/** A series of cards played into a round.*/
export type Play = Response[];

/**
 * A unique id for a play.
 * @TJS-format uuid
 */
export type Id = string;

/**
 * An id or id with play.
 */
export interface PotentiallyRevealed {
  id: Id;
  play?: Play;
}

/**
 * A play with its id.
 */
export type Revealed = PotentiallyRevealed & { play: Play; likes?: number };

/**
 * Create a new user id.
 */
export const id: () => Id = uuid.v4;
