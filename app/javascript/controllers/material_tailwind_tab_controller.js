import { Controller } from '@hotwired/stimulus'

// WHERE CREDITS ARE DUE: This only became a stimulus controller due to the nature of TurboFrame
// <script src="https://unpkg.com/@material-tailwind/html@latest/scripts/tabs.js"></script>
//
// Connects to data-controller='material-tailwind-tab'
export default class extends Controller {
  static targets = ['tabList', 'tabItem']

  connect() {
    this.initialise()
    this.render_default()
  }

  initialise() {
    const tabs = this.tabListTargets

    tabs.forEach(item => { this.add_moving_part(item) })

    tabs.filter(item => item.dataset.default == 'false').forEach(item => {
      item.parentElement.classList.add('hidden')
    });

    this.tabularise()
  }

  render_default() {
    const selected_li = this.tabItemTargets.find(item => item.querySelector('a').getAttribute('aria-selected') == 'true')
    const selected_a = selected_li.querySelector('a')
    if (selected_a) {
      selected_a.click()
    }
  }

  add_moving_part(item) {
    var getEventTarget = function getEventTarget(e) {
      return e.target || e.srcElement
    }

    var moving_div = document.createElement('div')
    var first_li = item.querySelector('li:first-child [data-tab-target]')
    var tab = first_li.cloneNode()
    tab.innerHTML = '-'
    tab.classList.remove('bg-inherit', 'text-slate-700')
    tab.classList.add('bg-white', 'dark:bg-sky-500', 'text-transparent')
    tab.style.animation = '.2s ease'
    moving_div.classList.add('z-10', 'absolute', 'text-slate-700', 'rounded-lg', 'bg-inherit', 'flex-auto', 'text-center', 'bg-none', 'border-0', 'block', 'shadow')
    moving_div.setAttribute('moving-tab', '')
    moving_div.setAttribute('data-tab-target', '')
    moving_div.appendChild(tab)
    item.appendChild(moving_div)

    moving_div.style.padding = '0px'
    moving_div.style.width = item.querySelector('li:nth-child(1)').offsetWidth + 'px'
    moving_div.style.transform = 'translate3d(0px, 0px, 0px)'
    moving_div.style.transition = '.5s ease'

    item.onmouseover = function(event) {
      var target = getEventTarget(event)
      var li = target.closest('li')
      if (li) {
        var nodes = Array.from(li.closest('ul').children)
        var index = nodes.indexOf(li) + 1
        item.querySelector('li:nth-child(' + index + ') [data-tab-target]').onclick = function() {
          item.querySelectorAll('li').forEach(function(list_item) {
            list_item.firstElementChild.removeAttribute('active')
            list_item.firstElementChild.setAttribute('aria-selected', 'false')
          })
          li.firstElementChild.setAttribute('active', '')
          li.firstElementChild.setAttribute('aria-selected', 'true')
          moving_div = item.querySelector('[moving-tab]')
          var sum = 0
          if (item.classList.contains('flex-col')) {
            for (var j = 1; j <= nodes.indexOf(li); j++) {
              sum += item.querySelector('li:nth-child(' + j + ')').offsetHeight
            }
            moving_div.style.transform = 'translate3d(0px,' + sum + 'px, 0px)'
            moving_div.style.height = item.querySelector('li:nth-child(' + j + ')').offsetHeight
          } else {
            for (var j = 1; j <= nodes.indexOf(li); j++) {
              sum += item.querySelector('li:nth-child(' + j + ')').offsetWidth
            }
            moving_div.style.transform = 'translate3d(' + sum + 'px, 0px, 0px)'
            moving_div.style.width = item.querySelector('li:nth-child(' + index + ')').offsetWidth + 'px'
          }
        }
      }
    }
  }

  tabularise() {
    const total = document.querySelectorAll('[data-tab-content]') || []
    total.forEach(function(nav_pills) {
      const links = nav_pills.previousElementSibling.querySelectorAll('li a[data-tab-target]')
      links.forEach(function(link) {
        link.addEventListener('click', function() {
          const clicked_tab = document.querySelector('#' + link.getAttribute('aria-controls'))
          if (clicked_tab.classList.contains('block', 'opacity-100')) return

          const active_link_v = clicked_tab.closest('[data-tab-content]').parentElement
          const active_link = active_link_v.querySelector("li a[data-tab-target][aria-selected='true']")
          const active_panel = document.querySelector('#' + active_link.getAttribute('aria-controls'));
          active_panel.classList.remove('block', 'opacity-100')
          active_panel.classList.add('hidden', 'opacity-0')
          clicked_tab.classList.add('block', 'opacity-100')
          clicked_tab.classList.remove('hidden', 'opacity-0')
        })
      })
    })
  }
}
