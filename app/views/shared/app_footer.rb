# frozen_string_literal: true

class Views::Shared::AppFooter < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::LinkTo

  include CacheHelper
  include TranslateHelper

  def view_template
    ShellContainer(tag: :footer, class: "antialiased pt-2 max-w-auto max-w-[1420px] mx-auto bg-gray-900 text-white") do
      div(class: "flex justify-between items-center") do
        locale_links
        action_links
      end

      button(data: { controller: "push", action: "push#subscribe" }, class: "pt-16 mb-2 text-xs flex mx-auto") { "🔔" }

      docs_link(class: "flex md:hidden justify-center mb-2")
      docs_link(class: "hidden md:flex justify-center mb-2")

      if current_user
        div(class: "hidden md:flex justify-center mb-2") do
          link_to "Download Backup", admin_data_backup_path, class: "text-sm text-indigo-700 hover:text-indigo-500"
        end
      end
    end
  end

  private

  def current_user
    rails_view_context.current_user
  end

  def locale_links
    div(class: "flex items-center gap-2") do
      locale_button("pt-BR", "https://cdn.icon-icons.com/icons2/1694/PNG/512/brbrazilflag_111698.png", "Português")
      locale_button("en", "https://static.vecteezy.com/system/resources/previews/005/416/914/original/flag-of-united-kingdom-illustration-free-vector.jpg", "English")
    end
  end

  def locale_button(locale, image_src, title)
    span do
      button_to(update_locale_path(locale:), method: :patch, class: "flex p-2 text-sm text-white hover:bg-gray-600") do
        image_tag image_src, size: "25x15", title:
      end
    end
  end

  def action_links
    div(class: "flex gap-2") do
      FooterLink(href: donation_pages_path, class: "flex items-center gap-2 p-2", data: { turbo_frame: :_top, turbo_prefetch: false }) do
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
end
