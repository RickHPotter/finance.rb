# frozen_string_literal: true

class Ledgers::Query
  Month = Data.define(:month_year, :count, :total, :last_updated_at)
  Result = Data.define(:kind, :rows, :months, :total_count, :total_amount, :page, :per_page, :user_card, :user_bank_account) do
    def count_by_month_year
      months.index_by(&:month_year)
    end

    def last_updated_at
      months.filter_map(&:last_updated_at).max
    end
  end

  def self.call(access:, state:, include_rows: true)
    new(access:, state:, include_rows:).call
  end

  def initialize(access:, state:, include_rows:)
    @access = access
    @state = state
    @include_rows = include_rows
  end

  def call
    relation, user_card, user_bank_account = authorized_relation
    months = month_summaries(relation)
    selected = months.find { |month| month.month_year == state.month_year }
    rows = include_rows ? paginated_rows(month_relation(relation)) : relation.none

    Result.new(
      kind: state.kind,
      rows:,
      months:,
      total_count: selected&.count || 0,
      total_amount: selected&.total || 0,
      page: state.page,
      per_page: state.per_page,
      user_card:,
      user_bank_account:
    )
  end

  private

  attr_reader :access, :state, :include_rows

  def authorized_relation
    state.kind == :cash ? authorized_cash_relation : authorized_card_relation
  end

  def authorized_cash_relation
    filter_id = state.user_bank_account_id unless access.share
    account = resolve_owner_filter(access.user.user_bank_accounts, filter_id)
    transactions = scoped_transactions(CashTransaction, [ "EXCHANGE RETURN", "BORROW RETURN" ])
    transactions = transactions.where(user_bank_account_id: account.id) if account
    relation = access.context.cash_installments.where(cash_transaction_id: transactions.select(:id))
    relation = relation.none if filter_id && account.nil?
    relation = apply_search(relation, :cash_transaction, "cash_transactions.description")
    relation = apply_paid_filter(relation)
    [ relation, nil, account ]
  end

  def authorized_card_relation
    filter_id = state.user_card_id unless access.share
    user_card = resolve_owner_filter(access.user.user_cards, filter_id)
    transactions = scoped_transactions(CardTransaction, [ "EXCHANGE" ])
    transactions = transactions.where(user_card_id: user_card.id) if user_card
    relation = access.context.card_installments.where(card_transaction_id: transactions.select(:id))
    relation = relation.none if filter_id && user_card.nil?
    relation = apply_search(relation, :card_transaction, "card_transactions.description")
    [ relation, user_card, nil ]
  end

  def scoped_transactions(model, category_names)
    type = model.name
    category_ids = access.user.categories.where(category_name: category_names).select(:id)
    category_transaction_ids = CategoryTransaction.where(transactable_type: type, category_id: category_ids).select(:transactable_id)
    entity_transaction_ids = EntityTransaction.where(transactable_type: type, entity_id: access.entity.id).select(:transactable_id)

    access.context.public_send(model.model_name.collection).where(id: category_transaction_ids).where(id: entity_transaction_ids)
  end

  def resolve_owner_filter(scope, id)
    scope.find_by(id:) if id
  end

  def apply_search(relation, transaction_association, column)
    return relation if state.search_term.blank?

    Search::NormalizedText.apply(relation.joins(transaction_association), state.search_term, column)
  end

  def apply_paid_filter(relation)
    return relation if state.paid == state.pending

    relation.where(paid: state.paid)
  end

  def month_summaries(relation)
    relation.reorder(nil).group(:year, :month).pluck(
      :year,
      :month,
      Arel.sql("COUNT(installments.id)"),
      Arel.sql("COALESCE(SUM(installments.price), 0)"),
      Arel.sql("MAX(installments.updated_at)")
    ).map do |year, month, count, total, last_updated_at|
      Month.new(month_year: (year * 100) + month, count:, total:, last_updated_at:)
    end.sort_by(&:month_year)
  end

  def month_relation(relation)
    return relation.none unless state.month_year

    relation.where(year: state.month_year / 100, month: state.month_year % 100)
  end

  def paginated_rows(relation)
    relation = preload_rows(relation)
    relation = apply_sort(relation)
    relation.offset((state.page - 1) * state.per_page).limit(state.per_page).load
  end

  def preload_rows(relation)
    transaction_association = state.kind == :cash ? :cash_transaction : :card_transaction

    relation.includes(
      transaction_association => [
        :categories,
        :entities,
        { category_transactions: :category },
        { entity_transactions: :entity }
      ]
    )
  end

  def apply_sort(relation)
    if state.kind == :cash
      sorted = Logic::CashInstallments.apply_sort(relation, sort: state.sort, direction: state.direction)
      state.sort == "default" ? sorted.order(id: :asc) : sorted
    else
      Logic::CardInstallments.apply_sort(relation, sort: state.sort, direction: state.direction)
    end
  end
end
