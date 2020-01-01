module MassiveDecks.Settings exposing
    ( auths
    , defaults
    , init
    , onJoinLobby
    , onTokenUpdate
    , subscriptions
    , update
    , view
    )

import Dict exposing (Dict)
import Dict.Extra as Dict
import FontAwesome.Attributes as Icon
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Events as HtmlE
import Http
import MassiveDecks.Components as Components
import MassiveDecks.Components.Form as Form
import MassiveDecks.Components.Form.Message as Message
import MassiveDecks.Error.Model as Error exposing (Error)
import MassiveDecks.Icon as Icon
import MassiveDecks.LocalStorage as LocalStorage
import MassiveDecks.Messages as Global
import MassiveDecks.Model exposing (..)
import MassiveDecks.Pages.Lobby.GameCode as GameCode exposing (GameCode)
import MassiveDecks.Pages.Lobby.Model as Lobby
import MassiveDecks.Pages.Lobby.Token as Token
import MassiveDecks.Requests.Api as Api
import MassiveDecks.Requests.Request as Request
import MassiveDecks.Settings.Messages exposing (..)
import MassiveDecks.Settings.Model exposing (..)
import MassiveDecks.Speech as Speech
import MassiveDecks.Strings as Strings
import MassiveDecks.Strings.Languages as Lang
import MassiveDecks.Strings.Languages.Model as Lang exposing (Language)
import Weightless as Wl
import Weightless.Attributes as WlA
import Weightless.Slider as Slider


init : Settings -> ( Model, Cmd Global.Msg )
init settings =
    let
        cmd =
            if Dict.isEmpty settings.tokens then
                Cmd.none

            else
                settings.tokens
                    |> Dict.values
                    |> Api.checkAlive (Request.map ignore ignore (RemoveInvalid >> Global.SettingsMsg))
                    |> Http.request

        ( speech, speechCmd ) =
            Speech.init
    in
    ( { settings = settings
      , open = False
      , speech = speech
      }
    , Cmd.batch [ cmd, speechCmd ]
    )


defaults : Settings
defaults =
    { tokens = Dict.empty
    , lastUsedName = Nothing
    , openUserList = False
    , recentDecks = []
    , chosenLanguage = Nothing
    , cardSize = Full
    , speech = Speech.default
    }


subscriptions : (Error -> msg) -> (Msg -> msg) -> Sub msg
subscriptions wrapError wrapMsg =
    Speech.subscriptions (Error.Json >> wrapError) (SpeechMsg >> wrapMsg)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ToggleOpen ->
            ( { model | open = not model.open }, Cmd.none )

        ChangeLang language ->
            changeSettings (\s -> { s | chosenLanguage = language }) model

        ChangeCardSize size ->
            changeSettings (\s -> { s | cardSize = size }) model

        ChangeOpenUserList open ->
            changeSettings (\s -> { s | openUserList = open }) model

        RemoveInvalid tokenValidity ->
            let
                newTokens =
                    model.settings.tokens
                        |> Dict.filter (\_ -> \t -> Dict.get t tokenValidity |> Maybe.withDefault True)
            in
            changeSettings (\s -> { s | tokens = newTokens }) model

        ToggleSpeech enabled ->
            let
                newSpeechSettings =
                    model.settings.speech |> Speech.toggle enabled
            in
            changeSettings (\s -> { s | speech = newSpeechSettings }) model

        ChangeSpeech voice ->
            let
                newSpeechSettings =
                    model.settings.speech |> Speech.selectVoice voice
            in
            changeSettings (\s -> { s | speech = newSpeechSettings }) model

        SpeechMsg speechMsg ->
            ( { model | speech = model.speech |> Speech.update speechMsg }, Cmd.none )


view : Shared -> Html Global.Msg
view shared =
    let
        model =
            shared.settings

        icon =
            if model.open then
                Icon.check

            else
                Icon.cog

        button =
            Components.iconButtonStyled
                [ HtmlA.id "settings-button"
                , ToggleOpen |> Global.SettingsMsg |> HtmlE.onClick
                , Strings.SettingsTitle |> Lang.title shared
                ]
                ( [ Icon.lg ], icon )

        panel =
            Wl.card [ HtmlA.classList [ ( "settings-panel", True ), ( "open", model.open ) ] ]
                [ Html.h3 [] [ Strings.SettingsTitle |> Lang.html shared ]
                , Html.div [ HtmlA.class "body" ]
                    [ languageSelector shared
                    , cardSize shared
                    , speechVoiceSelector shared
                    , notificationsSwitch shared
                    ]
                ]
    in
    Html.div [] [ button, panel ]


{-| Add a token to the token list and set the last used name, because the user has joined a lobby.
We take an `Auth` here even though we don't really use it to ensure the token has been successfully parsed.
-}
onJoinLobby : Lobby.Auth -> String -> Model -> ( Model, Cmd msg )
onJoinLobby auth name model =
    let
        settings =
            model.settings

        updatedSettings =
            { settings
                | tokens = Dict.insert (auth.claims.gc |> GameCode.toString) auth.token settings.tokens
                , lastUsedName = Just name
            }
    in
    ( { model | settings = updatedSettings }, LocalStorage.store updatedSettings )


{-| Replace a token in our storage because it has been updated.
-}
onTokenUpdate : Lobby.Auth -> Model -> ( Model, Cmd msg )
onTokenUpdate auth model =
    let
        settings =
            model.settings

        updatedSettings =
            { settings
                | tokens = Dict.insert (auth.claims.gc |> GameCode.toString) auth.token settings.tokens
            }
    in
    ( { model | settings = updatedSettings }, LocalStorage.store updatedSettings )


{-| Get all the tokens in settings as `Auth`s by game code.
-}
auths : Settings -> Dict String Lobby.Auth
auths settings =
    -- Only legit tokens should be in settings, so we ignore any that aren't.
    settings.tokens
        |> Dict.filterMap (\_ -> \v -> v |> Token.decode |> Result.toMaybe)



{- Private -}


ignore : anything -> Global.Msg
ignore =
    always Global.NoOp


changeSettings : (Settings -> Settings) -> Model -> ( Model, Cmd msg )
changeSettings f model =
    let
        settings =
            f model.settings
    in
    ( { model | settings = settings }, LocalStorage.store settings )


cardSize : Shared -> Html Global.Msg
cardSize shared =
    let
        settings =
            shared.settings.settings
    in
    Form.section shared
        "card-size"
        (Html.div
            [ HtmlA.class "multipart" ]
            [ Wl.slider
                [ HtmlA.class "primary"
                , Slider.step 1
                , Slider.min 1
                , Slider.max 3
                , WlA.label "Card Size"
                , WlA.outlined
                , Slider.thumbLabel True
                , String.toInt
                    >> Maybe.andThen cardSizeFromValue
                    >> Maybe.withDefault Full
                    >> ChangeCardSize
                    >> Global.SettingsMsg
                    |> HtmlE.onInput
                , settings.cardSize |> cardSizeToValue |> String.fromInt |> WlA.value
                ]
                [ Icon.viewStyled [ Slider.slot Slider.Before ] Icon.searchMinus
                , [ settings.cardSize |> cardSizeThumb ] |> Html.span [ Slider.slot Slider.ThumbLabel ]
                , Icon.viewStyled [ Slider.slot Slider.After ] Icon.searchPlus
                ]
            ]
        )
        [ Message.info Strings.CardSizeExplanation ]


cardSizeThumb : CardSize -> Html msg
cardSizeThumb size =
    case size of
        Minimal ->
            Icon.viewIcon Icon.minimalCardSize

        Square ->
            Icon.viewIcon Icon.squareCardSize

        Full ->
            Icon.viewIcon Icon.callCard


speechVoiceSelector : Shared -> Html Global.Msg
speechVoiceSelector shared =
    let
        selectedVoice =
            shared.settings.settings.speech.selectedVoice

        voices =
            shared.settings.speech.voices

        enabled =
            shared.settings.settings.speech.enabled

        isDisabled =
            List.isEmpty voices

        notPossibleWarning =
            if isDisabled then
                Message.warning Strings.SpeechNotSupportedExplanation

            else
                Message.none
    in
    Html.div []
        [ Form.section shared
            "speech"
            (Html.div []
                [ Html.div
                    [ HtmlA.class "multipart" ]
                    [ Wl.switch
                        [ HtmlE.onCheck (ToggleSpeech >> Global.SettingsMsg)
                        , HtmlA.disabled isDisabled
                        , HtmlA.checked enabled
                        ]
                    , Html.label []
                        [ Icon.viewIcon Icon.commentDots
                        , Html.text " "
                        , Strings.SpeechSetting |> Lang.html shared
                        ]
                    ]
                , Wl.select
                    [ HtmlE.onInput (ChangeSpeech >> Global.SettingsMsg)
                    , Strings.VoiceSetting |> Lang.string shared |> WlA.label
                    , WlA.outlined
                    , HtmlA.disabled (not enabled || isDisabled)
                    ]
                    (voices |> List.sortWith defaultFirst |> List.map (speechVoiceOption selectedVoice))
                ]
            )
            [ Message.info Strings.SpeechExplanation
            , notPossibleWarning
            ]
        ]


defaultFirst : Speech.Voice -> Speech.Voice -> Order
defaultFirst a b =
    if a.default && b.default then
        EQ

    else if a.default then
        LT

    else
        GT


speechVoiceOption : Maybe String -> Speech.Voice -> Html Global.Msg
speechVoiceOption selectedVoice voice =
    let
        selected =
            if selectedVoice == Just voice.name then
                [ WlA.selected ]

            else
                []
    in
    Html.option
        (HtmlA.value voice.name :: selected)
        [ Html.text (voice.name ++ " (" ++ voice.lang ++ ")") ]


notificationsSwitch : Shared -> Html Global.Msg
notificationsSwitch shared =
    -- TODO: Impl
    Form.section shared
        "notifications"
        (Html.div
            [ HtmlA.class "multipart" ]
            [ Wl.switch [ WlA.disabled ]
            , Html.label []
                [ Icon.viewIcon Icon.bell
                , Html.text " "
                , Strings.NotificationsSetting |> Lang.html shared
                ]
            ]
        )
        [ Message.info Strings.NotificationsExplanation
        , Message.info Strings.NotificationsBrowserPermissions
        ]


languageSelector : Shared -> Html Global.Msg
languageSelector shared =
    let
        selected =
            Lang.currentLanguage shared
    in
    Form.section
        shared
        "language"
        (Wl.select
            [ HtmlE.onInput onChangeLang
            , Strings.LanguageSetting |> Lang.string shared |> WlA.label
            , WlA.outlined
            ]
            (Lang.languages |> List.map (languageOption selected))
        )
        [ Message.info Strings.MissingLanguage ]


onChangeLang : String -> Global.Msg
onChangeLang code =
    Lang.fromCode code |> ChangeLang |> Global.SettingsMsg


languageOption : Language -> Language -> Html msg
languageOption currentLanguage language =
    let
        autonym =
            language |> Lang.autonym

        nameInCurrentLanguage =
            language |> Lang.languageName |> Lang.givenLanguageString currentLanguage

        name =
            if autonym == nameInCurrentLanguage then
                [ autonym |> Html.text ]

            else
                [ autonym |> Html.text
                , Html.text "("
                , nameInCurrentLanguage |> Html.text
                , Html.text ")"
                ]
    in
    Html.option
        [ language |> Lang.code |> HtmlA.value, HtmlA.selected (currentLanguage == language) ]
        name
