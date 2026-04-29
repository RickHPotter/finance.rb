# frozen_string_literal: true

module Logic
  class ContextPurgeService
    LOCK_NAMESPACE = 4_291

    class UnauthorizedContextAccessError < StandardError; end
    class CrossContextDependencyError < StandardError; end
    class InvariantViolation < StandardError; end

    def initialize(context:, user:)
      @context = context
      @user = user
    end

    def call
      Context.transaction do
        assert_context_ownership!
        acquire_transaction_lock!
        assert_no_cross_context_dependencies!
        before_snapshot = snapshot_main_context!
        collect_ids!
        delete_dependents!
        delete_parents!
        refresh_counters!
        after_snapshot = snapshot_main_context!

        ensure_main_context_unchanged!(before_snapshot:, after_snapshot:)
      end
    end

    private

    attr_reader :context, :user

    def assert_context_ownership!
      return if context.user_id == user.id && user.contexts.where(id: context.id).exists?

      raise UnauthorizedContextAccessError, "Context does not belong to the provided user"
    end

    def acquire_transaction_lock!
      Context.connection.select_value("SELECT pg_advisory_xact_lock(#{LOCK_NAMESPACE}, #{context.user_id})")
    end

    def assert_no_cross_context_dependencies!
      return if cross_context_dependency_messages.empty?

      raise CrossContextDependencyError, cross_context_dependency_messages.join(" | ")
    end

    def cross_context_dependency_messages
      @cross_context_dependency_messages ||= begin
        collect_primary_ids!
        [].tap do |messages|
          main_context = user.main_context

          main_cash_transactions = main_context.cash_transactions
          main_card_transactions = main_context.card_transactions

          if main_cash_transactions.where(reference_transactable_type: "CashTransaction", reference_transactable_id: @cash_transaction_ids).exists?
            messages << "Main-context cash transactions reference derived cash transactions"
          end

          if main_cash_transactions.where(reference_transactable_type: "CardTransaction", reference_transactable_id: @card_transaction_ids).exists?
            messages << "Main-context cash transactions reference derived card transactions"
          end

          if main_card_transactions.where(reference_transactable_type: "CashTransaction", reference_transactable_id: @cash_transaction_ids).exists?
            messages << "Main-context card transactions reference derived cash transactions"
          end

          if main_card_transactions.where(reference_transactable_type: "CardTransaction", reference_transactable_id: @card_transaction_ids).exists?
            messages << "Main-context card transactions reference derived card transactions"
          end

          if main_card_transactions.where(advance_cash_transaction_id: @cash_transaction_ids).exists?
            messages << "Main-context card advances point to derived cash transactions"
          end

          messages << "Main-context cash transactions belong to derived subscriptions" if main_cash_transactions.where(subscription_id: @subscription_ids).exists?

          messages << "Main-context card transactions belong to derived subscriptions" if main_card_transactions.where(subscription_id: @subscription_ids).exists?
        end
      end
    end

    def collect_ids!
      collect_primary_ids!
      collect_affected_owner_ids!
      @entity_transaction_ids = transactable_entity_transaction_ids
    end

    def delete_dependents!
      Exchange.where(entity_transaction_id: @entity_transaction_ids).or(Exchange.where(cash_transaction_id: @cash_transaction_ids)).delete_all

      Installment.where(card_transaction_id: @card_transaction_ids).or(Installment.where(cash_transaction_id: @cash_transaction_ids)).delete_all

      Investment.where(id: @investment_ids).delete_all

      BudgetCategory.where(budget_id: @budget_ids).delete_all
      BudgetEntity.where(budget_id: @budget_ids).delete_all

      delete_category_transactions!
      delete_entity_transactions!

      Reference.where(context_id: context.id).delete_all
    end

    def delete_parents!
      CardTransaction.where(id: @card_transaction_ids).delete_all
      CashTransaction.where(id: @cash_transaction_ids).delete_all
      Budget.where(id: @budget_ids).delete_all
      Subscription.where(id: @subscription_ids).delete_all
      Context.where(id: context.id).delete_all
    end

    def refresh_counters!
      Category.where(id: @affected_category_ids.uniq).find_each do |category|
        category.update_card_transactions_count_and_total
        category.update_cash_transactions_count_and_total
      end

      Entity.where(id: @affected_entity_ids.uniq).find_each do |entity|
        entity.update_card_transactions_count_and_total
        entity.update_cash_transactions_count_and_total
      end

      UserCard.where(id: @affected_user_card_ids.uniq).find_each do |user_card|
        user_card.update_columns(card_transactions_count: user_card.card_transactions.count)
      end

      UserBankAccount.where(id: @affected_user_bank_account_ids.uniq).find_each do |user_bank_account|
        user_bank_account.update_columns(cash_transactions_count: user_bank_account.cash_transactions.count)
      end

      Subscription.where(id: @affected_subscription_ids.uniq).find_each do |subscription|
        subscription.update_columns(
          card_transactions_count: subscription.card_transactions.count,
          cash_transactions_count: subscription.cash_transactions.count
        )
      end
    end

    def budget_category_ids
      BudgetCategory.where(budget_id: @budget_ids).distinct.pluck(:category_id)
    end

    def budget_entity_ids
      BudgetEntity.where(budget_id: @budget_ids).distinct.pluck(:entity_id)
    end

    def transactable_category_ids
      polymorphic_category_transactions_scope.distinct.pluck(:category_id)
    end

    def transactable_entity_ids
      polymorphic_entity_transactions_scope.distinct.pluck(:entity_id)
    end

    def transactable_entity_transaction_ids
      polymorphic_entity_transactions_scope.pluck(:id)
    end

    def delete_category_transactions!
      polymorphic_category_transactions_scope.delete_all
    end

    def delete_entity_transactions!
      EntityTransaction.where(id: @entity_transaction_ids).delete_all
    end

    def polymorphic_category_transactions_scope
      CategoryTransaction.none
                         .or(CategoryTransaction.where(transactable_type: "CardTransaction", transactable_id: @card_transaction_ids))
                         .or(CategoryTransaction.where(transactable_type: "CashTransaction", transactable_id: @cash_transaction_ids))
                         .or(CategoryTransaction.where(transactable_type: "Investment", transactable_id: @investment_ids))
                         .or(CategoryTransaction.where(transactable_type: "Subscription", transactable_id: @subscription_ids))
    end

    def polymorphic_entity_transactions_scope
      EntityTransaction.none
                       .or(EntityTransaction.where(transactable_type: "CardTransaction", transactable_id: @card_transaction_ids))
                       .or(EntityTransaction.where(transactable_type: "CashTransaction", transactable_id: @cash_transaction_ids))
                       .or(EntityTransaction.where(transactable_type: "Subscription", transactable_id: @subscription_ids))
    end

    def collect_primary_ids!
      @budget_ids = context.budgets.pluck(:id)
      @card_transaction_ids = context.card_transactions.pluck(:id)
      @cash_transaction_ids = context.cash_transactions.pluck(:id)
      @investment_ids = context.investments.pluck(:id)
      @subscription_ids = context.subscriptions.pluck(:id)
    end

    def collect_affected_owner_ids!
      @affected_category_ids = budget_category_ids + transactable_category_ids
      @affected_entity_ids = budget_entity_ids + transactable_entity_ids
      @affected_user_card_ids = context.card_transactions.where.not(user_card_id: nil).distinct.pluck(:user_card_id)
      @affected_user_bank_account_ids = context.cash_transactions.where.not(user_bank_account_id: nil).distinct.pluck(:user_bank_account_id)
      @affected_subscription_ids = @subscription_ids.dup
    end

    def snapshot_main_context!
      main_context = context.user.main_context
      recalculate_main_context!(main_context)

      {
        counts: main_context_counts(main_context),
        balances: main_context_balances(main_context)
      }
    end

    def recalculate_main_context!(main_context)
      year, month = main_context_recalculation_anchor(main_context)
      Logic::RecalculateBalancesService.new(user:, context: main_context, year:, month:).call
    end

    def main_context_recalculation_anchor(main_context)
      candidates = []

      first_cash_installment = main_context.cash_installments.reorder(:year, :month, :date, :id).pick(:year, :month)
      first_budget = main_context.budgets.reorder(:year, :month, :id).pick(:year, :month)

      candidates << first_cash_installment if first_cash_installment.present?
      candidates << first_budget if first_budget.present?

      candidates.min || [ 2000, 1 ]
    end

    def main_context_counts(main_context)
      {
        card_transactions: main_context.card_transactions.count,
        cash_transactions: main_context.cash_transactions.count,
        budgets: main_context.budgets.count,
        investments: main_context.investments.count,
        subscriptions: main_context.subscriptions.count,
        references: main_context.references.count,
        cash_installments: main_context.cash_installments.count
      }
    end

    def main_context_balances(main_context)
      cash_installment_rows = main_context.cash_installments
                                          .reorder(:order_id, :id)
                                          .pluck(:id, :order_id, :balance)
                                          .map { |id, order_id, balance| [ "CashInstallment", id, order_id, balance ] }

      budget_rows = main_context.budgets
                                .reorder(:order_id, :id)
                                .pluck(:id, :order_id, :balance)
                                .map { |id, order_id, balance| [ "Budget", id, order_id, balance ] }

      [ *cash_installment_rows, *budget_rows ].sort_by { |type, id, order_id, _balance| [ order_id || -1, type, id ] }
    end

    def ensure_main_context_unchanged!(before_snapshot:, after_snapshot:)
      return if before_snapshot == after_snapshot

      raise InvariantViolation, "Main context drift detected during context purge"
    end
  end
end
