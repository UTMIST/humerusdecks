module MassiveDecks.Pages.Lobby.Configure exposing
    ( applyChange
    , init
    , update
    , updateFromConfig
    , view
    )

import Dict exposing (Dict)
import FontAwesome.Attributes as Icon
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Events as HtmlE
import MassiveDecks.Card.Source as Source
import MassiveDecks.Card.Source.Cardcast.Model as Cardcast
import MassiveDecks.Card.Source.Model as Source exposing (Source)
import MassiveDecks.Components as Components
import MassiveDecks.Components.Form as Form
import MassiveDecks.Components.Form.Message as Message exposing (Message)
import MassiveDecks.Game.Round as Round
import MassiveDecks.Game.Rules as Rules
import MassiveDecks.Messages as Global
import MassiveDecks.Model exposing (..)
import MassiveDecks.Pages.Lobby.Actions as Actions
import MassiveDecks.Pages.Lobby.Configure.Messages exposing (..)
import MassiveDecks.Pages.Lobby.Configure.Model exposing (..)
import MassiveDecks.Pages.Lobby.Events as Events
import MassiveDecks.Pages.Lobby.GameCode as GameCode exposing (GameCode)
import MassiveDecks.Pages.Lobby.Invite as Invite
import MassiveDecks.Pages.Lobby.Messages as Lobby
import MassiveDecks.Pages.Lobby.Model as Lobby exposing (Lobby)
import MassiveDecks.Strings as Strings exposing (MdString)
import MassiveDecks.Strings.Languages as Lang
import MassiveDecks.User as User exposing (User)
import MassiveDecks.Util.Html as Html
import MassiveDecks.Util.Html.Attributes as HtmlA
import MassiveDecks.Util.Maybe as Maybe
import MassiveDecks.Util.Result as Result
import Weightless as Wl
import Weightless.Attributes as WlA


init : Model
init =
    { deckToAdd = Source.default
    , deckErrors = []
    , handSize = 10
    , scoreLimit = Just 25
    , tab = Decks
    , password = Nothing
    , passwordVisible = False
    , houseRules =
        { rando = Nothing
        , packingHeat = Nothing
        , reboot = Nothing
        }
    , public = False
    , timeLimits = Rules.defaultTimeLimits
    }


updateFromConfig : Config -> Model -> Model
updateFromConfig config model =
    { deckToAdd = model.deckToAdd
    , deckErrors = model.deckErrors
    , tab = model.tab
    , handSize = config.rules.handSize
    , scoreLimit = config.rules.scoreLimit
    , password = config.password
    , passwordVisible = model.passwordVisible
    , houseRules = config.rules.houseRules
    , public = config.public
    , timeLimits = config.rules.timeLimits
    }


update : Msg -> Model -> Config -> ( Model, Cmd msg )
update msg model config =
    case msg of
        AddDeck source ->
            ( { model | deckToAdd = Source.emptyMatching source }, Actions.addDeck config.version source )

        RemoveDeck source ->
            ( model, Actions.removeDeck config.version source )

        UpdateSource source ->
            ( { model | deckToAdd = source }, Cmd.none )

        ChangeTab t ->
            ( { model | tab = t }, Cmd.none )

        StartGame ->
            ( model, Actions.startGame )

        HandSizeChange target value ->
            ( { model | handSize = value }, ifRemote (Actions.setHandSize value config.version) target )

        ScoreLimitChange target value ->
            ( { model | scoreLimit = value }, ifRemote (Actions.setScoreLimit value config.version) target )

        PasswordChange target value ->
            let
                send =
                    ifRemote (Actions.setPassword value config.version) target

                cmd =
                    case value of
                        Just pw ->
                            Maybe.justIf (String.length pw >= 1) send |> Maybe.withDefault Cmd.none

                        Nothing ->
                            send
            in
            ( { model | password = value }, cmd )

        TogglePasswordVisibility ->
            ( { model | passwordVisible = not model.passwordVisible }, Cmd.none )

        HouseRuleChange target value ->
            let
                send =
                    ifRemote (Actions.changeHouseRule value config.version) target
            in
            ( { model | houseRules = model.houseRules |> Rules.apply value }, send )

        PublicChange target value ->
            let
                send =
                    ifRemote (Actions.setPublic value config.version) target
            in
            ( { model | public = value }, send )

        TimeLimitChangeMode target value ->
            let
                timeLimits =
                    model.timeLimits

                send =
                    ifRemote (Actions.changeTimeLimitMode value config.version) target
            in
            ( { model | timeLimits = { timeLimits | mode = value } }, send )

        TimeLimitChange target stage value ->
            let
                timeLimits =
                    model.timeLimits

                send =
                    ifRemote (Actions.changeTimeLimitForStage stage value config.version) target
            in
            ( { model | timeLimits = Rules.setTimeLimitByStage stage value timeLimits }, send )


view : Shared -> Bool -> Model -> GameCode -> Lobby -> Config -> Html Global.Msg
view shared canEdit model gameCode lobby config =
    Html.div [ HtmlA.class "configure" ]
        [ Wl.card []
            [ Html.div [ HtmlA.class "title" ]
                [ Html.h2 [] [ lobby.name |> Html.text ]
                , Html.div []
                    [ Invite.button shared
                    , Strings.GameCode { code = GameCode.toString gameCode } |> Lang.html shared
                    ]
                ]
            , Wl.tabGroup [ WlA.align WlA.Center ] (tabs |> List.map (tab shared model.tab))
            , tabContent shared canEdit model config
            ]
        , Wl.card []
            [ startGameSegment shared canEdit lobby config
            ]
        ]


applyChange : Events.ConfigChanged -> Config -> Model -> ( Config, Model )
applyChange configChange oldConfig oldConfigure =
    let
        oldRules =
            oldConfig.rules

        oldTimeLimits =
            oldRules.timeLimits

        oldConfigureTimeLimits =
            oldConfigure.timeLimits
    in
    case configChange of
        Events.DecksChanged decksChanged ->
            applyDeckChange decksChanged oldConfig oldConfigure

        Events.HandSizeSet { size } ->
            ( { oldConfig | rules = { oldRules | handSize = size } }, { oldConfigure | handSize = size } )

        Events.ScoreLimitSet { limit } ->
            ( { oldConfig | rules = { oldRules | scoreLimit = limit } }, { oldConfigure | scoreLimit = limit } )

        Events.PasswordSet { password } ->
            ( { oldConfig | password = password }
            , { oldConfigure | password = password }
            )

        Events.HouseRuleChanged { change } ->
            ( { oldConfig | rules = { oldRules | houseRules = oldRules.houseRules |> Rules.apply change } }
            , { oldConfigure | houseRules = oldConfigure.houseRules |> Rules.apply change }
            )

        Events.PublicSet { public } ->
            ( { oldConfig | public = public }
            , { oldConfigure | public = public }
            )

        Events.ChangeTimeLimitForStage { stage, timeLimit } ->
            ( { oldConfig | rules = { oldRules | timeLimits = Rules.setTimeLimitByStage stage timeLimit oldTimeLimits } }
            , { oldConfigure | timeLimits = Rules.setTimeLimitByStage stage timeLimit oldConfigureTimeLimits }
            )

        Events.ChangeTimeLimitMode { mode } ->
            ( { oldConfig | rules = { oldRules | timeLimits = { oldTimeLimits | mode = mode } } }
            , { oldConfigure | timeLimits = { oldConfigureTimeLimits | mode = mode } }
            )



{- Private -}


startGameSegment : Shared -> Bool -> Lobby -> Config -> Html Global.Msg
startGameSegment shared canEdit lobby config =
    let
        startErrors =
            startGameProblems lobby.users config

        startGameAttrs =
            if List.isEmpty startErrors && canEdit then
                [ StartGame |> lift |> HtmlE.onClick ]

            else
                [ WlA.disabled ]
    in
    Form.section shared
        "start-game"
        (Wl.button startGameAttrs [ Strings.StartGame |> Lang.html shared ])
        (startErrors |> Maybe.justIf canEdit |> Maybe.withDefault [])


addSummary : Source.External -> Source.Summary -> Deck -> Deck
addSummary target summary deckSource =
    if deckSource.source == target then
        Deck target (Just summary)

    else
        deckSource


applyDeckChange : { change : Events.DeckChange, deck : Source.External } -> Config -> Model -> ( Config, Model )
applyDeckChange event config configure =
    let
        change =
            event.change

        deckSource =
            event.deck

        newConfig =
            case change of
                Events.Add ->
                    { config | decks = config.decks ++ [ Deck deckSource Nothing ] }

                Events.Remove ->
                    { config | decks = config.decks |> List.filter (.source >> (/=) deckSource) }

                Events.Load { summary } ->
                    { config | decks = config.decks |> List.map (addSummary deckSource summary) }

                Events.Fail _ ->
                    { config | decks = config.decks |> List.filter (.source >> (/=) deckSource) }

        newConfigure =
            case change of
                Events.Fail { reason } ->
                    { configure | deckErrors = { deck = deckSource, reason = reason } :: configure.deckErrors }

                _ ->
                    configure
    in
    ( newConfig, newConfigure )


startGameProblems : Dict User.Id User -> Config -> List (Message Global.Msg)
startGameProblems users config =
    let
        -- We assume decks will have calls/responses.
        summaries =
            \getTypeAmount -> config.decks |> List.map (.summary >> Maybe.map getTypeAmount >> Maybe.withDefault 1)

        noDecks =
            List.length config.decks == 0

        loadingDecks =
            config.decks |> List.any (.summary >> Maybe.isNothing)

        deckIssues =
            if noDecks then
                [ Message.errorWithFix
                    Strings.NeedAtLeastOneDeck
                    [ { description = Strings.NoDecksHint
                      , icon = Icon.plus
                      , action = "CAHBS" |> Cardcast.playCode |> Source.Cardcast |> AddDeck |> lift
                      }
                    ]
                    |> Just
                ]

            else if loadingDecks then
                [ Strings.WaitForDecks |> Message.info |> Just ]

            else
                [ Strings.MissingCardType { cardType = Strings.Call }
                    |> Message.error
                    |> Maybe.justIf ((summaries .calls |> List.sum) < 1)
                , Strings.MissingCardType { cardType = Strings.Response }
                    |> Message.error
                    |> Maybe.justIf ((summaries .responses |> List.sum) < 1)
                ]

        playerCount =
            users
                |> Dict.values
                |> List.filter (\user -> user.role == User.Player && user.presence == User.Joined)
                |> List.length

        aiPlayers =
            config.rules.houseRules.rando |> Maybe.map .number |> Maybe.withDefault 0

        playerIssues =
            [ Message.errorWithFix
                Strings.NeedAtLeastThreePlayers
                [ { description = Strings.Invite
                  , icon = Icon.bullhorn
                  , action = Lobby.ToggleInviteDialog |> Global.LobbyMsg
                  }
                , { description = Strings.AddAnAiPlayer
                  , icon = Icon.robot
                  , action =
                        { number = 3 - playerCount + aiPlayers }
                            |> Just
                            |> Rules.RandoChange
                            |> HouseRuleChange Remote
                            |> Lobby.ConfigureMsg
                            |> Global.LobbyMsg
                  }
                ]
                |> Maybe.justIf (playerCount < 3)
            ]
    in
    [ deckIssues, playerIssues ] |> List.concat |> List.filterMap identity


ifRemote : Cmd msg -> Target -> Cmd msg
ifRemote cmd target =
    case target of
        Local ->
            Cmd.none

        Remote ->
            cmd


tabs : List Tab
tabs =
    [ Decks, Rules, TimeLimits, Privacy ]


tab : Shared -> Tab -> Tab -> Html Global.Msg
tab shared currently target =
    Wl.tab
        ((target |> ChangeTab |> lift |> always |> HtmlE.onCheck)
            :: ([ WlA.checked ] |> Maybe.justIf (currently == target) |> Maybe.withDefault [])
        )
        [ target |> tabName |> Lang.html shared ]


tabName : Tab -> MdString
tabName target =
    case target of
        Decks ->
            Strings.ConfigureDecks

        Rules ->
            Strings.ConfigureRules

        TimeLimits ->
            Strings.ConfigureTimeLimits

        Privacy ->
            Strings.ConfigurePrivacy


tabContent : Shared -> Bool -> Model -> Config -> Html Global.Msg
tabContent shared canEdit model config =
    let
        viewTab =
            case model.tab of
                Decks ->
                    configureDecks

                Rules ->
                    configureRules

                TimeLimits ->
                    configureTimeLimits

                Privacy ->
                    configurePrivacy
    in
    viewTab shared canEdit model config


configureRules : Shared -> Bool -> Model -> Config -> Html Global.Msg
configureRules shared canEdit model config =
    let
        viewOpt =
            viewOption shared model config Global.NoOp canEdit
    in
    Html.div [ HtmlA.id "rules-tab" ]
        [ Html.div [ HtmlA.class "core-rules" ]
            [ Html.h3 [] [ Strings.GameRulesTitle |> Lang.html shared ]
            , viewOpt handSizeOption
            , viewOpt scoreLimitOption
            ]
        , houseRules shared canEdit model config
        ]


handSizeOption : ConfigOption Int Global.Msg
handSizeOption =
    { id = "hand-size-option"
    , toggleable = Nothing
    , primaryEditor =
        TextField
            { placeholder = Strings.HandSize
            , inputType = Nothing
            , toString = String.fromInt >> Just
            , fromString = String.toInt
            , attrs = [ 3 |> WlA.min, 50 |> WlA.max ]
            }
    , extraEditor = Nothing
    , getRemoteValue = .rules >> .handSize
    , getLocalValue = .handSize
    , set = \t -> \v -> HandSizeChange t v |> lift
    , validate = \v -> v >= 3 && v <= 50
    , messages = [ Message.info Strings.HandSizeDescription ]
    }


scoreLimitOption : ConfigOption (Maybe Int) Global.Msg
scoreLimitOption =
    { id = "score-limit-option"
    , toggleable = Just { off = Nothing, on = Just 25 }
    , primaryEditor =
        TextField
            { placeholder = Strings.ScoreLimit
            , inputType = Nothing
            , toString = Maybe.map String.fromInt
            , fromString = String.toInt >> Maybe.map Just
            , attrs = [ 1 |> WlA.min, 10000 |> WlA.max ]
            }
    , extraEditor = Nothing
    , getRemoteValue = .rules >> .scoreLimit
    , getLocalValue = .scoreLimit
    , set = \t -> \v -> ScoreLimitChange t v |> lift
    , validate = Maybe.map (\v -> v >= 1 && v <= 10000) >> Maybe.withDefault True
    , messages = [ Message.info Strings.ScoreLimitDescription ]
    }


houseRules : Shared -> Bool -> Model -> Config -> Html Global.Msg
houseRules shared canEdit model config =
    Html.div [ HtmlA.class "house-rules" ]
        [ Html.h3 [] [ Strings.HouseRulesTitle |> Lang.html shared ]
        , rando shared canEdit model config
        , packingHeat shared canEdit model config
        , reboot shared canEdit model config
        ]


type alias ViewHouseRuleSettings houseRule =
    Shared -> Bool -> houseRule -> (houseRule -> Global.Msg) -> List (Html Global.Msg)


houseRule : Shared -> String -> Rules.HouseRule a -> Bool -> Model -> Config -> ViewHouseRuleSettings a -> Html Global.Msg
houseRule shared id { default, change, title, description, extract, validate } canEdit model config viewSettings =
    let
        localValue =
            model.houseRules |> extract

        enabled =
            localValue |> Maybe.isJust

        toggle =
            \checked ->
                default
                    |> Maybe.justIf checked
                    |> change
                    |> HouseRuleChange Remote
                    |> lift

        save =
            localValue |> change |> HouseRuleChange Remote |> lift |> HtmlE.onClick

        saved =
            localValue == (config.rules.houseRules |> extract)

        validated =
            localValue |> Maybe.map validate |> Maybe.withDefault True

        settings =
            localValue
                |> Maybe.map (\v -> viewSettings shared canEdit v (Just >> change >> HouseRuleChange Local >> lift))
                |> Maybe.withDefault []

        ( saveIcon, message ) =
            if saved then
                ( Icon.check, Strings.AppliedConfiguration )

            else if validated then
                ( Icon.save, Strings.ApplyConfiguration )

            else
                ( Icon.times, Strings.InvalidConfiguration )
    in
    Html.div [ HtmlA.classList [ ( "house-rule", True ), ( "enabled", enabled ) ] ]
        [ Form.section
            shared
            id
            (Html.div [ HtmlA.class "multipart" ]
                [ Wl.switch
                    [ WlA.disabled |> Maybe.justIf (not canEdit) |> Maybe.withDefault (toggle |> HtmlE.onCheck)
                    , WlA.checked |> Maybe.justIf enabled |> Maybe.withDefault HtmlA.nothing
                    ]
                , Html.h4 [ HtmlA.class "primary" ] [ Lang.html shared title ]
                , Components.iconButton
                    [ save
                    , WlA.disabled |> Maybe.justIf (saved || not validated) |> Maybe.withDefault HtmlA.nothing
                    , Lang.title shared message
                    ]
                    saveIcon
                ]
            )
            [ Message.info (localValue |> description) ]
        , Html.div [ HtmlA.class "house-rule-settings" ] settings
        ]


rando : Shared -> Bool -> Model -> Config -> Html Global.Msg
rando shared canEdit model config =
    houseRule shared "rando" Rules.rando canEdit model config randoSettings


randoSettings : Shared -> Bool -> Rules.Rando -> (Rules.Rando -> Global.Msg) -> List (Html Global.Msg)
randoSettings shared canEdit value localChange =
    [ Form.section
        shared
        "rando-number"
        (Wl.textField
            [ Strings.HouseRuleRandoCardrissianNumber |> Lang.label shared
            , HtmlA.class "primary"
            , WlA.type_ WlA.Number
            , WlA.min 1
            , WlA.max 10
            , Maybe.justIf (not canEdit) WlA.disabled |> Maybe.withDefault HtmlA.nothing
            , value.number |> String.fromInt |> WlA.value
            , String.toInt
                >> Maybe.map (\n -> { value | number = n } |> localChange)
                >> Maybe.withDefault Global.NoOp
                |> HtmlE.onInput
            ]
            []
        )
        [ Strings.HouseRuleRandoCardrissianNumberDescription |> Message.info ]
    ]


packingHeat : Shared -> Bool -> Model -> Config -> Html Global.Msg
packingHeat shared canEdit model config =
    houseRule shared "packing-heat" Rules.packingHeat canEdit model config packingHeatSettings


packingHeatSettings : Shared -> Bool -> Rules.PackingHeat -> (Rules.PackingHeat -> Global.Msg) -> List (Html Global.Msg)
packingHeatSettings shared canEdit value localChange =
    []


reboot : Shared -> Bool -> Model -> Config -> Html Global.Msg
reboot shared canEdit model config =
    houseRule shared "reboot" Rules.reboot canEdit model config rebootSettings


rebootSettings : Shared -> Bool -> Rules.Reboot -> (Rules.Reboot -> Global.Msg) -> List (Html Global.Msg)
rebootSettings shared canEdit value localChange =
    [ Form.section
        shared
        "reboot-cost"
        (Wl.textField
            [ Strings.HouseRuleRebootCost |> Lang.label shared
            , HtmlA.class "primary"
            , WlA.type_ WlA.Number
            , WlA.min 1
            , WlA.max 50
            , Maybe.justIf (not canEdit) WlA.disabled |> Maybe.withDefault HtmlA.nothing
            , value.cost |> String.fromInt |> WlA.value
            , String.toInt
                >> Maybe.map (\c -> { value | cost = c } |> localChange)
                >> Maybe.withDefault Global.NoOp
                |> HtmlE.onInput
            ]
            []
        )
        [ Strings.HouseRuleRebootCostDescription |> Message.info ]
    ]


configureDecks : Shared -> Bool -> Model -> Config -> Html Global.Msg
configureDecks shared canEdit model config =
    let
        hint =
            if canEdit then
                Components.linkButton
                    [ "CAHBS" |> Cardcast.playCode |> Source.Cardcast |> AddDeck |> lift |> HtmlE.onClick
                    ]
                    [ Strings.NoDecksHint |> Lang.html shared ]

            else
                Html.nothing

        tableContent =
            if List.isEmpty config.decks then
                [ Html.tr [ HtmlA.class "empty-info" ]
                    [ Html.td [ HtmlA.colspan 3 ]
                        [ Html.p []
                            [ Icon.viewIcon Icon.ghost
                            , Html.text " "
                            , Strings.NoDecks |> Lang.html shared
                            ]
                        , hint
                        ]
                    ]
                ]

            else
                config.decks |> List.map (deck shared canEdit)

        editor =
            if canEdit then
                [ addDeckWidget shared config.decks model.deckToAdd
                ]

            else
                []
    in
    Html.div [ HtmlA.id "decks-tab", HtmlA.class "compressed-terms" ]
        (List.concat
            [ [ Html.h3 [] [ Strings.ConfigureDecks |> Lang.html shared ]
              , Html.table []
                    [ Html.colgroup []
                        [ Html.col [ HtmlA.class "deck-name" ] []
                        , Html.col [ HtmlA.class "count" ] []
                        , Html.col [ HtmlA.class "count" ] []
                        ]
                    , Html.thead []
                        [ Html.tr []
                            [ Html.th [ HtmlA.class "deck-name", HtmlA.scope "col" ] [ Strings.Deck |> Lang.html shared ]
                            , Html.th [ HtmlA.scope "col" ] [ Strings.Call |> Lang.html shared ]
                            , Html.th [ HtmlA.scope "col" ] [ Strings.Response |> Lang.html shared ]
                            ]
                        ]
                    , Html.tbody [] tableContent
                    ]
              ]
            , editor
            ]
        )


configurePrivacy : Shared -> Bool -> Model -> Config -> Html Global.Msg
configurePrivacy shared canEdit model config =
    let
        viewOpt =
            viewOption shared model config Global.NoOp canEdit
    in
    Html.div [ HtmlA.id "privacy-tab" ]
        [ Html.h3 [] [ Strings.ConfigurePrivacy |> Lang.html shared ]
        , viewOpt publicGameOption
        , viewOpt (gamePasswordOption model)
        ]


addDeckWidget : Shared -> List Deck -> Source.External -> Html Global.Msg
addDeckWidget shared existing deckToAdd =
    let
        submit =
            deckToAdd |> submitDeckAction existing
    in
    Html.form
        [ submit |> Result.map (lift >> HtmlE.onSubmit) |> Result.withDefault HtmlA.nothing ]
        [ Form.section
            shared
            "add-deck"
            (Html.div [ HtmlA.class "multipart" ]
                [ Wl.select
                    [ HtmlA.id "source-selector"
                    , WlA.outlined
                    , HtmlE.onInput (Source.empty >> Maybe.withDefault Source.default >> UpdateSource >> lift)
                    ]
                    [ Html.option [ HtmlA.value "Cardcast" ]
                        [ Html.text "Cardcast"
                        ]
                    ]
                , Source.editor shared (deckToAdd |> Source.Ex) (UpdateSource >> lift)
                , Components.floatingActionButton
                    [ HtmlA.type_ "submit"
                    , Result.isError submit |> HtmlA.disabled
                    , Strings.AddDeck |> Lang.title shared
                    ]
                    Icon.plus
                ]
            )
            [ submit |> Result.error |> Maybe.withDefault Nothing ]
        ]


submitDeckAction : List Deck -> Source.External -> Result (Message Global.Msg) Msg
submitDeckAction existing deckToAdd =
    let
        potentialProblem =
            if List.any (.source >> Source.Ex >> Source.equals (Source.Ex deckToAdd)) existing then
                Strings.DeckAlreadyAdded |> Message.error |> Just

            else
                Source.validate (Source.Ex deckToAdd)
    in
    case potentialProblem of
        Just problem ->
            problem |> Result.Err

        Nothing ->
            deckToAdd |> AddDeck |> Result.Ok


lift : Msg -> Global.Msg
lift =
    Lobby.ConfigureMsg >> Global.LobbyMsg


deck : Shared -> Bool -> Deck -> Html Global.Msg
deck shared canEdit givenDeck =
    let
        source =
            givenDeck.source

        row =
            case givenDeck.summary of
                Just summary ->
                    [ Html.td [] [ name shared canEdit source False summary.details ]
                    , Html.td [] [ summary.calls |> String.fromInt |> Html.text ]
                    , Html.td [] [ summary.responses |> String.fromInt |> Html.text ]
                    ]

                Nothing ->
                    [ Html.td [ HtmlA.colspan 3 ] [ source |> Source.Ex |> Source.details |> name shared canEdit source True ]
                    ]
    in
    Html.tr [ HtmlA.class "deck-row" ] row


name : Shared -> Bool -> Source.External -> Bool -> Source.Details -> Html Global.Msg
name shared canEdit source loading details =
    let
        removeButton =
            if canEdit then
                [ Components.iconButton
                    [ source |> RemoveDeck |> lift |> HtmlE.onClick
                    , Strings.RemoveDeck |> Lang.title shared
                    , HtmlA.class "remove-button"
                    ]
                    Icon.minus
                ]

            else
                []

        ( maybeId, maybeTooltip ) =
            source |> Source.Ex |> Source.tooltip |> Maybe.decompose

        attrs =
            maybeId |> Maybe.map (\id -> [ HtmlA.id id ]) |> Maybe.withDefault []

        nameText =
            Html.text details.name

        tooltip =
            maybeTooltip |> Maybe.map (\t -> [ t ]) |> Maybe.withDefault []

        linkOrText =
            [ Html.span attrs [ Maybe.transformWith nameText makeLink details.url ] ]

        spinner =
            if loading then
                [ Icon.viewStyled [ Icon.spin ] Icon.circleNotch ]

            else
                []
    in
    Html.td [ HtmlA.class "name" ] (List.concat [ linkOrText, removeButton, spinner, tooltip ])


makeLink : Html msg -> String -> Html msg
makeLink text url =
    Html.blankA [ HtmlA.href url ] [ text ]


configureTimeLimits : Shared -> Bool -> Model -> Config -> Html Global.Msg
configureTimeLimits shared canEdit model config =
    let
        viewOpt =
            viewOption shared model config Global.NoOp canEdit

        stageLimit =
            \s -> \d -> \t -> stageLimitOption s d t |> viewOpt
    in
    Html.div [ HtmlA.id "time-limits-tab" ]
        [ Html.h3 [] [ Strings.ConfigureTimeLimits |> Lang.html shared ]
        , viewOpt timeLimitModeOption
        , stageLimit Round.SPlaying Strings.PlayingTimeLimitDescription True
        , stageLimit Round.SRevealing Strings.RevealingTimeLimitDescription True
        , stageLimit Round.SJudging Strings.JudgingTimeLimitDescription True
        , stageLimit Round.SComplete Strings.CompleteTimeLimitDescription False
        ]


timeLimitModeOption : ConfigOption Rules.TimeLimitMode Global.Msg
timeLimitModeOption =
    { id = "time-limit-mode"
    , toggleable = Just { off = Rules.Soft, on = Rules.Hard }
    , primaryEditor = Label { text = Strings.Automatic }
    , extraEditor = Nothing
    , getRemoteValue = .rules >> .timeLimits >> .mode
    , getLocalValue = .timeLimits >> .mode
    , set = \t -> \v -> TimeLimitChangeMode t v |> lift
    , validate = always True
    , messages = [ Message.info Strings.AutomaticDescription ]
    }


stageLimitOption : Round.Stage -> MdString -> Bool -> ConfigOption (Maybe Float) Global.Msg
stageLimitOption stage description toggleable =
    { id = "stage-limit-" ++ (stage |> Round.stageToName)
    , toggleable =
        { off = Nothing
        , on = Rules.defaultTimeLimits |> Rules.getTimeLimitByStage stage
        }
            |> Maybe.justIf toggleable
    , primaryEditor =
        TextField
            { placeholder = Strings.TimeLimit { stage = stage |> Round.stageDescription }
            , inputType = Just WlA.Number
            , toString = Maybe.map String.fromFloat
            , fromString = String.toFloat >> Maybe.map Just
            , attrs = [ WlA.min 0, WlA.max 900 ]
            }
    , extraEditor = Nothing
    , getRemoteValue = .rules >> .timeLimits >> Rules.getTimeLimitByStage stage
    , getLocalValue = .timeLimits >> Rules.getTimeLimitByStage stage
    , set = \t -> \v -> TimeLimitChange t stage v |> lift
    , validate = Maybe.map (\v -> v >= 0 && v <= 900) >> Maybe.withDefault True
    , messages =
        [ Message.info description ]
    }


publicGameOption : ConfigOption Bool Global.Msg
publicGameOption =
    { id = "public-option"
    , toggleable = Just { off = False, on = True }
    , primaryEditor = Label { text = Strings.Public }
    , extraEditor = Nothing
    , getRemoteValue = .public
    , getLocalValue = .public
    , set = \t -> \v -> PublicChange t v |> lift
    , validate = always True
    , messages = [ Message.info Strings.PublicDescription ]
    }


gamePasswordOption : Model -> ConfigOption (Maybe String) Global.Msg
gamePasswordOption model =
    { id = "game-password-option"
    , toggleable = Just { off = Nothing, on = Just "" }
    , primaryEditor =
        TextField
            { placeholder = Strings.LobbyPassword
            , inputType = WlA.Password |> Maybe.justIf (not model.passwordVisible)
            , toString = identity
            , fromString = Just >> Just
            , attrs = [ WlA.minLength 1 ]
            }
    , extraEditor =
        Just
            (Components.iconButton
                [ TogglePasswordVisibility |> lift |> HtmlE.onClick
                , WlA.disabled |> Maybe.justIf (Maybe.isNothing model.password) |> Maybe.withDefault HtmlA.nothing
                ]
                (Icon.eyeSlash |> Maybe.justIf model.passwordVisible |> Maybe.withDefault Icon.eye)
            )
    , getRemoteValue = .password
    , getLocalValue = .password
    , set = \t -> \v -> PasswordChange t v |> lift
    , validate = Maybe.map (String.isEmpty >> not) >> Maybe.withDefault True
    , messages =
        [ Message.info Strings.LobbyPasswordDescription
        , Message.warning Strings.PasswordShared
        , Message.warning Strings.PasswordNotSecured
        ]
    }


type alias ConfigOption value msg =
    { id : String
    , toggleable : Maybe (Toggleable value)
    , primaryEditor : PrimaryEditor value msg
    , extraEditor : Maybe (Html msg)
    , getRemoteValue : Config -> value
    , getLocalValue : Model -> value
    , set : Target -> value -> msg
    , validate : value -> Bool
    , messages : List (Message msg)
    }


type alias Toggleable value =
    { off : value
    , on : value
    }


type PrimaryEditor value msg
    = TextField
        { placeholder : MdString
        , inputType : Maybe WlA.InputType
        , toString : value -> Maybe String
        , fromString : String -> Maybe value
        , attrs : List (Html.Attribute msg)
        }
    | Label { text : MdString }


viewOption : Shared -> Model -> Config -> msg -> Bool -> ConfigOption value msg -> Html msg
viewOption shared model config noOp canEdit opt =
    let
        localValue =
            opt.getLocalValue model

        remoteValue =
            opt.getRemoteValue config

        saved =
            localValue == remoteValue

        validated =
            localValue |> opt.validate

        ( saveIcon, message ) =
            if saved then
                ( Icon.check, Strings.AppliedConfiguration )

            else if validated then
                ( Icon.save, Strings.ApplyConfiguration )

            else
                ( Icon.times, Strings.InvalidConfiguration )

        saveState =
            Components.iconButton
                [ WlA.disabled
                    |> Maybe.justIf (saved || not validated || not canEdit)
                    |> Maybe.withDefault (HtmlE.onClick (opt.set Remote localValue))
                , Lang.title shared message
                ]
                saveIcon

        primaryEditor =
            case opt.primaryEditor of
                TextField { placeholder, inputType, toString, fromString, attrs } ->
                    Wl.textField
                        ([ placeholder |> Lang.label shared
                         , WlA.outlined
                         , inputType |> Maybe.map WlA.type_ |> Maybe.withDefault HtmlA.nothing
                         , HtmlA.class "primary"
                         , localValue |> toString |> Maybe.map WlA.value |> Maybe.withDefault HtmlA.nothing
                         , fromString
                            >> Maybe.map (opt.set Local)
                            >> Maybe.withDefault noOp
                            |> HtmlE.onInput
                         , opt.set Remote localValue |> HtmlE.onBlur
                         , opt.toggleable
                            |> Maybe.andThen (\t -> Maybe.justIf (t.off == localValue) WlA.disabled)
                            |> Maybe.withDefault HtmlA.nothing
                         , WlA.disabled |> Maybe.justIf (not canEdit) |> Maybe.withDefault HtmlA.nothing
                         ]
                            ++ attrs
                        )
                        []

                Label { text } ->
                    Html.span [ HtmlA.class "primary" ] [ text |> Lang.html shared ]

        switch =
            case opt.toggleable of
                Just { off, on } ->
                    Wl.switch
                        [ WlA.checked |> Maybe.justIf (localValue /= off) |> Maybe.withDefault HtmlA.nothing
                        , HtmlE.onCheck (\c -> Maybe.justIf c on |> Maybe.withDefault off |> opt.set Remote)
                        , WlA.disabled |> Maybe.justIf (not canEdit) |> Maybe.withDefault HtmlA.nothing
                        ]
                        |> Just

                Nothing ->
                    Nothing

        contents =
            [ switch, Just primaryEditor, opt.extraEditor, Just saveState ] |> List.filterMap identity
    in
    Form.section shared opt.id (Html.div [ HtmlA.class "multipart" ] contents) opt.messages
