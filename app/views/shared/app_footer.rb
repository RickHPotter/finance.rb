# frozen_string_literal: true

class Views::Shared::AppFooter < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::LinkTo

  include CacheHelper
  include TranslateHelper

  def view_template
    ShellContainer(tag: :footer, class: "antialiased pt-2 max-w-auto max-w-[1420px] mx-auto") do
      mobile_section
      desktop_section

      button(data: { controller: "push", action: "push#subscribe" }, class: "pt-16 mb-2 text-xs flex mx-auto") { "🔔" }

      docs_link(class: "flex md:hidden justify-center mb-2")
      docs_link(class: "hidden md:flex justify-center mb-2")

      if current_user
        div(class: "hidden md:flex justify-center mb-2") do
          div(class: "flex items-center gap-4") do
            link_to "Download Backup", admin_data_backup_path, class: "text-sm text-indigo-700 hover:text-indigo-500"
          end
        end
      end
    end
  end

  private

  def mobile_section
    div(class: "block md:hidden") do
      div(class: "flex items-center justify-between w-full px-4 py-2") do
        donate_link
        baby_names_link if current_user&.id&.in?(BabyNamesAccess::ALLOWED_USER_IDS)
        logout_link if current_user
      end

      div(class: "flex justify-center items-center py-2") do
        theme_switcher(id: "theme_toggle_mobile")
      end

      div(class: "flex justify-center items-center py-2") do
        locale_links
      end

      if current_context
        div(class: "flex justify-center items-center gap-1.5 py-2 text-xs text-gray-400") do
          span(class: "text-gray-500 uppercase text-2xs") { "#{Context.model_name.human}:" }
          span(class: "font-semibold text-slate-200") { current_context.name }
        end
      end
    end
  end

  def desktop_section
    div(class: "hidden md:block") do
      div(class: "flex items-center justify-between w-full py-1") do
        theme_switcher(id: "theme_toggle")
        locale_links
      end

      if current_user&.id&.in?(BabyNamesAccess::ALLOWED_USER_IDS)
        div(class: "flex justify-center mb-2") do
          baby_names_link
        end
      end
    end
  end

  def current_user
    rails_view_context.current_user
  end

  def current_context
    rails_view_context.current_context
  end

  def baby_names_link
    FooterLink(href: baby_names_path, class: "flex items-center gap-2 p-2", data: { turbo_frame: "_top", turbo_prefetch: false }) do
      plain I18n.t("baby_names.pwa.shortcut_name")
      render_icon(:light_bulb)
    end
  end

  def donate_link
    FooterLink(href: donation_static_path, class: "flex items-center gap-2 p-2", data: { turbo_frame: "_top", turbo_prefetch: false }) do
      plain I18n.t(:donate)
      render_icon(:heart)
    end
  end

  def logout_link
    FooterLink(href: destroy_user_session_path, class: "flex items-center gap-2 p-2", data: { turbo_method: :delete }) do
      plain I18n.t(:sign_out)
      render_icon(:leave)
    end
  end

  def locale_links
    div(class: "flex items-center gap-2") do
      locale_button("pt-BR", "🇧🇷", "PT-BR")
      locale_button("en", "🇬🇧", "EN")
    end
  end

  def locale_button(locale, flag, label)
    span do
      button_to(update_locale_path(locale:), method: :patch,
                                             class: "inline-flex items-center gap-1 rounded-full px-2.5 py-1.5 text-sm text-white hover:bg-gray-600") do
        span(aria: { hidden: "true" }) { flag }
        span { label }
      end
    end
  end

  def theme_switcher(id: "theme_toggle")
    button(
      id:,
      type: "button",
      title: "Switch theme",
      aria: { pressed: "false" },
      class: "inline-flex min-h-10 items-center gap-1 rounded-full border border-slate-300 bg-white px-3 py-1.5 text-xs font-semibold text-slate-700 shadow-sm " \
             "transition-colors hover:border-sky-400 hover:text-sky-700 " \
             "dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200 dark:hover:border-sky-500 dark:hover:text-sky-300",
      data: {
        controller: "theme",
        action: "click->theme#toggle",
        theme_update_url_value: preference_path,
        theme_light_label_value: "Light",
        theme_dark_label_value: "Dark"
      }
    ) do
      span(aria: { hidden: "true" }) { "◐" }
      span(data: { theme_target: "label" }) { "Light" }
    end
  end

  def docs_link(class:)
    div(class:) do
      a(class: "flex items-center text-sm text-gray-600 hover:text-gray-500", href: "https://rickhpotter.github.io/30fev_docs.ts/", target: "_blank") do
        I18n.t("pages.docs")
      end
    end
  end
end
