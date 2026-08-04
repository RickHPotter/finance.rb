# frozen_string_literal: true

# Helper for Context
module ContextHelper
  def set_banks
    @banks = Bank.order(:bank_name).pluck(:bank_name, :id)
  end

  def set_cards
    @cards = Card.order(:card_name).pluck(:card_name, :id)
  end

  def set_user_bank_accounts
    @user_bank_accounts = current_user.user_bank_accounts.active.includes(:bank).order(:agency_number, :account_number).map do |uba|
      label = "#{uba.user_bank_account_name} [#{uba.bank.bank_name}]"
      alias_str = combobox_alias(uba.bank.bank_name, uba.account_number.to_s.presence)
      [ label, uba.id, { alias: alias_str } ]
    end
  end

  def set_user_cards
    @user_cards = current_user.user_cards.active.includes(:card).order(:user_card_name).map do |uc|
      [ uc.user_card_name, uc.id, { alias: combobox_alias(uc.card.card_name) } ]
    end
  end

  def set_categories
    @categories = current_user.custom_categories.active.order(:category_name).map { |category| [ category.name, category.id ] }
  end

  def set_entities
    @entities = current_user.entities.active.includes(:friendship).order(:entity_name).map { |entity| [ entity.name, entity.id ] }
  end

  def set_all_categories
    @categories = current_user.categories.active.order(:category_name).map { |category| [ category.name, category.id ] }
  end

  def set_investment_types
    @investment_types = InvestmentType.order(:investment_type_code, :investment_type_name_fallback).map do |investment_type|
      [ investment_type.display_name, investment_type.id ]
    end
  end

  private

  # Returns a pre-normalized alias string suitable for data-alias on a combobox item.
  # Applies the same normalization pipeline as the JS normalize() utility:
  #   NFKD decomposition → strip combining marks → downcase → collapse whitespace
  def combobox_alias(*parts)
    parts.compact.join(" ")
         .unicode_normalize(:nfkd)
         .gsub(/\p{Mn}/, "")
         .downcase
         .gsub(/\s+/, " ")
         .strip
  end
end
