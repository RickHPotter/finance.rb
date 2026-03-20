# frozen_string_literal: true

class Views::Shared::Tabs < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include CacheHelper

  attr_reader :main_tab, :sub_tab, :mobile

  def initialize(main_tab:, sub_tab:, mobile: false)
    @main_tab = main_tab
    @sub_tab = sub_tab
    @mobile = mobile
  end

  def view_template
    render_tabs(items: main_tab, dependents: sub_tab, default: true)
  end

  private

  def render_tabs(items:, default:, dependents: [], dependent: false, dependent_no: nil)
    if dependent
      panel_classes = default ? "block opacity-100" : "hidden opacity-0"
      div(class: panel_classes, role: :tabpanel, id: "tab-item-#{dependent_no}") do
        render_tabs_content(items:, dependents:, default:, dependent:, dependent_no:)
      end
    else
      div(data: { controller: "tab", load_on_empty_content: "center_container" }) do
        render_tabs_content(items:, dependents:, default:, dependent:, dependent_no:)
      end
    end
  end

  def render_tabs_content(items:, dependents:, default:, dependent:, dependent_no:)
    ul(
      class: tabs_list_classes(dependent:),
      data: { tabs: "tabs", default:, material_tailwind_tab_lite_target: "tabList" },
      role: :list
    ) do
      extra_data = dependent ? { action: "click->material-tailwind-tab-lite#updateParentLink", parent_id: dependent_no } : {}

      items.each_with_index do |item, index|
        li(class: tabs_item_classes(items.count)) do
          link_to(
            item.link,
            role: :tab,
            aria: { selected: item.default, controls: "tab-item-#{index}" },
            class: tabs_link_classes(item.default),
            data: {
              turbo_frame: item.turbo_frame,
              turbo_prefetch: false,
              material_tailwind_tab_lite_target: "tabLink",
              id: index,
              **extra_data
            },
            tabindex: "-1"
          ) do
            notification = "bg-orange-500" if item.notification_type == 1
            notification = "bg-red-500" if item.notification_type == 2

            if notification
              span(class: notification_classes) do
                span(class: "relative inline-flex h-full w-full animate-ping rounded-full bg-red-400 opacity-80")
                span(class: "absolute inline-flex rounded-full size-2 md:size-3 #{notification}")
              end
            end

            span(class: "pointer-events-none") { cached_icon(item.icon) }
            span(class: tabs_label_classes) { item.label }
          end
        end
      end
    end

    return if dependents.blank?

    div(data: { tab_content: "" }) do
      dependents.each_with_index do |partial_items, index|
        current_index_is_default = items.index(&:default) == index
        render_tabs(items: partial_items, default: current_index_is_default, dependent: true, dependent_no: index)
      end
    end
  end

  def tabs_list_classes(dependent:)
    return "relative flex list-none rounded-xl p-1 overflow-x-auto" unless mobile

    base_classes = "
      relative flex list-none overflow-x-auto overscroll-x-contain whitespace-nowrap [scrollbar-width:none] [-ms-overflow-style:none]
      justify-center gap-1 rounded-2xl border border-slate-700/70 bg-slate-900/60 px-1.5 py-1
      ".squish

    "#{base_classes} #{dependent ? 'mt-2' : 'shadow-sm'}".squish
  end

  def tabs_item_classes(items_count)
    return "ring-1 rounded-lg ring-gray-800 z-30 flex-auto text-center w-1/#{items_count}" unless mobile

    "relative z-30 shrink-0 text-center"
  end

  def tabs_link_classes(default_tab)
    unless mobile
      return "relative z-30 mb-0 flex items-center justify-center rounded-lg border-0 px-4 py-1 transition-opacity duration-300
        #{default_tab ? 'bg-sky-500 text-white' : 'bg-inherit'}".squish
    end

    state_classes = default_tab ? "bg-sky-500 text-white shadow-sm shadow-sky-950/50" : "bg-slate-900/80 text-slate-300 ring-1 ring-slate-700/70"

    "relative z-30 mb-0 flex min-h-8 items-center justify-center gap-1 rounded-2xl border-0 px-2 py-1 text-[10px]
      font-medium transition-all duration-200 #{state_classes}".squish
  end

  def notification_classes
    return "absolute flex size-2 md:size-3 z-30 left-2 pointer-events-none" unless mobile

    "absolute top-1.5 right-1.5 flex size-2 z-30 pointer-events-none"
  end

  def tabs_label_classes
    return "ml-1 pointer-events-none text-slate-100 text-xs md:text-md font-light md:font-bold text-nowrap" unless mobile

    "pointer-events-none text-slate-100 text-[10px] font-medium text-nowrap"
  end
end
