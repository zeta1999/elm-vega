port module MarkTests exposing (elmToJS)

import Html exposing (Html, div, pre)
import Html.Attributes exposing (id)
import Json.Encode
import Platform
import Vega exposing (..)


arcTest : Spec
arcTest =
    let
        si =
            signals
                << signal "startAngle" [ SiValue (Number -0.73), SiBind (IRange [ InMin -6.28, InMax 6.28 ]) ]
                << signal "endAngle" [ SiValue (Number 0.73), SiBind (IRange [ InMin -6.28, InMax 6.28 ]) ]
                << signal "padAngle" [ SiValue (Number 0), SiBind (IRange [ InMin 0, InMax 1.57 ]) ]
                << signal "innerRadius" [ SiValue (Number 0), SiBind (IRange [ InMin 0, InMax 100, InStep 1 ]) ]
                << signal "outerRadius" [ SiValue (Number 50), SiBind (IRange [ InMin 0, InMax 100, InStep 1 ]) ]
                << signal "cornerRadius" [ SiValue (Number 0), SiBind (IRange [ InMin 0, InMax 50, InStep 1 ]) ]
                << signal "strokeWidth" [ SiValue (Number 4), SiBind (IRange [ InMin 0, InMax 10, InStep 0.5 ]) ]
                << signal "color" [ SiValue (Str "both"), SiBind (IRadio [ InOptions [ "fill", "stroke", "both" ] ]) ]
                << signal "x" [ SiValue (Number 100) ]
                << signal "y" [ SiValue (Number 100) ]

        mk =
            marks
                << mark Symbol
                    [ MInteractive False
                    , MEncode
                        [ Enter [ MFill [ VString "firebrick" ], MSize [ VNumber 25 ] ]
                        , Update [ MX [ VSignal (SName "x") ], MY [ VSignal (SName "y") ] ]
                        ]
                    ]
                << mark Arc
                    [ MEncode
                        [ Enter [ MFill [ VString "#939597" ], MStroke [ VString "#652c90" ] ]
                        , Update
                            [ MX [ VSignal (SName "x") ]
                            , MY [ VSignal (SName "y") ]
                            , MStartAngle [ VSignal (SName "startAngle") ]
                            , MEndAngle [ VSignal (SName "endAngle") ]
                            , MInnerRadius [ VSignal (SName "innerRadius") ]
                            , MOuterRadius [ VSignal (SName "outerRadius") ]
                            , MCornerRadius [ VSignal (SName "cornerRadius") ]
                            , MPadAngle [ VSignal (SName "padAngle") ]
                            , MStrokeWidth [ VSignal (SName "strokeWidth") ]
                            , MOpacity [ VNumber 1 ]
                            , MFillOpacity [ VSignal (SExpr "color === 'fill' || color === 'both' ? 1 : 0") ]
                            , MStrokeOpacity [ VSignal (SExpr "color === 'stroke' || color === 'both' ? 1 : 0") ]
                            ]
                        , Hover [ MOpacity [ VNumber 0.5 ] ]
                        ]
                    ]
    in
    toVega
        [ width 200, height 200, padding (PSize 5), si [], mk [] ]


areaTest : Spec
areaTest =
    let
        table =
            dataFromColumns "table" []
                << dataColumn "u" (Numbers [ 1, 2, 3, 4, 5, 6 ])
                << dataColumn "v" (Numbers [ 28, 55, 42, 34, 36, 48 ])

        ds =
            dataSource [ table [] ]

        sc =
            scales
                << scale "xscale"
                    [ SType ScLinear
                    , SDomain (DData [ DDataset "table", DField "u" ])
                    , SRange (RDefault RWidth)
                    , SZero False
                    ]
                << scale "yscale"
                    [ SType ScLinear
                    , SDomain (DData [ DDataset "table", DField "v" ])
                    , SRange (RDefault RHeight)
                    , SZero True
                    , SNice (IsNice True)
                    ]

        si =
            signals
                << signal "defined" [ SiValue (Boolean True), SiBind (ICheckbox []) ]
                << signal "interpolate"
                    [ SiValue (markInterpolationLabel Linear |> Str)
                    , SiBind (ISelect [ InOptions [ "basis", "cardinal", "catmull-rom", "linear", "monotone", "natural", "step", "step-after", "step-before" ] ])
                    ]
                << signal "tension" [ SiValue (Number 0), SiBind (IRange [ InMin 0, InMax 1, InStep 0.05 ]) ]
                << signal "y2" [ SiValue (Number 0), SiBind (IRange [ InMin 0, InMax 20, InStep 1 ]) ]
                << signal "strokeWidth" [ SiValue (Number 4), SiBind (IRange [ InMin 0, InMax 10, InStep 0.5 ]) ]
                << signal "color" [ SiValue (Str "both"), SiBind (IRadio [ InOptions [ "fill", "stroke", "both" ] ]) ]

        mk =
            marks
                << mark Area
                    [ MFrom (SData "table")
                    , MEncode
                        [ Enter [ MFill [ VString "#939597" ], MStroke [ VString "#652c90" ] ]
                        , Update
                            [ MX [ VScale (FName "xscale"), VField (FName "u") ]
                            , MY [ VScale (FName "yscale"), VField (FName "v") ]
                            , MY2 [ VScale (FName "yscale"), VSignal (SName "y2") ]
                            , MDefined [ VSignal (SExpr "defined || datum.u !== 3") ]
                            , MInterpolate [ VSignal (SName "interpolate") ]
                            , MTension [ VSignal (SName "tension") ]
                            , MOpacity [ VNumber 1 ]
                            , MFillOpacity [ VSignal (SExpr "color === 'fill' || color === 'both' ? 1 : 0") ]
                            , MStrokeOpacity [ VSignal (SExpr "color === 'stroke' || color === 'both' ? 1 : 0") ]
                            , MStrokeWidth [ VSignal (SName "strokeWidth") ]
                            ]
                        , Hover [ MOpacity [ VNumber 0.5 ] ]
                        ]
                    ]
    in
    toVega
        [ width 400, height 200, padding (PSize 5), ds, sc [], si [], mk [] ]


imageTest : Spec
imageTest =
    let
        si =
            signals
                << signal "x" [ SiValue (Number 75), SiBind (IRange [ InMin 0, InMax 100, InStep 1 ]) ]
                << signal "y" [ SiValue (Number 75), SiBind (IRange [ InMin 0, InMax 100, InStep 1 ]) ]
                << signal "w" [ SiValue (Number 50), SiBind (IRange [ InMin 0, InMax 200, InStep 1 ]) ]
                << signal "h" [ SiValue (Number 50), SiBind (IRange [ InMin 0, InMax 200, InStep 1 ]) ]
                << signal "aspect" [ SiValue (Boolean True), SiBind (ICheckbox []) ]
                << signal "align" [ SiValue (Str "left"), SiBind (ISelect [ InOptions [ "left", "center", "right" ] ]) ]
                << signal "baseline" [ SiValue (Str "top"), SiBind (ISelect [ InOptions [ "top", "middle", "bottom" ] ]) ]

        mk =
            marks
                << mark Image
                    [ MEncode
                        [ Enter [ MUrl [ VString "https://vega.github.io/images/idl-logo.png" ] ]
                        , Update
                            [ MOpacity [ VNumber 1 ]
                            , MX [ VSignal (SName "x") ]
                            , MY [ VSignal (SName "y") ]
                            , MWidth [ VSignal (SName "w") ]
                            , MHeight [ VSignal (SName "h") ]
                            , MAspect [ VSignal (SName "aspect") ]
                            , MAlign [ VSignal (SName "align") ]
                            , MBaseline [ VSignal (SName "baseline") ]
                            ]
                        , Hover [ MOpacity [ VNumber 0.5 ] ]
                        ]
                    ]
    in
    toVega
        [ width 200, height 200, padding (PSize 5), si [], mk [] ]


sourceExample : Spec
sourceExample =
    imageTest



{- This list comprises the specifications to be provided to the Vega runtime. -}


mySpecs : Spec
mySpecs =
    combineSpecs
        [ ( "arcTest", arcTest )
        , ( "areaTest", areaTest )
        , ( "imageTest", imageTest )
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