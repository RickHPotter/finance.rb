# frozen_string_literal: true

class Views::NamingConventions::Modal < Views::Base
  include CacheHelper
  include TranslateHelper

  def view_template
    ModalShell(id: "namingConventionModal", title: I18n.t("naming_conventions.title")) do
      div(class: "max-h-[80vh] overflow-hidden") do
        render Views::NamingConventions::Initial.new
      end
    end
  end
end
