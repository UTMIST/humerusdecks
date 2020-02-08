module MassiveDecks.Models.Decoders exposing
    ( castStatus
    , config
    , event
    , eventOrMdError
    , externalSource
    , flags
    , gameCode
    , gameStateError
    , language
    , lobbyState
    , lobbySummary
    , lobbyToken
    , mdError
    , privilege
    , remoteControlCommand
    , revealingRound
    , settings
    , tokenValidity
    , userId
    , userSummary
    )

import Dict exposing (Dict)
import Json.Decode as Json
import Json.Patch
import MassiveDecks.Card.Model as Card exposing (Call, Response)
import MassiveDecks.Card.Parts as Parts exposing (Part, Parts)
import MassiveDecks.Card.Play as Play exposing (Play)
import MassiveDecks.Card.Source.Cardcast.Model as Cardcast
import MassiveDecks.Card.Source.Model as Source exposing (Source)
import MassiveDecks.Cast.Model as Cast
import MassiveDecks.Game.Model as Game exposing (Game)
import MassiveDecks.Game.Player as Player exposing (Player)
import MassiveDecks.Game.Round as Round exposing (Round)
import MassiveDecks.Game.Rules as Rules exposing (Rules)
import MassiveDecks.Game.Time as Time
import MassiveDecks.Model exposing (..)
import MassiveDecks.Models.MdError as MdError exposing (MdError)
import MassiveDecks.Notifications.Model as Notifications
import MassiveDecks.Pages.Lobby.Configure.Decks.Model as DeckConfig
import MassiveDecks.Pages.Lobby.Configure.Model as Configure
import MassiveDecks.Pages.Lobby.Configure.Privacy.Model as PrivacyConfig
import MassiveDecks.Pages.Lobby.Events as Events exposing (Event)
import MassiveDecks.Pages.Lobby.GameCode as GameCode exposing (GameCode)
import MassiveDecks.Pages.Lobby.Model as Lobby exposing (Lobby)
import MassiveDecks.Pages.Start.LobbyBrowser.Model as LobbyBrowser
import MassiveDecks.Settings.Model as Settings exposing (Settings)
import MassiveDecks.Speech as Speech
import MassiveDecks.Strings.Languages as Lang
import MassiveDecks.Strings.Languages.Model as Lang exposing (Language)
import MassiveDecks.User as User exposing (User)
import Set exposing (Set)


unknownValue : String -> String -> Json.Decoder a
unknownValue name value =
    ("Unknown " ++ name ++ ": \"" ++ value ++ "\".") |> Json.fail


castStatus : Json.Decoder Cast.Status
castStatus =
    Json.field "status" Json.string |> Json.andThen castStatusByName


castStatusByName : String -> Json.Decoder Cast.Status
castStatusByName name =
    case name of
        "NoDevicesAvailable" ->
            Json.succeed Cast.NoDevicesAvailable

        "NotConnected" ->
            Json.succeed Cast.NotConnected

        "Connecting" ->
            Json.succeed Cast.Connecting

        "Connected" ->
            Json.map Cast.Connected
                (Json.field "name" Json.string)

        _ ->
            unknownValue "cast status" name


remoteControlCommand : Json.Decoder Cast.RemoteControlCommand
remoteControlCommand =
    Json.field "command" Json.string |> Json.andThen remoteControlCommandByName


remoteControlCommandByName : String -> Json.Decoder Cast.RemoteControlCommand
remoteControlCommandByName name =
    case name of
        "Spectate" ->
            spectateCommand

        _ ->
            unknownValue "remote command" name


spectateCommand : Json.Decoder Cast.RemoteControlCommand
spectateCommand =
    Json.map2 (\t -> \l -> Cast.Spectate { token = t, language = l })
        (Json.field "token" lobbyToken)
        (Json.field "language" language)


flags : Json.Decoder Flags
flags =
    Json.map3 Flags
        (Json.field "settings" settings)
        (Json.field "browserLanguages" (Json.list Json.string))
        (Json.maybe (Json.field "remoteMode" Json.bool) |> Json.map (Maybe.withDefault False))


settings : Json.Decoder Settings
settings =
    Json.map8 Settings
        (Json.field "tokens" (Json.dict lobbyToken))
        (Json.field "openUserList" Json.bool)
        (Json.maybe (Json.field "lastUsedName" Json.string))
        (Json.field "recentDecks" (Json.list externalSource))
        (Json.maybe (Json.field "chosenLanguage" language))
        (Json.field "compactCards" cardSize)
        (Json.maybe (Json.field "speech" speech) |> Json.map (Maybe.withDefault Speech.default))
        (Json.maybe (Json.field "notifications" notifications) |> Json.map (Maybe.withDefault Notifications.default))


notifications : Json.Decoder Notifications.Settings
notifications =
    Json.map2 Notifications.Settings
        (Json.field "enabled" Json.bool)
        (Json.field "requireNotVisible" Json.bool)


speech : Json.Decoder Speech.Settings
speech =
    Json.map2 Speech.Settings
        (Json.field "enabled" Json.bool)
        (Json.maybe (Json.field "selectedVoice" Json.string))


cardSize : Json.Decoder Settings.CardSize
cardSize =
    Json.int |> Json.andThen (\i -> i |> Settings.cardSizeFromValue |> Maybe.map Json.succeed |> Maybe.withDefault (unknownValue "card size" (String.fromInt i)))


gameCode : Json.Decoder GameCode
gameCode =
    Json.string |> Json.map GameCode.trusted


source : Json.Decoder Source
source =
    Json.field "source" Json.string |> Json.andThen sourceByName


sourceByName : String -> Json.Decoder Source
sourceByName name =
    case name of
        "Player" ->
            Json.succeed Source.Player

        _ ->
            externalSourceByName name |> Json.map Source.Ex


externalSource : Json.Decoder Source.External
externalSource =
    Json.field "source" Json.string |> Json.andThen externalSourceByName


externalSourceByName : String -> Json.Decoder Source.External
externalSourceByName name =
    case name of
        "Cardcast" ->
            Json.field "playCode" Json.string |> Json.map (Cardcast.playCode >> Source.Cardcast)

        _ ->
            unknownValue "source" name


tokenValidity : Json.Decoder (Dict Lobby.Token Bool)
tokenValidity =
    Json.dict Json.bool


lobbyToken : Json.Decoder Lobby.Token
lobbyToken =
    Json.string


language : Json.Decoder Language
language =
    Json.string |> Json.andThen languageFromCode


languageFromCode : String -> Json.Decoder Language
languageFromCode code =
    code
        |> Lang.fromCode
        |> Maybe.map Json.succeed
        |> Maybe.withDefault (unknownValue "language code" code)


lobby : Json.Decoder Lobby
lobby =
    Json.map7 Lobby
        (Json.field "name" Json.string)
        (Json.field "public" Json.bool)
        (Json.field "users" users)
        (Json.field "owner" userId)
        (Json.field "config" config)
        (Json.maybe (Json.field "game" game |> Json.map Game.emptyModel))
        (Json.maybe (Json.field "errors" (Json.list gameStateError)) |> Json.map (Maybe.withDefault []))


game : Json.Decoder Game
game =
    Json.map7 Game
        (Json.field "round" round)
        (Json.field "history" (Json.list completeRound))
        (Json.field "playerOrder" (Json.list userId))
        (Json.field "players" (Json.dict player))
        (Json.field "rules" rules)
        (Json.maybe (Json.field "winner" (Json.list userId |> Json.map Set.fromList)))
        (Json.maybe (Json.field "paused" Json.bool) |> Json.map (Maybe.withDefault False))


config : Json.Decoder Configure.Config
config =
    Json.map4 Configure.Config
        (Json.field "rules" rules)
        (Json.field "decks" (Json.list deckOrError))
        privacyConfig
        (Json.field "version" Json.string)


privacyConfig : Json.Decoder PrivacyConfig.Config
privacyConfig =
    Json.map2 PrivacyConfig.Config
        (Json.maybe (Json.field "password" Json.string))
        (Json.maybe (Json.field "public" Json.bool) |> Json.map (Maybe.withDefault False))


deckOrError : Json.Decoder DeckConfig.DeckOrError
deckOrError =
    Json.oneOf [ Json.map DeckConfig.E deckError, Json.map DeckConfig.D deck ]


deck : Json.Decoder DeckConfig.Deck
deck =
    Json.map2 DeckConfig.Deck
        (Json.field "source" externalSource)
        (Json.maybe (Json.field "summary" summary))


deckError : Json.Decoder DeckConfig.Error
deckError =
    Json.map2 DeckConfig.Error
        (Json.field "source" externalSource)
        (Json.field "failure" failReason)


summary : Json.Decoder Source.Summary
summary =
    Json.map3 Source.Summary
        (Json.field "details" details)
        (Json.field "calls" Json.int)
        (Json.field "responses" Json.int)


details : Json.Decoder Source.Details
details =
    Json.map2 Source.Details
        (Json.field "name" Json.string)
        (Json.maybe (Json.field "url" Json.string))


rules : Json.Decoder Rules
rules =
    Json.map4 Rules
        (Json.field "handSize" Json.int)
        (Json.maybe (Json.field "scoreLimit" score))
        (Json.field "houseRules" houseRules)
        (Json.field "timeLimits" timeLimits)


timeLimits : Json.Decoder Rules.TimeLimits
timeLimits =
    Json.map5 Rules.TimeLimits
        (Json.field "mode" timeLimitMode)
        (Json.maybe (Json.field "playing" Json.int))
        (Json.maybe (Json.field "revealing" Json.int))
        (Json.maybe (Json.field "judging" Json.int))
        (Json.field "complete" Json.int)


timeLimitMode : Json.Decoder Rules.TimeLimitMode
timeLimitMode =
    Json.string |> Json.andThen timeLimitModeByName


timeLimitModeByName : String -> Json.Decoder Rules.TimeLimitMode
timeLimitModeByName name =
    case name of
        "Hard" ->
            Json.succeed Rules.Hard

        "Soft" ->
            Json.succeed Rules.Soft

        _ ->
            unknownValue "time limit mode" name


houseRules : Json.Decoder Rules.HouseRules
houseRules =
    Json.map4 Rules.HouseRules
        (Json.maybe (Json.field "rando" rando))
        (Json.maybe (Json.field "packingHeat" packingHeat))
        (Json.maybe (Json.field "reboot" reboot))
        (Json.maybe (Json.field "comedyWriter" comedyWriter))


comedyWriter : Json.Decoder Rules.ComedyWriter
comedyWriter =
    Json.map2 Rules.ComedyWriter
        (Json.field "number" Json.int)
        (Json.field "exclusive" Json.bool)


packingHeat : Json.Decoder Rules.PackingHeat
packingHeat =
    {} |> Json.succeed


reboot : Json.Decoder Rules.Reboot
reboot =
    Json.map Rules.Reboot
        (Json.field "cost" score)


rando : Json.Decoder Rules.Rando
rando =
    Json.map Rules.Rando
        (Json.field "number" score)


player : Json.Decoder Player
player =
    Json.map3 Player
        (Json.field "score" score)
        (Json.field "likes" Json.int)
        (Json.field "presence" playerPresence)


playerPresence : Json.Decoder Player.Presence
playerPresence =
    Json.string |> Json.andThen playerPresenceByName


playerPresenceByName : String -> Json.Decoder Player.Presence
playerPresenceByName name =
    case name of
        "Active" ->
            Json.succeed Player.Active

        "Away" ->
            Json.succeed Player.Away

        _ ->
            unknownValue "player presence" name


control : Json.Decoder User.Control
control =
    Json.string |> Json.andThen controlByName


controlByName : String -> Json.Decoder User.Control
controlByName name =
    case name of
        "Human" ->
            Json.succeed User.Human

        "Computer" ->
            Json.succeed User.Computer

        _ ->
            unknownValue "user controller" name


score : Json.Decoder Player.Score
score =
    Json.int


users : Json.Decoder (Dict User.Id User)
users =
    Json.dict user


user : Json.Decoder User
user =
    Json.map6 User
        (Json.field "name" Json.string)
        (Json.field "presence" userPresence)
        (Json.field "connection" userConnection)
        (Json.field "privilege" privilege)
        (Json.field "role" userRole)
        (Json.field "control" control)


userConnection : Json.Decoder User.Connection
userConnection =
    Json.string |> Json.andThen userConnectionByName


userConnectionByName : String -> Json.Decoder User.Connection
userConnectionByName name =
    case name of
        "Connected" ->
            Json.succeed User.Connected

        "Disconnected" ->
            Json.succeed User.Disconnected

        _ ->
            unknownValue "connection state" name


userPresence : Json.Decoder User.Presence
userPresence =
    Json.string |> Json.andThen userPresenceByName


userPresenceByName : String -> Json.Decoder User.Presence
userPresenceByName name =
    case name of
        "Joined" ->
            Json.succeed User.Joined

        "Left" ->
            Json.succeed User.Left

        _ ->
            unknownValue "presence state" name


role : Json.Decoder User.Role
role =
    Json.string |> Json.andThen roleByName


roleByName : String -> Json.Decoder User.Role
roleByName name =
    case name of
        "Spectator" ->
            Json.succeed User.Spectator

        "Player" ->
            Json.succeed User.Player

        _ ->
            unknownValue "user role" name


lobbyState : Json.Decoder Lobby.State
lobbyState =
    Json.string |> Json.andThen lobbyStateByName


lobbyStateByName : String -> Json.Decoder Lobby.State
lobbyStateByName name =
    case name of
        "Playing" ->
            Json.succeed Lobby.Playing

        "SettingUp" ->
            Json.succeed Lobby.SettingUp

        _ ->
            unknownValue "lobby state" name


lobbySummary : Json.Decoder LobbyBrowser.Summary
lobbySummary =
    Json.map5 LobbyBrowser.Summary
        (Json.field "name" Json.string)
        (Json.field "gameCode" gameCode)
        (Json.field "state" lobbyState)
        (Json.field "users" userSummary)
        (Json.maybe (Json.field "password" Json.bool) |> Json.map (Maybe.withDefault False))


userId : Json.Decoder User.Id
userId =
    Json.string


privilege : Json.Decoder User.Privilege
privilege =
    Json.string |> Json.andThen privilegeByName


privilegeByName : String -> Json.Decoder User.Privilege
privilegeByName name =
    case name of
        "Privileged" ->
            Json.succeed User.Privileged

        "Unprivileged" ->
            Json.succeed User.Unprivileged

        _ ->
            unknownValue "privilege level" name


userSummary : Json.Decoder LobbyBrowser.UserSummary
userSummary =
    Json.map2 LobbyBrowser.UserSummary
        (Json.field "players" Json.int)
        (Json.field "spectators" Json.int)


eventOrMdError : Json.Decoder (Result MdError Event)
eventOrMdError =
    Json.oneOf
        [ event |> Json.map Result.Ok
        , mdError |> Json.map Result.Err
        ]


event : Json.Decoder Event
event =
    Json.field "event" Json.string |> Json.andThen eventByName


eventByName : String -> Json.Decoder Event
eventByName name =
    case name of
        "Sync" ->
            sync

        "Connected" ->
            connection User.Connected

        "Disconnected" ->
            connection User.Disconnected

        "Joined" ->
            userJoined |> Json.andThen presence

        "Left" ->
            userLeft |> Json.andThen presence

        "Configured" ->
            configured

        "GameStarted" ->
            gameStarted

        "RoundStarted" ->
            timedGameEvent roundStarted

        "PlaySubmitted" ->
            gameEvent playSubmitted

        "PlayTakenBack" ->
            gameEvent playTakenBack

        "StartRevealing" ->
            timedGameEvent startRevealing

        "PlayRevealed" ->
            timedGameEvent playRevealed

        "RoundFinished" ->
            timedGameEvent roundFinished

        "HandRedrawn" ->
            gameEvent handRedrawn

        "Away" ->
            gameEvent playerAway

        "Back" ->
            gameEvent playerBack

        "PrivilegeChanged" ->
            privilegeChanged

        "Paused" ->
            gameEvent (Json.succeed Events.Paused)

        "Continued" ->
            gameEvent (Json.succeed Events.Continued)

        "StageTimerDone" ->
            gameEvent stageTimerDone

        "GameEnded" ->
            gameEvent ended

        "ErrorEncountered" ->
            errorEncountered

        _ ->
            unknownValue "event" name


errorEncountered : Json.Decoder Events.Event
errorEncountered =
    Json.map (\e -> Events.ErrorEncountered { error = e })
        (Json.field "error" gameStateError)


configured : Json.Decoder Events.Event
configured =
    Json.map (\c -> Events.Configured { change = c })
        (Json.field "change" Json.Patch.decoder)


ended : Json.Decoder Events.GameEvent
ended =
    Json.map (\w -> Events.GameEnded { winner = w })
        (Json.field "winner" (Json.list userId |> Json.map Set.fromList))


stageTimerDone : Json.Decoder Events.GameEvent
stageTimerDone =
    Json.map2 (\r -> \s -> Events.StageTimerDone { round = r, stage = s })
        (Json.field "round" Round.idDecoder)
        (Json.field "stage" stage)


playerAway : Json.Decoder Events.GameEvent
playerAway =
    Json.map (\p -> Events.PlayerAway { player = p })
        (Json.field "player" userId)


playerBack : Json.Decoder Events.GameEvent
playerBack =
    Json.map (\p -> Events.PlayerBack { player = p })
        (Json.field "player" userId)


handRedrawn : Json.Decoder Events.GameEvent
handRedrawn =
    Json.map2 (\pl -> \ha -> Events.HandRedrawn { player = pl, hand = ha })
        (Json.field "player" userId)
        (Json.maybe (Json.field "hand" (Json.list potentiallyBlankResponse)))


roundFinished : Json.Decoder Events.TimedGameEvent
roundFinished =
    Json.map2 (\wi -> \pb -> Events.RoundFinished { winner = wi, playedBy = pb })
        (Json.field "winner" userId)
        (Json.field "playDetails" (Json.dict playDetails))


playDetails : Json.Decoder Play.Details
playDetails =
    Json.map2 Play.Details
        (Json.field "playedBy" userId)
        (Json.maybe (Json.field "likes" Json.int))


playRevealed : Json.Decoder Events.TimedGameEvent
playRevealed =
    Json.map2 (\id -> \pl -> Events.PlayRevealed { id = id, play = pl })
        (Json.field "id" playId)
        (Json.field "play" (Json.list response))


startRevealing : Json.Decoder Events.TimedGameEvent
startRevealing =
    Json.map2 (\ps -> \dr -> Events.StartRevealing { plays = ps, drawn = dr })
        (Json.field "plays" (Json.list playId))
        (Json.maybe (Json.field "drawn" (Json.list potentiallyBlankResponse)))


gameEvent : Json.Decoder Events.GameEvent -> Json.Decoder Event
gameEvent =
    Json.map Events.Game


timedGameEvent : Json.Decoder Events.TimedGameEvent -> Json.Decoder Event
timedGameEvent =
    Json.map (\e -> Events.NoTime { event = e } |> Events.Timed) >> gameEvent


playSubmitted : Json.Decoder Events.GameEvent
playSubmitted =
    Json.map (\by -> Events.PlaySubmitted { by = by })
        (Json.field "by" userId)


playTakenBack : Json.Decoder Events.GameEvent
playTakenBack =
    Json.map (\by -> Events.PlayTakenBack { by = by })
        (Json.field "by" userId)


roundStarted : Json.Decoder Events.TimedGameEvent
roundStarted =
    Json.map5 (\id -> \ca -> \cz -> \pl -> \d -> { id = id, call = ca, czar = cz, players = pl, drawn = d } |> Events.RoundStarted)
        (Json.field "id" Round.idDecoder)
        (Json.field "call" call)
        (Json.field "czar" userId)
        (Json.field "players" playerSet)
        (Json.maybe (Json.field "drawn" (Json.list potentiallyBlankResponse)))


privilegeChanged : Json.Decoder Events.Event
privilegeChanged =
    Json.map2 (\u -> \p -> Events.PrivilegeChanged { user = u, privilege = p })
        (Json.field "user" userId)
        (Json.field "privilege" privilege)


gameStarted : Json.Decoder Events.Event
gameStarted =
    Json.map2 (\r -> \h -> { round = r, hand = h } |> Events.GameStarted)
        (Json.field "round" playingRound)
        (Json.field "hand" (Json.list potentiallyBlankResponse))


sync : Json.Decoder Event
sync =
    Json.map4 (\ls -> \h -> \p -> \pa -> Events.Sync { state = ls, hand = h, play = p, partialTimeAnchor = pa })
        (Json.field "state" lobby)
        (Json.maybe (Json.field "hand" (Json.list potentiallyBlankResponse)))
        (Json.maybe (Json.field "play" (Json.list cardPlayed)))
        (Json.field "gameTime" Time.partialAnchorDecoder)


cardPlayed : Json.Decoder Card.Played
cardPlayed =
    Json.oneOf
        [ Json.string |> Json.map (\id -> { id = id, text = Nothing })
        , Json.map2 (\id -> \text -> { id = id, text = Just text })
            (Json.field "id" cardId)
            (Json.field "text" Json.string)
        ]


connection : User.Connection -> Json.Decoder Event
connection state =
    Json.map (\u -> Events.Connection { user = u, state = state })
        (Json.field "user" userId)


presence : Events.PresenceState -> Json.Decoder Event
presence state =
    Json.map (\u -> Events.Presence { user = u, state = state })
        (Json.field "user" userId)


userJoined : Json.Decoder Events.PresenceState
userJoined =
    Json.map3 (\n -> \p -> \c -> Events.UserJoined { name = n, privilege = p, control = c })
        (Json.field "name" Json.string)
        (Json.maybe (Json.field "privilege" privilege) |> Json.map (Maybe.withDefault User.Unprivileged))
        (Json.maybe (Json.field "control" control) |> Json.map (Maybe.withDefault User.Human))


userLeft : Json.Decoder Events.PresenceState
userLeft =
    Json.map (\r -> Events.UserLeft { reason = r })
        (Json.maybe (Json.field "reason" leaveReason) |> Json.map (Maybe.withDefault User.LeftNormally))


leaveReason : Json.Decoder User.LeaveReason
leaveReason =
    Json.string |> Json.andThen leaveReasonByName


leaveReasonByName : String -> Json.Decoder User.LeaveReason
leaveReasonByName name =
    case name of
        "Left" ->
            Json.succeed User.LeftNormally

        "Kicked" ->
            Json.succeed User.Kicked

        _ ->
            unknownValue "leaving reason" name


failReason : Json.Decoder Source.LoadFailureReason
failReason =
    Json.string |> Json.andThen failReasonByName


failReasonByName : String -> Json.Decoder Source.LoadFailureReason
failReasonByName name =
    case name of
        "SourceFailure" ->
            Json.succeed Source.SourceFailure

        "NotFound" ->
            Json.succeed Source.NotFound

        _ ->
            unknownValue "failure reason" name


play : Json.Decoder Play
play =
    Json.map2 Play
        (Json.field "id" playId)
        (Json.maybe (Json.field "play" (Json.list response)))


playId : Json.Decoder Play.Id
playId =
    Json.string


knownPlay : Json.Decoder Play.Known
knownPlay =
    Json.map2 Play.Known
        (Json.field "id" playId)
        (Json.field "play" (Json.list response))


cardId : Json.Decoder Card.Id
cardId =
    Json.string


response : Json.Decoder Card.Response
response =
    Json.map3 Card.response
        (Json.field "text" Json.string)
        (Json.field "id" cardId)
        (Json.field "source" source)


blankResponse : Json.Decoder Card.BlankResponse
blankResponse =
    Json.map2 Card.blankResponse
        (Json.field "id" cardId)
        (Json.field "source" source)


potentiallyBlankResponse : Json.Decoder Card.PotentiallyBlankResponse
potentiallyBlankResponse =
    Json.oneOf [ response |> Json.map Card.Normal, blankResponse |> Json.map Card.Blank ]


call : Json.Decoder Card.Call
call =
    Json.map3 Card.call
        (Json.field "parts" parts)
        (Json.field "id" cardId)
        (Json.field "source" source)


parts : Json.Decoder Parts
parts =
    Json.list (Json.list part)
        |> Json.map Parts.fromList
        |> Json.andThen (Maybe.map Json.succeed >> Maybe.withDefault (Json.fail "Given no slot in call."))


part : Json.Decoder Part
part =
    Json.oneOf
        [ Json.string |> Json.map Parts.Text
        , transform |> Json.map Parts.Slot
        ]


transform : Json.Decoder Parts.Transform
transform =
    Json.maybe (Json.field "transform" Json.string) |> Json.andThen transformByName


transformByName : Maybe String -> Json.Decoder Parts.Transform
transformByName maybeName =
    case maybeName of
        Nothing ->
            Json.succeed Parts.Stay

        Just name ->
            case name of
                "UpperCase" ->
                    Json.succeed Parts.UpperCase

                "Capitalize" ->
                    Json.succeed Parts.Capitalize

                _ ->
                    unknownValue "transform" name


round : Json.Decoder Round
round =
    Json.field "stage" Json.string |> Json.andThen roundByName


roundByName : String -> Json.Decoder Round
roundByName name =
    case name of
        "Playing" ->
            playingRound |> Json.map Round.P

        "Revealing" ->
            revealingRound |> Json.map Round.R

        "Judging" ->
            judgingRound |> Json.map Round.J

        "Complete" ->
            completeRound |> Json.map Round.C

        _ ->
            unknownValue "round stage" name


playerSet : Json.Decoder (Set User.Id)
playerSet =
    Json.list userId |> Json.map Set.fromList


playingRound : Json.Decoder Round.Playing
playingRound =
    Json.map7 Round.playing
        (Json.field "id" Round.idDecoder)
        (Json.field "czar" userId)
        (Json.field "players" playerSet)
        (Json.field "call" call)
        (Json.field "played" playerSet)
        (Json.field "startedAt" Time.timeDecoder)
        (Json.maybe (Json.field "timedOut" Json.bool) |> Json.map (Maybe.withDefault False))


revealingRound : Json.Decoder Round.Revealing
revealingRound =
    Json.map7 Round.revealing
        (Json.field "id" Round.idDecoder)
        (Json.field "czar" userId)
        (Json.field "players" playerSet)
        (Json.field "call" call)
        (Json.field "plays" (Json.list play))
        (Json.field "startedAt" Time.timeDecoder)
        (Json.maybe (Json.field "timedOut" Json.bool) |> Json.map (Maybe.withDefault False))


judgingRound : Json.Decoder Round.Judging
judgingRound =
    Json.map7 Round.judging
        (Json.field "id" Round.idDecoder)
        (Json.field "czar" userId)
        (Json.field "players" playerSet)
        (Json.field "call" call)
        (Json.field "plays" (Json.list knownPlay))
        (Json.field "startedAt" Time.timeDecoder)
        (Json.maybe (Json.field "timedOut" Json.bool) |> Json.map (Maybe.withDefault False))


completeRound : Json.Decoder Round.Complete
completeRound =
    Json.map8 Round.complete
        (Json.field "id" Round.idDecoder)
        (Json.field "czar" userId)
        (Json.field "players" playerSet)
        (Json.field "call" call)
        (Json.field "plays" (Json.dict playWithLikes))
        (Json.field "playOrder" (Json.list userId))
        (Json.field "winner" userId)
        (Json.field "startedAt" Time.timeDecoder)


playWithLikes : Json.Decoder Play.WithLikes
playWithLikes =
    Json.map2 Play.WithLikes
        (Json.field "play" (Json.list response))
        (Json.maybe (Json.field "likes" Json.int))


playerRole : Json.Decoder Player.Role
playerRole =
    Json.string |> Json.andThen playerRoleByName


playerRoleByName : String -> Json.Decoder Player.Role
playerRoleByName name =
    case name of
        "Czar" ->
            Json.succeed Player.RCzar

        "Player" ->
            Json.succeed Player.RPlayer

        _ ->
            unknownValue "player role" name


userRole : Json.Decoder User.Role
userRole =
    Json.string |> Json.andThen userRoleByName


userRoleByName : String -> Json.Decoder User.Role
userRoleByName name =
    case name of
        "Spectator" ->
            Json.succeed User.Spectator

        "Player" ->
            Json.succeed User.Player

        _ ->
            unknownValue "user role" name


mdError : Json.Decoder MdError
mdError =
    Json.field "error" Json.string |> Json.andThen mdErrorByName


mdErrorByName : String -> Json.Decoder MdError
mdErrorByName name =
    case name of
        "IncorrectPlayerRole" ->
            incorrectPlayerRole |> Json.map MdError.ActionExecution

        "IncorrectUserRole" ->
            incorrectUserRole |> Json.map MdError.ActionExecution

        "IncorrectRoundStage" ->
            incorrectRoundStageError |> Json.map MdError.ActionExecution

        "ConfigEditConflict" ->
            configEditConflictError |> Json.map MdError.ActionExecution

        "Unprivileged" ->
            Json.succeed (MdError.ActionExecution MdError.Unprivileged)

        "GameNotStarted" ->
            Json.succeed (MdError.ActionExecution MdError.GameNotStarted)

        "AuthenticationFailure" ->
            authenticationError |> Json.map MdError.Authentication

        "LobbyNotFound" ->
            Json.map2 (\r -> \g -> MdError.LobbyNotFound { reason = r, gameCode = g })
                (Json.field "reason" lobbyError)
                (Json.field "gameCode" gameCode)

        "Registration" ->
            registrationError |> Json.map MdError.Registration

        "OutOfCards" ->
            gameStateErrorByName name |> Json.map MdError.Game

        "InvalidAction" ->
            invalidActionError |> Json.map MdError.ActionExecution

        _ ->
            unknownValue "error" name


gameStateError : Json.Decoder MdError.GameStateError
gameStateError =
    Json.field "error" Json.string |> Json.andThen gameStateErrorByName


gameStateErrorByName : String -> Json.Decoder MdError.GameStateError
gameStateErrorByName name =
    case name of
        "OutOfCards" ->
            Json.succeed MdError.OutOfCardsError

        _ ->
            unknownValue "game state error" name


stage : Json.Decoder Round.Stage
stage =
    Json.string |> Json.andThen stageByName


stageByName : String -> Json.Decoder Round.Stage
stageByName name =
    case name of
        "Playing" ->
            Json.succeed Round.SPlaying

        "Revealing" ->
            Json.succeed Round.SRevealing

        "Judging" ->
            Json.succeed Round.SJudging

        "Complete" ->
            Json.succeed Round.SComplete

        _ ->
            unknownValue "round stage" name


invalidActionError : Json.Decoder MdError.ActionExecutionError
invalidActionError =
    Json.map (\r -> MdError.InvalidAction { reason = r })
        (Json.field "reason" Json.string)


incorrectRoundStageError : Json.Decoder MdError.ActionExecutionError
incorrectRoundStageError =
    Json.map2 (\s -> \e -> MdError.IncorrectRoundStage { stage = s, expected = e })
        (Json.field "stage" stage)
        (Json.field "expected" stage)


configEditConflictError : Json.Decoder MdError.ActionExecutionError
configEditConflictError =
    Json.map2 (\v -> \e -> MdError.ConfigEditConflict { version = v, expected = e })
        (Json.field "version" Json.string)
        (Json.field "expected" Json.string)


incorrectPlayerRole : Json.Decoder MdError.ActionExecutionError
incorrectPlayerRole =
    Json.map2 (\r -> \e -> MdError.IncorrectPlayerRole { role = r, expected = e })
        (Json.field "role" playerRole)
        (Json.field "expected" playerRole)


incorrectUserRole : Json.Decoder MdError.ActionExecutionError
incorrectUserRole =
    Json.map2 (\r -> \e -> MdError.IncorrectUserRole { role = r, expected = e })
        (Json.field "role" userRole)
        (Json.field "expected" userRole)


authenticationError : Json.Decoder MdError.AuthenticationError
authenticationError =
    Json.field "reason" Json.string |> Json.andThen authenticationErrorByName


authenticationErrorByName : String -> Json.Decoder MdError.AuthenticationError
authenticationErrorByName name =
    case name of
        "IncorrectIssuer" ->
            Json.succeed MdError.IncorrectIssuer

        "InvalidAuthentication" ->
            Json.succeed MdError.InvalidAuthentication

        "InvalidLobbyPassword" ->
            Json.succeed MdError.InvalidLobbyPassword

        "AlreadyLeftError" ->
            Json.succeed MdError.AlreadyLeftError

        _ ->
            unknownValue "authentication failure reason" name


registrationError : Json.Decoder MdError.RegistrationError
registrationError =
    Json.field "reason" Json.string |> Json.andThen registrationErrorByName


registrationErrorByName : String -> Json.Decoder MdError.RegistrationError
registrationErrorByName name =
    case name of
        "UsernameAlreadyInUse" ->
            Json.map (\u -> MdError.UsernameAlreadyInUseError { username = u })
                (Json.field "username" Json.string)

        _ ->
            unknownValue "registration error" name


lobbyError : Json.Decoder MdError.LobbyNotFoundError
lobbyError =
    Json.string |> Json.andThen lobbyErrorByName


lobbyErrorByName : String -> Json.Decoder MdError.LobbyNotFoundError
lobbyErrorByName name =
    case name of
        "Closed" ->
            Json.succeed MdError.Closed

        "DoesNotExist" ->
            Json.succeed MdError.DoesNotExist

        _ ->
            unknownValue "lobby not found error" name
