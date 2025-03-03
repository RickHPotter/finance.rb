# frozen_string_literal: true

require "rails_helper"

RSpec.describe "UserCards", type: :feature do
  let(:basic) { FeatureHelper::BASIC }
  let(:user_card_submenu) { FeatureHelper::USERCARD }

  let(:user) { create(:user, :random) }
  let(:card) { build(:card, :random) }
  let(:current_closing_date) { Date.current + 4.days }
  let(:current_due_date) { Date.current + 9.days }
  let(:user_card) { build(:user_card, :random, user:, card:, days_until_due_date: 5, due_date_day: (Date.current + 9.days).day) }

  before { sign_in_as(user:) }

  feature "/user_cards" do
    scenario "center_container is swapped for correct form" do
      navigate_to(menu: basic, sub_menu: user_card_submenu)
      match_center_container_content("user_cards")
    end
  end

  feature "/user_cards/index" do
    background do
      user_card.save
      create_list(:card_transaction, 2, :random, user:, date: Date.current, user_card:)
      navigate_to(menu: basic, sub_menu: user_card_submenu)
    end

    scenario "jumping to card_transactions that belong to the newly-created user_card" do
      find("#user_card_#{user_card.id} .jump_to_card_transactions a", match: :first).click

      match_center_container_content("card_transactions")

      within "turbo-frame#center_container turbo-frame#card_transactions" do
        expect(page).to have_selector("#month_year_selector_title", text: user_card.user_card_name)
      end
    end
  end

  feature "/user_cards/new" do
    background do
      card.save
      navigate_to(menu: basic, sub_menu: user_card_submenu)
      click_on action_model(:new, UserCard)
    end

    scenario "creating an invalid user_card" do
      within "turbo-frame#new_user_card" do
        find("form input[type=submit]", match: :first).click
      end

      expect(notification).to have_content(notification_model(:not_created, UserCard))
    end

    scenario "creating a valid user_card and getting redirected to card_transaction creation with user_card already preselected" do
      within "turbo-frame#new_user_card form" do
        fill_in "user_card_user_card_name",       with: "Test Card"
        hotwire_select "hw_user_card_card_id",    with: card.id
        fill_in "user_card_current_closing_date", with: current_closing_date
        fill_in "user_card_current_due_date",     with: current_due_date
        fill_in "user_card_min_spend",            with: 200 * 100
        fill_in "user_card_credit_limit",         with: 2000 * 100

        find("input[type=submit]", match: :first).click
      end

      expect(notification).to have_content(notification_model(:created, UserCard))

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
      user_card.save
      navigate_to(menu: basic, sub_menu: user_card_submenu)
    end

    scenario "editing an invalid user_card" do
      find("#edit_user_card_#{user_card.id}", match: :first).click
      fill_in "user_card_user_card_name", with: ""
      find("form input[type=submit]", match: :first).click

      expect(notification).to have_content(notification_model(:not_updated, UserCard))
    end

    scenario "editing a valid user_card and getting redirected to card_transaction creation with user_card already preselected" do
      within "turbo-frame#center_container" do
        find("#edit_user_card_#{user_card.id}", match: :first).click

        within "turbo-frame#user_card_#{user_card.id} form" do
          fill_in "user_card_user_card_name",       with: "Another Test Entity"
          fill_in "user_card_current_closing_date", with: current_closing_date + 2.days
          fill_in "user_card_current_due_date",     with: current_due_date + 2.days
          fill_in "user_card_min_spend",            with: user_card.min_spend * 2
          fill_in "user_card_credit_limit",         with: user_card.credit_limit * 2

          find("form input[type=submit]", match: :first).click
        end
      end

      expect(notification).to have_content(notification_model(:updated, UserCard))

      match_center_container_content("new_card_transaction")

      within "turbo-frame#new_card_transaction form" do
        within ".hw-cb .hw-combobox[data-async-id='card_transaction_user_card_id']" do |element|
          card_name = element["data-hw-combobox-prefilled-display-value"]
          card_id   = find("#card_transaction_user_card_id-hw-hidden-field", visible: false)["value"]

          expect(card_name).to eq("Another Test Entity")
          expect(card_id).to eq(user_card.id.to_s)
        end
      end

      navigate_to(menu: basic, sub_menu: user_card_submenu)

      within "turbo-frame#user_cards turbo-frame#user_card_#{user_card.id}" do
        expect(page).to have_selector("span", text: "Another Test Entity")
        expect(page).to have_selector("span.current_closing_date", text: I18n.l(current_closing_date + 2.days, format: :shorter))
        expect(page).to have_selector("span.current_due_date",     text: I18n.l(current_due_date     + 2.days, format: :shorter))
      end
    end
  end

  feature "/user_cards/destroy" do
    background do
      user_card.save
      navigate_to(menu: basic, sub_menu: user_card_submenu)
    end

    scenario "destroying a user_card that has no card_transactions" do
      within "turbo-frame#user_card_#{user_card.id}" do
        find("#delete_user_card_#{user_card.id}").click
        accept_alert
      end

      expect(page).to_not have_css("turbo-frame#user_card_#{user_card.id}")

      expect(notification).to have_content(notification_model(:destroyed, UserCard))
    end

    scenario "failing to destroy a user_card that has card_transactions" do
      create_list(:card_transaction, 2, :random, user:, date: Date.current, user_card:)

      within "turbo-frame#user_card_#{user_card.id}" do
        find("#delete_user_card_#{user_card.id}").click
        accept_alert
      end

      expect(page).to have_css("turbo-frame#user_card_#{user_card.id}")

      expect(notification).to have_content(notification_model(:not_destroyed_because_has_transactions, UserCard))
    end
  end
end
