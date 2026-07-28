# frozen_string_literal: true

class Views::UserCards::New < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :current_user, :user_card, :cards, :return_to

  def initialize(current_user:, user_card:, cards:, return_to: "/user_cards")
    @current_user = current_user
    @user_card = user_card
    @cards = cards
    @return_to = return_to
  end

  def view_template
    turbo_frame_tag :center_container do
      render Views::Shared::FormShell.new(badge_text: I18n.t("gerund.new"), badge_class: form_badge_class(:new)) do
        render Views::UserCards::Form.new(current_user:, user_card:, cards:, return_to:)
      end
    end
  end
end
