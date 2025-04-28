## This is a simple example on how to use Stylus' tokenizer.
import std/unittest
import chroma
import cssgrid
import pretty
import chronicles

import figuro/widget
import figuro/common/nodes/uinodes
import figuro/common/nodes/render
import figuro/widgets/button

suite "css parser":
  setup:
    setLogLevel(WARN)
    # setLogLevel(TRACE)

  test "blocks":
    # skip()
    const src = """
    :root {
      --color-background: #000000;
    }

    Button {
    }

    Button.btnBody {
    }

    Button child {
    }

    Button > directChild {
    }

    Button > directChild.field {
    }

    Button:hover {
    }

    #name {
    }

    Button > #child {
    }

    Button #child {
    }

    Slider > #bar > #filling > #button-bg > #button {
    }

    Slider #bar > #filling #button-bg > #button {
    }

    Button {
      width: calc(100% - 10px);
      height: min(100%, 100px);
      left: max(100%, 100px);
    }
    """

    let parser = newCssParser(src)
    let values = newCssValues()
    let res = parse(parser, values)
    # echo "root: ", res[0].repr
    check res[0].selectors == @[CssSelector(cssType: atom"root", combinator: skPseudo)]

    check res[1].selectors == @[CssSelector(cssType: atom"Button")]
    check res[2].selectors == @[CssSelector(cssType: atom"Button", class: atom"btnBody")]
    check res[3].selectors == @[
      CssSelector(cssType: atom"Button", combinator: skNone),
      CssSelector(cssType: atom"child", combinator: skDescendent)
    ]
    check res[4].selectors == @[
      CssSelector(cssType: atom"Button", combinator: skNone),
      CssSelector(cssType: atom"directChild", combinator: skDirectChild)
    ]
    check res[5].selectors == @[
      CssSelector(cssType: atom"Button", combinator: skNone),
      CssSelector(cssType: atom"directChild", class: atom"field", combinator: skDirectChild)
    ]
    check res[6].selectors == @[
      CssSelector(cssType: atom"Button", combinator: skNone),
      CssSelector(cssType: atom"hover", combinator: skPseudo)
    ]
    check res[7].selectors == @[
      CssSelector(id: atom"name", combinator: skNone),
    ]
    check res[8].selectors == @[
      CssSelector(cssType: atom"Button", combinator: skNone),
      CssSelector(id: atom"child", combinator: skDirectChild)
    ]
    check res[9].selectors == @[
      CssSelector(cssType: atom"Button", combinator: skNone),
      CssSelector(id: atom"child", combinator: skDescendent)
    ]
    check res[10].selectors == @[
      CssSelector(cssType: atom"Slider", combinator: skNone),
      CssSelector(id: atom"bar", combinator: skDirectChild),
      CssSelector(id: atom"filling", combinator: skDirectChild),
      CssSelector(id: atom"button-bg", combinator: skDirectChild),
      CssSelector(id: atom"button", combinator: skDirectChild)
    ]
    check res[11].selectors == @[
      CssSelector(cssType: atom"Slider", combinator: skNone),
      CssSelector(id: atom"bar", combinator: skDescendent),
      CssSelector(id: atom"filling", combinator: skDirectChild),
      CssSelector(id: atom"button-bg", combinator: skDescendent),
      CssSelector(id: atom"button", combinator: skDirectChild)
    ]
    check res[12].selectors == @[
      CssSelector(cssType: atom"Button", combinator: skNone),
    ]
    check res[12].properties[0] == CssProperty(name: atom"width", value: CssSize(csSub(csPerc(100.0), csFixed(10.0))))
    check res[12].properties[1] == CssProperty(name: atom"height", value: CssSize(csMin(csPerc(100.0), csFixed(100.0))))

    # echo "results: ", res[6].selectors.repr

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
    let values = newCssValues()
    let res = parse(parser, values)[0]
    check res.selectors == @[CssSelector(cssType: atom"Button", combinator: skNone)]
    check res.properties.len() == 5
    check res.properties[0] == CssProperty(name: atom"color-background", value: CssColor(parseHtmlColor("#00a400")))
    check res.properties[1] == CssProperty(name: atom"color", value: CssColor(parseHtmlColor("rgb(214, 122, 127)")))
    check res.properties[2] == CssProperty(name: atom"border-width", value: CssSize(csFixed(1.0.UiScalar)))
    check res.properties[3] == CssProperty(name: atom"width", value: CssSize(csPerc(80.0)))
    check res.properties[4] == CssProperty(name: atom"border-radius", value: CssSize(csFixed(25.0)))
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
    let values = newCssValues()
    let res = parse(parser, values)[0]
    # echo "results: ", res.repr
    check res.selectors[0] == CssSelector(cssType: atom"Button", combinator: skNone)
    check res.properties[0] == CssProperty(name: atom"color", value: CssColor(parseHtmlColor("rgb(214, 122, 127)")))

  test "missing property name":
    const src = """

    Button {
      : #00a400;
      color: rgb(214, 122, 127);
    }

    """

    let parser = newCssParser(src)
    let values = newCssValues()
    let res = parse(parser, values)[0]
    # echo "results: ", res.repr
    check res.selectors[0] == CssSelector(cssType: atom"Button", combinator: skNone)
    check res.properties[0] == CssProperty(name: atom"color", value: CssColor(parseHtmlColor("rgb(214, 122, 127)")))

  test "test child descent tokenizer is working":
    if true:
      const src = """
      Button > directChild {
      }

      Button > directChild.field {
      }
      """

      echo "trying to parse `>`..."
      let parser = newCssParser(src)
      let values = newCssValues()
      let res = parse(parser, values)
      # for r in res:
      #   echo "results: ", r.repr

type
  TMain* = ref object of Figuro

proc draw*(self: TMain) {.slot.} =
  withWidget(self):
    this.name = "main".toAtom()
    rectangle "body":
      rectangle "child1":
        discard
        Button[int].new "btnC":
          with this:
            box 40'ux, 30'ux, 80'ux, 80'ux
            fill css"#FFFFFF"

      Button[int].new "btnA":
        with this:
          box 40'ux, 30'ux, 80'ux, 80'ux
          fill css"#FFFFFF"
    
      rectangle "child2":
        Button[int].new "btnB":
          with this:
            box 40'ux, 30'ux, 80'ux, 80'ux
            fill css"#FFFFFF"
          rectangle "child21":
            with this:
              box 40'ux, 30'ux, 80'ux, 80'ux
              fill css"#FFFFFF"

      rectangle "child3":
        rectangle "child30":
          Button[int].new "btnD":
            with this:
              box 40'ux, 30'ux, 80'ux, 80'ux
              fill css"#FFFFFF"

const
  initialColor = parseHtmlColor "#FFFFFF"

suite "css exec":

  template setupMain(themeSrc) =
    var main {.inject.} = TMain.new()
    var frame = newAppFrame(main, size=(400'ui, 140'ui))
    main.frame = frame.unsafeWeakRef()
    main.frame[].theme = Theme(font: defaultFont())
    let parser = newCssParser(themeSrc)
    let values {.inject, used.} = newCssValues()
    let rules = parse(parser, values)
    echo "rules: ", rules
    echo "values: ", values
    # print cssTheme
    main.frame[].theme.cssValues = values
    main.frame[].theme.css = @[(path: "", theme: CssTheme(rules: rules))]
    connectDefaults(main)
    emit main.doDraw()
    let btnA {.inject, used.} = main.children[0].children[1]
    let btnB {.inject, used.} = main.children[0].children[2].children[0]
    let btnC {.inject, used.} = main.children[0].children[0].children[0]
    let child30 {.inject, used.} = main.children[0].children[3].children[0]
    let btnD {.inject, used.} = main.children[0].children[3].children[0].children[0]
    let child21 {.inject, used.} = btnB.children[0]

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
    #body > Button {
      background: #FF0000;
      border-width: 3;
      border-color: #00FF00;
    }

    #child2 > Button {
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

  test "match kind with direct child id selector":
    const themeSrc = """

    Button > #child21 {
      background: #F0F0F0;
    }
    """
    setupMain(themeSrc)

    # echo "btnB: ", $btnB
    check btnB.fill == initialColor
    check child21.fill == parseHtmlColor("#F0F0F0")

    # should be untouched
    check btnA.fill == initialColor
    check btnD.fill == initialColor
    check btnC.fill == initialColor

  test "match kind with descendent child id selector":
    const themeSrc = """

    Button #child21 {
      background: #F0F0F0;
    }
    """
    setupMain(themeSrc)

    # echo "btnB: ", $btnB
    check btnB.fill == initialColor
    check child21.fill == parseHtmlColor("#F0F0F0")

    # should be untouched
    check btnA.fill == initialColor
    check btnD.fill == initialColor
    check btnC.fill == initialColor
    # check main.fill == initialColor

  test "match kind with multiple path direct children":
    const themeSrc = """

    #child2 > Button > #child21 {
      background: #F0F0F0;
    }
    """
    setupMain(themeSrc)

    # echo "btnB: ", $btnB
    check btnB.fill == initialColor
    check child21.fill == parseHtmlColor("#F0F0F0")

    # should be untouched
    check btnA.fill == initialColor
    check btnD.fill == initialColor
    check btnC.fill == initialColor

  test "match kind with long path direct children":
    const themeSrc = """

    #body > #child2 > Button > #child21 {
      background: #F0F0F0;
    }
    """
    setupMain(themeSrc)

    # echo "btnB: ", $btnB
    check btnB.fill == initialColor
    check child21.fill == parseHtmlColor("#F0F0F0")

    # should be untouched
    check btnA.fill == initialColor
    check btnD.fill == initialColor
    check btnC.fill == initialColor

  test "match kind with multiple path descendent children":
    const themeSrc = """

    #child2 Button #child21 {
      background: #F0F0F0;
    }
    """
    setupMain(themeSrc)

    # echo "btnB: ", $btnB
    check btnB.fill == initialColor
    check child21.fill == parseHtmlColor("#F0F0F0")

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

  test "string conversion":
    # Test the string conversion functions for CSS types
    let selector1 = CssSelector(cssType: atom"Button", class: atom"primary")
    let selector2 = CssSelector(id: atom"myId")
    let selector3 = CssSelector(cssType: atom"hover", combinator: skPseudo)
    
    check $selector1 == "Button.primary"
    check $selector2 == "#myId"
    check $selector3 == ":hover"
    
    # Test with linked selectors
    let selectorA = CssSelector(cssType: atom"Button")
    let selectorB = CssSelector(cssType: atom"hover", combinator: skPseudo)
    let linked = CssBlock(
      selectors: @[selectorA, selectorB],
      properties: @[]
    )
    check $linked == "Button:hover {\n}"
    
    let property1 = CssProperty(name: atom"background", value: CssColor(parseHtmlColor("#FF0000")))
    let property2 = CssProperty(name: atom"width", value: CssSize(csFixed(20.0)))
    
    check $property1 == "background: #FF0000;"
    check $property2 == "width: 20.0'ux;"
    
    # Test CSS block
    let blk = CssBlock(
      selectors: @[selector1, selector3],
      properties: @[property1, property2]
    )
    
    let blkStr = $blk
    check blkStr.contains("Button.primary:hover {")
    check blkStr.contains("  background: #FF0000;")
    check blkStr.contains("  width: 20.0'ux;")
    
    # Test full theme
    let theme = CssTheme(
      rules: @[blk],
    )
    
    let themeStr = $theme
    check themeStr.contains("Button.primary:hover {")
    check themeStr.contains("  background: #FF0000;")
    check themeStr.contains("  width: 20.0'ux;")

  test "box shadow":
    const themeSrc = """

    #child2 > Button {
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

    #child2 > Button {
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

    #child2 > Button {
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

    #child2 > Button {
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

    #child2 > Button {
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

    #child2 > Button {
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

    #child2 > Button {
      background: #0000FF;
      box-shadow: none;
    }

    """
    let parser = newCssParser(themeSrc2)
    let cssValues = newCssValues()
    main.frame[].theme.cssValues = cssValues
    main.frame[].theme.css = @[(path: "", theme: newCssTheme(parser, values))]
    emit main.doDraw()

    check btnB.fill == parseHtmlColor("#0000FF")
    check btnB.shadow[DropShadow].blur == 0
    check btnB.shadow[DropShadow].color == blackColor

    check btnB.shadow[InnerShadow].x == 0
    check btnB.shadow[InnerShadow].y == 0
    check btnB.shadow[InnerShadow].blur == 0

  test "box shadow none inset":
    let themeSrc = """

    #child2 > Button {
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

    # CSS Warning: unhandled css shadow kind:
    let themeSrc2 = """

    #child2 > Button {
      background: #0000FF;
      box-shadow: none inset;
    }

    """
    let parser = newCssParser(themeSrc2)
    let cssValues = newCssValues()
    main.frame[].theme.cssValues = cssValues
    main.frame[].theme.css = @[(path: "", theme: newCssTheme(parser, values))]
    emit main.doDraw()

    check btnB.fill == parseHtmlColor("#0000FF")
    check btnB.shadow[InnerShadow].blur == 0
    check btnB.shadow[InnerShadow].color == blackColor
    check btnB.shadow[InnerShadow].x == 0
    check btnB.shadow[InnerShadow].y == 0

  test "empty css":
    let themeSrc = """

    /* #child2 > Button {
      background: #0000FF;
      box-shadow: 5px 5px 10px red inset;
    } */

    """
    let parser = newCssParser(themeSrc)
    let values = newCssValues()
    let res = parse(parser, values)
    check res.len() == 0

  test "css variables":
    # setLogLevel(TRACE)
    const themeSrc = """
    :root {
      --primary-color: #FF0000;
      --secondary-color: #00FF00;
      --spacing: 10px;
    }

    #child2 > Button {
      background: var(--primary-color);
      border-width: var(--spacing);
      border-color: var(--secondary-color);
    }
    
    #child3 Button {
      background: var(--secondary-color);
    }
    """
    
    setupMain(themeSrc)
    
    # Check that variables are properly applied
    check btnB.fill == parseHtmlColor("#FF0000")
    check btnB.stroke.weight == 10.0
    check btnB.stroke.color == parseHtmlColor("#00FF00")
    
    check btnD.fill == parseHtmlColor("#00FF00")
    
  test "calc expression":
    const themeSrc = """
    #child2 > Button {
      width: calc(100% - 10px);
    }
    """
    
    setupMain(themeSrc)
    
    # Check that calc expressions are properly parsed and applied
    check btnB.cxSize[dcol] == csSub(csPerc(100.0), csFixed(10.0))
    

  test "nested css variables":
    const themeSrc = """
    :root {
      --base-color: #FF0000;
      --accent-color: var(--base-color);
      --padding-base: 5px;
      --padding-other: var(--padding-base);
    }

    #child2 > Button {
      background: var(--accent-color);
      border-width: var(--padding-other);
    }
    """
    
    setupMain(themeSrc)
    
    # Check that nested variables are resolved correctly
    check btnB.fill == parseHtmlColor("#FF0000")
    check btnB.stroke.weight == 5.0  # 5px * 2
    
    # Update base variables and check that dependent variables update
    let updatedThemeSrc = """
    :root {
      --base-color: #0000FF;
      --accent-color: var(--base-color);
      --padding-base: 8px;
      --padding-other: var(--padding-base);
    }

    #child2 > Button {
      background: var(--accent-color);
      border-width: var(--padding-other);
    }
    """
    
    let parser = newCssParser(updatedThemeSrc)
    let cssValues = newCssValues()
    main.frame[].theme.cssValues = cssValues
    main.frame[].theme.css = @[(path: "", theme: newCssTheme(parser, values))]
    emit main.doDraw()
    
    # Check that updated nested variables are applied
    check btnB.fill == parseHtmlColor("#0000FF")
    check btnB.stroke.weight == 8.0  # 8px * 2


