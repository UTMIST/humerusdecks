module MassiveDecks.Messages exposing (Msg(..))

import MassiveDecks.Cast.Model as Cast
import MassiveDecks.Error.Messages as Error
import MassiveDecks.Notifications.Model as Notifications
import MassiveDecks.Pages.Lobby.Messages as Lobby
import MassiveDecks.Pages.Lobby.Model as Lobby
import MassiveDecks.Pages.Route exposing (Route)
import MassiveDecks.Pages.Spectate.Messages as Spectate
import MassiveDecks.Pages.Start.Messages as Start
import MassiveDecks.Settings.Messages as Settings
import MassiveDecks.Speech as Speech
import Url exposing (Url)


{-| The main message type for the application.
-}
type Msg
    = ChangePage Route
    | PageChanged Url
    | JoinLobby String Lobby.Auth
    | SpectateMsg Spectate.Msg
    | StartMsg Start.Msg
    | LobbyMsg Lobby.Msg
    | SettingsMsg Settings.Msg
    | ErrorMsg Error.Msg
    | SpeechMsg Speech.Msg
    | NotificationMsg Notifications.Msg
    | UpdateToken Lobby.Auth
    | CastStatusUpdate Cast.Status
    | TryCast Lobby.Auth
    | Refresh
    | BlockedExternalUrl
    | Copy String
    | NoOp
