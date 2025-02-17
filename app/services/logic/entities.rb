# frozen_string_literal: true

module Logic
  class Entities
    def self.create(entity_params)
      entity = Entity.new(entity_params)
      _handle_creation(entity)
    end

    def self.find_by(user, conditions) # rubocop:disable Metrics/MethodLength
      # FIXME: create counter_cache and card_transactions_total and cash_transactions_total for both categories and entities
      user.entities
          .left_joins(:entity_transactions)
          .joins("LEFT JOIN card_transactions
                  ON entity_transactions.transactable_id = card_transactions.id
                  AND entity_transactions.transactable_type = 'CardTransaction'

                  LEFT JOIN cash_transactions
                  ON entity_transactions.transactable_id = cash_transactions.id
                  AND entity_transactions.transactable_type = 'CashTransaction'")
          .where(conditions)
          .group("entities.id")
          .select("entities.*",
                  "COUNT(DISTINCT CASE WHEN entity_transactions.transactable_type = 'CardTransaction'
                                       THEN entity_transactions.transactable_id
                                  END) AS card_transactions_count",
                  "COUNT(DISTINCT CASE WHEN entity_transactions.transactable_type = 'CashTransaction'
                                       THEN entity_transactions.transactable_id
                                  END) AS cash_transactions_count",

                  "COALESCE(SUM(CASE WHEN entity_transactions.transactable_type = 'CardTransaction'
                                     THEN card_transactions.price
                                END), 0) AS card_transactions_total",
                  "COALESCE(SUM(CASE WHEN entity_transactions.transactable_type = 'CashTransaction'
                                     THEN cash_transactions.price
                                END), 0) AS cash_transactions_total")
          .order(entity_name: :asc)
    end

    def self.update(entity, entity_params)
      entity.assign_attributes(entity_params)
      _handle_creation(entity)
    end

    def self._handle_creation(entity)
      entity.save
      entity
    end
  end
end
