import * as User from "../../../user";
import * as Card from "../../cards/card";
import * as Play from "../../cards/play";
import * as Player from "../../player";

export type Public = Playing | Revealing | Judging | Complete;

interface Base {
  stage: string;
  id: string;
  czar: User.Id;
  players: User.Id[];
  call: Card.Call;
  startedAt: number;
}

interface Timed {
  timedOut?: boolean;
}

export interface Playing extends Base, Timed {
  stage: "Playing";
  played: User.Id[];
}

export interface Revealing extends Base, Timed {
  stage: "Revealing";
  plays: Play.PotentiallyRevealed[];
}

export interface Judging extends Base, Timed {
  stage: "Judging";
  plays: Play.Revealed[];
}

export interface PlayWithLikes {
  play: Play.Play;
  likes?: number;
}

export interface Complete extends Base {
  stage: "Complete";
  winner: User.Id;
  plays: { [player: string]: PlayWithLikes };
  playOrder: User.Id[];
}

export interface PlayDetails {
  playedBy: User.Id;
  likes?: Player.Likes;
}
