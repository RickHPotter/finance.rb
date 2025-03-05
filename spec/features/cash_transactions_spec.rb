# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CashTransactions", type: :feature do
  let(:basic) { FeatureHelper::BASIC }
  let(:cash_transaction_menu) { FeatureHelper::CASH }
  let(:pix) { FeatureHelper::PIX }

  let(:user) { create(:user, :random) }
  let(:cash_transaction) { build(:cash_transaction, :random, user:, date: Date.current) }

  before do
    sign_in_as(user:)
  end

  feature "/cash_transactions/index" do
    background do
      navigate_to(menu: cash_transaction_menu, sub_menu: pix)
    end

    scenario "checking cash_transactions index page" do
      match_center_container_content("cash_transactions")
    end
  end

  feature "/cash_transactions/new" do
    background do
      navigate_to(menu: cash_transaction_menu, sub_menu: pix)
      find("#new_cash_transaction").click
    end

    scenario "creating an invalid cash_transaction" do
      within "turbo-frame#new_cash_transaction" do
        find("form input[type=submit]", match: :first).click
      end

      expect(page).to have_css("#notification-content", text: notification_model(:not_createda, CashTransaction))
    end

    scenario "creating a valid cash_transaction and getting redirected to cash_transactions/index" do
      within "turbo-frame#new_cash_transaction form" do
        fill_in "cash_transaction_description",             with: "Test Cash Transaction"
        fill_in "cash_transaction_comment",                 with: "A really nice comment"
        fill_in "cash_transaction_date",                    with: Date.current
        fill_in "cash_transaction_price",                   with: 300_000
        fill_in "cash_transaction_cash_installments_count", with: 2

        find("input[type=submit]", match: :first).click
      end

      expect(page).to have_css("#notification-content", text: notification_model(:createda, CashTransaction))

      cash_transaction = user.cash_transactions.last
      within "turbo-frame#cash_transactions turbo-frame#cash_installment_#{cash_transaction.cash_installments.first.id}" do
        expect(page).to have_css("a#edit_cash_transaction_#{cash_transaction.id}", text: cash_transaction.description)
      end
    end
  end

  feature "/cash_transactions/edit" do
    background do
      cash_transaction.save
      navigate_to(menu: cash_transaction_menu, sub_menu: pix)
    end

    scenario "editing an invalid cash_transaction" do
      find("#edit_cash_transaction_#{user.cash_transactions.first.id}", match: :first).click
      fill_in "cash_transaction_description", with: ""
      find("form input[type=submit]", match: :first).click

      expect(page).to have_css("#notification-content", text: notification_model(:not_updateda, CashTransaction))
    end

    scenario "editing a valid cash_transaction and getting redirected to cash_transactions/index" do
      find("#edit_cash_transaction_#{user.cash_transactions.first.id}", match: :first).click
      fill_in "cash_transaction_description", with: "Some Other Cash Transaction Name"
      find("form input[type=submit]", match: :first).click

      expect(page).to have_css("#notification-content", text: notification_model(:updateda, CashTransaction))

      within "turbo-frame#cash_transactions" do
        within "turbo-frame#cash_installment_#{cash_transaction.cash_installments.first.id}" do
          expect(page).to have_css("a#edit_cash_transaction_#{cash_transaction.id}", text: "Some Other Cash Transaction Name")
        end
      end
    end
  end

  feature "/cash_transactions/destroy" do
    before { cash_transaction.save }

    scenario "destroying a cash_transaction" do
      navigate_to(menu: cash_transaction_menu, sub_menu: pix)

      within "turbo-frame#cash_transactions #cash_installment_#{cash_transaction.cash_installments.first.id}" do
        click_link("edit_cash_transaction_#{cash_transaction.id}")
      end

      click_link("delete_cash_transaction_#{cash_transaction.id}")
      accept_alert

      expect(page).to have_css("#notification-content", text: notification_model(:destroyeda, CashTransaction))
    end
  end
end
