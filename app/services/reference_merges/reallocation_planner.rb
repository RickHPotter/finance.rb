# frozen_string_literal: true

class ReferenceMerges::ReallocationPlanner
  attr_reader :user_card, :context, :raw_source_date, :raw_target_date

  def initialize(user_card:, context:, source_date:, target_date:)
    @user_card = user_card
    @context = context
    @raw_source_date = source_date
    @raw_target_date = target_date
  end

  def call
    load_state

    ReferenceMerges::ReallocationPlan.new(
      user_card:,
      context:,
      source_date:,
      target_date:,
      buckets: build_buckets,
      issues: build_issues,
      lock_keys: build_lock_keys,
      state_rows: build_state_rows
    )
  end

  private

  def load_state
    source_date
    target_date
    references
    invoices
    installments
    exchanges
    projections
  end

  def source_date
    @source_date ||= normalize_date(raw_source_date)
  end

  def target_date
    @target_date ||= normalize_date(raw_target_date)
  end

  def normalize_date(value)
    value = Date.parse(value) unless value.respond_to?(:to_date)
    value.to_date.beginning_of_month
  rescue ArgumentError, TypeError
    nil
  end

  def references
    @references ||= user_card.references.where(context:).order(:year, :month, :id).to_a
  end

  def invoices
    @invoices ||= context.cash_transactions.card_payment.where(user_card:).includes(:cash_installments).order(:year, :month, :id).to_a
  end

  def installments
    @installments ||= if source_date
                        CardInstallment.unscoped
                                       .joins(:card_transaction)
                                       .where(installment_type: "CardInstallment", card_transactions: { user_card_id: user_card.id, context_id: context.id })
                                       .where(month_range_sql("installments"), source_date.year, source_date.year, source_date.month)
                                       .includes(:cash_transaction, :card_transaction)
                                       .order(:year, :month, :id)
                                       .to_a
                      else
                        []
                      end
  end

  def exchanges
    @exchanges ||= if source_date
                     Exchange
                       .monetary
                       .card_bound
                       .joins(:entity_transaction)
                       .joins("INNER JOIN card_transactions ON card_transactions.id = entity_transactions.transactable_id " \
                              "AND entity_transactions.transactable_type = 'CardTransaction'")
                       .where(card_transactions: { user_card_id: user_card.id, context_id: context.id })
                       .where(month_range_sql("exchanges"), source_date.year, source_date.year, source_date.month)
                       .includes(:cash_transaction)
                       .order(:year, :month, :id)
                       .to_a
                   else
                     []
                   end
  end

  def projections
    @projections ||= CashTransaction.where(id: exchanges.filter_map(&:cash_transaction_id).uniq).includes(:cash_installments).order(:id).to_a
  end

  def month_range_sql(table)
    "#{table}.year > ? OR (#{table}.year = ? AND #{table}.month >= ?)"
  end

  def build_buckets
    return [] unless source_date && latest_occupied_date

    bucket_dates.map do |date|
      destination_date = date.next_month
      bucket_installments = installments_by_date.fetch(date, [])
      bucket_exchanges = exchanges_by_date.fetch(date, [])

      ReferenceMerges::ReallocationPlan::Bucket.new(
        source_date: date,
        destination_date:,
        installment_ids: bucket_installments.map(&:id).sort,
        exchange_ids: bucket_exchanges.map(&:id).sort,
        source_invoice_ids: bucket_installments.filter_map(&:cash_transaction_id).uniq.sort,
        destination_invoice_id: sole_invoice_id(destination_date),
        destination_reference_id: references_by_date[destination_date]&.id
      )
    end
  end

  def bucket_dates
    dates = []
    date = source_date
    while date <= latest_occupied_date
      dates << date
      date = date.next_month
    end
    dates
  end

  def latest_occupied_date
    @latest_occupied_date ||= (installments.map { |row| row_date(row) } + exchanges.map { |row| row_date(row) }).max
  end

  def installments_by_date
    @installments_by_date ||= installments.group_by { |row| row_date(row) }
  end

  def exchanges_by_date
    @exchanges_by_date ||= exchanges.group_by { |row| row_date(row) }
  end

  def references_by_date
    @references_by_date ||= references.index_by { |row| row_date(row) }
  end

  def invoices_by_date
    @invoices_by_date ||= invoices.group_by { |row| row_date(row) }
  end

  def sole_invoice_id(date)
    rows = invoices_by_date.fetch(date, [])
    rows.sole.id if rows.one?
  end

  def row_date(row)
    Date.new(row.year, row.month, 1)
  end

  def build_issues
    [
      invalid_context_issue,
      invalid_date_issue,
      adjacency_issue,
      missing_root_issue(:source, source_date),
      missing_root_issue(:target, target_date),
      empty_shift_issue,
      paid_installments_issue,
      invalid_installment_invoices_issue,
      paid_invoices_issue,
      duplicate_invoices_issue,
      locked_projections_issue
    ].compact
  end

  def invalid_context_issue
    return if context.user_id == user_card.user_id

    issue(:context_mismatch, context_id: context.id, user_card_id: user_card.id)
  end

  def invalid_date_issue
    return if source_date && target_date

    issue(:invalid_date)
  end

  def adjacency_issue
    return unless source_date && target_date
    return if source_date.next_month == target_date

    issue(:not_forward_adjacent)
  end

  def missing_root_issue(kind, date)
    return unless date

    missing = []
    missing << "reference" unless references_by_date.key?(date)
    rows = invoices_by_date.fetch(date, [])
    missing << "invoice" unless rows.one?
    return if missing.empty?

    issue(:missing_root, kind:, date: date.iso8601, missing: missing.join(","))
  end

  def empty_shift_issue
    return if installments.present? || exchanges.present?

    issue(:empty_shift)
  end

  def paid_installments_issue
    ids = installments.select(&:paid?).map(&:id).sort
    issue(:paid_installments, ids: ids.join(",")) if ids.present?
  end

  def invalid_installment_invoices_issue
    invoice_ids = invoices.map(&:id)
    ids = installments.reject { |installment| installment.cash_transaction_id.in?(invoice_ids) }.map(&:id).sort
    issue(:invalid_installment_invoices, ids: ids.join(",")) if ids.present?
  end

  def paid_invoices_issue
    ids = affected_invoices.select { |invoice| invoice.paid? || invoice.paid_history? }.map(&:id).sort
    issue(:paid_invoices, ids: ids.join(",")) if ids.present?
  end

  def duplicate_invoices_issue
    dates = invoices_by_date.filter_map { |date, rows| date.iso8601 if rows.many? }.sort
    issue(:duplicate_invoices, dates: dates.join(",")) if dates.present?
  end

  def locked_projections_issue
    ids = projections.select(&:paid_history?).map(&:id).sort
    issue(:locked_exchange_projections, ids: ids.join(",")) if ids.present?
  end

  def affected_invoices
    ids = installments.filter_map(&:cash_transaction_id).uniq
    invoices.select { |invoice| invoice.id.in?(ids) }
  end

  def issue(code, details = {})
    ReferenceMerges::ReallocationPlan::Issue.new(code:, details:)
  end

  def build_lock_keys
    lock_records.map { |record| "#{record.class.base_class.name}:#{record.id}" }
  end

  def build_state_rows
    lock_records.map do |record|
      {
        record_type: record.class.base_class.name,
        record_id: record.id,
        attributes: record.attributes.except("created_at", "updated_at", "balance", "order_id").sort.to_h
      }
    end
  end

  def lock_records
    @lock_records ||= begin
      records = [ context, *references, *invoices, *invoices.flat_map(&:cash_installments), *installments, *installments.map(&:card_transaction),
                  *exchanges, *projections, *projections.flat_map(&:cash_installments) ]
      records.compact.uniq { |record| [ record.class.base_class.name, record.id ] }
             .sort_by { |record| [ record.class.base_class.name, record.id ] }
    end
  end
end
