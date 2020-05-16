module MassiveDecks.Game.Action exposing (actions, view)

import FontAwesome.Icon as Icon exposing (Icon)
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import MassiveDecks.Game.Action.Model exposing (..)
import MassiveDecks.Game.Messages as Game exposing (Msg)
import MassiveDecks.Model exposing (..)
import MassiveDecks.Strings as Strings exposing (MdString)
import Material.Fab as Fab


actions : List Action
actions =
    [ Submit, TakeBack, Judge, Like, Advance ]


{-| Style for actions that are blocking the game from continuing until they are performed.
-}
blocking : List (Html.Attribute msg)
blocking =
    [ HtmlA.class "blocking" ]


{-| Style for an action that doesn't block the game.
-}
normal : List (Html.Attribute msg)
normal =
    [ HtmlA.class "normal" ]


view : (Msg -> msg) -> Shared -> Maybe Action -> Action -> Html msg
view wrap shared visible action =
    let
        { icon, attrs, title, onClick } =
            case action of
                Submit ->
                    IconView Icon.check blocking Strings.SubmitPlay Game.Submit

                TakeBack ->
                    IconView Icon.undo normal Strings.TakeBackPlay Game.TakeBack

                Judge ->
                    IconView Icon.trophy blocking Strings.JudgePlay Game.Judge

                Like ->
                    IconView Icon.thumbsUp normal Strings.LikePlay Game.Like

                Advance ->
                    IconView Icon.forward blocking Strings.AdvanceRound Game.AdvanceRound
    in
    Fab.view shared
        Fab.Normal
        title
        (icon |> Icon.present)
        (onClick |> wrap |> Just)
        (HtmlA.classList [ ( "action", True ), ( "exited", visible /= Just action ) ] :: attrs)


type alias IconView msg =
    { icon : Icon
    , attrs : List (Html.Attribute msg)
    , title : MdString
    , onClick : Game.Msg
    }
