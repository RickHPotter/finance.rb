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
      account_number = uba.account_number.to_s.presence
      alias_str = combobox_alias(uba.bank.bank_name, uba.agency_number.to_s.presence, account_number, account_number&.last(4))
      [ label, uba.id, { alias: alias_str } ]
    end
  end

  def set_user_cards
    @user_cards = current_user.user_cards.active.includes(:card).order(:user_card_name).map do |uc|
      [ uc.user_card_name, uc.id, { alias: combobox_alias(uc.card.card_name) } ]
    end
  end

  def set_categories
    @categories = format_category_options(current_user.custom_categories.active)
  end

  def set_entities
    @entities = current_user.entities.active.includes(friendship: { user: :profile, friend: :profile }).order(:entity_name).map do |entity|
      [ entity.name, entity.id ]
    end
  end

  def set_all_categories
    @categories = format_category_options(current_user.categories.active)
  end

  def set_investment_types
    @investment_types = InvestmentType.order(:investment_type_code, :investment_type_name_fallback).map do |investment_type|
      [ investment_type.display_name, investment_type.id ]
    end
  end

  private

  # Returns independently ranked, pre-normalized aliases for a combobox item.
  # Applies the same normalization pipeline as the JS normalizeComboboxText() utility:
  #   NFKD decomposition → strip combining marks → downcase → collapse whitespace
  def combobox_alias(*parts)
    parts.compact_blank.map do |part|
      part.to_s.unicode_normalize(:nfkd)
          .gsub(/\p{Mn}/, "")
          .downcase
          .gsub(/\s+/, " ")
          .strip
    end.uniq.join(" | ")
  end

  def format_category_options(scope)
    order_categories_hierarchically(scope.includes(:parent_category, :subcategories).to_a).map do |category|
      format_category_combobox_option(category)
    end
  end

  def order_categories_hierarchically(categories)
    top_level = categories.select { |c| c.parent_category_id.nil? }
    subcategories_by_parent = categories.reject { |c| c.parent_category_id.nil? }.group_by(&:parent_category_id)

    ordered = []
    top_level.sort_by { |c| c.name.downcase }.each do |parent|
      ordered << parent
      children = subcategories_by_parent.delete(parent.id) || []
      ordered.concat(children.sort_by { |c| c.name.downcase })
    end
    subcategories_by_parent.each_value do |orphans|
      ordered.concat(orphans.sort_by { |c| c.name.downcase })
    end
    ordered
  end

  def format_category_combobox_option(category)
    if category.subcategory?
      parent_name = category.parent_category.name
      label = "#{parent_name} / #{category.name}"
      alias_str = combobox_alias(parent_name, category.name, "#{parent_name} #{category.name}")
      [ label, category.id, { alias: alias_str } ]
    else
      [ category.name, category.id, { alias: combobox_alias(category.name) } ]
    end
  end
end
