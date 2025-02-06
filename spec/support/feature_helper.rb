# frozen_string_literal: true

module FeatureHelper
  def sign_in_as(user:)
    visit root_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    click_on "Log in"
  end

  def notification
    find("#notification-content")
  end

  def center_container_content
    within "turbo-frame#center_container" do
      find("turbo-frame")
    end
  end
end

RSpec.configure do |config|
  config.include FeatureHelper
end
