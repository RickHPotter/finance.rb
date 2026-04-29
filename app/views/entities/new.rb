# frozen_string_literal: true

class Views::Entities::New < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :current_user, :entity

  def initialize(current_user:, entity:)
    @current_user = current_user
    @entity = entity
  end

  def view_template
    turbo_frame_tag :center_container do
      render Views::Shared::FormShell.new(badge_text: I18n.t("gerund.new"), badge_class: form_badge_class(:new)) do
        render Views::Entities::Form.new(current_user:, entity:)
      end
    end
  end
end
