# frozen_string_literal: true

class Views::Layouts::Application < Views::Base
  register_output_helper :csrf_meta_tags
  register_output_helper :csp_meta_tag
  register_output_helper :stylesheet_link_tag
  register_output_helper :combobox_style_tag
  register_output_helper :javascript_include_tag
  register_output_helper :javascript_tag

  def view_template(&)
    doctype

    html do
      head do
        title { I18n.t("pages.title") }
        meta name: "viewport", content: "width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"
        meta name: "theme-color", content: homolog? ? "#78350f" : "#1a202c"
        meta name: "mobile-web-app-capable", content: "yes"
        meta name: "current-user-id", content: rails_view_context.current_user&.id

        csrf_meta_tags
        csp_meta_tag

        link rel: "manifest", href: "/manifest.json"
        link rel: "icon", href: "/pwa_logos/128.png", type: "image/png"
        link rel: "apple-touch-icon", href: "/pwa_logos/512.png"

        stylesheet_link_tag("tailwind", data: { turbo_track: :reload })
        stylesheet_link_tag("application", data: { turbo_track: :reload })

        combobox_style_tag
        javascript_include_tag("application", data: { turbo_track: :reload }, type: :module)
      end

      body class: body_class do
        ShellContainer(tag: :main, class: "flex flex-1 flex-col antialiased max-w-auto max-w-[1420px] mx-auto w-full") do
          turbo_frame_tag :notification do
            render partial "shared/flash"
          end

          section class: "mt-10 flex min-h-0 flex-1 flex-col w-full" do
            div class: "flex min-h-0 flex-1 flex-col w-full" do
              div class: "mb-10 flex shrink-0 justify-center" do
                div id: "tabs", class: "w-screen" do
                  render Views::Shared::Tabs.new(main_tab:, sub_tab:, mobile:)
                end
              end

              PageCard(class: "mx-1 flex min-h-0 flex-1 flex-col break-words rounded-lg bg-white shadow-md shadow-red-50") do
                div class: "flex min-h-0 flex-1 flex-col p-1 md:p-2 lg:p-3" do
                  div class: "hidden xl:block", data: { controller: "history-nav" } do
                    FloatingNavButton(side: :left, title: "Back", target: :back, action: "click->history-nav#back") do
                      "←"
                    end

                    FloatingNavButton(side: :right, title: "Forward", target: :forward, action: "click->history-nav#forward") do
                      "→"
                    end
                  end

                  div class: "hidden relative", data: { controller: "price-sum" } do
                    div(
                      class: "absolute -top-8 right-0 p-2 rounded-t-lg bg-yellow-400 shadow-md border border-yellow-600 font-lekton font-bold text-black text-md z-50"
                    ) do
                      span id: "totalPriceSum"
                    end
                  end

                  render Views::Static::Calculator.new

                  div(class: "flex min-h-0 flex-1 flex-col pt-2 text-center text-black", &)
                end
              end
            end
          end
        end

        render Views::Shared::AppFooter.new

        javascript_tag(<<~JS)
          window.APP_LOCALE = "#{I18n.locale}";
          window.vapid_public_key = "#{Rails.application.credentials.dig(:vapid, :public_key)}";
        JS
      end
    end
  end

  private

  def main_tab
    rails_view_context.instance_variable_get(:@main_tab)
  end

  def sub_tab
    rails_view_context.instance_variable_get(:@sub_tab)
  end

  def mobile
    rails_view_context.instance_variable_get(:@mobile) || false
  end

  def homolog?
    Rails.env.homolog?
  end

  def body_class
    return "min-h-screen bg-linear-to-br from-amber-950 via-stone-900 to-rose-950 text-amber-50" if homolog?

    "min-h-screen bg-gray-900 text-white"
  end
end
