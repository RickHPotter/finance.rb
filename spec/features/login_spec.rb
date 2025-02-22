# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LogIn", type: :feature do
  let(:user) { create(:user, :random) }

  scenario "invalid inputs" do
    visit root_path
    fill_in "user_email", with: "anything@mail.com"
    fill_in "user_password", with: "123123"
    click_on I18n.t(:sign_in)
    expect(notification).to have_content(I18n.t("devise.failure.invalid", authentication_keys: "Email"))
  end

  scenario "valid inputs" do
    visit root_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    click_on I18n.t(:sign_in)
    expect(notification).to have_content(I18n.t("devise.sessions.signed_in"))
  end
end
