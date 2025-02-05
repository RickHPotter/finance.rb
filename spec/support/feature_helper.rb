# frozen_string_literal: true

module FeatureHelper
  def sign_in_as(user:)
    visit root_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    click_on "Log in"
  end

  def navigate_to(menu:, sub_menu:)
    within "turbo-frame#tabs" do
      click_on menu
      click_on sub_menu
    end
  end

  def notification
    find("#notification-content")
  end

  def match_center_container_content(turbo_frame_id)
    expect(page).to have_selector("turbo-frame#center_container turbo-frame##{turbo_frame_id}")
  end
end

RSpec.configure do |config|
  config.include FeatureHelper
end
