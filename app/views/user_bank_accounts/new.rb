# frozen_string_literal: true

class Views::UserBankAccounts::New < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :current_user, :user_bank_account, :banks, :return_to

  def initialize(current_user:, user_bank_account:, banks:, return_to: "/user_bank_accounts")
    @current_user = current_user
    @user_bank_account = user_bank_account
    @banks = banks
    @return_to = return_to
  end

  def view_template
    turbo_frame_tag :center_container do
      render Views::Shared::FormShell.new(badge_text: I18n.t("gerund.new"), badge_class: form_badge_class(:new)) do
        render Views::UserBankAccounts::Form.new(current_user:, user_bank_account:, banks:, return_to:)
      end
    end
  end
end
