//import wu, { reject } from "wu";
import wu from "wu";
import { InvalidActionError } from "../errors/validation";
import * as Event from "../event";
import * as GameStarted from "../events/game-event/game-started";
import * as PauseStateChanged from "../events/game-event/pause-state-changed";
import * as PlaySubmitted from "../events/game-event/play-submitted";
import * as RoundStarted from "../events/game-event/round-started";
import { Lobby } from "../lobby";
import { ServerState } from "../server-state";
import * as Timeout from "../timeout";
import * as FinishedPlaying from "../timeout/finished-playing";
import * as RoundStageTimerDone from "../timeout/round-stage-timer-done";
import * as User from "../user";
import * as Util from "../util";
import * as Card from "./cards/card";
import * as Decks from "./cards/decks";
import * as Play from "./cards/play";
//import { Resolver } from "./cards/sources/many-decks";
import * as Round from "./game/round";
import * as PublicRound from "./game/round/public";
import * as Player from "./player";
import * as Rules from "./rules";
import fetch from "node-fetch";
//import fetch from "node-fetch";
// eslint-disable-next-line prettier/prettier
//import { XMLHttpRequest } from 'xmlhttprequest-ts';

export interface Public {
  round: PublicRound.Public;
  history: PublicRound.Complete[];
  playerOrder: User.Id[];
  players: { [id: string]: Player.Public };
  rules: Rules.Public;
  winner?: string[];
  paused?: boolean;
}

/**
 * The state of a game.
 */
export class Game {
  public round: Round.Round;
  public readonly history: PublicRound.Complete[];
  public readonly playerOrder: User.Id[];
  public readonly players: { [id: string]: Player.Player };
  public readonly decks: Decks.Decks;
  public readonly rules: Rules.Rules;
  public winner?: User.Id[];
  public paused: boolean;

  private constructor(
    round: Round.Round,
    playerOrder: User.Id[],
    players: { [id: string]: Player.Player },
    decks: Decks.Decks,
    rules: Rules.Rules,
    paused = false,
    history: PublicRound.Complete[] | undefined = undefined,
    winner: User.Id[] | undefined = undefined
  ) {
    this.round = round;
    this.history = history === undefined ? [] : history;
    this.playerOrder = playerOrder;
    this.players = players;
    this.decks = decks;
    this.rules = rules;
    this.paused = paused;
    this.winner = winner;
  }

  // eslint-disable-next-line @typescript-eslint/ban-types
  public toJSON(): object {
    return {
      round: this.round,
      playerOrder: this.playerOrder,
      players: this.players,
      decks: this.decks,
      rules: this.rules,
      paused: this.paused,
      history: this.history,
      winner: this.winner,
    };
  }

  public static fromJSON = (game: Game): Game =>
    new Game(
      Round.fromJSON(game.round),
      game.playerOrder,
      game.players,
      {
        responses: Decks.Responses.fromJSON(game.decks.responses),
        calls: Decks.Calls.fromJSON(game.decks.calls),
      },
      game.rules,
      game.paused,
      game.history,
      game.winner
    );

  private static activePlayer(
    user: User.User,
    player?: Player.Player
  ): boolean {
    return (
      user.presence === "Joined" &&
      user.role === "Player" &&
      player !== undefined &&
      player.presence === "Active"
    );
  }

  private static canBeCzar(user: User.User, player?: Player.Player): boolean {
    return user.control !== "Computer" && Game.activePlayer(user, player);
  }

  public nextCzar(users: { [id: string]: User.User }): User.Id | undefined {
    const current = this.round.czar;
    const playerOrder = this.playerOrder;
    const currentIndex = playerOrder.findIndex((id) => id === current);
    return Game.internalNextCzar(
      currentIndex,
      users,
      this.players,
      playerOrder
    );
  }

  public static internalNextCzar(
    currentIndex: number,
    users: { [id: string]: User.User },
    players: { [id: string]: Player.Player },
    playerOrder: User.Id[]
  ): User.Id | undefined {
    let nextIndex = currentIndex;
    function incrementIndex(): void {
      nextIndex += 1;
      nextIndex = nextIndex >= playerOrder.length ? 0 : nextIndex;
    }

    let triedEveryone = false;
    incrementIndex();
    while (!triedEveryone) {
      if (nextIndex === currentIndex) {
        triedEveryone = true;
      }
      const potentialCzar = playerOrder[nextIndex];
      if (Game.canBeCzar(users[potentialCzar], players[potentialCzar])) {
        return potentialCzar;
      }
      incrementIndex();
    }
    return undefined;
  }

  public static start(
    templates: Iterable<Decks.Templates>,
    users: { [id: string]: User.User },
    rules: Rules.Rules
  ): Game & { round: Round.Playing } {
    let allTemplates: Iterable<Decks.Templates>;
    const cw = rules.houseRules.comedyWriter;
    if (cw !== undefined) {
      const blanks: Decks.Templates = {
        calls: new Set(),
        responses: new Set(
          wu.repeat({}, cw.number).map(() => ({
            id: Card.id(),
            source: { source: "Custom" },
            text: "",
          }))
        ),
      };
      allTemplates = [
        ...(cw.exclusive
          ? wu(templates).map((t) => ({
              calls: t.calls,
              responses: new Set<Card.Response>(),
            }))
          : templates),
        blanks,
      ];
    } else {
      allTemplates = templates;
    }
    const gameDecks = Decks.decks(allTemplates);
    const playerOrder = wu(Object.entries(users))
      .map(([id, _]) => id)
      .toArray();
    const playerMap = Object.fromEntries(
      wu(Object.entries(users))
        .filter(([_, user]) => user.role === "Player")
        .map(([id, _]) => [
          id,
          Player.initial(gameDecks.responses.draw(rules.handSize)),
        ])
    );
    const czar = Game.internalNextCzar(0, users, playerMap, playerOrder);
    if (czar === undefined) {
      throw new Error(
        "Game was allowed to start with too few players to have a czar."
      );
    }
    const [call] = gameDecks.calls.draw(1);
    const playersInRound = new Set(
      wu(playerOrder).filter((id) =>
        Game.isPlayerInRound(czar, playerMap, id, users[id])
      )
    );
    return new Game(
      new Round.Playing(0, czar, playersInRound, call),
      playerOrder,
      playerMap,
      gameDecks,
      rules
    ) as Game & { round: Round.Playing };
  }

  public public(): Public {
    return {
      round: this.round.public(),
      history: this.history,
      playerOrder: this.playerOrder,
      players: Util.mapObjectValues(this.players, (p: Player.Player) =>
        Player.censor(p)
      ),
      rules: Rules.censor(this.rules),
      ...(this.winner === undefined ? {} : { winner: this.winner }),
      ...(this.paused ? { paused: true } : {}),
    };
  }

  /**
   * Forcibly start a new round, regardless of the current state.
   * @param server the server context this game is in.
   * @param lobby the lobby this game is in.
   */
  public startNewRound(
    server: ServerState,
    lobby: Lobby
  ): {
    events?: Iterable<Event.Distributor>;
    timeouts?: Iterable<Timeout.After>;
  } {
    const czar = this.nextCzar(lobby.users);
    const events = [];
    if (czar === undefined) {
      if (!this.paused) {
        this.paused = true;
        return { events: [Event.targetAll(PauseStateChanged.paused)] };
      } else {
        return {};
      }
    } else if (this.paused) {
      this.paused = false;
      events.push(Event.targetAll(PauseStateChanged.continued));
    }
    const [call] = this.decks.calls.replace(this.round.call);
    const roundId = this.round.id + 1;
    const playersInRound = new Set(
      wu(this.playerOrder).filter((id) =>
        Game.isPlayerInRound(czar, this.players, id, lobby.users[id])
      )
    );
    this.decks.responses.discard(
      (this.round as Round.Base<Round.Stage>).plays.flatMap((play) => play.play)
    );
    this.round = new Round.Playing(roundId, czar, playersInRound, call);
    const updatedGame = this as Game & { round: Round.Playing };
    const atStart = Game.atStartOfRound(server, false, updatedGame);
    return {
      events: [
        ...events,
        ...(atStart.events !== undefined ? atStart.events : []),
      ],
      timeouts: atStart.timeouts,
    };
  }

  /**
   * Remove the player from the round if we are waiting on them.
   * @param toRemove The id of the player.
   * @param server The server context.
   */
  public removeFromRound(
    toRemove: User.Id,
    server: ServerState
  ): { timeouts?: Iterable<Timeout.After> } {
    const player = this.players[toRemove];
    if (player !== undefined) {
      const play = this.round.plays.find((p) => p.playedBy === toRemove);
      if (play === undefined) {
        this.round.players.delete(toRemove);
        if (this.round.stage === "Playing") {
          return {
            timeouts: Util.asOptionalIterable(
              FinishedPlaying.ifNeeded(this.rules, this.round)
            ),
          };
        }
      }
      return {};
    } else {
      throw new InvalidActionError("User must be a player.");
    }
  }

  private static isPlayerInRound(
    czar: User.Id,
    players: { [id: string]: Player.Player },
    playerId: User.Id,
    user: User.User
  ): boolean {
    if (playerId === czar || user.role !== "Player") {
      return false;
    }
    const player = players[playerId];
    return Game.activePlayer(user, player);
  }

  static atStartOfRound(
    server: ServerState,
    first: boolean,
    game: Game & { round: Round.Playing }
  ): {
    game: Game & { round: Round.Playing };
    events?: Iterable<Event.Distributor>;
    timeouts?: Iterable<Timeout.After>;
  } {
    const slotCount = Card.slotCount(game.round.call);

    const events = [];
    if (
      slotCount > 2 ||
      (slotCount === 2 && game.rules.houseRules.packingHeat !== undefined)
    ) {
      const responseDeck = game.decks.responses;
      const drawnByPlayer = new Map();
      for (const [id, playerState] of Object.entries(game.players)) {
        if (Player.role(id, game) === "Player") {
          const drawn = responseDeck.draw(slotCount - 1);
          drawnByPlayer.set(id, { drawn });
          playerState.hand.push(...drawn);
        }
      }
      if (!first) {
        events.push(
          Event.additionally(RoundStarted.of(game.round), drawnByPlayer)
        );
      }
    } else {
      if (!first) {
        events.push(Event.targetAll(RoundStarted.of(game.round)));
      }
    }

    if (first) {
      events.push(
        Event.playerSpecificAddition(
          GameStarted.of(game.round),
          (id, user, player) => ({
            hand: player.hand,
          })
        )
      );
    }

    const ais = game.rules.houseRules.rando.current;
    for (const ai of ais) {
      const player = game.players[ai] as Player.Player;
      const plays = game.round.plays;
      const playId = Play.id();

      const flatCall = game.round.call["parts"].flat();
      let potentialPlay = [];
      const potentialPlays: string[] = [];
      const tempCall = flatCall;
      let sentence;
      let slotIndex = 0;
      let slotIndeces = [];

      // Iterate through every card in the player's hand and
      // store all potential plays in an array in sentence form
      for (const card in player.hand) {
        if (player.hand.hasOwnProperty(card)) {
          if (slotCount == 1) {
            // Reset potentialPlay
            potentialPlay = [];

            // Push card onto potentialPlay
            potentialPlay.push(
              player.hand[card]["text"].slice(
                0,
                player.hand[card]["text"].length
              )
            );

            // Insert card into call card slot
            for (let i = 0; i < tempCall.length; i++) {
              if (
                typeof tempCall[i] == "object" &&
                !tempCall[i].hasOwnProperty("text")
              ) {
                tempCall[i] = potentialPlay[0];
                slotIndex = i;
              }
            }

            // Flatten tempCall into sentence and remove any quote characters
            sentence = tempCall.join("").replace(/['"]+/g, "");

            // Push sentence into potentialPlays
            potentialPlays.push(sentence);

            // Reset tempCall
            tempCall[slotIndex] = {};
          } else if (slotCount == 2) {
            for (const nextCard in player.hand) {
              if (player.hand.hasOwnProperty(nextCard) && card != nextCard) {
                // Reset arrays
                potentialPlay = [];
                slotIndeces = [];

                // Push cards onto potentialPlay
                potentialPlay.push(
                  player.hand[card]["text"].slice(
                    0,
                    player.hand[card]["text"].length
                  )
                );
                potentialPlay.push(
                  player.hand[nextCard]["text"].slice(
                    0,
                    player.hand[nextCard]["text"].length
                  )
                );

                // Identify index of every slot in call card
                for (let i = 0; i < tempCall.length; i++) {
                  if (
                    typeof tempCall[i] == "object" &&
                    !tempCall[i].hasOwnProperty("text")
                  ) {
                    slotIndeces.push(i);
                  }
                }

                // Insert cards into tempCall slots
                for (let i = 0; i < slotIndeces.length; i++) {
                  tempCall[slotIndeces[i]] = potentialPlay[i];
                }

                // Flatten tempCall into sentence and remove any quote characters
                sentence = tempCall.join("").replace(/['"]+/g, "");

                // Push sentence into potentialPlays
                potentialPlays.push(sentence);

                // Reset tempCall
                for (let i = 0; i < slotIndeces.length; i++) {
                  tempCall[slotIndeces[i]] = {};
                }
              }
            }
          }
        }
      }

      console.log("POTENTIAL PLAYS _____________________________");
      console.log(potentialPlays);

      /* Console log for debugging purposes
      console.log("______________________________________");
      console.log("Call: ");
      console.log(game.round.call["parts"]);
      console.log("Flat Call:");
      console.log(flatCall);
      console.log("Player hand: ");
      console.log(player.hand);
      console.log("Potential plays: ");
      console.log(JSON.stringify(potentialPlays));
      console.log("______________________________________");*/

      //const formData = { plays: ["string1", "string2"] };
      const key = "plays";
      const value = JSON.stringify(potentialPlays);
      const formString = '{"' + key + '":' + value + "}";
      const formData = JSON.parse(formString);
      /*const formBody = [];
      const encodedKey = encodeURIComponent("text");
      const encodedValue = encodeURIComponent(JSON.stringify(potentialPlays));
      formBody.push(encodedKey + "=" + encodedValue);
      const form = formBody.join("&");
*/
      let responseJson;

      // eslint-disable-next-line @typescript-eslint/explicit-function-return-type
      async function getResponse(formData: string) {
        const response = await fetch("http://44.230.29.224/", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: formData,
        });
        console.log(response.status);
        const resJson = await response.json();
        responseJson = resJson;
        return resJson;
      }

      // eslint-disable-next-line @typescript-eslint/explicit-function-return-type
      async function result(formData: string) {
        const json = await getResponse(formData);
        responseJson = json; // this will get set and work however this will not happen before line 35 gets executed
        console.log("a", json); // this will work
        console.log("b", responseJson); // and so will this

        pickCard(responseJson);
      }

      // eslint-disable-next-line @typescript-eslint/explicit-function-return-type
      async function playCard() {
        const play = player.hand.slice(0, slotCount) as Card.Response[];

        plays.push({
          id: playId,
          play: play,
          playedBy: ai,
          revealed: false,
          likes: [],
        });
        events.push(Event.targetAll(PlaySubmitted.of(ai)));
      }

      // eslint-disable-next-line @typescript-eslint/explicit-function-return-type
      async function pickCard(responseJson: unknown) {
        const stringData = JSON.stringify(responseJson);
        const parse = JSON.parse(stringData);
        console.log(parse);

        let maxValue = 0;

        // Find the max score from API response data
        // eslint-disable-next-line guard-for-in
        for (const x in parse) {
          console.log(x);
          if (Number(parse[x]) > Number(maxValue)) {
            maxValue = parse[x];
          }
        }

        console.log("Max Score: " + Number(maxValue));

        // Get the top play from the API response data
        const topPlay = String(getKeyByValue(parse, maxValue));
        console.log("Top Play: " + topPlay);

        // Iterate through player's hand and identify the top plays
        // and store their indeces in an array, indecesOfTopPlays
        const indecesOfTopPlays = [];
        for (const card in player.hand) {
          if (player.hand.hasOwnProperty(card)) {
            const potentialPlay = player.hand[card]["text"]
              .slice(0, player.hand[card]["text"].length)
              .replace(/['"]+/g, "");
            const indexOfTopPlay = topPlay.indexOf(potentialPlay);
            if (indexOfTopPlay > -1) {
              console.log(potentialPlay + " is located at " + indexOfTopPlay);
              // store the potential play
              indecesOfTopPlays.push([indexOfTopPlay, Number(card)]);
            }
          }
        }

        // Sort top play indeces by order in which they will be played
        indecesOfTopPlays.sort(sortByPlay);

        // Copy top plays to new array
        const topPlays = [];
        for (let i = 0; i < indecesOfTopPlays.length; i++) {
          topPlays.push(player.hand[indecesOfTopPlays[i][1]]);
        }

        console.log("TOP PLAYS: ");
        console.log(topPlays);

        // If there is a top play in the player's hand, proceed to play it
        if (topPlays.length > 0) {
          console.log("Playing top play");
          // Delete top plays from player hand
          indecesOfTopPlays.sort(sortByDeletion);
          for (let i = 0; i < indecesOfTopPlays.length; i++) {
            player.hand.splice(indecesOfTopPlays[i][1], 1);
          }

          // Append top plays to beginning of player hand
          player.hand.splice(0, 0, ...topPlays);
          // Delete top plays from player hand
          indecesOfTopPlays.sort(sortByDeletion);
          for (let i = 0; i < indecesOfTopPlays.length; i++) {
            player.hand.splice(indecesOfTopPlays[i][1], 1);
          }

          // Append top plays to beginning of player hand
          player.hand.splice(0, 0, ...topPlays);
        } else {
          console.log("Playing random card");
        }

        console.log("FINAL PLAYER HAND: ");
        console.log(player.hand);

        // Play card
        playCard();
      }

      result(JSON.stringify(formData));
      /*
      // Play random card
      const play = player.hand.slice(0, slotCount) as Card.Response[];

      plays.push({
        id: playId,
        play: play,
        playedBy: ai,
        revealed: false,
        likes: [],
      });
      events.push(Event.targetAll(PlaySubmitted.of(ai)));
      */
    }

    const timeouts = [];
    const finishedTimeout = FinishedPlaying.ifNeeded(game.rules, game.round);
    if (finishedTimeout !== undefined) {
      timeouts.push(finishedTimeout);
    }

    const timer = RoundStageTimerDone.ifEnabled(game.round, game.rules.stages);
    if (timer !== undefined) {
      timeouts.push(timer);
    }

    return { game, events, timeouts };
  }
}

// DEFINE FUNCTIONS
// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
function getKeyByValue(object: { [x: string]: unknown }, value: unknown) {
  return Object.keys(object).find((key) => object[key] === value);
}

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
function sortByPlay(a: (string | number)[], b: (string | number)[]) {
  if (a[0] === b[0]) {
    return 0;
  } else {
    return a[0] < b[0] ? -1 : 1;
  }
}

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
function sortByDeletion(a: (string | number)[], b: (string | number)[]) {
  if (a[1] === b[1]) {
    return 0;
  } else {
    return a[1] > b[1] ? -1 : 1;
  }
}
