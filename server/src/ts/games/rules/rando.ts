import { RegisterUser } from "../../action/initial/register-user";
import * as Event from "../../event";
import * as PresenceChanged from "../../events/lobby-event/presence-changed";
import * as Lobby from "../../lobby";
import * as User from "../../user";
import * as Util from "../../util";

/**
 * The maximum number of AI players allowed in a single game.
 */
const max = 10;

/**
 * The default name for an AI.
 */
export const aiName = "Rando Cardrissian";

/**
 * Apart from the one inherited from Cards against Humanity (a reference to
 *  Star Wars), we use some references to famous AIs and computers from films
 *  and games.
 */
export const aiNames = new Set([
  "HAL 9000", // 2001: A Space Odyssey
  "GLaDOS", // Portal
  "Wheatley", // Portal
  "TEC-XX", // Paper Mario
  "EDI", // Mass Effect
  "343 Guilty Spark", // Halo
  "Cortana", // Halo
  "J.A.R.V.I.S.", // MCU
  "Deep Thought", // HHGTTG
  "Gibson", // Hackers
  "Skynet", // Terminator
  "Project 2501", // GITS
  "SHODAN", // System Shock
  "Mr. House" // Fallout: New Vegas
]);

/**
 * The internal model of the Rando house rule.
 */
export interface Rando {
  /**
   * The ids of active AI players in the game.
   */
  current: User.Id[];
  /**
   * The names or ids of potential AI players that are not currently active in
   * the game.
   */
  unused: (User.Id | RegisterUser)[];
}

/**
 * Create the initial model.
 */
export const create = (): Rando => ({
  current: [],
  unused: [aiName]
    .concat(Util.shuffled(aiNames).slice(0, max - 1))
    .map(name => ({ name }))
});

/**
 * The public view of the Rando house rule.
 */
export interface Public {
  /**
   * The number of AI players to add to the game.
   * @TJS-type integer
   * @minimum 1
   * @maximum 10
   */
  number: number;
}

/**
 * Get the public view of the given internal model.
 */
export const censor = (rando: Rando): Public | undefined =>
  rando.current.length > 0 ? { number: rando.current.length } : undefined;

const isId = (ai: User.Id | RegisterUser): ai is User.Id =>
  typeof ai === "string";

export const createIfNeeded = (
  inLobby: Lobby.Lobby,
  ai: User.Id | RegisterUser
): { user: User.Id; events: Iterable<Event.Distributor> } => {
  if (isId(ai)) {
    return {
      user: ai,
      events: [Event.targetAll(PresenceChanged.joined(ai, inLobby.users[ai]))]
    };
  } else {
    return Lobby.addUser(inLobby, ai, user => ({
      ...user,
      control: "Computer"
    }));
  }
};

/**
 * Change the internal model to match the given public representation.
 */
export function* change(
  inLobby: Lobby.Lobby,
  config: Rando,
  changeTo?: Public
): Iterable<Event.Distributor> {
  const want = changeTo !== undefined ? changeTo.number : 0;
  const have = config.current.length;
  const eventsCollection = [];
  if (want === have) {
    return null;
  }
  if (want > have) {
    const toAdd = want - have;
    const added = config.unused
      .splice(0, toAdd)
      .map(ai => createIfNeeded(inLobby, ai));
    for (const { user, events } of added) {
      const userData = inLobby.users[user];
      userData.presence = "Joined";
      config.current.push(user);
      eventsCollection.push(...events);
    }
  } else if (have > want) {
    const toRemove = have - want;
    const removed = config.current.splice(
      config.current.length - toRemove,
      toRemove
    );
    for (const ai of removed) {
      const user = inLobby.users[ai];
      user.presence = "Left";
      eventsCollection.push(Event.targetAll(PresenceChanged.left(ai, "Left")));
    }
    config.unused.splice(0, 0, ...removed);
  }
  yield* eventsCollection;
}
