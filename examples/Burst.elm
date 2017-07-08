module Burst exposing (main)

import AnimationFrame
import Html exposing (Html)
import Json.Decode exposing (Decoder)
import Random.Pcg as Random exposing (Generator)
import Svg exposing (Svg)
import Svg.Attributes
import Svg.Events
import Time exposing (Time)


-- project

import Geometry.Vector as Vector exposing (Vector, Point)
import Main exposing (transformPoints, wrapPosition, updateMoving, updateExpiring)
import Screen
import Particle exposing (Particle)


type alias Model =
    { drag : Maybe ( Point, Point )
    , seed : Random.Seed
    , particles : List Particle
    }


main : Program Never Model Msg
main =
    Html.program
        { init =
            ( { drag = Nothing
              , seed = Random.initialSeed 3780540833
              , particles = []
              }
            , Cmd.none
            )
        , update = \x r -> ( update x r, Cmd.none )
        , view = view
        , subscriptions = always (AnimationFrame.diffs (Time.inSeconds >> Tick))
        }



-- update


type Msg
    = MouseDown Point
    | MouseMove Point
    | MouseUp
    | Tick Time


update : Msg -> Model -> Model
update msg model =
    case msg of
        MouseDown p0 ->
            { model | drag = Just ( p0, p0 ) }

        MouseMove p1 ->
            case model.drag of
                Just ( p0, _ ) ->
                    { model | drag = Just ( p0, p1 ) }

                Nothing ->
                    model

        MouseUp ->
            let
                ( particles, seedNext ) =
                    model.drag
                        |> Maybe.map (\( p0, p1 ) -> generateBurst p1 (Vector.sub p1 p0) model.seed)
                        |> Maybe.withDefault ( [], model.seed )
            in
                { model
                    | drag = Nothing
                    , seed = seedNext
                    , particles = particles ++ model.particles
                }

        Tick dt ->
            { model | particles = model.particles |> List.filterMap (updateParticle dt) }


generateBurst : Point -> Vector -> Random.Seed -> ( List Particle, Random.Seed )
generateBurst origin velocity =
    Particle.burst
        |> Random.map
            (List.map
                (\particle ->
                    { particle
                        | position = origin
                        , velocity = particle.velocity |> Vector.add velocity
                    }
                )
            )
        |> Random.step



-- view


screenSize : ( Float, Float )
screenSize =
    ( 1200, 900 )


( width, height ) =
    screenSize


view : Model -> Html Msg
view { drag, particles } =
    let
        attributes =
            [ Svg.Attributes.width (width |> px)
            , Svg.Attributes.height (height |> px)
            , Svg.Attributes.style "cursor: default;"
            ]

        events =
            drag
                |> Maybe.map
                    (always [ mousemove, mouseup ])
                |> Maybe.withDefault [ mousedown ]
    in
        Svg.svg
            (attributes ++ events)
            [ drag |> Maybe.map viewLine |> Maybe.withDefault (Svg.g [] [])
            , Screen.render screenSize (particles |> List.map particleToPath)
            ]


mouseup : Svg.Attribute Msg
mouseup =
    Svg.Events.on "mouseup" (Json.Decode.succeed MouseUp)


mousedown : Svg.Attribute Msg
mousedown =
    Svg.Events.on "mousedown" (decodeMouseOffset |> Json.Decode.map MouseDown)


mousemove : Svg.Attribute Msg
mousemove =
    Svg.Events.on "mousemove" (decodeMouseOffset |> Json.Decode.map MouseMove)


decodeMouseOffset : Decoder Point
decodeMouseOffset =
    Json.Decode.map2
        (,)
        (Json.Decode.field "offsetX" Json.Decode.float)
        (Json.Decode.field "offsetY" Json.Decode.float)


viewLine : ( Point, Point ) -> Svg a
viewLine ( ( x1, y1 ), ( x2, y2 ) ) =
    Svg.line
        [ Svg.Attributes.x1 (x1 |> px)
        , Svg.Attributes.y1 (y1 |> px)
        , Svg.Attributes.x2 (x2 |> px)
        , Svg.Attributes.y2 (y2 |> px)
        , Svg.Attributes.style "stroke: rgba(0, 0, 0, 0.1)"
        ]
        []


px : Float -> String
px =
    toString >> (++) >> (|>) "px"



-- Particle


updateParticle : Time -> Particle -> Maybe Particle
updateParticle dt =
    updateMoving dt >> wrapPosition >> updateExpiring dt


particleToPath : Particle -> Screen.Path
particleToPath { polyline, position, rotation } =
    ( False
    , polyline |> transformPoints position rotation
    )
