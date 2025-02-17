# frozen_string_literal: true

module Logic
  class Categories
    def self.create(category_params)
      category = Category.new(category_params)
      _handle_creation(category)
    end

    def self.find_by(user, conditions) # rubocop:disable Metrics/MethodLength
      # FIXME: create counter_cache and card_transactions_total and cash_transactions_total for both categories and entities
      user.categories
          .left_joins(:category_transactions)
          .joins("LEFT JOIN card_transactions
                  ON category_transactions.transactable_id = card_transactions.id
                  AND category_transactions.transactable_type = 'CardTransaction'

                  LEFT JOIN cash_transactions
                  ON category_transactions.transactable_id = cash_transactions.id
                  AND category_transactions.transactable_type = 'CashTransaction'")
          .where(conditions)
          .group("categories.id")
          .select("categories.*",
                  "COUNT(DISTINCT CASE WHEN category_transactions.transactable_type = 'CardTransaction'
                                       THEN category_transactions.transactable_id
                                  END) AS card_transactions_count",
                  "COUNT(DISTINCT CASE WHEN category_transactions.transactable_type = 'CashTransaction'
                                       THEN category_transactions.transactable_id
                                  END) AS cash_transactions_count",

                  "COALESCE(SUM(CASE WHEN category_transactions.transactable_type = 'CardTransaction'
                                     THEN card_transactions.price
                                END), 0) AS card_transactions_total",
                  "COALESCE(SUM(CASE WHEN category_transactions.transactable_type = 'CashTransaction'
                                     THEN cash_transactions.price
                                END), 0) AS cash_transactions_total")
          .order(category_name: :asc)
    end

    def self.update(category, category_params)
      category.assign_attributes(category_params)
      _handle_creation(category)
    end

    def self._handle_creation(category)
      category.save
      category
    end
  end
end
