# frozen_string_literal: true

class Views::Shared::AppFooter < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::LinkTo

  include CacheHelper
  include TranslateHelper

  def view_template
    ShellContainer(tag: :footer, class: "antialiased pt-2 max-w-auto max-w-[1420px] mx-auto") do
      div(class: "flex justify-between items-center") do
        div(class: "flex items-center gap-2") do
          theme_switcher
          locale_links
        end
        action_links
      end

      context_switcher(class: "flex justify-center mb-2")

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

  def current_user
    rails_view_context.current_user
  end

  def current_context
    rails_view_context.current_context
  end

  def context_switcher(class:)
    return unless current_user

    div(class:) do
      div(class: "flex flex-wrap items-center justify-center gap-2 px-2") do
        span(class: "text-xs text-gray-500") { Context.model_name.human }

        current_user.contexts.active.order(main: :desc, created_at: :asc).each do |context|
          active = current_context&.id == context.id
          button_to switch_context_path(context),
                    method: :patch,
                    params: { return_to: request.fullpath },
                    form: { data: { turbo_frame: "_top", turbo_action: "replace" } },
                    data: { turbo_prefetch: false },
                    class: context_button_class(active) do
            plain context.name
          end
        end
      end
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

  def theme_switcher
    button(
      id: "theme_toggle",
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

  def action_links
    div(class: "flex gap-2") do
      FooterLink(href: donation_static_path, class: "flex items-center gap-2 p-2", data: { turbo_frame: "_top", turbo_prefetch: false }) do
        plain I18n.t(:donate)
        render_icon(:heart)
      end

      if current_user
        FooterLink(href: destroy_user_session_path, class: "flex items-center gap-2 p-2", data: { turbo_method: :delete }) do
          plain I18n.t(:sign_out)
          render_icon(:leave)
        end
      end
    end
  end

  def docs_link(class:)
    div(class:) do
      a(class: "flex items-center text-sm text-gray-600 hover:text-gray-500", href: "https://rickhpotter.github.io/30fev_docs.ts/", target: "_blank") do
        I18n.t("pages.docs")
      end
    end
  end

  def context_button_class(active)
    classes = %w[
      rounded-full
      border
      px-3
      py-1
      text-xs
      transition-colors
    ]

    if active
      classes.push(%w[border-red-400 bg-red-500 text-white])
    else
      classes.push(
        "border-gray-300", "bg-white", "text-gray-700", "hover:border-red-300", "hover:text-red-600",
        "dark:border-slate-700", "dark:bg-slate-950", "dark:text-slate-200", "dark:hover:border-emerald-400", "dark:hover:text-emerald-300"
      )
    end

    classes.join(" ")
  end
end
