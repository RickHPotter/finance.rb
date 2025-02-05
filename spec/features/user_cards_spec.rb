# frozen_string_literal: true

require "rails_helper"

RSpec.describe "UserCards", type: :feature do
  let(:user) { create(:user, :random) }
  let(:card) { build(:card, :random) }
  let(:current_closing_date) { Date.current + 4.days }
  let(:current_due_date) { Date.current + 9.days }

  before { sign_in_as(user:) }

  feature "/user_cards" do
    scenario "center_container is swapped for correct form" do
      navigate_to(menu: "New", sub_menu: "Card")
      match_center_container_content("new_user_card")
    end
  end

  feature "/user_cards/show" do
    background do
      navigate_to(menu: "New", sub_menu: "Card")
    end

    scenario "jumping to card_transactions that belong to the newly-created user_card" do
      user_card = create(:user_card, :random, user:, card:, current_closing_date:, current_due_date:)

      click_on "Existing User Cards"
      first("turbo-frame#center_container table tbody th:nth-child(2) span a").click

      match_center_container_content("card_transactions")

      within "turbo-frame#center_container turbo-frame#card_transactions" do
        expect(page).to have_selector("#card_transaction_user_card_name", text: user_card.user_card_name)
      end
    end
  end

  feature "/user_cards/new" do
    background do
      card.save
      navigate_to(menu: "New", sub_menu: "Card")
    end

    scenario "creating an invalid user_card" do
      within "turbo-frame#new_user_card" do
        first("form input[type=submit]").click
      end

      expect(notification).to have_content("Something is wrong.")
    end

    scenario "creating a valid user_card and getting redirected to card_transaction creation with user_card already preselected" do
      within "turbo-frame#new_user_card form" do
        within ".hw-cb .hw-combobox__main__wrapper" do
          page.click
          first(".hw-combobox__listbox li[data-value='#{card.id}']").click
        end

        fill_in "user_card_user_card_name",       with: "Test Card"
        fill_in "user_card_current_closing_date", with: current_closing_date
        fill_in "user_card_current_due_date",     with: current_due_date
        fill_in "user_card_min_spend",            with: 200 * 100
        fill_in "user_card_credit_limit",         with: 2000 * 100

        first("input[type=submit]").click
      end

      expect(notification).to have_content("Card has been created.")

      match_center_container_content("new_card_transaction")

      within "turbo-frame#new_card_transaction form" do
        within ".hw-cb .hw-combobox[data-async-id='card_transaction_user_card_id']" do |element|
          user_card = user.user_cards.find_by(user_card_name: "Test Card")
          card_name = element["data-hw-combobox-prefilled-display-value"]
          card_id   = find("#card_transaction_user_card_id-hw-hidden-field", visible: false)["value"]

          expect(card_name).to eq(user_card.user_card_name)
          expect(card_id).to eq(user_card.id.to_s)
        end
      end
    end
  end

  feature "/user_cards/edit" do
    background do
      card.save
      navigate_to(menu: "New", sub_menu: "Card")
    end

    scenario "editing an invalid user_card" do
      user_card = create(:user_card, :random, user:, card:, current_closing_date:, current_due_date:)

      within "turbo-frame#center_container" do
        click_on "Existing User Cards"
      end

      match_center_container_content("user_cards")

      first("#edit_user_card_#{user_card.id}").click
      fill_in "user_card_user_card_name", with: ""
      first("form input[type=submit]").click

      expect(notification).to have_content("Something is wrong.")
    end

    scenario "editing a valid user_card and getting redirected to card_transaction creation with user_card already preselected" do
      user_card = create(:user_card, :random, user:, card:, current_closing_date:, current_due_date:)

      within "turbo-frame#center_container" do
        click_on "Existing User Cards"
        first("#edit_user_card_#{user_card.id}").click

        within "turbo-frame#user_card_#{user_card.id} form" do
          fill_in "user_card_user_card_name",       with: "Another Test Entity"
          fill_in "user_card_current_closing_date", with: current_closing_date + 2.days
          fill_in "user_card_current_due_date",     with: current_due_date + 2.days
          fill_in "user_card_min_spend",            with: user_card.min_spend * 2
          fill_in "user_card_credit_limit",         with: user_card.credit_limit * 2

          first("form input[type=submit]").click
        end
      end

      expect(notification).to have_content("Card has been updated.")

      match_center_container_content("new_card_transaction")

      within "turbo-frame#new_card_transaction form" do
        within ".hw-cb .hw-combobox[data-async-id='card_transaction_user_card_id']" do |element|
          card_name = element["data-hw-combobox-prefilled-display-value"]
          card_id   = find("#card_transaction_user_card_id-hw-hidden-field", visible: false)["value"]

          expect(card_name).to eq("Another Test Entity")
          expect(card_id).to eq(user_card.id.to_s)
        end
      end

      navigate_to(menu: "New", sub_menu: "Card")

      click_on "Existing User Cards"

      within "turbo-frame#center_container table tbody #user_card_#{user_card.id}" do
        expect(page).to have_selector("th:nth-child(2) span a", text: "Another Test Entity")
        expect(page).to have_selector("th:nth-child(3)", text: I18n.l(current_closing_date + 2.days, format: :long))
        expect(page).to have_selector("th:nth-child(4)", text: I18n.l(current_due_date     + 2.days, format: :long))
      end
    end
  end

  feature "/user_cards/destroy" do
    background do
      navigate_to(menu: "New", sub_menu: "Card")
    end

    scenario "destroying a user_card that has no card_transactions" do
      user_card = create(:user_card, :random, user:, card:, current_closing_date:, current_due_date:)

      within "turbo-frame#center_container" do
        click_on "Existing User Cards"
      end

      within "turbo-frame#user_cards table tbody" do
        first("a#delete_user_card_#{user_card.id}").click
        expect(page).to_not have_css("tr#user_card_#{user_card.id}")
      end

      expect(notification).to have_content("Card has been deleted.")
    end

    scenario "failing to destroy a user_card that has card_transactions" do
      user_card = create(:user_card, :random, user:, card:, current_closing_date:, current_due_date:)
      create_list(:card_transaction, 2, :random, user:, date: Date.current, user_card:)

      within "turbo-frame#center_container" do
        click_on "Existing User Cards"
      end

      within "turbo-frame#user_cards table tbody" do
        first("a#delete_user_card_#{user_card.id}").click
        expect(page).to have_css("tr#user_card_#{user_card.id}")
      end

      expect(notification).to have_content("User Card with transactions cannot be deleted.")
    end
  end
end
