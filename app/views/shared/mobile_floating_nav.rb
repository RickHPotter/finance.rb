# frozen_string_literal: true

class Views::Shared::MobileFloatingNav < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include CacheHelper

  attr_reader :new_href, :new_data, :modal_action, :inbox_action

  def initialize(new_href:, new_data: {}, modal_action: nil, inbox_action: nil)
    @new_href = new_href
    @new_data = new_data
    @modal_action = modal_action
    @inbox_action = inbox_action
  end

  def view_template
    div(class: "md:hidden") do
      link_to(
        "#",
        class: nav_button_class,
        style: hidden_nav_style,
        data: { mobile_scroll_nav: "bottom" }
      ) do
        cached_icon :bigger_bottom
      end

      if modal_action
        div(class: "fixed bottom-20 right-3 z-50", data: { controller: "action-menu" }) do
          div(
            class: "absolute bottom-full right-0 mb-2 w-56 overflow-hidden rounded-xl border border-slate-200 bg-white p-1 shadow-xl " \
                   "dark:border-slate-700 dark:bg-slate-900",
            hidden: true,
            role: "menu",
            data: { action_menu_target: "menu" }
          ) do
            button(
              type: :button,
              class: menu_item_class,
              role: "menuitem",
              data: {
                action: "click->action-menu#close",
                modal_target: modal_action.fetch(:id),
                modal_toggle: modal_action.fetch(:id)
              }
            ) { modal_action.fetch(:import_label) }
            if inbox_action
              link_to inbox_action.fetch(:href),
                      class: menu_item_class,
                      role: "menuitem",
                      data: { action: "click->action-menu#close", turbo_frame: "_top" } do
                inbox_action.fetch(:use_saved_label)
              end
            end
          end

          button(
            type: :button,
            title: modal_action.fetch(:label),
            aria: { label: modal_action.fetch(:label), expanded: "false", haspopup: "menu" },
            class: "relative flex h-14 w-14 items-center justify-center rounded-full bg-sky-700 text-white shadow-lg " \
                   "transition-transform active:scale-95 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-400",
            data: { action: "click->action-menu#toggle", action_menu_target: "trigger" }
          ) do
            cached_icon :paperclip
            span(class: "absolute bottom-1 right-2 text-xs font-bold leading-none", aria: { hidden: true }) { "⌄" }
          end
        end
      end

      link_to(
        new_href,
        class: "flex items-center justify-center fixed bottom-4 right-3 h-14 w-14 bg-blue-600 text-white rounded-full shadow-lg z-50",
        data: { turbo_frame: "_top", mobile_scroll_nav: "plus" }.merge(new_data)
      ) do
        cached_icon :bigger_plus
      end

      link_to(
        "#",
        class: nav_button_class,
        style: hidden_nav_style,
        data: { mobile_scroll_nav: "top" }
      ) do
        cached_icon :bigger_top
      end
    end
  end

  private

  def menu_item_class
    "flex w-full items-center rounded-lg px-3 py-3 text-left text-sm font-medium text-slate-700 transition-colors " \
      "hover:bg-slate-100 dark:text-slate-200 dark:hover:bg-slate-800"
  end

  def nav_button_class
    bottom = inbox_action ? "bottom-52" : "bottom-36"
    "opacity-0 translate-y-2 pointer-events-none flex items-center justify-center fixed #{bottom} right-3
     h-12 w-12 bg-gray-300/95 text-black rounded-full shadow-lg z-50 transition-all duration-200".squish
  end

  def hidden_nav_style
    "display: flex; visibility: hidden;"
  end
end
