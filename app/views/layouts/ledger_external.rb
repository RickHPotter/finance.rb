# frozen_string_literal: true

class Views::Layouts::LedgerExternal < Views::Base
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
        stylesheet_link_tag("tailwind", data: { turbo_track: :reload })
        stylesheet_link_tag("application", data: { turbo_track: :reload })
        javascript_include_tag("application", data: { turbo_track: :reload }, type: :module)
      end

      body(class: "min-h-screen bg-slate-100 text-slate-950 antialiased dark:bg-slate-950 dark:text-slate-100") do
        main(class: "mx-auto min-h-screen w-full max-w-355 px-3 py-5 sm:px-6 lg:px-8", &)
        javascript_tag(<<~JS)
          window.APP_LOCALE = "#{I18n.locale}";
        JS
      end
    end
  end

  private

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
