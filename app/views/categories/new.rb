# frozen_string_literal: true

class Views::Categories::New < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :current_user, :category, :return_to

  def initialize(current_user:, category:, return_to: "/categories")
    @current_user = current_user
    @category = category
    @return_to = return_to
  end

  def view_template
    turbo_frame_tag :center_container do
      render Views::Shared::FormShell.new(badge_text: I18n.t("gerund.new"), badge_class: form_badge_class(:new)) do
        render Views::Categories::Form.new(current_user:, category:, return_to:)
      end
    end
  end
end
