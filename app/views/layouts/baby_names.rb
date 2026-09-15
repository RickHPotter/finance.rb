# frozen_string_literal: true

class Views::Layouts::BabyNames < Views::Base
  register_output_helper :csrf_meta_tags
  register_output_helper :csp_meta_tag
  register_output_helper :stylesheet_link_tag
  register_output_helper :javascript_include_tag

  def view_template(&)
    doctype

    html do
      head do
        title { I18n.t("baby_names.page_title") }
        meta name: "viewport", content: "width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover"
        meta name: "theme-color", content: "#172554"
        meta name: "mobile-web-app-capable", content: "yes"
        meta name: "apple-mobile-web-app-capable", content: "yes"
        meta name: "apple-mobile-web-app-status-bar-style", content: "black-translucent"
        meta name: "current-user-id", content: rails_view_context.current_user&.id

        csrf_meta_tags
        csp_meta_tag

        link rel: "manifest", href: "/manifest.json"
        link rel: "icon", href: "/pwa_logos/128.png", type: "image/png"
        link rel: "apple-touch-icon", href: "/pwa_logos/512.png"

        stylesheet_link_tag("tailwind", data: { turbo_track: :reload })
        stylesheet_link_tag("application", data: { turbo_track: :reload })
        javascript_include_tag("application", data: { turbo_track: :reload }, type: :module)
      end

      body(class: "min-h-dvh overflow-hidden bg-slate-950 text-white antialiased", &)
    end
  end
end
