# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CashTransactions", type: :feature do
  let(:user) { create(:user, :random) }
  let(:bank) { build(:bank, :random) }
  let(:user_bank_account) { build(:user_bank_account, :random, user:, bank:) }

  before do
    sign_in_as(user:)
  end

  feature "/cash_transactions" do
    scenario "center_container is swapped for correct form" do
      navigate_to(menu: "New", sub_menu: "Cash Transaction")
      match_center_container_content("new_cash_transaction")
    end
  end

  feature "/cash_transactions/show" do
    background do
      navigate_to(menu: "Cash Transaction", sub_menu: :PIX)
    end

    scenario "checking cash_transactions index page" do
      match_center_container_content("cash_transactions")
    end
  end

  feature "/cash_transactions/new" do
    background do
      navigate_to(menu: "New", sub_menu: "Cash Transaction")
    end

    scenario "creating an invalid cash_transaction" do
      skip
      # within "turbo-frame#new_cash_transaction" do
      #   find("form input[type=submit]", match: :first).click
      # end
      #
      # expect(notification).to have_content("Something is wrong.")
    end

    scenario "creating a valid cash_transaction and getting redirected to cash_transactions/index" do
      skip
      # user_card = create(:user_card, :random, user:)
      # category = create(:category, :random, user:)
      # entity = create(:entity, :random, user:)
      #
      # within "turbo-frame#new_cash_transaction form" do
      #   fill_in "cash_transaction_description",             with: "Test Cash Transaction"
      #   fill_in "cash_transaction_comment",                 with: "A really nice comment"
      #   hotwire_select "hw_cash_transaction_user_cash_id",  with: user_card.id
      #   hotwire_select "hw_cash_transaction_category_id",   with: category.id
      #   hotwire_select "hw_cash_transaction_entity_id",     with: entity.id
      #   fill_in "cash_transaction_date",                    with: Date.current
      #   fill_in "cash_transaction_price",                   with: 3000 * 100
      #   fill_in "cash_transaction_cash_installments_count", with: 3
      #
      #   find("input[type=submit]", match: :first).click
      # end
      #
      # expect(notification).to have_content("Cash Transaction has been created.")
      #
      # match_center_container_content("cash_transactions")
      #
      # within "turbo-frame#cash_transactions" do
      #   expect(page).to have_css("#cash_transaction_user_cash_name", text: user_card.user_cash_name)
      # end
    end
  end

  feature "/cash_transactions/edit" do
    background do
      create(:cash_transaction, :random, user:, user_bank_account:)
      navigate_to(menu: "Cash Transaction", sub_menu: :PIX)
    end

    scenario "editing an invalid cash_transaction" do
      skip
      # find("#edit_cash_transaction_#{user.cash_transactions.first.id}", match: :first).click
      # fill_in "cash_transaction_description", with: ""
      # find("form input[type=submit]", match: :first).click
      #
      # expect(notification).to have_content("Something is wrong.")
    end

    scenario "editing a valid cash_transaction and getting redirected to cash_transactions/index" do
      skip
      # find("#edit_cash_transaction_#{user.cash_transactions.first.id}", match: :first).click
      # fill_in "cash_transaction_description", with: "Some Other Cash Transaction Name"
      # fill_in "cash_transaction_date",        with: Date.current + 1.days
      # find("form input[type=submit]", match: :first).click
      #
      # expect(notification).to have_content("Cash Transaction has been updated.")
      #
      # match_center_container_content("cash_transactions")
      #
      # within "turbo-frame#cash_transactions" do
      #   expect(page).to have_css("#cash_transaction_user_cash_name", text: user.user_cards.first.user_cash_name)
      # end
    end
  end

  feature "/cash_transactions/destroy" do
    scenario "destroying a cash_transaction that is not from a particular category" do
      skip
      # cash_transaction = create(:cash_transaction, user:, user_bank_account:, date: Date.current)
      #
      # navigate_to(menu: "Cash Transaction", sub_menu: user_card.user_cash_name)
      #
      # within "turbo-frame#cash_transactions table tbody #cash_installment_#{cash_transaction.cash_installments.first.id}" do
      #   click_link("delete_cash_transaction_#{cash_transaction.id}")
      # end
      #
      # expect(notification).to have_content("Cash Transaction has been deleted.")
    end

    scenario "failing to destroy a cash_transaction that is from a particular category" do
      skip
    end
  end
end
