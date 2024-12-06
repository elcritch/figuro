## This is a simple example on how to use Stylus' tokenizer.
import figuro/ui/basiccss
import chroma
import cssgrid
import pretty

import std/unittest

import figuro/widget
import figuro/common/nodes/ui
import figuro/common/nodes/render
import figuro/widgets/button

suite "css parser":

  test "blocks":
    # skip()
    const src = """

    Button {
    }

    Button.btnBody {
    }

    Button child {
    }

    Button < directChild {
    }

    Button < directChild.field {
    }

    Button:hover {
    }

    #name {
    }

    """

    let parser = newCssParser(src)
    let res = parse(parser)
    check res[0].selectors == @[CssSelector(cssType: "Button")]
    check res[1].selectors == @[CssSelector(cssType: "Button", class: "btnBody")]
    check res[2].selectors == @[
      CssSelector(cssType: "Button", combinator: skNone),
      CssSelector(cssType: "child", combinator: skDescendent)
    ]
    check res[3].selectors == @[
      CssSelector(cssType: "Button", combinator: skNone),
      CssSelector(cssType: "directChild", combinator: skDirectChild)
    ]
    check res[4].selectors == @[
      CssSelector(cssType: "Button", combinator: skNone),
      CssSelector(cssType: "directChild", class: "field", combinator: skDirectChild)
    ]
    check res[5].selectors == @[
      CssSelector(cssType: "Button", combinator: skNone),
      CssSelector(cssType: "hover", combinator: skPseudo)
    ]
    check res[6].selectors == @[
      CssSelector(id: "name", combinator: skNone),
    ]
    echo "results: ", res[6].selectors.repr

  test "properties":
    const src = """

    Button {
      color-background: #00a400;
      color: rgb(214, 122, 127);
      border-width: 1;
      width: 80%;
      border-radius: 25px;
    }

    """

    let parser = newCssParser(src)
    let res = parse(parser)[0]
    check res.selectors == @[CssSelector(cssType: "Button", combinator: skNone)]
    check res.properties.len() == 5
    check res.properties[0] == CssProperty(name: "color-background", value: CssColor(parseHtmlColor("#00a400")))
    check res.properties[1] == CssProperty(name: "color", value: CssColor(parseHtmlColor("rgb(214, 122, 127)")))
    check res.properties[2] == CssProperty(name: "border-width", value: CssSize(csFixed(1.0.UiScalar)))
    check res.properties[3] == CssProperty(name: "width", value: CssSize(csPerc(80.0)))
    check res.properties[4] == CssProperty(name: "border-radius", value: CssSize(csFixed(25.0)))
    # echo "\nresults:"
    # for r in res.properties:
    #   echo "\t", r.repr


  test "missing property value":
    const src = """

    Button {
      color-background: ;
      color: rgb(214, 122, 127);
    }

    """

    let parser = newCssParser(src)
    let res = parse(parser)[0]
    # echo "results: ", res.repr
    check res.selectors == @[CssSelector(cssType: "Button", combinator: skNone)]
    check res.properties[0] == CssProperty(name: "color", value: CssColor(parseHtmlColor("rgb(214, 122, 127)")))

  test "missing property name":
    const src = """

    Button {
      : #00a400;
      color: rgb(214, 122, 127);
    }

    """

    let parser = newCssParser(src)
    let res = parse(parser)[0]
    # echo "results: ", res.repr
    check res.selectors == @[CssSelector(cssType: "Button", combinator: skNone)]
    check res.properties[0] == CssProperty(name: "color", value: CssColor(parseHtmlColor("rgb(214, 122, 127)")))

  test "test child descent tokenizer is working":
    skip()
    if false:
      const src = """
      Button > directChild {
      }

      Button > directChild.field {
      }
      """

      echo "trying to parse `>`..."
      let parser = newCssParser(src)
      let res = parse(parser)
      echo "results: ", res.repr

type
  TMain* = ref object of Figuro

proc draw*(self: TMain) {.slot.} =
  echo "draw: "
  let node = self
  self.name = "main"
  rectangle "body":
    rectangle "child1":
      discard

    Button[int].new "btnA":
      with node:
        box 40'ux, 30'ux, 80'ux, 80'ux
        fill css"#2B9F2B"
  
    Button[int].new "btnB":
      with node:
        box 40'ux, 30'ux, 80'ux, 80'ux
        fill css"#2B9F2B"

suite "css exec":
  test "css target":

    const themeSrc = """
    #body Button {
      background: #FF0000;
      border-width: 3;
      border-color: #00FF00;
    }
    """

    var main = TMain.new()
    main.frame = newAppFrame(main, size=(400'ui, 140'ui))
    main.frame.theme = Theme(font: defaultFont)
    let parser = newCssParser(themeSrc)
    let cssTheme = parse(parser)
    # print cssTheme
    main.frame.theme.cssRules = cssTheme
    connectDefaults(main)
    emit main.doDraw()

    echo "\nmain: ", $main

    let btnA = main.children[0].children[1]
    echo "btnA: ", $btnA
    check btnA.name == "btnA"
    check btnA.fill == parseHtmlColor("#FF0000")
    check btnA.stroke.weight == 3.0
    check btnA.stroke.color == parseHtmlColor("#00FF00")
