# frozen_string_literal: true

class Views::Profiles::Edit < Views::Base
  include TranslateHelper

  attr_reader :profile, :preference, :user_bank_accounts, :user_cards

  def initialize(profile:, preference:, user_bank_accounts:, user_cards:)
    @profile = profile
    @preference = preference
    @user_bank_accounts = user_bank_accounts
    @user_cards = user_cards
  end

  def view_template
    turbo_frame_tag :center_container do
      render Views::Shared::FormShell.new(badge_text: "Edit Profile", badge_class: "bg-blue-100 text-blue-800") do
        render Views::Profiles::Form.new(profile:, preference:, user_bank_accounts:, user_cards:)
      end
    end
  end
end
