# frozen_string_literal: true

class Views::Settings::Show < Views::Base
  include TranslateHelper

  attr_reader :show_exchange_audit

  def initialize(show_exchange_audit:)
    @show_exchange_audit = show_exchange_audit
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "m-1 min-h-[calc(100svh-16rem)] rounded-lg bg-white shadow-md") do
        div(class: "flex items-start justify-between border-b border-stone-200 px-4 py-3") do
          div(class: "flex flex-col items-start") do
            h1(class: "text-sm font-semibold uppercase tracking-[0.2em] text-stone-700") { I18n.t("settings.title") }
            render_scenario_badge
            p(class: "mt-2 max-w-3xl text-sm text-slate-600") { I18n.t("settings.description") }
          end
        end

        div(class: "rounded-2xl border border-slate-200 bg-slate-50/80 p-3 shadow-sm",
            data: { controller: "naming-tabs", naming_tabs_current_value: default_tab_name }) do
          div(class: "flex gap-2 overflow-x-auto border-b border-slate-200 pb-3") do
            tab_button(name: "exchange_audit", label: I18n.t("settings.tabs.exchange_audit")) if show_exchange_audit
            tab_button(name: "exchange_return_audit", label: I18n.t("settings.tabs.exchange_return_audit")) if show_exchange_audit
            tab_button(name: "card_exchange_projection_audit", label: I18n.t("settings.tabs.card_exchange_projection_audit")) if show_exchange_audit
            tab_button(name: "naming", label: I18n.t("settings.tabs.naming"))
          end

          div(class: "pt-4") do
            if show_exchange_audit
              div(class: "hidden", data: { naming_tabs_target: "panel", naming_tabs_name: "exchange_audit" }) do
                turbo_frame_tag :settings_exchange_audit_content, src: exchange_audit_admin_settings_path do
                  loading_state
                end
              end

              div(class: "hidden", data: { naming_tabs_target: "panel", naming_tabs_name: "exchange_return_audit" }) do
                turbo_frame_tag :settings_exchange_return_audit_content, src: exchange_return_audit_admin_settings_path do
                  loading_state(I18n.t("settings.exchange_return_audit.loading"))
                end
              end

              div(class: "hidden", data: { naming_tabs_target: "panel", naming_tabs_name: "card_exchange_projection_audit" }) do
                turbo_frame_tag :settings_card_exchange_projection_audit_content, src: card_exchange_projection_audit_admin_settings_path do
                  loading_state(I18n.t("settings.card_exchange_projection_audit.loading"))
                end
              end
            end

            div(class: show_exchange_audit ? "hidden" : nil, data: { naming_tabs_target: "panel", naming_tabs_name: "naming" }) do
              turbo_frame_tag :naming_convention_content, src: preview_naming_convention_path do
                loading_state
              end
            end
          end
        end
      end
    end
  end

  private

  def tab_button(name:, label:)
    button(
      type: :button,
      class: "shrink-0 rounded-full bg-slate-200 px-3 py-1 text-sm font-semibold text-slate-700 transition-colors",
      data: { action: "click->naming-tabs#select", naming_tabs_target: "tab", naming_tabs_name: name }
    ) { label }
  end

  def loading_state(text = I18n.t("settings.exchange_audit.loading"))
    div(class: "rounded-2xl border border-dashed border-slate-300 bg-white px-4 py-8 text-center text-sm text-slate-500") do
      text
    end
  end

  def default_tab_name
    show_exchange_audit ? "exchange_audit" : "naming"
  end
end
