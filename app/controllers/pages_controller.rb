# frozen_string_literal: true

# Controller for Home SPA
class PagesController < ApplicationController
  def home
    items = ['New', 'Card Transaction', 'Transaction']
    icons = %w[plus credit_card wallet]
    links = %i[root card_transaction_pages transaction_pages]

    @items_first_tab = items.map.with_index do |item, index|
      TabsComponent::Item.new(item, "shared/svgs/#{icons[index]}", links[index], :second_tab)
    end
  end

  def card_transaction
    items = %w[Azul Click Will Nubank]
    icons = %w[credit_card credit_card credit_card credit_card]
    links = %i[whatever_pages card_transaction_pages root root]

    @items_second_tab = items.map.with_index do |item, index|
      TabsComponent::Item.new(item, "shared/svgs/#{icons[index]}", links[index], :center_container)
    end

    # respond_to(&:turbo_stream)
  end

  def transaction
    items = %w[Pix Investment]
    icons = %w[wallet wallet]
    links = %i[card_transaction_pages card_transaction_pages]

    @items_second_tab = items.map.with_index do |item, index|
      TabsComponent::Item.new(item, "shared/svgs/#{icons[index]}", links[index], :center_container)
    end

    # respond_to(&:turbo_stream)
  end

  def whatever; end
end
