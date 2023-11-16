# frozen_string_literal: true

# Controller for Home SPA
class PagesController < ApplicationController
  def home
    main_items = ['New', 'Card Transaction', 'Transaction']
    main_icons = %w[plus credit_card wallet]
    main_links = %i[new_card_transaction card_transactions transactions]

    @main_tab = main_items.map.with_index do |item, index|
      TabsComponent::Item.new(item, "shared/svgs/#{main_icons[index]}", main_links[index], :center_container)
    end

    @sub_tab = [new, card_transaction, transaction]
  end

  def whatever; end

  def whatevers; end

  private

  def new
    items = %w[Card Entity Transaction]
    icons = %w[credit_card credit_card credit_card credit_card]
    links = %i[new_card_transaction whatever_pages whatever_pages whatever_pages]

    items.map.with_index do |item, index|
      TabsComponent::Item.new(item, "shared/svgs/#{icons[index]}", links[index], :center_container)
    end
  end

  def card_transaction
    items = %w[Azul Click Will Nubank]
    icons = %w[credit_card credit_card credit_card credit_card]
    links = %i[card_transactions whatevers_pages whatevers_pages whatevers_pages]

    @card_transaction_tab = items.map.with_index do |item, index|
      TabsComponent::Item.new(item, "shared/svgs/#{icons[index]}", links[index], :center_container)
    end
  end

  def transaction
    items = %w[Pix Investment]
    icons = %w[wallet wallet]
    links = %i[transactions whatever_pages]

    @transaction_tab = items.map.with_index do |item, index|
      TabsComponent::Item.new(item, "shared/svgs/#{icons[index]}", links[index], :center_container)
    end
  end
end
