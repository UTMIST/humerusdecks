module MassiveDecks.Scenes.Start.Messages exposing (..)

import MassiveDecks.Components.Input as Input
import MassiveDecks.Components.Errors as Errors
import MassiveDecks.Components.Tabs as Tabs
import MassiveDecks.Components.Overlay as Overlay
import MassiveDecks.Components.Storage as Storage
import MassiveDecks.Scenes.Lobby.Messages as Lobby
import MassiveDecks.Models.Game as Game
import MassiveDecks.Models.Player as Player


{-| The messages used in the start screen.
-}
type Message
  = SubmitCurrentTab
  | CreateLobby
  | SetButtonsEnabled Bool
  | JoinLobbyAsNewPlayer
  | JoinGivenLobbyAsNewPlayer String
  | JoinLobbyAsExistingPlayer Player.Secret String
  | MoveToLobby String
  | JoinLobby Player.Secret Game.LobbyAndHand
  | TryExistingGame String
  | ClearExistingGame Game.GameCodeAndSecret
  | InputMessage (Input.Message InputId)
  | LobbyMessage Lobby.ConsumerMessage
  | ErrorMessage Errors.Message
  | OverlayMessage (Overlay.Message Message)
  | TabsMessage (Tabs.Message Tab)
  | StorageMessage (Storage.Message)
  | Batch (List Message)
  | NoOp


{-| IDs for the inputs to differentiate between them in messages.
-}
type InputId
  = Name
  | GameCode


{-| Tabs for the start page.
-}
type Tab
  = Create
  | Join
