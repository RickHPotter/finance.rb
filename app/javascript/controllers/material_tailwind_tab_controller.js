import { Controller } from "@hotwired/stimulus"

// WHERE CREDITS ARE DUE: This only became a stimulus controller due to the nature of TurboFrame
// <script src="https://unpkg.com/@material-tailwind/html@latest/scripts/tabs.js"></script>
//
// Connects to data-controller="material-tailwind-tab"
export default class extends Controller {
  static targets = ["tabList", "tabItem", "tabLink"]

  connect() {
    this.initialise()

    const loadOnEmptyContent = this.element.dataset.loadOnEmptyContent
    const emptyContent       = document.getElementById(loadOnEmptyContent)

    if(!loadOnEmptyContent)          { return }
    if(emptyContent.children.length) { return }

    this.render_default()
  }

  initialise() {
    const tabs = this.tabListTargets
    tabs.forEach(tab => { this.add_moving_part(tab) })

    tabs.filter(item => item.dataset.default == "false").forEach(item => {
      item.parentElement.classList.add("hidden")
    });

    this.tabularise()
  }

  render_default() {
    const links = this.tabLinkTargets
    const selected_links = links.filter(e => e.getAttribute("aria-selected") == "true")
    selected_links.forEach(link => link.click())
  }

  add_moving_part(tab) {
    var getEventTarget = function getEventTarget(e) {
      return e.target || e.srcElement
    }

    const obj = { item: null, offsetWidth: 0 }
    const items = this.tabLinkTargets.filter(item => tab.contains(item))

    obj.item = items.find(item => {
      if (item.getAttribute("aria-selected") == "true") {
        return item
      }

      obj.offsetWidth += item.offsetWidth
    })

    if (!obj.item) {
      obj.item = items[0]
      obj.offsetWidth = 0
    }

    const { item, offsetWidth } = obj
    const width = item.offsetWidth

    var moving_div = document.createElement("div")
    var new_tab = item.cloneNode()
    new_tab.innerHTML = "-"
    new_tab.classList.remove("bg-inherit", "text-slate-700")
    new_tab.classList.add("bg-white", "dark:bg-sky-500", "text-transparent")
    new_tab.style.animation = ".2s ease"

    moving_div.appendChild(new_tab)
    moving_div.classList.add("z-10", "absolute", "text-slate-700", "rounded-lg", "bg-inherit", "flex-auto", "text-center", "bg-none", "border-0", "block", "shadow")
    moving_div.setAttribute("moving-tab", "")
    moving_div.setAttribute("data-material-tailwind-tab-target", "tabLink")
    moving_div.style.padding = "0px"
    moving_div.style.width = width + "px"
    moving_div.style.transform = `translate3d(${offsetWidth}px, 0px, 0px)`
    moving_div.style.transition = ".5s ease"

    tab.appendChild(moving_div)

    tab.onmouseover = function(event) {
      var target = getEventTarget(event)
      var li = target.closest("li")
      if (li) {
        var nodes = Array.from(li.closest("ul").children)
        var index = nodes.indexOf(li) + 1
        tab.querySelector("li:nth-child(" + index + ") [data-material-tailwind-tab-target=tabLink]").onclick = function() {
          tab.querySelectorAll("li").forEach(function(list_item) {
            list_item.firstElementChild.removeAttribute("active")
            list_item.firstElementChild.setAttribute("aria-selected", "false")
          })
          li.firstElementChild.setAttribute("active", "")
          li.firstElementChild.setAttribute("aria-selected", "true")
          moving_div = tab.querySelector("[moving-tab]")
          var sum = 0
          if (tab.classList.contains("flex-col")) {
            for (var j = 1; j <= nodes.indexOf(li); j++) {
              sum += tab.querySelector("li:nth-child(" + j + ")").offsetHeight
            }
            moving_div.style.transform = "translate3d(0px," + sum + "px, 0px)"
            moving_div.style.height = tab.querySelector("li:nth-child(" + j + ")").offsetHeight
          } else {
            for (var j = 1; j <= nodes.indexOf(li); j++) {
              sum += tab.querySelector("li:nth-child(" + j + ")").offsetWidth
            }
            moving_div.style.transform = "translate3d(" + sum + "px, 0px, 0px)"
            moving_div.style.width = tab.querySelector("li:nth-child(" + index + ")").offsetWidth + "px"
          }
        }
      }
    }
  }

  tabularise() {
    const total = document.querySelectorAll("[data-tab-content]") || []
    total.forEach(function(nav_pills) {
      const links = nav_pills.previousElementSibling.querySelectorAll("li a[data-material-tailwind-tab-target=tabLink]")
      links.forEach(function(link) {
        link.addEventListener("click", function() {
          const clicked_tab = document.querySelector("#" + link.getAttribute("aria-controls"))
          if (clicked_tab.classList.contains("block", "opacity-100")) return

          const active_link_v = clicked_tab.closest("[data-tab-content]").parentElement
          const active_link = active_link_v.querySelector("li a[data-material-tailwind-tab-target=tabLink][aria-selected='true']")
          const active_panel = document.querySelector("#" + active_link.getAttribute("aria-controls"));
          active_panel.classList.remove("block", "opacity-100")
          active_panel.classList.add("hidden", "opacity-0")
          clicked_tab.classList.add("block", "opacity-100")
          clicked_tab.classList.remove("hidden", "opacity-0")
        })
      })
    })
  }

  updateParentLink({ target }) {
    const parentId = target.dataset.parentId
    const parent   = this.tabLinkTargets.find((link) => link.dataset.id === parentId )
    parent.href    = target.href
  }
}
