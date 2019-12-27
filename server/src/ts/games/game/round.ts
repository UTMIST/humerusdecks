import wu from "wu";
import { Action } from "../../action";
import { IncorrectRoundStageError } from "../../errors/action-execution-error";
import * as user from "../../user";
import * as card from "../cards/card";
import * as play from "../cards/play";
import { Play } from "../cards/play";
import * as publicRound from "./round/public";
import { Public as PublicRound } from "./round/public";
import * as storedPlay from "./round/storedPlay";
import { StoredPlay } from "./round/storedPlay";

export type Round = Playing | Revealing | Judging | Complete;

export type Stage = "Playing" | "Revealing" | "Judging" | "Complete";

export type Id = number;

abstract class Base<TStage extends Stage> {
  public abstract readonly stage: TStage;
  public abstract readonly id: Id;
  public abstract readonly czar: user.Id;
  public abstract readonly players: Set<user.Id>;
  public abstract readonly call: card.Call;
  public abstract readonly plays: StoredPlay[];

  /**
   * The players that need to do something before this stage can advance.
   */
  public abstract waitingFor(): Set<user.Id> | null;

  /**
   * Get the public view of the round.
   */
  public abstract public(): PublicRound;

  /**
   * Verifies the user is on the right stage for this action, throwing if they
   * are not. Note that you will need to give the generic type explicitly, as
   * it can't be inferred.
   */
  public verifyStage<TRound extends Round>(
    action: Action,
    expected: TRound["stage"]
  ): this is TRound {
    if (this.stage !== expected) {
      throw new IncorrectRoundStageError(action, this.stage, expected);
    }
    return true;
  }
}

export class Complete extends Base<"Complete"> {
  public get stage(): "Complete" {
    return "Complete";
  }

  public readonly id: Id;
  public readonly czar: card.Id;

  public get players(): Set<user.Id> {
    return new Set(wu(this.plays).map(play => play.playedBy));
  }

  public readonly call: card.Call;
  public readonly plays: storedPlay.Revealed[];
  public readonly winner: user.Id;

  public constructor(
    id: Id,
    czar: card.Id,
    call: card.Call,
    plays: storedPlay.Revealed[],
    winner: user.Id
  ) {
    super();
    this.id = id;
    this.czar = czar;
    this.call = call;
    this.plays = plays;
    this.winner = winner;
  }

  public waitingFor(): Set<user.Id> | null {
    return null;
  }

  public public(): publicRound.Complete {
    return {
      stage: this.stage,
      id: this.id.toString(),
      czar: this.czar,
      players: Array.from(this.players),
      call: this.call,
      winner: this.winner,
      plays: this.playsObj()
    };
  }

  public playedBy(): { [player: string]: user.Id } {
    const obj: { [player: string]: user.Id } = {};
    for (const roundPlay of this.plays) {
      obj[roundPlay.id] = roundPlay.playedBy;
    }
    return obj;
  }

  private playsObj(): { [player: string]: Play } {
    const obj: { [player: string]: Play } = {};
    for (const roundPlay of this.plays) {
      obj[roundPlay.playedBy] = roundPlay.play;
    }
    return obj;
  }
}

export class Judging extends Base<"Judging"> {
  public get stage(): "Judging" {
    return "Judging";
  }

  public readonly id: Id;
  public readonly czar: card.Id;

  public get players(): Set<user.Id> {
    return new Set(wu(this.plays).map(play => play.playedBy));
  }

  public readonly call: card.Call;
  public readonly plays: storedPlay.Revealed[];

  public constructor(
    id: Id,
    czar: card.Id,
    call: card.Call,
    plays: storedPlay.Revealed[]
  ) {
    super();
    this.id = id;
    this.czar = czar;
    this.call = call;
    this.plays = plays;
  }

  public advance(winner: user.Id): Complete {
    return new Complete(this.id, this.czar, this.call, this.plays, winner);
  }

  public waitingFor(): Set<user.Id> | null {
    return new Set(this.czar);
  }

  public public(): publicRound.Judging {
    return {
      stage: this.stage,
      id: this.id.toString(),
      czar: this.czar,
      players: Array.from(this.players),
      call: this.call,
      plays: Array.from(this.revealedPlays())
    };
  }

  private *revealedPlays(): Iterable<play.Revealed> {
    for (const roundPlay of this.plays) {
      yield { id: roundPlay.id, play: roundPlay.play };
    }
  }
}

export class Revealing extends Base<"Revealing"> {
  public get stage(): "Revealing" {
    return "Revealing";
  }

  public readonly id: Id;
  public readonly czar: card.Id;

  public get players(): Set<user.Id> {
    return new Set(wu(this.plays).map(play => play.playedBy));
  }

  public readonly call: card.Call;
  public readonly plays: StoredPlay[];

  public constructor(
    id: Id,
    czar: card.Id,
    call: card.Call,
    plays: StoredPlay[]
  ) {
    super();
    this.id = id;
    this.czar = czar;
    this.call = call;
    this.plays = plays;
  }

  public advance(): Judging | null {
    if (storedPlay.allRevealed(this)) {
      return new Judging(this.id, this.czar, this.call, this.plays);
    } else {
      return null;
    }
  }

  public waitingFor(): Set<user.Id> | null {
    return wu(this.plays).find(p => !p.revealed) === undefined
      ? null
      : new Set(this.czar);
  }

  public public(): publicRound.Revealing {
    return {
      stage: this.stage,
      id: this.id.toString(),
      czar: this.czar,
      players: Array.from(this.players),
      call: this.call,
      plays: Array.from(this.potentiallyRevealedPlays())
    };
  }

  private *potentiallyRevealedPlays(): Iterable<play.PotentiallyRevealed> {
    for (const roundPlay of this.plays) {
      const potentiallyRevealed: play.PotentiallyRevealed = {
        id: roundPlay.id
      };
      if (roundPlay.revealed) {
        potentiallyRevealed.play = roundPlay.play;
      }
      yield potentiallyRevealed;
    }
  }
}

export class Playing extends Base<"Playing"> {
  public get stage(): "Playing" {
    return "Playing";
  }

  public readonly id: Id;
  public readonly czar: card.Id;
  public readonly players: Set<user.Id>;
  public readonly call: card.Call;
  public readonly plays: storedPlay.Unrevealed[];

  public constructor(
    id: Id,
    czar: card.Id,
    players: Set<user.Id>,
    call: card.Call
  ) {
    super();
    this.id = id;
    this.czar = czar;
    this.players = players;
    this.call = call;
    this.plays = [];
  }

  public advance(): Revealing {
    return new Revealing(this.id, this.czar, this.call, this.plays);
  }

  public waitingFor(): Set<user.Id> | null {
    const done = new Set(
      wu(this.players).filter(p => !this.hasPlayed().has(p))
    );
    return done.size > 0 ? done : null;
  }

  private hasPlayed(): Set<user.Id> {
    return new Set(wu(this.plays).map(play => play.playedBy));
  }

  public public(): publicRound.Playing {
    return {
      stage: this.stage,
      id: this.id.toString(),
      czar: this.czar,
      players: Array.from(this.players),
      call: this.call,
      played: this.plays.map(play => play.playedBy)
    };
  }
}
