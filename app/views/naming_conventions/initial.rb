# frozen_string_literal: true

class Views::NamingConventions::Initial < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include TranslateHelper

  def view_template
    turbo_frame_tag :naming_convention_content do
      div(class: "w-[min(56rem,88vw)] text-black") do
        p(class: "text-sm text-gray-700") do
          I18n.t("naming_conventions.description")
        end

        div(class: "mt-4 flex justify-end") do
          form_with(url: preview_naming_convention_path, method: :post, data: { turbo_frame: :naming_convention_content }) do |form|
            form.submit I18n.t("naming_conventions.preview"),
                        class: "bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-2 px-4 rounded cursor-pointer"
          end
        end
      end
    end
  end
end
