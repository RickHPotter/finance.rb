# frozen_string_literal: true

class Views::UserCards::Edit < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :current_user, :user_card, :cards

  def initialize(current_user:, user_card:, cards:)
    @current_user = current_user
    @user_card = user_card
    @cards = cards
  end

  def view_template
    turbo_frame_tag :center_container do
      render Views::Shared::FormShell.new(badge_text: I18n.t("gerund.edit"), badge_class: form_badge_class(:edit)) do
        render Views::UserCards::Form.new(current_user:, user_card:, cards:)
      end
    end
  end
end
