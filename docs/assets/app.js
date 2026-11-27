(function () {
  const Config = window.DOCS || {}
  const External = /^(https?:)?\/\//
  const State = { Path: null, Sidebar: undefined, Ticket: 0 }

  const MoonIcon = '<svg class="moon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"></path></svg>'
  const SunIcon = '<svg class="sun" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="4"></circle><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"></path></svg>'
  const GithubIcon = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 19c-4 1.5-4-2-6-2.5M15 21v-3.5a3 3 0 0 0-.8-2.3c2.7-.3 5.5-1.3 5.5-6a4.7 4.7 0 0 0-1.3-3.2 4.4 4.4 0 0 0-.1-3.2s-1-.3-3.4 1.3a11.6 11.6 0 0 0-6.2 0C6.3 2.5 5.3 2.8 5.3 2.8a4.4 4.4 0 0 0-.1 3.2A4.7 4.7 0 0 0 3.9 9.2c0 4.6 2.8 5.7 5.5 6a3 3 0 0 0-.8 2.3V21"></path></svg>'

  const Labels = { tip: "Tip", info: "Info", note: "Note", warning: "Warning", danger: "Danger", details: "Details" }
  const Aliases = { luau: "lua", sh: "bash", shell: "bash", zsh: "bash", js: "javascript", ts: "typescript" }

  const escape = (Value) =>
    String(Value ?? "").replace(/[&<>"']/g, (Char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[Char])

  const slugify = (Value) =>
    String(Value)
      .toLowerCase()
      .replace(/<[^>]*>/g, "")
      .replace(/&[#a-z0-9]+;/g, "")
      .replace(/[^\p{L}\p{N}\s-]/gu, "")
      .trim()
      .replace(/\s+/g, "-")

  const asset = (Source) => String(Source || "").replace(/^\/+/, "")

  const link = (Target) => {
    const Value = String(Target || "")
    if (External.test(Value) || /^(mailto|tel):/.test(Value) || Value.startsWith("#")) {
      return Value
    }
    const Path = Value.replace(/^\.?\/+/, "").replace(/\.md$/, "").replace(/(^|\/)index$/, "$1")
    return "#/" + Path
  }

  const outside = (Target) => (External.test(Target) ? ' target="_blank" rel="noopener"' : "")

  const readHash = () => {
    const Raw = decodeURIComponent(location.hash.slice(1))
    if (!Raw.startsWith("/")) {
      return { Path: State.Path ?? "", Anchor: Raw || null }
    }
    const [Path, Query] = Raw.slice(1).split("?")
    return { Path, Anchor: Query ? new URLSearchParams(Query).get("h") : null }
  }

  const fileFor = (Path) => (Path === "" || Path.endsWith("/") ? Path + "index.md" : Path + ".md")

  const splitFront = (Text) => {
    const Match = Text.match(/^---\r?\n([\s\S]*?)\r?\n---[ \t]*(\r?\n|$)/)
    if (!Match) {
      return { Data: {}, Body: Text }
    }
    let Data = {}
    try {
      Data = window.jsyaml.load(Match[1]) || {}
    } catch (Problem) {
      console.warn("[docs] the front matter could not be read", Problem)
    }
    return { Data, Body: Text.slice(Match[0].length) }
  }

  const renderMarkdown = (Source) => {
    const Toc = []
    const Seen = {}
    const Blocks = []
    const Text = Source.replace(/^:::[ \t]*(tip|info|note|warning|danger|details)[ \t]*(.*)\r?\n([\s\S]*?)^:::[ \t]*$/gm, (_, Kind, Title, Inner) => {
      Blocks.push({ Kind, Title: Title.trim() || Labels[Kind], Inner })
      return `\n\n<!--block:${Blocks.length - 1}-->\n\n`
    })

    const Renderer = new window.marked.Renderer()
    Renderer.heading = (Inner, Level, Raw) => {
      const Plain = String(Raw).replace(/`/g, "")
      let Id = slugify(Plain) || "section"
      if (Seen[Id] === undefined) {
        Seen[Id] = 0
      } else {
        Seen[Id] += 1
        Id = `${Id}-${Seen[Id]}`
      }
      if (Level === 2 || Level === 3) {
        Toc.push({ Id, Level, Text: Plain.replace(/\(.*$/, "").trim() })
      }
      return `<h${Level} id="${Id}">${Inner}<a class="anchor" href="#${Id}" aria-label="Link to ${escape(Plain)}">#</a></h${Level}>\n`
    }
    Renderer.code = (Code, Info) => {
      const Lang = String(Info || "").trim().split(/\s+/)[0].toLowerCase()
      const Name = Aliases[Lang] || Lang
      const Highlighter = window.hljs
      const Body = Highlighter && Name && Highlighter.getLanguage(Name)
        ? Highlighter.highlight(Code, { language: Name, ignoreIllegals: true }).value
        : escape(Code)
      const Label = Lang ? `<span class="lang">${escape(Lang)}</span>` : ""
      return `<div class="code">${Label}<button class="copy" type="button">Copy</button><pre><code>${Body}</code></pre></div>\n`
    }
    Renderer.link = (Href, Title, Inner) => {
      const Target = link(Href)
      const Hint = Title ? ` title="${escape(Title)}"` : ""
      return `<a href="${escape(Target)}"${Hint}${outside(Target)}>${Inner}</a>`
    }
    Renderer.image = (Href, Title, Alt) => {
      const Source = External.test(Href) ? Href : asset(Href)
      const Hint = Title ? ` title="${escape(Title)}"` : ""
      return `<img src="${escape(Source)}" alt="${escape(Alt)}"${Hint} loading="lazy">`
    }
    Renderer.table = (Header, Body) => `<div class="table"><table><thead>${Header}</thead><tbody>${Body}</tbody></table></div>\n`

    let Html = window.marked.parse(Text, { renderer: Renderer, gfm: true })
    Html = Html.replace(/<!--block:(\d+)-->/g, (_, Index) => {
      const Block = Blocks[Number(Index)]
      const Inner = renderMarkdown(Block.Inner).Html
      if (Block.Kind === "details") {
        return `<details class="callout details"><summary>${escape(Block.Title)}</summary>${Inner}</details>`
      }
      return `<div class="callout ${Block.Kind}"><p class="callout-title">${escape(Block.Title)}</p>${Inner}</div>`
    })
    return { Html, Toc }
  }

  const button = (Action) => {
    const Target = link(Action.link)
    const Kind = Action.theme === "alt" ? "alt" : "brand"
    return `<a class="button ${Kind}" href="${escape(Target)}"${outside(Target)}>${escape(Action.text)}</a>`
  }

  const renderDirectory = (Sections) => {
    if (!Array.isArray(Sections) || Sections.length === 0) {
      return ""
    }
    const Columns = Sections.map((Section) => {
      const Links = (Section.links || []).map((Item) => {
        const Target = link(Item.link)
        return `<li><a href="${escape(Target)}"${outside(Target)}>${escape(Item.text)}</a></li>`
      }).join("")
      return `<div class="directory-group"><h3>${escape(Section.title)}</h3><ul>${Links}</ul></div>`
    }).join("")
    return `<section class="directory" aria-labelledby="directory-title"><h2 id="directory-title">Browse the docs</h2><div class="directory-grid">${Columns}</div></section>`
  }

  const renderHome = (Data, Html) => {
    const Hero = Data.hero || {}
    const Actions = Array.isArray(Hero.actions) ? `<div class="hero-actions">${Hero.actions.map(button).join("")}</div>` : ""
    const Features = (Data.features || [])
      .map((Feature) => `<article class="feature"><h2>${escape(Feature.title)}</h2><p>${escape(Feature.details)}</p></article>`)
      .join("")
    const Sample = Hero.code
      ? `<figure class="hero-code">${renderMarkdown("```" + (Hero.codeLang || "luau") + "\n" + String(Hero.code).replace(/\n$/, "") + "\n```").Html}${Hero.codeCaption ? `<figcaption>${escape(Hero.codeCaption)}</figcaption>` : ""}</figure>`
      : ""
    return `<div class="home">
<section class="hero${Sample ? " has-code" : ""}">
<div class="hero-text">
${Hero.eyebrow ? `<p class="hero-eyebrow">${escape(Hero.eyebrow)}</p>` : ""}
${Hero.name ? `<h1 class="hero-name">${escape(Hero.name)}</h1>` : ""}
${Hero.text ? `<p class="hero-title">${escape(Hero.text)}</p>` : ""}
${Hero.tagline ? `<p class="hero-tagline">${escape(Hero.tagline)}</p>` : ""}
${Actions}
</div>
${Sample}
</section>
${Features ? `<section class="features" aria-label="Features">${Features}</section>` : ""}
${Html.trim() ? `<div class="home-body doc">${Html}</div>` : ""}
${renderDirectory(Data.sections)}
</div>`
  }

  const renderDoc = (Data, Rendered) => {
    const Sidebar = State.Sidebar
      ? `<button class="menu" type="button" aria-controls="sidebar" aria-expanded="false">Menu</button><nav class="sidebar" id="sidebar" aria-label="Pages">${State.Sidebar}</nav>`
      : ""
    const Headings = Rendered.Toc.map((Item) => `<a href="#${Item.Id}"${Item.Level === 3 ? ' class="sub"' : ""}>${escape(Item.Text)}</a>`).join("")
    const Toc = Data.outline === false || Rendered.Toc.length < 2
      ? ""
      : `<nav class="toc" aria-label="On this page"><p class="toc-title">On this page</p>${Headings}</nav>`
    return `<div class="page${Sidebar ? " has-sidebar" : ""}">${Sidebar}<main class="doc">${Rendered.Html}</main>${Toc}</div>`
  }

  const renderMessage = (Title, Text) =>
    `<div class="message"><h1>${escape(Title)}</h1><p>${escape(Text)}</p><a class="button brand" href="#/">Go home</a></div>`

  const header = () => {
    const Logo = Config.logo ? `<img src="${escape(asset(Config.logo))}" alt="" width="28" height="28">` : ""
    const Links = (Config.nav || []).map((Item) => {
      const Target = link(Item.link)
      return `<a href="${escape(Target)}"${outside(Target)}>${escape(Item.text)}</a>`
    }).join("")
    const Github = Config.github
      ? `<a class="icon-button" href="${escape(Config.github)}" target="_blank" rel="noopener" aria-label="GitHub">${GithubIcon}</a>`
      : ""
    return `<header class="nav">
<div class="nav-in">
<a class="brand" href="#/">${Logo}<span>${escape(Config.title || "Docs")}</span></a>
<nav class="nav-links" aria-label="Main">${Links}</nav>
<div class="nav-tools">
<button class="icon-button theme" type="button" aria-label="Switch between light and dark">${MoonIcon}${SunIcon}</button>
${Github}
</div>
</div>
</header>`
  }

  const loadSidebar = async () => {
    if (State.Sidebar !== undefined) {
      return
    }
    if (!Config.sidebar) {
      State.Sidebar = null
      return
    }
    try {
      const Response = await fetch(Config.sidebar, { cache: "no-cache" })
      State.Sidebar = Response.ok ? renderMarkdown(await Response.text()).Html : null
    } catch (Problem) {
      State.Sidebar = null
    }
  }

  const markActive = () => {
    const Here = "#/" + (State.Path ?? "")
    document.querySelectorAll(".nav-links a, .sidebar a").forEach((Item) => {
      const On = Item.getAttribute("href") === Here
      Item.classList.toggle("active", On)
      if (On) {
        Item.setAttribute("aria-current", "page")
      } else {
        Item.removeAttribute("aria-current")
      }
    })
  }

  const scrollToId = (Id) => {
    const Target = Id ? document.getElementById(Id) : null
    if (Target) {
      Target.scrollIntoView()
    }
  }

  const titleOf = (Data, Html) => {
    if (Data.title) {
      return Data.title
    }
    const Match = Html.match(/<h1[^>]*>([\s\S]*?)<a class="anchor"/)
    return Match ? Match[1].replace(/<[^>]*>/g, "") : null
  }

  const View = document.createElement("div")
  View.className = "view"

  const load = async () => {
    const Where = readHash()
    const Changed = Where.Path !== State.Path
    if (Changed) {
      State.Path = Where.Path
      const Ticket = ++State.Ticket
      let Text = null
      let Failed = false
      try {
        const Response = await fetch(fileFor(Where.Path), { cache: "no-cache" })
        if (Response.ok) {
          Text = await Response.text()
        }
      } catch (Problem) {
        Failed = true
      }
      if (Ticket !== State.Ticket) {
        return
      }
      if (Failed && location.protocol === "file:") {
        View.innerHTML = renderMessage("Open this through a web server", "Browsers block loading pages from files. Run python3 -m http.server inside the docs folder, then open http://localhost:8000")
      } else if (Text === null) {
        View.innerHTML = renderMessage("Page not found", "There is no page at this address.")
        document.title = `Not found | ${Config.title || "Docs"}`
      } else {
        const { Data, Body } = splitFront(Text)
        const Rendered = renderMarkdown(Body)
        if (Data.layout === "home") {
          View.innerHTML = renderHome(Data, Rendered.Html)
          document.title = Config.title || "Docs"
        } else {
          await loadSidebar()
          if (Ticket !== State.Ticket) {
            return
          }
          View.innerHTML = renderDoc(Data, Rendered)
          const Title = titleOf(Data, Rendered.Html)
          document.title = Title ? `${Title} | ${Config.title || "Docs"}` : Config.title || "Docs"
        }
      }
      markActive()
    }
    if (Where.Anchor) {
      scrollToId(Where.Anchor)
    } else if (Changed) {
      window.scrollTo(0, 0)
    }
  }

  const copy = (Button) => {
    const Block = Button.closest(".code")
    const Code = Block ? Block.querySelector("code") : null
    if (!Code) {
      return
    }
    const done = (Text) => {
      Button.textContent = Text
      setTimeout(() => {
        Button.textContent = "Copy"
      }, 1600)
    }
    if (navigator.clipboard) {
      navigator.clipboard.writeText(Code.textContent).then(() => done("Copied"), () => done("Press Ctrl C"))
    } else {
      done("Press Ctrl C")
    }
  }

  const toggleTheme = () => {
    const Dark = document.documentElement.classList.toggle("dark")
    try {
      localStorage.setItem("docs-theme", Dark ? "dark" : "light")
    } catch (Problem) {}
  }

  const toggleMenu = (Button) => {
    const Sidebar = document.getElementById("sidebar")
    if (!Sidebar) {
      return
    }
    const Open = Sidebar.classList.toggle("open")
    Button.setAttribute("aria-expanded", String(Open))
  }

  document.addEventListener("click", (Event) => {
    const Target = Event.target instanceof Element ? Event.target : null
    if (!Target) {
      return
    }
    const Copy = Target.closest(".copy")
    if (Copy) {
      copy(Copy)
      return
    }
    if (Target.closest(".theme")) {
      toggleTheme()
      return
    }
    const Menu = Target.closest(".menu")
    if (Menu) {
      toggleMenu(Menu)
      return
    }
    const Anchor = Target.closest("a[href^='#']")
    if (!Anchor) {
      return
    }
    const Href = Anchor.getAttribute("href")
    const Sidebar = document.getElementById("sidebar")
    if (Sidebar && Sidebar.classList.contains("open") && Anchor.closest(".sidebar")) {
      Sidebar.classList.remove("open")
    }
    if (Href.startsWith("#/") || Href === "#") {
      return
    }
    Event.preventDefault()
    const Id = Href.slice(1)
    scrollToId(Id)
    history.replaceState(null, "", `#/${State.Path ?? ""}?h=${encodeURIComponent(Id)}`)
  })

  const start = () => {
    const App = document.getElementById("app")
    if (!window.marked || !window.jsyaml) {
      App.innerHTML = renderMessage("Could not load the page tools", "The markdown reader did not load. Check your internet connection and refresh.")
      return
    }
    App.innerHTML = header()
    App.appendChild(View)
    if (Config.footer) {
      const Footer = document.createElement("footer")
      Footer.className = "footer"
      Footer.innerHTML = `<p>${escape(Config.footer)}</p>`
      App.appendChild(Footer)
    }
    window.addEventListener("hashchange", load)
    load()
  }

  start()
})()
