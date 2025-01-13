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
      Button[int].new "btnC":
        with node:
          box 40'ux, 30'ux, 80'ux, 80'ux
          fill css"#FFFFFF"

    Button[int].new "btnA":
      with node:
        box 40'ux, 30'ux, 80'ux, 80'ux
        fill css"#FFFFFF"
  
    rectangle "child2":
      Button[int].new "btnB":
        with node:
          box 40'ux, 30'ux, 80'ux, 80'ux
          fill css"#FFFFFF"

    rectangle "child3":
      rectangle "child30":
        Button[int].new "btnD":
          with node:
            box 40'ux, 30'ux, 80'ux, 80'ux
            fill css"#FFFFFF"

const
  initialColor = parseHtmlColor "#FFFFFF"

suite "css exec":

  template setupMain(themeSrc) =
    var main {.inject.} = TMain.new()
    var frame = newAppFrame(main, size=(400'ui, 140'ui))
    main.frame = frame.unsafeWeakRef()
    main.frame[].theme = Theme(font: defaultFont)
    let parser = newCssParser(themeSrc)
    let cssTheme = parse(parser)
    # print cssTheme
    main.frame[].theme.cssRules = cssTheme
    connectDefaults(main)
    emit main.doDraw()
    let btnA {.inject, used.} = main.children[0].children[1]
    let btnB {.inject, used.} = main.children[0].children[2].children[0]
    let btnC {.inject, used.} = main.children[0].children[0].children[0]
    let child30 {.inject, used.} = main.children[0].children[3].children[0]
    let btnD {.inject, used.} = main.children[0].children[3].children[0].children[0]

  test "node names":
    setupMain("")
    check btnA.name == "btnA"
    check btnB.name == "btnB"
    check btnC.name == "btnC"
    check btnD.name == "btnD"
    check child30.name == "child30"
    check child30.fill == clearColor

  test "css direct descendants":
    const themeSrc = """
    #body < Button {
      background: #FF0000;
      border-width: 3;
      border-color: #00FF00;
    }

    #child2 < Button {
      background: #0000FF;
    }
    """
    setupMain(themeSrc)
    check btnA.fill == parseHtmlColor("#FF0000")
    check btnA.stroke.weight == 3.0
    check btnA.stroke.color == parseHtmlColor("#00FF00")

    check btnB.fill == parseHtmlColor("#0000FF")
    check btnB.stroke.weight == 0.0
    check btnB.stroke.color == clearColor

    ## Not a direct descendant of body or child2, should be orig
    # should be untouched
    check btnC.fill == initialColor
    check btnC.stroke.weight == 0.0
    check btnC.stroke.color == clearColor

  test "css grandchild descdendant":
    const themeSrc = """

    #child3 Button {
      background: #00FFFF;
    }
    """
    setupMain(themeSrc)

    # echo "btnB: ", $btnB
    check btnD.fill == parseHtmlColor("#00FFFF")

    # should be untouched
    check btnA.fill == initialColor
    check btnB.fill == initialColor
    check btnC.fill == initialColor

  test "css grandchild descdendant of direct child":
    const themeSrc = """

    #child2 Button {
      background: #00FFFF;
    }
    """
    setupMain(themeSrc)

    # echo "btnB: ", $btnB
    check btnB.fill == parseHtmlColor("#00FFFF")

    # should be untouched
    check btnA.fill == initialColor
    check btnD.fill == initialColor
    check btnC.fill == initialColor

  test "test hover":
    const themeSrc = """
    #child2 Button:hover {
      background: #0000FF;
    }

    #child3 Button:hover {
      background: #00FFFF;
    }
    """
    setupMain(themeSrc)
    # if evHover in current.events:
    btnD.events.incl evHover
    child30.events.incl evHover
    echo "btnD.events: ", btnD.events
    emit main.doDraw()

    # print main.frame[].theme.cssRules
    # echo "btnB: ", $btnB
    check btnD.fill == parseHtmlColor("#00FFFF")

    check evHover notin btnB.events
    check btnB.fill != parseHtmlColor("#0000FF")
    check btnB.fill == initialColor

    # should be untouched
    check child30.fill == clearColor
    check btnA.fill == initialColor
    check btnC.fill == initialColor

  test "test comment":
    const themeSrc = """
    /* #child3 Button:hover {
      background: #00FFFF;
    } */
    #child2 Button:hover {
      background: #0000FF;
    }
    /* #child3 Button:hover {
      background: #00FFFF;
    } */
    """
    setupMain(themeSrc)
    # if evHover in current.events:
    btnB.events.incl evHover
    emit main.doDraw()

    # print main.frame[].theme.cssRules
    check btnB.fill == parseHtmlColor("#0000FF")

    # should be untouched
    check child30.fill == clearColor
    check btnA.fill == initialColor
    check btnC.fill == initialColor
    check btnD.fill == initialColor

  test "box shadow":
    const themeSrc = """

    #child2 < Button {
      background: #0000FF;
      box-shadow: 5px 5px 10px red;
    }

    """
    setupMain(themeSrc)

    check btnB.fill == parseHtmlColor("#0000FF")
    check btnB.shadow[DropShadow].x == 5
    check btnB.shadow[DropShadow].y == 5
    check btnB.shadow[DropShadow].blur == 10
    check btnB.shadow[DropShadow].color == parseHtmlColor("red")

    check btnB.shadow[InnerShadow].blur == 0
    check btnB.shadow[InnerShadow].color == clearColor
    # check btnB.fill == parseHtmlColor("#FF0000")
    check btnB.stroke.weight == 0.0
    check btnB.stroke.color == clearColor

  test "box shadow 2":
    const themeSrc = """

    #child2 < Button {
      background: #0000FF;
      box-shadow: 5px 5px red;
    }

    """
    setupMain(themeSrc)

    check btnB.fill == parseHtmlColor("#0000FF")
    check btnB.shadow[DropShadow].x == 5
    check btnB.shadow[DropShadow].y == 5
    check btnB.shadow[DropShadow].blur == 0
    check btnB.shadow[DropShadow].color == parseHtmlColor("red")

    check btnB.shadow[InnerShadow].blur == 0
    check btnB.shadow[InnerShadow].color == clearColor
    # check btnB.fill == parseHtmlColor("#FF0000")
    check btnB.stroke.weight == 0.0
    check btnB.stroke.color == clearColor

  test "box shadow 3":
    const themeSrc = """

    #child2 < Button {
      background: #0000FF;
      box-shadow: 5px 5px 10px 20px red;
    }

    """
    setupMain(themeSrc)

    check btnB.fill == parseHtmlColor("#0000FF")
    check btnB.shadow[DropShadow].x == 5
    check btnB.shadow[DropShadow].y == 5
    check btnB.shadow[DropShadow].blur == 10
    check btnB.shadow[DropShadow].spread == 20
    check btnB.shadow[DropShadow].color == parseHtmlColor("red")

    check btnB.shadow[InnerShadow].blur == 0
    check btnB.shadow[InnerShadow].color == clearColor
    # check btnB.fill == parseHtmlColor("#FF0000")
    check btnB.stroke.weight == 0.0
    check btnB.stroke.color == clearColor

  test "inset box shadow":
    const themeSrc = """

    #child2 < Button {
      background: #0000FF;
      box-shadow: 5px 5px 10px red inset;
    }

    """
    setupMain(themeSrc)

    check btnB.fill == parseHtmlColor("#0000FF")
    check btnB.shadow[DropShadow].blur == 0
    check btnB.shadow[DropShadow].color == clearColor

    check btnB.shadow[InnerShadow].x == 5
    check btnB.shadow[InnerShadow].y == 5
    check btnB.shadow[InnerShadow].blur == 10
    check btnB.shadow[InnerShadow].color == parseHtmlColor("red")
    # check btnB.fill == parseHtmlColor("#FF0000")
    check btnB.stroke.weight == 0.0
    check btnB.stroke.color == clearColor

  test "inset box shadow 2":
    const themeSrc = """

    #child2 < Button {
      background: #0000FF;
      box-shadow: 5px 5px 10px 20px red inset;
    }

    """
    setupMain(themeSrc)

    check btnB.fill == parseHtmlColor("#0000FF")
    check btnB.shadow[DropShadow].blur == 0
    check btnB.shadow[DropShadow].color == clearColor

    check btnB.shadow[InnerShadow].x == 5
    check btnB.shadow[InnerShadow].y == 5
    check btnB.shadow[InnerShadow].blur == 10
    check btnB.shadow[InnerShadow].spread == 20
    check btnB.shadow[InnerShadow].color == parseHtmlColor("red")
    # check btnB.fill == parseHtmlColor("#FF0000")
    check btnB.stroke.weight == 0.0
    check btnB.stroke.color == clearColor

  test "box shadow none":
    let themeSrc = """

    #child2 < Button {
      background: #0000FF;
      box-shadow: 5px 5px 10px red;
    }

    """
    setupMain(themeSrc)

    check btnB.fill == parseHtmlColor("#0000FF")
    check btnB.shadow[DropShadow].x == 5
    check btnB.shadow[DropShadow].y == 5
    check btnB.shadow[DropShadow].blur == 10
    check btnB.shadow[DropShadow].color == parseHtmlColor("red")

    let themeSrc2 = """

    #child2 < Button {
      background: #0000FF;
      box-shadow: none;
    }

    """
    let parser = newCssParser(themeSrc2)
    let cssTheme = parse(parser)
    main.frame[].theme.cssRules = cssTheme
    emit main.doDraw()

    check btnB.fill == parseHtmlColor("#0000FF")
    check btnB.shadow[DropShadow].blur == 0
    check btnB.shadow[DropShadow].color == blackColor

    check btnB.shadow[InnerShadow].x == 0
    check btnB.shadow[InnerShadow].y == 0
    check btnB.shadow[InnerShadow].blur == 0

  test "box shadow none inset":
    let themeSrc = """

    #child2 < Button {
      background: #0000FF;
      box-shadow: 5px 5px 10px red inset;
    }

    """
    setupMain(themeSrc)

    check btnB.fill == parseHtmlColor("#0000FF")
    check btnB.shadow[InnerShadow].x == 5
    check btnB.shadow[InnerShadow].y == 5
    check btnB.shadow[InnerShadow].blur == 10
    check btnB.shadow[InnerShadow].color == parseHtmlColor("red")

    let themeSrc2 = """

    #child2 < Button {
      background: #0000FF;
      box-shadow: none inset;
    }

    """
    let parser = newCssParser(themeSrc2)
    let cssTheme = parse(parser)
    main.frame[].theme.cssRules = cssTheme
    emit main.doDraw()

    check btnB.fill == parseHtmlColor("#0000FF")
    check btnB.shadow[InnerShadow].blur == 0
    check btnB.shadow[InnerShadow].color == blackColor
    check btnB.shadow[InnerShadow].x == 0
    check btnB.shadow[InnerShadow].y == 0
    check btnB.shadow[InnerShadow].blur == 0
