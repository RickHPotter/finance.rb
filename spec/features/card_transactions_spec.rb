# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CardTransactions", type: :feature do
  let(:user) { create(:user, :random) }
  let(:card) { build(:card, :random) }
  let(:user_card) { build(:user_card, :random, user:, card:, current_closing_date: Date.current + 4.days, current_due_date: Date.current + 9.days) }

  before do
    user_card.save
    sign_in_as(user:)
  end

  feature "/card_transactions" do
    scenario "center_container is swapped for correct form" do
      navigate_to(menu: "New", sub_menu: "Card Transaction")
      match_center_container_content("new_card_transaction")
    end
  end

  feature "/card_transactions/show" do
    background do
      navigate_to(menu: "Card Transaction", sub_menu: user_card.user_card_name)
    end

    scenario "checking card_transactions index page" do
      match_center_container_content("card_transactions")
    end
  end

  feature "/card_transactions/new" do
    background do
      navigate_to(menu: "New", sub_menu: "Card Transaction")
    end

    scenario "creating an invalid card_transaction" do
      within "turbo-frame#new_card_transaction" do
        find("form input[type=submit]", match: :first).click
      end

      expect(notification).to have_content("Something is wrong.")
    end

    scenario "creating a valid card_transaction and getting redirected to card_transactions/index of given user_card" do
      user_card = create(:user_card, :random, user:)
      category = create(:category, :random, user:)
      entity = create(:entity, :random, user:)

      within "turbo-frame#new_card_transaction form" do
        fill_in "card_transaction_description",             with: "Test Card Transaction"
        fill_in "card_transaction_comment",                 with: "A really nice comment"
        hotwire_select "hw_card_transaction_user_card_id",  with: user_card.id
        hotwire_select "hw_card_transaction_category_id",   with: category.id
        hotwire_select "hw_card_transaction_entity_id",     with: entity.id
        fill_in "card_transaction_date",                    with: Date.current
        fill_in "card_transaction_price",                   with: 3000 * 100
        fill_in "card_transaction_card_installments_count", with: 3

        find("input[type=submit]", match: :first).click
      end

      expect(notification).to have_content("Card Transaction has been created.")

      match_center_container_content("card_transactions")

      within "turbo-frame#card_transactions" do
        expect(page).to have_css("#card_transaction_user_card_name", text: user_card.user_card_name)
      end
    end
  end

  feature "/card_transactions/edit" do
    background do
      create(:card_transaction, :random, user:, user_card:)
      navigate_to(menu: "Card Transaction", sub_menu: user_card.user_card_name)
    end

    scenario "editing an invalid card_transaction" do
      find("#edit_card_transaction_#{user.card_transactions.first.id}", match: :first).click
      fill_in "card_transaction_description", with: ""
      find("form input[type=submit]", match: :first).click

      expect(notification).to have_content("Something is wrong.")
    end

    scenario "editing a valid card_transaction and getting redirected to card_transactions/index of given user_card" do
      find("#edit_card_transaction_#{user.card_transactions.first.id}", match: :first).click
      fill_in "card_transaction_description", with: "Some Other Card Transaction Name"
      fill_in "card_transaction_date",        with: Date.current + 1.days
      find("form input[type=submit]", match: :first).click

      expect(notification).to have_content("Card Transaction has been updated.")

      match_center_container_content("card_transactions")

      within "turbo-frame#card_transactions" do
        expect(page).to have_css("#card_transaction_user_card_name", text: user.user_cards.first.user_card_name)
      end
    end
  end

  feature "/card_transactions/destroy" do
    scenario "destroying a card_transaction" do
      card_transaction = create(:card_transaction, user:, user_card:, date: Date.current)

      navigate_to(menu: "Card Transaction", sub_menu: user_card.user_card_name)

      within "turbo-frame#card_transactions table tbody #card_installment_#{card_transaction.card_installments.first.id}" do
        click_link("delete_card_transaction_#{card_transaction.id}")
      end

      expect(notification).to have_content("Card Transaction has been deleted.")
    end
  end
end
