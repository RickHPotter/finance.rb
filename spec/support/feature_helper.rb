# frozen_string_literal: true

module FeatureHelper
  BASIC      = I18n.t("tabs.basic")
  CARD       = I18n.t("tabs.card_transaction")
  CASH       = I18n.t("tabs.cash_transaction")
  USERCARD   = I18n.t("tabs.user_card")
  CATEGORY   = I18n.t("tabs.category")
  ENTITY     = I18n.t("tabs.entity")
  PIX        = I18n.t("tabs.pix")
  INVESTMENT = I18n.t("tabs.investment")

  def sign_in_as(user:)
    visit root_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    click_on I18n.t(:sign_in)
  end

  def navigate_to(menu:, sub_menu:)
    within "turbo-frame#tabs ul:nth-child(1)", match: :first do
      click_on menu
    end

    within "turbo-frame#tabs div[role='tabpanel'] ul" do
      click_on sub_menu
    end
  end

  def notification
    find("#notification-content")
  end

  def match_center_container_content(turbo_frame_id)
    expect(page).to have_selector("turbo-frame#center_container turbo-frame##{turbo_frame_id}")
  end

  def hotwire_select(div_id, with:)
    within "##{div_id} .hw-combobox__main__wrapper" do
      page.click
      find(".hw-combobox__listbox li[data-value='#{with}']", match: :first).click
    end
  end

  def card_transactions_search_form_params(only: nil, except: [])
    only ||= %i[category_ids entity_ids]
    params_to_return = only - except

    params = {}
    within "turbo-frame#card_transactions #search_form" do
      # params[:search_term] = find("#card_transaction_search_term").text if params_to_return.include?(:search_term)

      within "#card_transaction_category_ids" do
        params[:category_ids] = find("option:checked").value if params_to_return.include?(:category_ids) && page.has_css?("option:checked")
      end
      within "#card_transaction_entity_ids" do
        params[:entity_ids] = find("option:checked").value if params_to_return.include?(:entity_ids) && page.has_css?("option:checked")
      end
    end

    params
  end
end

RSpec.configure do |config|
  config.include FeatureHelper
  config.include TranslateHelper
end
