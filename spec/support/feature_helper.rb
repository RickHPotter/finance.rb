# frozen_string_literal: true

module FeatureHelper
  BASIC           = I18n.t("tabs.basic")
  CARD            = I18n.t("tabs.card_transaction")
  CASH            = I18n.t("tabs.cash_transaction")
  USERBANKACCOUNT = I18n.t("tabs.user_bank_account")
  USERCARD        = I18n.t("tabs.user_card")
  CATEGORY        = I18n.t("tabs.category")
  ENTITY          = I18n.t("tabs.entity")
  PIX             = I18n.t("tabs.pix")
  INVESTMENT      = I18n.t("tabs.investment")

  def sign_in_as(user:)
    visit root_path(locale: I18n.locale)
    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    click_on I18n.t(:sign_in)
  end

  def navigate_to(menu:, sub_menu:)
    within "turbo-frame#tabs ul:nth-child(1)", match: :first do
      find("a", text: menu.to_s, match: :first).click
    end

    within "turbo-frame#tabs div[role='tabpanel'] ul" do
      find("a", text: sub_menu.to_s, match: :first).click
    end
  end

  def match_center_container_content(turbo_frame_id)
    expect(page).to have_css("turbo-frame#center_container turbo-frame##{turbo_frame_id}")
  end

  def replace_field(locator, with:)
    fill_in locator, with:, fill_options: { clear: :backspace }
    expect(page).to have_field(locator, with:)
  end

  def card_transactions_search_form_params(only: nil, except: [])
    only ||= %i[category_id entity_id]
    params_to_return = only - except

    params = {}
    within "turbo-frame#card_transactions #search_form" do
      find("#advanced_filter").click

      within "#card_transaction_category_id", visible: false do
        params[:category_id] = find("option:checked").value if params_to_return.include?(:category_id) && page.has_css?("option:checked")
      end
      within "#card_transaction_entity_id", visible: false do
        params[:entity_id] = find("option:checked").value if params_to_return.include?(:entity_id) && page.has_css?("option:checked")
      end
    end

    params
  end
end

module FeatureBrowser
  CHROME_CANDIDATES = %w[
    /opt/google/chrome/chrome
    /opt/google/chrome/google-chrome
    /usr/bin/google-chrome-stable
    /usr/bin/google-chrome
    /usr/bin/chromium
  ].freeze

  class << self
    def paths
      browser_path = usable_path(ENV.fetch("CHROME_EXECUTABLE", nil)) || CHROME_CANDIDATES.find { |path| usable_path(path) }
      driver_path = usable_path(ENV.fetch("CHROMEDRIVER_EXECUTABLE", nil))
      return { browser_path:, driver_path: } if browser_path && driver_path

      arguments = [ "--browser", "chrome", "--skip-driver-in-path" ]
      arguments += [ "--browser-path", browser_path ] if browser_path
      managed_paths = Selenium::WebDriver::SeleniumManager.binary_paths(*arguments)

      {
        browser_path: browser_path || managed_paths.fetch("browser_path"),
        driver_path: driver_path || managed_paths.fetch("driver_path")
      }
    end

    private

    def usable_path(path)
      return if path.blank? || !File.executable?(path)
      return if path.start_with?("/snap/") || File.realpath(path) == "/usr/bin/snap"

      path
    rescue Errno::ENOENT
      nil
    end
  end
end

Capybara.register_driver :selenium_chrome_headless do |app|
  paths = FeatureBrowser.paths
  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = paths.fetch(:browser_path)
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--disable-site-isolation-trials")

  service = Selenium::WebDriver::Chrome::Service.new(path: paths.fetch(:driver_path))
  Capybara::Selenium::Driver.new(app, browser: :chrome, options:, service:)
end

RSpec.configure do |config|
  config.include FeatureHelper
  config.include TranslateHelper
end
