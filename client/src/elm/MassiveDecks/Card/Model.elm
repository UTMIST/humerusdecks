module MassiveDecks.Card.Model exposing
    ( Call
    , Details
    , Id
    , Response
    , Side(..)
    , UnknownResponse
    , ViewBody(..)
    , ViewInstructions(..)
    , call
    , frontSide
    , response
    )

import Html exposing (Html)
import MassiveDecks.Card.Parts exposing (..)
import MassiveDecks.Card.Source.Model exposing (..)


{-| A unique ID for a card.
-}
type alias Id =
    String


{-| The side of a card.
-}
type Side
    = Front
    | Back


{-| Get a side from a boolean test.
-}
frontSide : Bool -> Side
frontSide isFront =
    if isFront then
        Front

    else
        Back


{-| A call card.
-}
type alias Call =
    Card Parts


{-| A simple constructor for a call card.
-}
call : Parts -> Id -> Source -> Call
call parts id source =
    { details = { source = source, id = id }
    , body = parts
    }


{-| A response card.
-}
type alias Response =
    Card String


{-| A simple constructor for a response card.
-}
response : String -> Id -> Source -> Response
response text id source =
    { details = { source = source, id = id }
    , body = text
    }


{-| A response that isn't known to the user. Only the back can be displayed.
-}
type UnknownResponse
    = UnknownResponse Id


{-| The data for a type of card.
-}
type alias Card body =
    { details : Details
    , body : body
    }


{-| The general details for a card.
-}
type alias Details =
    { source : Source
    , id : Id
    }


{-| A function to render the body of a card.
-}
type ViewBody msg
    = ViewBody (() -> List (Html msg))


{-| A function to render the instructions for a card.
-}
type ViewInstructions msg
    = ViewInstructions (() -> List (Html msg))
