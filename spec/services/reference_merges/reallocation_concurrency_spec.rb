# frozen_string_literal: true

require "rails_helper"
RSpec.describe "Concurrent reference reallocation", :non_transactional do
  self.use_transactional_tests = false

  before { truncate_audit_storage }
  after { truncate_audit_storage }

  it "serializes same-card plans and rejects the stale racer without a partial merge" do
    user = create(:user, :random)
    context = user.main_context
    user_card = create(:user_card, :random, user:, due_date_day: 12, days_until_due_date: 5)
    account = create(:user_bank_account, :random, user:)
    references = [ 8, 9 ].map do |month|
      create(
        :reference,
        user_card:,
        context:,
        month:,
        year: 2026,
        reference_date: Date.new(2026, month, 12),
        reference_closing_date: Date.new(2026, month, 7)
      )
    end
    invoices = references.map do |reference|
      create_invoice(user:, context:, user_card:, account:, reference:)
    end
    transaction = create_transaction(user:, context:, user_card:, references:)
    transaction.card_installments.order(:number).zip(invoices).each do |installment, invoice|
      installment.update_columns(cash_transaction_id: invoice.id)
    end
    plan = ReferenceMerges::ReallocationPlanner.new(
      user_card:,
      context:,
      source_date: Date.new(2026, 8, 1),
      target_date: Date.new(2026, 9, 1)
    ).call

    ready = Queue.new
    release = Queue.new
    threads = 2.times.map do
      Thread.new do
        ready << true
        wait_for_signal(release, description: "the reference reallocation race release")
        ActiveRecord::Base.connection_pool.with_connection do
          ReferenceMerges::ReallocationApply.new(plan:).call
        end
      end
    end
    2.times { wait_for_signal(ready, description: "a reference reallocation racer to become ready") }
    2.times { release << true }
    results = threads.map { |thread| thread_value(thread, description: "a reference reallocation racer") }

    expect(results.map(&:status)).to contain_exactly("applied", "rejected")
    expect(results.find(&:rejected?).reason_code).to eq("stale_plan")
    expect(transaction.card_installments.reload.order(:number).pluck(:month, :year)).to eq([ [ 9, 2026 ], [ 10, 2026 ] ])
    expect(user_card.references.where(context:, month: 8, year: 2026)).not_to exist
    expect(user_card.references.where(context:, month: 10, year: 2026).count).to eq(1)
    expect(AuditOperation.where("metadata ->> 'reference_merge_mode' = ?", Logic::References::REALLOCATE_INSTALLMENTS).count).to eq(1)
  end

  it "serializes independently planned combine and reallocation attempts for the same card and context" do
    user = create(:user, :random)
    context = user.main_context
    user_card = create(:user_card, :random, user:, due_date_day: 12, days_until_due_date: 5)
    account = create(:user_bank_account, :random, user:)
    references = [ 8, 9 ].map do |month|
      create(
        :reference,
        user_card:,
        context:,
        month:,
        year: 2026,
        reference_date: Date.new(2026, month, 12),
        reference_closing_date: Date.new(2026, month, 7)
      )
    end
    invoices = references.map { |reference| create_invoice(user:, context:, user_card:, account:, reference:) }
    transaction = create_transaction(user:, context:, user_card:, references:)
    transaction.card_installments.order(:number).zip(invoices).each do |installment, invoice|
      installment.update_columns(cash_transaction_id: invoice.id)
    end

    ready = Queue.new
    release = Queue.new
    modes = [ Logic::References::COMBINE_INTO_TARGET, Logic::References::REALLOCATE_INSTALLMENTS ]
    threads = modes.map do |merge_mode|
      Thread.new do
        ready << true
        wait_for_signal(release, description: "the reference merge race release")
        ActiveRecord::Base.connection_pool.with_connection do
          Logic::References.merge_result(
            user_card,
            Date.new(2026, 8, 1),
            Date.new(2026, 9, 1),
            merge_mode:,
            context:
          )
        end
      end
    end
    2.times { wait_for_signal(ready, description: "a reference merge racer to become ready") }
    2.times { release << true }
    results = threads.map { |thread| thread_value(thread, description: "a reference merge racer") }

    expect(results.map(&:status)).to contain_exactly("applied", "rejected")
    expect(user_card.references.where(context:, month: 8, year: 2026)).not_to exist
    expect(user_card.references.where(context:).group(:year, :month).having("COUNT(*) > 1")).to be_empty
    expect(AuditOperation.where("metadata ->> 'reference_merge_mode' IN (?)", modes).count).to eq(1)

    installment_buckets = transaction.card_installments.reload.order(:number).pluck(:month, :year)
    expect(installment_buckets).to be_in([ [ [ 9, 2026 ], [ 9, 2026 ] ], [ [ 9, 2026 ], [ 10, 2026 ] ] ])
  end

  it "does not make independent cards in the same context share a merge lock" do
    user = create(:user, :random)
    context = user.main_context
    first_card = create(:user_card, :random, user:)
    second_card = create(:user_card, :random, user:)
    locked = Queue.new
    release = Queue.new
    holder = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        ApplicationRecord.transaction do
          ReferenceMerges::Lock.acquire!(user_card: first_card, context:)
          locked << true
          wait_for_signal(release, description: "the first card reference lock release")
        end
      end
    end

    wait_for_signal(locked, description: "the first card reference lock")
    independent_lock = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        ApplicationRecord.transaction { ReferenceMerges::Lock.acquire!(user_card: second_card, context:) }
      end
      true
    end

    expect(thread_value(independent_lock, description: "the independent card reference lock")).to be(true)
  ensure
    release << true if release
    join_thread(holder, description: "the first card reference lock holder") if holder
    join_thread(independent_lock, description: "the independent card reference lock") if independent_lock
  end

  private

  def create_invoice(user:, context:, user_card:, account:, reference:)
    create(
      :cash_transaction,
      user:,
      context:,
      user_card:,
      user_bank_account: account,
      cash_transaction_type: "CardInstallment",
      date: reference.reference_date.end_of_day,
      month: reference.month,
      year: reference.year,
      price: -1_000,
      paid: false,
      cash_installments: [
        build(
          :cash_installment,
          number: 1,
          date: reference.reference_date.end_of_day,
          month: reference.month,
          year: reference.year,
          price: -1_000,
          paid: false
        )
      ],
      category_transactions: [ CategoryTransaction.new(category: user.built_in_category("CARD PAYMENT")) ],
      entity_transactions: []
    )
  end

  def create_transaction(user:, context:, user_card:, references:)
    create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      date: references.first.reference_closing_date - 1.day,
      month: references.first.month,
      year: references.first.year,
      price: -2_000,
      card_installments: references.map.with_index do |reference, index|
        build(
          :card_installment,
          number: index + 1,
          date: reference.reference_closing_date - 1.day,
          month: reference.month,
          year: reference.year,
          price: -1_000,
          paid: false
        )
      end,
      category_transactions: [],
      entity_transactions: []
    )
  end

  def truncate_audit_storage
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE audit_versions, audit_operations RESTART IDENTITY CASCADE")
  end
end
