# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pages", type: :feature do
  let(:user) { create(:user, :random) }
  let(:card) { build(:card, :random) }

  def match_center_container_content(turbo_frame_id)
    sleep 0.1
    expect(center_container_content["id"]).to eq(turbo_frame_id)
  end

  before { sign_in_as(user:) }

  feature "UserCards" do
    background do
      card.save

      within "#tabs" do
        click_on "New"
        click_on "Card"
      end
    end

    scenario "center_container is swapped for correct form" do
      match_center_container_content("new_user_card")
    end

    scenario "creating an invalid user_card" do
      within "turbo-frame#new_user_card" do
        find("form input[type=submit]").click
      end

      expect(notification).to have_content("Something is wrong.")
    end

    scenario "editing an invalid user_card" do
      skip
    end

    scenario "creating a valid user_card and getting redirected to card_transaction creation with user_card already preselected" do
      within "turbo-frame#new_user_card form" do
        fill_in "user_card_user_card_name", with: "Test Card"

        within ".hw-cb .hw-combobox__main__wrapper" do |element|
          element.click
          find(".hw-combobox__listbox li[data-value='#{card.id}']").click
        end

        fill_in "user_card_current_closing_date", with: Date.current + 4.days
        fill_in "user_card_current_due_date", with: Date.current + 10.days
        fill_in "user_card_min_spend", with: 200 * 100
        fill_in "user_card_credit_limit", with: 2000 * 100

        find("input[type=submit]").click
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

    scenario "editing a valid user_card and getting redirected to card_transaction creation with user_card already preselected" do
      skip
    end

    scenario "destroying a user_card that has no card_transactions" do
      skip
    end

    scenario "failing to destroy a user_card that has card_transactions" do
      skip
    end
  end

  feature "Entities" do
    background do
      within "#tabs" do
        click_on "New"
        click_on "Entity"
      end
    end

    scenario "center_container is swapped for correct form" do
      match_center_container_content("new_entity")
    end
  end
end
