port module GalleryCustom exposing (elmToJS)

import Html exposing (Html, div, pre)
import Html.Attributes exposing (id)
import Json.Encode
import Platform
import Vega exposing (..)


-- NOTE: All data sources in these examples originally provided at
-- https://vega.github.io/vega-datasets/
-- The examples themselves reproduce those at https://vega.github.io/vega/examples/


custom1 : Spec
custom1 =
    -- TODO: Add config
    let
        ds =
            dataSource
                [ data "budgets" [ daUrl "https://vega.github.io/vega/data/budgets.json" ]
                    |> transform
                        [ trFormula "abs(datum.value)" "abs" AlwaysUpdate
                        , trFormula "datum.value < 0 ? 'deficit' : 'surplus'" "type" AlwaysUpdate
                        ]
                , data "budgets-current" [ daSource "budgets" ]
                    |> transform [ trFilter (expr "datum.budgetYear <= currentYear") ]
                , data "budgets-actual" [ daSource "budgets" ]
                    |> transform [ trFilter (expr "datum.budgetYear <= currentYear && datum.forecastYear == datum.budgetYear - 1") ]
                , data "tooltip" [ daSource "budgets" ]
                    |> transform
                        [ trFilter (expr "datum.budgetYear <= currentYear && datum.forecastYear == tipYear && abs(datum.value - tipValue) <= 0.1")
                        , trAggregate [ agFields [ field "value", field "value" ], agOps [ Min, ArgMin ], agAs [ "min", "argmin" ] ]
                        , trFormula "datum.argmin.budgetYear" "tooltipYear" AlwaysUpdate
                        ]
                , data "tooltip-forecast" [ daSource "budgets" ]
                    |> transform
                        [ trLookup "tooltip" (field "tooltipYear") [ field "budgetYear" ] [ luAs [ "tooltip" ] ]
                        , trFilter (expr "datum.tooltip")
                        ]
                ]

        si =
            signals
                << signal "dragging"
                    [ siValue (vBoo False)
                    , siOn
                        [ evHandler (esObject [ esMarkName "handle", esType MouseDown ]) [ evUpdate "true" ]
                        , evHandler (esObject [ esSource ESWindow, esType MouseUp ]) [ evUpdate "false" ]
                        ]
                    ]
                << signal "handleYear"
                    [ siValue (vNum 2010)
                    , siOn
                        [ evHandler
                            (esObject
                                [ esBetween [ esMarkName "handle", esType MouseDown ] [ esSource ESWindow, esType MouseUp ]
                                , esSource ESWindow
                                , esType MouseMove
                                , esConsume True
                                ]
                            )
                            [ evUpdate "invert('xScale', clamp(x(), 0, width))" ]
                        ]
                    ]
                << signal "currentYear" [ siUpdate "clamp(handleYear, 1980, 2010)" ]
                << signal "tipYear"
                    [ siOn
                        [ evHandler (esObject [ esType MouseMove ]) [ evUpdate "dragging ? tipYear : invert('xScale', x())" ] ]
                    ]
                << signal "tipValue"
                    [ siOn
                        [ evHandler (esObject [ esType MouseMove ]) [ evUpdate "dragging ? tipValue : invert('yScale', y())" ] ]
                    ]
                << signal "cursor"
                    [ siValue (vStr "default")
                    , siOn
                        [ evHandler (esSignal "dragging") [ evUpdate "dragging ? 'pointer' : 'default'" ] ]
                    ]

        sc =
            scales
                << scale "xScale"
                    [ scType ScBand
                    , scDomain (doData [ daDataset "budgets", daField (field "forecastYear") ])
                    , scRange RaWidth
                    ]
                << scale "yScale"
                    [ scType ScLinear
                    , scDomain (doData [ daDataset "budgets", daField (field "value") ])
                    , scZero true
                    , scRange RaHeight
                    ]

        ax =
            axes
                << axis "xScale"
                    SBottom
                    [ axGrid true
                    , axDomain false
                    , axValues (vNums [ 1982, 1986, 1990, 1994, 1998, 2002, 2006, 2010, 2014, 2018 ])
                    , axTickSize (num 0)
                    , axEncode
                        [ ( EGrid, [ enEnter [ maStroke [ vStr "white" ], maStrokeOpacity [ vNum 0.75 ] ] ] )
                        , ( ELabels, [ enUpdate [ maX [ vScale "xScale", vField (field "value") ] ] ] )
                        ]
                    ]
                << axis "yScale"
                    SRight
                    [ axGrid true
                    , axDomain false
                    , axValues (vNums [ 0, -0.5, -1, -1.5 ])
                    , axTickSize (num 0)
                    , axEncode
                        [ ( EGrid, [ enEnter [ maStroke [ vStr "white" ], maStrokeOpacity [ vNum 0.75 ] ] ] )
                        , ( ELabels, [ enEnter [ maText [ vSignal "format(datum.value, '$.1f') + ' trillion'" ] ] ] )
                        ]
                    ]

        nestedMk1 =
            marks
                << mark Line
                    [ mFrom [ srData (str "facet") ]
                    , mEncode
                        [ enUpdate
                            [ maX [ vScale "xScale", vField (field "forecastYear") ]
                            , maY [ vScale "yScale", vField (field "value") ]
                            , maStroke [ vStr "steelblue" ]
                            , maStrokeWidth [ vNum 1 ]
                            , maStrokeOpacity [ vNum 0.25 ]
                            ]
                        ]
                    ]

        nestedMk2 =
            marks
                << mark Text
                    [ mInteractive false
                    , mEncode
                        [ enUpdate
                            [ maX [ vNum 6 ]
                            , maY [ vNum 14 ]
                            , maText [ vSignal "'Forecast from early ' + parent.argmin.budgetYear" ]
                            , maFill [ vStr "black" ]
                            , maFontWeight [ vStr "bold" ]
                            ]
                        ]
                    ]
                << mark Text
                    [ mInteractive false
                    , mEncode
                        [ enUpdate
                            [ maX [ vNum 6 ]
                            , maY [ vNum 29 ]
                            , maText [ vSignal "parent.argmin.forecastYear + ': ' + format(parent.argmin.abs, '$.3f') + ' trillion ' + parent.argmin.type" ]
                            , maFill [ vStr "black" ]
                            , maAlign [ hAlignLabel AlignLeft |> vStr ]
                            ]
                        ]
                    ]

        mk =
            marks
                << mark Group
                    [ mFrom [ srFacet "budgets-current" "facet" [ faGroupBy [ "budgetYear" ] ] ]
                    , mGroup [ nestedMk1 [] ]
                    ]
                << mark Line
                    [ mFrom [ srData (str "budgets-actual") ]
                    , mEncode
                        [ enUpdate
                            [ maX [ vScale "xScale", vField (field "forecastYear") ]
                            , maY [ vScale "yScale", vField (field "value") ]
                            , maStroke [ vStr "steelblue" ]
                            , maStrokeWidth [ vNum 3 ]
                            ]
                        ]
                    ]
                << mark Line
                    [ mFrom [ srData (str "tooltip-forecast") ]
                    , mEncode
                        [ enUpdate
                            [ maX [ vScale "xScale", vField (field "forecastYear") ]
                            , maY [ vScale "yScale", vField (field "value") ]
                            , maStroke [ vStr "black" ]
                            , maStrokeWidth [ vNum 1 ]
                            ]
                        ]
                    ]
                << mark Symbol
                    [ mFrom [ srData (str "tooltip") ]
                    , mEncode
                        [ enUpdate
                            [ maX [ vScale "xScale", vField (field "argmin.forecastYear") ]
                            , maY [ vScale "yScale", vField (field "argmin.value") ]
                            , maSize [ vNum 50 ]
                            , maFill [ vStr "black" ]
                            ]
                        ]
                    ]
                << mark Rule
                    [ mEncode
                        [ enEnter
                            [ maY [ vScale "yScale", vNum 0 ]
                            , maStroke [ vStr "black" ]
                            , maStrokeWidth [ vNum 1 ]
                            ]
                        , enUpdate
                            [ maX [ vNum 0 ]
                            , maX2 [ vScale "xScale", vSignal "currentYear" ]
                            ]
                        ]
                    ]
                << mark Symbol
                    [ mName "handle"
                    , mEncode
                        [ enEnter
                            [ maY [ vScale "yScale", vNum 0, vOffset (vNum 1) ]
                            , maShape [ symbolLabel SymTriangleDown |> vStr ]
                            , maSize [ vNum 400 ]
                            , maStroke [ vStr "black" ]
                            , maStrokeWidth [ vNum 0.5 ]
                            ]
                        , enUpdate
                            [ maX [ vScale "xScale", vSignal "currentYear" ]
                            , maFill [ vSignal "dragging ? 'lemonchiffon' : 'white'" ]
                            ]
                        , enHover
                            [ maFill [ vStr "lemonchiffon" ]
                            , maCursor [ cursorLabel CPointer |> vStr ]
                            ]
                        ]
                    ]
                << mark Text
                    [ mEncode
                        [ enEnter
                            [ maX [ vNum 0 ]
                            , maY [ vNum 25 ]
                            , maFontSize [ vNum 32 ]
                            , maFontWeight [ vStr "bold" ]
                            , maFill [ vStr "steelblue" ]
                            ]
                        , enUpdate [ maText [ vSignal "currentYear" ] ]
                        ]
                    ]
                << mark Group
                    [ mFrom [ srData (str "tooltip") ]
                    , mInteractive false
                    , mEncode
                        [ enUpdate
                            [ maX [ vScale "xScale", vField (field "argmin.forecastYear"), vOffset (vNum -5) ]
                            , maY [ vScale "yScale", vField (field "argmin.value"), vOffset (vNum 20) ]
                            , maWidth [ vNum 150 ]
                            , maHeight [ vNum 35 ]
                            , maFill [ vStr "white" ]
                            , maFillOpacity [ vNum 0.85 ]
                            , maStroke [ vStr "#aaa" ]
                            , maStrokeWidth [ vNum 0.5 ]
                            ]
                        ]
                    , mGroup [ nestedMk2 [] ]
                    ]
    in
    toVega
        [ width 700, height 400, padding 5, background (str "#edf1f7"), ds, si [], sc [], ax [], mk [] ]


custom2 : Spec
custom2 =
    let
        ds =
            dataSource
                [ data "wheat" [ daUrl "https://vega.github.io/vega/data/wheat.json" ]
                , data "wheat-filtered" [ daSource "wheat" ] |> transform [ trFilter (expr "!!datum.wages") ]
                , data "monarchs" [ daUrl "https://vega.github.io/vega/data/monarchs.json" ]
                    |> transform [ trFormula "((!datum.commonwealth && datum.index % 2) ? -1: 1) * 2 + 95" "offset" AlwaysUpdate ]
                ]

        sc =
            scales
                << scale "xScale"
                    [ scType ScLinear
                    , scRange RaWidth
                    , scDomain (doNums (nums [ 1565, 1825 ]))
                    , scZero false
                    ]
                << scale "yScale"
                    [ scType ScLinear
                    , scRange RaHeight
                    , scZero true
                    , scDomain (doData [ daDataset "wheat", daField (field "wheat") ])
                    ]
                << scale "cScale"
                    [ scType ScOrdinal
                    , scRange (raStrs [ "black", "white" ])
                    , scDomain (doData [ daDataset "monarchs", daField (field "commonwealth") ])
                    ]

        ax =
            axes
                << axis "xScale" SBottom [ axTickCount (num 5), axFormat "04d" ]
                << axis "yScale"
                    SRight
                    [ axGrid true
                    , axDomain false
                    , axZIndex (num 1)
                    , axTickCount (num 5)
                    , axOffset (vNum 5)
                    , axTickSize (num 0)
                    , axEncode
                        [ ( EGrid, [ enEnter [ maStroke [ vStr "white" ], maStrokeWidth [ vNum 1 ], maStrokeOpacity [ vNum 0.25 ] ] ] )
                        , ( ELabels, [ enEnter [ maFontStyle [ vStr "italic" ] ] ] )
                        ]
                    ]

        mk =
            marks
                << mark Rect
                    [ mFrom [ srData (str "wheat") ]
                    , mEncode
                        [ enEnter
                            [ maX [ vScale "xScale", vField (field "year") ]
                            , maWidth [ vNum 17 ]
                            , maY [ vScale "yScale", vField (field "wheat") ]
                            , maY2 [ vScale "yScale", vNum 0 ]
                            , maFill [ vStr "#aaa" ]
                            , maStroke [ vStr "#5d5d5d" ]
                            , maStrokeWidth [ vNum 0.25 ]
                            ]
                        ]
                    ]
                << mark Area
                    [ mFrom [ srData (str "wheat-filtered") ]
                    , mEncode
                        [ enEnter
                            [ maInterpolate [ markInterpolationLabel Linear |> vStr ]
                            , maX [ vScale "xScale", vField (field "year") ]
                            , maY [ vScale "yScale", vField (field "wages") ]
                            , maY2 [ vScale "yScale", vNum 0 ]
                            , maFill [ vStr "#b3d9e6" ]
                            , maFillOpacity [ vNum 0.8 ]
                            ]
                        ]
                    ]
                << mark Line
                    [ mFrom [ srData (str "wheat-filtered") ]
                    , mEncode
                        [ enEnter
                            [ maInterpolate [ markInterpolationLabel Linear |> vStr ]
                            , maX [ vScale "xScale", vField (field "year") ]
                            , maY [ vScale "yScale", vField (field "wages") ]
                            , maStroke [ vStr "#ff7e79" ]
                            , maStrokeWidth [ vNum 3 ]
                            ]
                        ]
                    ]
                << mark Line
                    [ mFrom [ srData (str "wheat-filtered") ]
                    , mEncode
                        [ enEnter
                            [ maInterpolate [ markInterpolationLabel Linear |> vStr ]
                            , maX [ vScale "xScale", vField (field "year") ]
                            , maY [ vScale "yScale", vField (field "wages") ]
                            , maStroke [ vStr "black" ]
                            , maStrokeWidth [ vNum 1 ]
                            ]
                        ]
                    ]
                << mark Rect
                    [ mName "monarch_rects"
                    , mFrom [ srData (str "monarchs") ]
                    , mEncode
                        [ enEnter
                            [ maX [ vScale "xScale", vField (field "start") ]
                            , maX2 [ vScale "xScale", vField (field "end") ]
                            , maY [ vScale "yScale", vNum 95 ]
                            , maY2 [ vScale "yScale", vField (field "offset") ]
                            , maFill [ vScale "cScale", vField (field "commonwealth") ]
                            , maStroke [ vStr "black" ]
                            , maStrokeWidth [ vNum 2 ]
                            ]
                        ]
                    ]
                << mark Text
                    [ mFrom [ srData (str "monarch_rects") ]
                    , mEncode
                        [ enEnter
                            [ maX [ vField (field "x") ]
                            , maDx [ vField (field "width"), vMultiply (vNum 0.5) ]
                            , maY [ vField (field "y2"), vOffset (vNum 14) ]
                            , maText [ vField (field "datum.name") ]
                            , maAlign [ hAlignLabel AlignCenter |> vStr ]
                            , maFill [ vStr "black" ]
                            , maFont [ vStr "Helvetica Neue, Arial" ]
                            , maFontSize [ vNum 10 ]
                            , maFontStyle [ vStr "italic" ]
                            ]
                        ]
                    ]
    in
    toVega
        [ width 900, height 465, padding 5, ds, sc [], ax [], mk [] ]


sourceExample : Spec
sourceExample =
    custom2



{- This list comprises the specifications to be provided to the Vega runtime. -}


mySpecs : Spec
mySpecs =
    combineSpecs
        [ ( "custom1", custom1 )
        , ( "custom2", custom2 )
        ]



{- ---------------------------------------------------------------------------
   The code below creates an Elm module that opens an outgoing port to Javascript
   and sends both the specs and DOM node to it.
   This is used to display the generated Vega specs for testing purposes.
-}


main : Program Never Spec msg
main =
    Html.program
        { init = ( mySpecs, elmToJS mySpecs )
        , view = view
        , update = \_ model -> ( model, Cmd.none )
        , subscriptions = always Sub.none
        }



-- View


view : Spec -> Html msg
view spec =
    div []
        [ div [ id "specSource" ] []
        , pre []
            [ Html.text (Json.Encode.encode 2 sourceExample) ]
        ]


port elmToJS : Spec -> Cmd msg