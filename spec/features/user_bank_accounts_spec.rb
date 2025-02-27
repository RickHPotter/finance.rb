# frozen_string_literal: true

require "rails_helper"

RSpec.describe "UserBankAccounts", type: :feature do
  let(:basic) { FeatureHelper::BASIC }
  let(:user_bank_account_submenu) { FeatureHelper::USERBANKACCOUNT }

  let(:user) { create(:user, :random) }
  let(:bank) { build(:bank, :random) }
  let(:user_bank_account) { build(:user_bank_account, :random, user:, bank:) }

  before { sign_in_as(user:) }

  feature "/user_bank_accounts" do
    scenario "center_container is swapped for correct form" do
      navigate_to(menu: basic, sub_menu: user_bank_account_submenu)
      match_center_container_content("user_bank_accounts")
    end
  end

  feature "/user_bank_accounts/index" do
    background do
      user_bank_account.save
      create_list(:cash_transaction, 2, :random, user:, date: Date.current, user_bank_account:)
      navigate_to(menu: basic, sub_menu: user_bank_account_submenu)
    end

    scenario "jumping to cash_transactions that belong to the newly-created user_bank_account" do
      skip
      find("#user_bank_account_#{user_bank_account.id} .jump_to_cash_transactions a", match: :first).click

      match_center_container_content("cash_transactions")

      within "turbo-frame#center_container turbo-frame#cash_transactions" do
        expect(page).to have_selector("#month_year_selector_title", text: user_bank_account.user_bank_account_name)
      end
    end
  end

  feature "/user_bank_accounts/new" do
    background do
      bank.save
      navigate_to(menu: basic, sub_menu: user_bank_account_submenu)
      click_on action_model(:newa, UserBankAccount)
    end

    scenario "creating an invalid user_bank_account" do
      within "turbo-frame#new_user_bank_account" do
        find("form input[type=submit]", match: :first).click
      end

      expect(notification).to have_content(notification_model(:not_createda, UserBankAccount))
    end

    scenario "creating a valid user_bank_account and getting redirected to cash_transaction creation with user_bank_account already preselected" do
      skip
      within "turbo-frame#new_user_bank_account form" do
        hotwire_select "hw_user_bank_account_bank_id", with: bank.id
        fill_in "user_bank_account_agency_number",     with: "123"
        fill_in "user_bank_account_account_number",    with: "456"

        find("input[type=submit]", match: :first).click
      end

      expect(notification).to have_content(notification_model(:createda, UserBankAccount))

      match_center_container_content("new_cash_transaction")

      within "turbo-frame#new_cash_transaction form" do
        within ".hw-cb .hw-combobox[data-async-id='cash_transaction_user_bank_account_id']" do |element|
          # FIXME: a
          # user_bank_account = user.user_bank_accounts.find_by()
          user_bank_account = user.user_bank_accounts.first
          bank_name = element["data-hw-combobox-prefilled-display-value"]
          bank_id   = find("#cash_transaction_user_bank_account_id-hw-hidden-field", visible: false)["value"]

          expect(bank_name).to eq(user_bank_account.user_bank_account_name)
          expect(bank_id).to eq(user_bank_account.id.to_s)
        end
      end
    end
  end

  feature "/user_bank_accounts/edit" do
    background do
      bank.save
      user_bank_account.save
      navigate_to(menu: basic, sub_menu: user_bank_account_submenu)
    end

    scenario "editing a valid user_bank_account and getting redirected to cash_transaction creation with user_bank_account already preselected" do
      skip
      within "turbo-frame#center_container" do
        find("#edit_user_bank_account_#{user_bank_account.id}", match: :first).click

        within "turbo-frame#user_bank_account_#{user_bank_account.id} form" do
          hotwire_select "hw_user_bank_account_bank_id", with: bank.id
          fill_in "user_bank_account_agency_number",     with: "123"
          fill_in "user_bank_account_account_number",    with: "456"

          find("form input[type=submit]", match: :first).click
        end
      end

      expect(notification).to have_content(notification_model(:updateda, UserBankAccount))

      match_center_container_content("new_cash_transaction")

      within "turbo-frame#new_cash_transaction form" do
        within ".hw-cb .hw-combobox[data-async-id='cash_transaction_user_bank_account_id']" do |element|
          # FIXME: a
          # user_bank_account = user.user_bank_accounts.find_by()
          user_bank_account = user.user_bank_accounts.first
          bank_name = element["data-hw-combobox-prefilled-display-value"]
          bank_id   = find("#cash_transaction_user_bank_account_id-hw-hidden-field", visible: false)["value"]

          expect(bank_name).to eq(user_bank_account.user_bank_account_name)
          expect(bank_id).to eq(user_bank_account.id.to_s)
        end
      end

      navigate_to(menu: basic, sub_menu: user_bank_account_submenu)

      within "turbo-frame#user_bank_accounts turbo-frame#user_bank_account_#{user_bank_account.id}" do
        expect(page).to have_selector("span", text: "Another Test Entity")
        expect(page).to have_selector("span.agency_number", text: "123")
        expect(page).to have_selector("span.account_number", text: "456")
      end
    end
  end

  feature "/user_bank_accounts/destroy" do
    background do
      user_bank_account.save
      navigate_to(menu: basic, sub_menu: user_bank_account_submenu)
    end

    scenario "destroying a user_bank_account that has no cash_transactions" do
      within "turbo-frame#user_bank_account_#{user_bank_account.id}" do
        find("#delete_user_bank_account_#{user_bank_account.id}").click
      end

      expect(page).to_not have_css("turbo-frame#user_bank_account_#{user_bank_account.id}")

      expect(notification).to have_content(notification_model(:destroyeda, UserBankAccount))
    end

    scenario "failing to destroy a user_bank_account that has cash_transactions" do
      create_list(:cash_transaction, 2, :random, user:, date: Date.current, user_bank_account:)

      within "turbo-frame#user_bank_account_#{user_bank_account.id}" do
        find("#delete_user_bank_account_#{user_bank_account.id}").click
      end

      expect(page).to have_css("turbo-frame#user_bank_account_#{user_bank_account.id}")

      expect(notification).to have_content(notification_model(:not_destroyed_because_has_transactionsa, UserBankAccount))
    end
  end
end
