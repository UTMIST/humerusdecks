module MassiveDecks.Scenes.Start exposing (update, urlUpdate, view, init, subscriptions)

import String

import Html exposing (..)
import Html.App as Html

import Navigation

import MassiveDecks.Models exposing (Init, Path)
import MassiveDecks.Models.Game as Game
import MassiveDecks.Components.Tabs as Tabs
import MassiveDecks.Components.Storage as Storage
import MassiveDecks.Components.Input as Input
import MassiveDecks.Components.Errors as Errors
import MassiveDecks.Components.Overlay as Overlay exposing (Overlay)
import MassiveDecks.Components.Title as Title
import MassiveDecks.Scenes.Start.Messages exposing (InputId(..), Message(..), Tab(..))
import MassiveDecks.Scenes.Start.Models exposing (Model)
import MassiveDecks.Scenes.Start.UI as UI
import MassiveDecks.Scenes.Lobby as Lobby
import MassiveDecks.Scenes.Lobby.Messages as Lobby
import MassiveDecks.API as API
import MassiveDecks.API.Request as Request
import MassiveDecks.Util as Util


{-| Create the initial model for the start screen.
-}
init : Init -> Path -> (Model, Cmd Message)
init init path =
  let
    tab = if path.gameCode |> Maybe.withDefault "" |> String.isEmpty then Create else Join
  in
    ( { lobby = Nothing
      , init = init
      , path = path
      , nameInput = Input.init Name "name-input" [ text "Your name in the game." ] "" "Nickname" (Util.cmd SubmitCurrentTab) InputMessage
      , gameCodeInput = Input.init GameCode "game-code-input" [ text "The code for the game to join." ] (path.gameCode |> Maybe.withDefault "") "" (Util.cmd JoinLobbyAsNewPlayer) InputMessage
      , errors = Errors.init
      , overlay = Overlay.init OverlayMessage
      , buttonsEnabled = True
      , tabs = Tabs.init [ Tabs.Tab Create [ text "Create" ], Tabs.Tab Join [ text "Join" ] ] tab TabsMessage
      , storage = Storage.init init.existingGames
      }
    , Maybe.map (TryExistingGame >> Util.cmd) path.gameCode |> Maybe.withDefault Cmd.none)


{-| Subscriptions for the start screen.
-}
subscriptions : Model -> Sub Message
subscriptions model =
  case model.lobby of
    Nothing ->
      Sub.none

    Just lobby ->
      Lobby.subscriptions lobby |> Sub.map LobbyMessage


{-| Render the start scene.
-}
view : Model -> Html Message
view model =
  let
    contents = case model.lobby of
      Nothing ->
        UI.view model

      Just lobby ->
        Html.map LobbyMessage (Lobby.view lobby)
  in
    div []
        ([ contents
         , Errors.view { url = model.init.url, version = model.init.version } model.errors |> Html.map ErrorMessage
         ] ++ Overlay.view model.overlay)


{-| Handles changes to the url.
-}
urlUpdate : Path -> Model -> (Model, Cmd Message)
urlUpdate path model =
  if path.gameCode /= model.path.gameCode then
    let
      noGameCode = case path.gameCode of
        Just _ -> False
        Nothing -> True
      setInput =
        path.gameCode |> Maybe.map (\gameCode -> (GameCode, Input.SetDefaultValue gameCode) |> InputMessage |> Util.cmd)
    in
      { model | path = path
              , lobby = if noGameCode then Nothing else model.lobby
              , buttonsEnabled = True } !
        [ (if noGameCode then Tabs.SetTab Create else Tabs.SetTab Join) |> TabsMessage |> Util.cmd
        , setInput
          |> Maybe.withDefault Cmd.none
        , path.gameCode
          |> Maybe.map (\gc -> Title.set ("Game " ++ gc ++ " - " ++ title))
          |> Maybe.withDefault (Title.set title)
        , path.gameCode
          |> Maybe.map (TryExistingGame >> Util.cmd)
          |> Maybe.withDefault Cmd.none
        ]
  else
    (model, Cmd.none)


{-| Handles messages and alters the model as appropriate.
-}
update : Message -> Model -> (Model, Cmd Message)
update message model =
  case message of
    ErrorMessage message ->
      let
        (newErrors, cmd) = Errors.update message model.errors
      in
        ({ model | errors = newErrors }, Cmd.map ErrorMessage cmd)

    TabsMessage tabsMessage ->
      ({ model | tabs = (Tabs.update tabsMessage model.tabs) }, Cmd.none)

    ClearExistingGame existingGame ->
      model !
        [ Overlay "info-circle" "Game over." [ text ("The game " ++ existingGame.gameCode ++ " has ended.") ]
            |> Overlay.Show
            |> OverlayMessage
            |> Util.cmd
        , Storage.Leave existingGame |> StorageMessage |> Util.cmd
        , Navigation.newUrl model.init.url
        ]

    TryExistingGame gameCode ->
      let
        existing =
          List.filter (.gameCode >> ((==) gameCode)) model.storage.existingGames
            |> List.head
        cmd =
          Maybe.map (\existing -> JoinLobbyAsExistingPlayer existing.secret existing.gameCode |> Util.cmd) existing
            |> Maybe.withDefault Cmd.none
      in
        (model, cmd)

    CreateLobby ->
      ({ model | buttonsEnabled = False }, Request.send' API.createLobby ErrorMessage (\lobby -> JoinGivenLobbyAsNewPlayer lobby.gameCode))

    SubmitCurrentTab ->
      case model.tabs.current of
        Create ->
          (model, Util.cmd CreateLobby)

        Join ->
          (model, Util.cmd JoinLobbyAsNewPlayer)

    SetButtonsEnabled enabled ->
      ({ model | buttonsEnabled = enabled }, Cmd.none)

    JoinLobbyAsNewPlayer ->
      ({ model | buttonsEnabled = False }, Util.cmd (JoinGivenLobbyAsNewPlayer model.gameCodeInput.value))

    JoinGivenLobbyAsNewPlayer gameCode ->
      case List.filter (.gameCode >> ((==) gameCode)) model.storage.existingGames |> List.head of
        Nothing ->
          let
            cmd = (\secret -> Batch
              [ Storage.Join (Game.GameCodeAndSecret gameCode secret) |> StorageMessage
              , MoveToLobby gameCode
              ])
          in
            model !
              [ Request.send (API.newPlayer gameCode model.nameInput.value)
                                 newPlayerErrorHandler
                                 ErrorMessage
                                 cmd
              ]

        Just _ ->
          model !
            [ MoveToLobby gameCode |> Util.cmd
            , UI.alreadyInGameOverlay
                |> Overlay.Show
                |> OverlayMessage
                |> Util.cmd
            ]

    MoveToLobby gameCode ->
      model ! [ Navigation.newUrl (model.init.url ++ "#" ++ gameCode) ]

    JoinLobbyAsExistingPlayer secret gameCode ->
      model !
        [ Request.send (API.getLobbyAndHand gameCode secret)
                       (getLobbyAndHandErrorHandler (Game.GameCodeAndSecret gameCode secret))
                       ErrorMessage
                       (JoinLobby secret)
        ]

    JoinLobby secret lobbyAndHand ->
      let
        (lobby, cmd) = Lobby.init model.init lobbyAndHand secret
      in
        { model | lobby = Just lobby } !
          [ cmd |> Cmd.map LobbyMessage
          ]

    InputMessage message ->
      let
        (nameInput, nameCmd) = Input.update message model.nameInput
        (gameCodeInput, gameCodeCmd) = Input.update message model.gameCodeInput
      in
        ({ model | nameInput = nameInput
                 , gameCodeInput = gameCodeInput
         }, Cmd.batch [ nameCmd, gameCodeCmd ])

    OverlayMessage overlayMessage ->
      ({ model | overlay = Overlay.update overlayMessage model.overlay }, Cmd.none)

    StorageMessage storageMessage ->
      let
        (storageModel, cmd) = Storage.update storageMessage model.storage
      in
        ({ model | storage = storageModel }, cmd |> Cmd.map StorageMessage)

    LobbyMessage message ->
      case message of
        Lobby.ErrorMessage message ->
          (model, Util.cmd (ErrorMessage message))

        Lobby.OverlayMessage message ->
          (model, Util.cmd (OverlayMessage (Overlay.map (Lobby.LocalMessage >> LobbyMessage) message)))

        Lobby.Leave ->
          let
            leave = case model.lobby of
              Nothing -> []
              Just lobby -> [ Request.send' (API.leave lobby.lobby.gameCode lobby.secret) ErrorMessage (\_ -> NoOp)
                            , Storage.Leave (Game.GameCodeAndSecret lobby.lobby.gameCode lobby.secret) |> StorageMessage |> Util.cmd
                            ]
          in
            { model | lobby = Nothing
                    , buttonsEnabled = True } !
              ([ Navigation.newUrl model.init.url
               ] ++ leave)

        Lobby.LocalMessage message ->
          case model.lobby of
            Nothing ->
              (model, Cmd.none)

            Just lobby ->
              let
                (newLobby, cmd) = Lobby.update message lobby
              in
                ({ model | lobby = Just newLobby }, Cmd.map LobbyMessage cmd)

    Batch messages ->
      (model, messages |> List.map Util.cmd |> Cmd.batch)

    NoOp ->
      (model, Cmd.none)


title : String
title = "Massive Decks"


newPlayerErrorHandler : API.NewPlayerError -> Message
newPlayerErrorHandler error =
  let
    errorMessage = case error of
      API.NameInUse -> (Name, Just "This name is already in use in this game, try something else." |> Input.Error) |> InputMessage
      API.NewPlayerLobbyNotFound -> (GameCode, Just "This game doesn't exist - check you have the right code." |> Input.Error) |> InputMessage
  in
    Batch [ SetButtonsEnabled True, errorMessage ]


getLobbyAndHandErrorHandler : Game.GameCodeAndSecret -> API.GetLobbyAndHandError -> Message
getLobbyAndHandErrorHandler gameCodeAndSecret error =
  let
    errorMessage = case error of
      API.LobbyNotFound -> ClearExistingGame gameCodeAndSecret
  in
    Batch [ SetButtonsEnabled True, errorMessage ]
