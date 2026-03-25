# frozen_string_literal: true

module Logic
  class ContextCloneService
    def initialize(source_context:, name:, description: nil, scenario_key: nil)
      @source_context = source_context
      @user = source_context.user
      @name = name
      @description = description.presence || source_context.description
      @scenario_key = scenario_key

      @budget_map = {}
      @cash_transaction_map = {}
      @card_transaction_map = {}
      @entity_transaction_map = {}
      @investment_map = {}
      @reference_map = {}
      @subscription_map = {}
    end

    def call
      ApplicationRecord.transaction do
        clone_context!
        clone_references!
        clone_budgets!
        clone_subscriptions!
        clone_cash_transactions!
        clone_card_transactions!
        clone_investments!
        clone_budget_associations!
        clone_subscription_associations!
        clone_cash_transaction_associations!
        clone_card_transaction_associations!
        clone_investment_associations!
        clone_exchanges!

        @target_context
      end
    end

    private

    def clone_context!
      @target_context = @user.contexts.create!(
        name: @name,
        description: @description,
        main: false,
        scenario_key: @scenario_key,
        source_context: @source_context,
        cloned_at: Time.current
      )
    end

    def clone_references!
      @source_context.references.order(:id).find_each do |reference|
        @reference_map[reference.id] = insert_clone!(Reference, reference, overrides: {
                                                       context_id: @target_context.id
                                                     })
      end
    end

    def clone_budgets!
      @source_context.budgets.order(:id).find_each do |budget|
        @budget_map[budget.id] = insert_clone!(Budget, budget, overrides: {
                                                 context_id: @target_context.id
                                               })
      end
    end

    def clone_subscriptions!
      @source_context.subscriptions.order(:id).find_each do |subscription|
        @subscription_map[subscription.id] = insert_clone!(Subscription, subscription, overrides: {
                                                             context_id: @target_context.id
                                                           })
      end
    end

    def clone_cash_transactions!
      @source_context.cash_transactions.order(:id).find_each do |cash_transaction|
        @cash_transaction_map[cash_transaction.id] = insert_clone!(CashTransaction, cash_transaction, overrides: {
                                                                     context_id: @target_context.id,
                                                                     subscription_id: map_subscription_id(cash_transaction.subscription_id),
                                                                     reference_transactable_type: nil,
                                                                     reference_transactable_id: nil
                                                                   })
      end
    end

    def clone_card_transactions!
      @source_context.card_transactions.order(:id).find_each do |card_transaction|
        @card_transaction_map[card_transaction.id] = insert_clone!(CardTransaction, card_transaction, overrides: {
                                                                     context_id: @target_context.id,
                                                                     subscription_id: map_subscription_id(card_transaction.subscription_id),
                                                                     advance_cash_transaction_id: map_cash_transaction_id(
                                                                       card_transaction.advance_cash_transaction_id
                                                                     ),
                                                                     reference_transactable_type: nil,
                                                                     reference_transactable_id: nil
                                                                   })
      end
    end

    def clone_investments!
      @source_context.investments.order(:id).find_each do |investment|
        @investment_map[investment.id] = insert_clone!(Investment, investment, overrides: {
                                                         context_id: @target_context.id,
                                                         cash_transaction_id: map_cash_transaction_id(investment.cash_transaction_id)
                                                       })
      end
    end

    def clone_budget_associations!
      clone_join_rows!(BudgetCategory, BudgetCategory.where(budget_id: @budget_map.keys), "budget_id" => @budget_map)
      clone_join_rows!(BudgetEntity, BudgetEntity.where(budget_id: @budget_map.keys), "budget_id" => @budget_map)
    end

    def clone_subscription_associations!
      clone_polymorphic_category_transactions!("Subscription", @subscription_map)
      clone_polymorphic_entity_transactions!("Subscription", @subscription_map)
    end

    def clone_cash_transaction_associations!
      clone_polymorphic_category_transactions!("CashTransaction", @cash_transaction_map)
      clone_polymorphic_entity_transactions!("CashTransaction", @cash_transaction_map)
      clone_installments!(
        CashInstallment.where(cash_transaction_id: @cash_transaction_map.keys),
        transaction_id_map: @cash_transaction_map
      )
    end

    def clone_card_transaction_associations!
      clone_polymorphic_category_transactions!("CardTransaction", @card_transaction_map)
      clone_polymorphic_entity_transactions!("CardTransaction", @card_transaction_map)
      clone_installments!(
        CardInstallment.where(card_transaction_id: @card_transaction_map.keys),
        transaction_id_map: @card_transaction_map,
        linked_cash_transaction_map: @cash_transaction_map
      )
    end

    def clone_investment_associations!
      clone_polymorphic_category_transactions!("Investment", @investment_map)
    end

    def clone_exchanges!
      Exchange.where(entity_transaction_id: @entity_transaction_map.keys).order(:id).find_each do |exchange|
        insert_clone!(Exchange, exchange, overrides: {
                        entity_transaction_id: @entity_transaction_map.fetch(exchange.entity_transaction_id),
                        cash_transaction_id: map_cash_transaction_id(exchange.cash_transaction_id)
                      })
      end
    end

    def clone_polymorphic_category_transactions!(transactable_type, id_map)
      return if id_map.empty?

      CategoryTransaction.where(transactable_type:, transactable_id: id_map.keys).order(:id).find_each do |row|
        insert_clone!(CategoryTransaction, row, overrides: {
                        transactable_id: id_map.fetch(row.transactable_id)
                      })
      end
    end

    def clone_polymorphic_entity_transactions!(transactable_type, id_map)
      return if id_map.empty?

      EntityTransaction.where(transactable_type:, transactable_id: id_map.keys).order(:id).find_each do |row|
        @entity_transaction_map[row.id] = insert_clone!(EntityTransaction, row, overrides: {
                                                          transactable_id: id_map.fetch(row.transactable_id)
                                                        })
      end
    end

    def clone_installments!(relation, transaction_id_map:, linked_cash_transaction_map: nil)
      relation.order(:id).find_each do |installment|
        overrides = {
          cash_transaction_id: map_cash_transaction_id(installment.cash_transaction_id),
          card_transaction_id: map_card_transaction_id(installment.card_transaction_id)
        }

        if linked_cash_transaction_map && installment.cash_transaction_id.present?
          overrides[:cash_transaction_id] =
            linked_cash_transaction_map.fetch(installment.cash_transaction_id)
        end
        overrides[:card_transaction_id] = transaction_id_map.fetch(installment.card_transaction_id) if installment.card_transaction_id.present?
        if installment.cash_transaction_id.present? && linked_cash_transaction_map.nil?
          overrides[:cash_transaction_id] =
            transaction_id_map.fetch(installment.cash_transaction_id)
        end

        insert_clone!(installment.class, installment, overrides:)
      end
    end

    def clone_join_rows!(model, relation, column_maps)
      relation.order(:id).find_each do |row|
        overrides = column_maps.transform_values { |mapping| mapping.fetch(row.public_send(mapping_key_for(column_maps, mapping))) }
        insert_clone!(model, row, overrides:)
      end
    end

    def mapping_key_for(column_maps, mapping)
      column_maps.key(mapping).to_s.delete_suffix("=")
    end

    def insert_clone!(model, record, overrides: {})
      attrs = record.attributes.slice(*cloneable_column_names_for(model)).merge(overrides.stringify_keys)
      result = model.insert_all!([ attrs ], returning: %w[id], record_timestamps: false)
      result.rows.first.first
    end

    def cloneable_column_names_for(model)
      generated_columns = model.columns.filter_map do |column|
        column.name if column.respond_to?(:virtual?) && column.virtual?
      end

      model.column_names - [ "id", *generated_columns ]
    end

    def map_subscription_id(id)
      return if id.blank?

      @subscription_map.fetch(id)
    end

    def map_cash_transaction_id(id)
      return if id.blank?

      @cash_transaction_map.fetch(id)
    end

    def map_card_transaction_id(id)
      return if id.blank?

      @card_transaction_map.fetch(id)
    end
  end
end
