import { Say, Voice } from "../../ts/speech";
import {
  State as NotificationState,
  Command as NotificationCommand
} from "../../ts/notification-manager";

type Token = string;

interface Settings {
  tokens: Token[];
  lastUsedName: string | null;
  recentDecks: string[];
  chosenLanguage: string | null;
}

interface Flags {
  settings: Settings;
  browserLanguages: string[];
  remoteMode?: boolean;
}

interface CastStatus {
  status: string;
  name?: string;
}

interface OpenCommand {
  gameCode: string;
  token: string;
}

interface MessageCommand {
  message: string;
}

interface SpectateCommand {
  command: "Spectate";
  token: string;
  language: string;
}

type RemoteControlCommand = SpectateCommand;

interface CloseCommand {}

type ConnectionCommand = OpenCommand | MessageCommand | CloseCommand;

export interface InboundPort<T> {
  subscribe(callback: (data: T) => void): void;
}

export interface OutboundPort<T> {
  send(data: T): void;
}

export namespace Elm {
  namespace MassiveDecks {
    export interface App {
      ports: {
        notificationState: OutboundPort<NotificationState>;
        notificationCommands: InboundPort<NotificationCommand>;
        speechCommands: InboundPort<Say>;
        speechVoices: OutboundPort<Array<Voice>>;
        storeSettings: InboundPort<Settings>;
        tryCast: InboundPort<RemoteControlCommand>;
        castStatus: OutboundPort<CastStatus>;
        serverRecv: OutboundPort<string>;
        serverSend: InboundPort<ConnectionCommand>;
        copyText: InboundPort<string>;
        remoteControl: OutboundPort<RemoteControlCommand>;
      };
    }
    export function init(options: {
      node?: HTMLElement | null;
      flags: Flags;
    }): Elm.MassiveDecks.App;
  }
}
