# frozen_string_literal: true

module Logic
  class CardInstallments
    def self.find_ref_month_year_by_params(user, card_transaction_params, search_params) # rubocop:disable Metrics/AbcSize
      month_year   = search_params.delete(:month_year)
      year         = month_year[0..3]
      month        = month_year[4..]
      search_term  = search_params.delete(:search_term) || ""
      entity_ids   = card_transaction_params.delete(:entity_id).presence
      category_ids = card_transaction_params.delete(:category_id).presence

      joins      = { card_transaction: %i[categories entities] }
      inclusions = joins
      inclusions[:card_transaction] << :user_card if card_transaction_params[:user_card_id].blank?

      card_installment_ids = card_transaction_params[:card_installment_ids]
      return user.card_installments.includes(inclusions).where(id: card_installment_ids) if card_installment_ids.present?

      conditions = build_conditions_from_params(card_transaction_params, search_params)

      relation = user.card_installments
                     .includes(inclusions)
                     .left_joins(joins)
                     .where(conditions)
                     .where("card_transactions.description ILIKE ?", "%#{search_term}%")
                     .where("installments.year = ? AND installments.month = ?", year, month)

      relation = relation.where("entities.id IN (?)", entity_ids) if entity_ids.present?
      relation = relation.where("categories.id IN (?)", category_ids) if category_ids.present?

      relation.distinct.order("installments.date, installments.id")
    end

    def self.build_conditions_from_params(card_transaction_params, search_params)
      search_params.delete(:controller)
      search_params.delete(:action)

      return {} if card_transaction_params.blank? && search_params.blank?

      installments_price = build_card_transaction_price_range_conditions(search_params)
      card_transaction_params[:price] = build_price_range_conditions(search_params)
      card_transaction_params[:card_installments_count] = build_installments_count_range_conditions(search_params)

      {
        price: installments_price,
        card_transaction: card_transaction_params.to_unsafe_h.compact_blank
      }.compact_blank
    end

    def self.build_card_transaction_price_range_conditions(search_params)
      from_ct_price = search_params.delete(:from_ct_price).to_i
      to_ct_price = search_params.delete(:to_ct_price).to_i
      return nil if from_ct_price.zero? && to_ct_price.zero?

      from_ct_price ||= 0
      to_ct_price   ||= from_ct_price if from_ct_price
      from_ct_price, to_ct_price = to_ct_price, from_ct_price if from_ct_price > to_ct_price

      (from_ct_price..to_ct_price)
    end

    def self.build_price_range_conditions(search_params)
      from_price = search_params.delete(:from_price).to_i
      to_price = search_params.delete(:to_price).to_i
      return nil if from_price.zero? && to_price.zero?

      from_price ||= 0
      to_price   ||= from_price if from_price
      from_price, to_price = to_price, from_price if from_price > to_price

      (from_price..to_price)
    end

    def self.build_installments_count_range_conditions(search_params)
      from_installments_count = search_params.delete(:from_installments_count).to_i
      to_installments_count = search_params.delete(:to_installments_count).to_i
      return nil if from_installments_count.zero? && to_installments_count.zero?

      from_installments_count ||= 1
      to_installments_count   ||= from_installments_count if from_installments_count
      from_installments_count, to_installments_count = to_installments_count, from_installments_count if from_installments_count > to_installments_count

      (from_installments_count..to_installments_count)
    end
  end
end
