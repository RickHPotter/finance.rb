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
      div(class: compact_crud_shell_class) do
        div(class: compact_crud_header_class) do
          div(class: "flex flex-col items-start") do
            h1(class: compact_crud_title_class) { I18n.t("profiles.edit.title") }
          end
        end

        div(class: "#{compact_crud_panel_class} space-y-6") do
          render Views::Profiles::Form.new(profile:, preference:, user_bank_accounts:, user_cards:)
        end
      end
    end
  end
end
