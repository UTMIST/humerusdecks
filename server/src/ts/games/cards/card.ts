import { v4 as uuid } from "uuid";
import { Source } from "./source";
import wu = require("wu");

/**
 * A game card.
 */
export type Card = Call | Response;

/**
 * A call for plays. Some text with blank slots to be filled with responses.
 */
export interface Call extends BaseCard {
  /** The text and slots on the call.*/
  parts: Part[][];
}

/**
 * A response (some text) played into slots.
 */
export interface Response extends BaseCard {
  /** The text on the response.*/
  text: string;
}

/** A unique id for an instance of a card.*/
export type Id = string;

/** Values shared by all cards.*/
export interface BaseCard {
  /** A unique id for a card.*/
  id: Id;
  /** Where the card came from.*/
  source: Source;
}

/** An empty slot for responses to be played into.*/
export interface Slot {
  /**
   * Defines a transformation over the content the slot is filled with.
   */
  transform?: "UpperCase" | "Capitalize";
}

export const isSlot = (part: Part): part is Slot => typeof part !== "string";

/** Either text or a slot.*/
export type Part = string | Slot;

/**
 * Create a new user id.
 */
export const id: () => Id = uuid;

/**
 * If the given card is a call.
 */
export const isCall = (card: Card): card is Call =>
  (card as Call).parts !== undefined;

/**
 * If the given card is a response.
 */
export const isResponse = (card: Card): card is Response =>
  (card as Response).text !== undefined;

/**
 * The number of slots the given call.
 */
export const slotCount = (call: Call): number =>
  wu(call.parts)
    .flatten(true)
    .reduce((count, part) => count + (isSlot(part) ? 1 : 0), 0);
