# frozen_string_literal: true

class Views::UserCards::New < Views::Base
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
      div(class: "bg-white p-4 shadow-md rounded-lg") do
        div(class: "flex justify-between mb-8") do
          link_to(
            pluralise_model(UserCard, 2),
            user_cards_path,
            class: "py-2 px-3 rounded-sm border border-sky-900 bg-blue-600 hover:bg-blue-800 transition-colors text-white shadow-lg font-thin",
            data: { turbo_frame: "_top" }
          )
        end

        render Views::UserCards::Form.new(current_user:, user_card:, cards:)
      end
    end
  end
end
