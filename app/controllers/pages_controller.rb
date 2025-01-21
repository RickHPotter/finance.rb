# frozen_string_literal: true

# Controller for Home SPA
class PagesController < ApplicationController
  def home
    main_items = [ "Cash Transaction", "Card Transaction", "New" ]
    main_icons = %w[plus credit_card wallet]
    main_links = %i[cash_transactions card_transactions new_card_transaction]

    @main_tab = main_items.map.with_index do |item, index|
      TabsComponent::Item.new(item, "shared/svgs/#{main_icons[index]}", main_links[index], :center_container)
    end

    @sub_tab = [ new_sublinks, card_transaction_sublinks, cash_transaction_sublinks ]
  end

  private

  def new_sublinks
    items = %w[Card Entity Transaction]
    icons = %w[credit_card credit_card credit_card credit_card]
    links = %i[new_card_transaction new_card_transaction new_card_transaction new_card_transaction]

    items.map.with_index do |item, index|
      TabsComponent::Item.new(item, "shared/svgs/#{icons[index]}", links[index], :center_container)
    end
  end

  def card_transaction_sublinks
    items = current_user.user_cards.pluck(:id, :user_card_name)
    icon = "credit_card"

    @card_transaction_tab = items.map do |user_card_id, user_card_name|
      TabsComponent::Item.new(user_card_name, "shared/svgs/#{icon}", card_transactions_path(user_card_id:), :center_container)
    end
  end

  def cash_transaction_sublinks
    items = %w[Pix Investment]
    icons = %w[wallet wallet]
    links = %i[cash_transactions cash_transactions]

    @cash_transaction_tab = items.map.with_index do |item, index|
      TabsComponent::Item.new(item, "shared/svgs/#{icons[index]}", links[index], :center_container)
    end
  end
end
