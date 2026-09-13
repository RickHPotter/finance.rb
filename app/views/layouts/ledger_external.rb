# frozen_string_literal: true

class Views::Layouts::LedgerExternal < Views::Base
  LOCALE_QUERY_KEYS = %w[
    active_month_years
    default_year
    direction
    force_mobile
    month_year
    page
    paid
    pending
    per_page
    search_term
    sort
  ].freeze

  register_output_helper :csp_meta_tag
  register_output_helper :stylesheet_link_tag
  register_output_helper :javascript_include_tag
  register_output_helper :javascript_tag

  def view_template(&)
    doctype
    html(lang: I18n.locale) do
      head do
        title { I18n.t("ledgers.external.title") }
        meta name: "viewport", content: "width=device-width, initial-scale=1"
        meta name: "theme-color", content: "#0f172a"
        meta name: "referrer", content: "no-referrer"
        csp_meta_tag
        javascript_tag(theme_script)
        link rel: "icon", href: "/pwa_logos/128.png", type: "image/png"
        link rel: "apple-touch-icon", href: "/pwa_logos/512.png"
        stylesheet_link_tag("tailwind", data: { turbo_track: :reload })
        stylesheet_link_tag("application", data: { turbo_track: :reload })
        javascript_include_tag("application", data: { turbo_track: :reload }, type: :module)
      end

      body(class: "min-h-screen bg-slate-100 text-slate-950 antialiased dark:bg-slate-950 dark:text-slate-100") do
        main(class: "mx-auto min-h-screen w-full max-w-355 px-3 py-5 sm:px-6 lg:px-8") do
          div(class: "mb-2 flex items-center justify-start gap-2") do
            theme_toggle
            locale_switcher unless ledger_unavailable?
          end
          yield
        end
        javascript_tag(<<~JS)
          window.APP_LOCALE = "#{I18n.locale}";
        JS
      end
    end
  end

  private

  def theme_toggle
    button(
      id: "theme_toggle",
      type: :button,
      title: I18n.t("ledgers.external.theme.toggle"),
      aria: { pressed: "false" },
      class: "inline-flex min-h-10 items-center gap-2 rounded-full border border-slate-300 bg-white px-3 py-1.5 text-xs font-semibold text-slate-700 shadow-sm " \
             "transition-colors hover:border-sky-400 hover:text-sky-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-500 " \
             "dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200 dark:hover:border-sky-500 dark:hover:text-sky-300",
      data: {
        controller: "theme",
        action: "click->theme#toggle",
        theme_light_label_value: I18n.t("ledgers.external.theme.light"),
        theme_dark_label_value: I18n.t("ledgers.external.theme.dark")
      }
    ) do
      span(aria: { hidden: "true" }) { "◐" }
      span(data: { theme_target: "label" }) { I18n.t("ledgers.external.theme.light") }
    end
  end

  def locale_switcher
    nav(
      class: "inline-flex min-h-10 items-center rounded-full border border-slate-300 bg-white p-1 text-xs font-semibold shadow-sm " \
             "dark:border-slate-700 dark:bg-slate-900",
      aria: { label: I18n.t("ledgers.external.locale.label") },
      data: { ledger_locale_switcher: true }
    ) do
      locale_link("pt-BR", "🇧🇷", "PT-BR")
      locale_link("en", "🇬🇧", "EN")
    end
  end

  def ledger_unavailable?
    rails_view_context.instance_variable_get(:@ledger_unavailable)
  end

  def locale_link(locale, flag, label)
    active = I18n.locale.to_s == locale
    a(
      href: locale_path(locale),
      hreflang: locale,
      lang: locale,
      aria: { current: ("page" if active) },
      class: "inline-flex items-center gap-1 rounded-full px-2.5 py-1.5 transition-colors #{locale_link_class(active)}"
    ) do
      span(aria: { hidden: "true" }) { flag }
      span { label }
    end
  end

  def locale_path(locale)
    query = rails_view_context.request.query_parameters.slice(*LOCALE_QUERY_KEYS).merge(locale:)
    "#{rails_view_context.request.path}?#{Rack::Utils.build_nested_query(query)}"
  end

  def locale_link_class(active)
    return "bg-sky-600 text-white dark:bg-sky-400 dark:text-slate-950" if active

    "text-slate-600 hover:bg-slate-100 hover:text-sky-700 dark:text-slate-300 dark:hover:bg-slate-800 dark:hover:text-sky-300"
  end

  def theme_script
    <<~JS
      (() => {
        try {
          const local = window.localStorage.getItem("finance.theme");
          const dark = local === "dark" || (local === null && window.matchMedia("(prefers-color-scheme: dark)").matches);
          document.documentElement.classList.toggle("dark", dark);
        } catch (_) {}
      })();
    JS
  end
end
