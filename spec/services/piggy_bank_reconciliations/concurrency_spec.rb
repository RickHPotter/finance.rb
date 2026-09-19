# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Concurrent Piggy Bank net reconciliation", :non_transactional do
  self.use_transactional_tests = false

  before { truncate_audit_storage }
  after { truncate_audit_storage }

  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let!(:investment_type) do
    InvestmentType.find_or_create_by!(investment_type_code: PiggyBankReconciliations::Preview::INVESTMENT_TYPE_CODE) do |type|
      type.investment_type_name_fallback = "Other - Piggy Bank"
      type.built_in = true
    end
  end

  def create_piggy_bank_return(owner: user, transaction_context: context, price: 5_000)
    owner_account = owner == user ? account : create(:user_bank_account, :random, user: owner)
    owner_entity = owner == user ? entity : create(:entity, :random, user: owner)
    source = build(
      :cash_transaction,
      user: owner,
      context: transaction_context,
      user_bank_account: owner_account,
      description: "Observed reserve",
      price: -price,
      cash_installments: [ build(:cash_installment, number: 1, price: -price, date: Date.new(2026, 9, 1)) ],
      category_transactions: [ CategoryTransaction.new(category: owner.built_in_category("PIGGY BANK")) ],
      entity_transactions: [ EntityTransaction.new(entity: owner_entity, price: 0, price_to_be_returned: 0, is_payer: false) ],
      piggy_bank: PiggyBank.new(return_price: price, return_date: Date.new(2026, 12, 1))
    )
    source.save!
    source.piggy_bank.return_cash_transaction
  end

  it "serializes same-group applies and rejects the stale racer without duplicate investment or corruption" do
    return_transaction = create_piggy_bank_return
    preview = PiggyBankReconciliations::Preview.new(
      user:,
      context:,
      return_cash_transaction_id: return_transaction.id,
      observed_net_cents: 5_500,
      observed_on: "2026-09-15"
    ).call

    ready = Queue.new
    release = Queue.new
    threads = 2.times.map do |index|
      Thread.new do
        ready << true
        wait_for_signal(release, description: "the piggy bank reconciliation race release")
        ActiveRecord::Base.connection_pool.with_connection do
          PiggyBankReconciliations::Apply.new(
            user:,
            context:,
            return_cash_transaction_id: return_transaction.id,
            observed_net_cents: 5_500,
            observed_on: "2026-09-15",
            digest: preview.digest,
            request_id: "concurrent-reconcile-#{index}"
          ).call
        end
      end
    end
    2.times { wait_for_signal(ready, description: "a piggy bank reconciliation racer to become ready") }
    2.times { release << true }
    results = threads.map { |thread| thread_value(thread, description: "a piggy bank reconciliation racer") }

    expect(results.map(&:status)).to contain_exactly(:applied, :stale)
    stale_result = results.find(&:stale?)
    expect(stale_result.reason_code).to eq(:stale_preview)

    expect(Investment.where(piggy_bank_return_cash_transaction_id: return_transaction.id).count).to eq(1)
    expect(return_transaction.reload.price).to eq(5_500)
    expect(return_transaction.cash_installments.sole.price).to eq(5_500)
    expect(AuditOperation.where(source: :web, actor_id: user.id).count).to eq(1)
  end

  it "allows concurrent applies on independent return groups without blocking or cross-talk" do
    first_return = create_piggy_bank_return(price: 5_000)
    second_return = create_piggy_bank_return(price: 3_000)

    first_preview = PiggyBankReconciliations::Preview.new(
      user:,
      context:,
      return_cash_transaction_id: first_return.id,
      observed_net_cents: 5_400,
      observed_on: "2026-09-15"
    ).call
    second_preview = PiggyBankReconciliations::Preview.new(
      user:,
      context:,
      return_cash_transaction_id: second_return.id,
      observed_net_cents: 3_200,
      observed_on: "2026-09-15"
    ).call

    ready = Queue.new
    release = Queue.new
    tasks = [ [ first_return, 5_400, first_preview.digest ], [ second_return, 3_200, second_preview.digest ] ]

    threads = tasks.map.with_index do |(target, observed_cents, digest), index|
      Thread.new do
        ready << true
        wait_for_signal(release, description: "the independent reconciliation release")
        ActiveRecord::Base.connection_pool.with_connection do
          PiggyBankReconciliations::Apply.new(
            user:,
            context:,
            return_cash_transaction_id: target.id,
            observed_net_cents: observed_cents,
            observed_on: "2026-09-15",
            digest:,
            request_id: "independent-reconcile-#{index}"
          ).call
        end
      end
    end
    2.times { wait_for_signal(ready, description: "an independent reconciliation racer to become ready") }
    2.times { release << true }
    results = threads.map { |thread| thread_value(thread, description: "an independent reconciliation racer") }

    expect(results.map(&:status)).to eq(%i[applied applied])
    expect(first_return.reload.price).to eq(5_400)
    expect(second_return.reload.price).to eq(3_200)
    expect(Investment.where(piggy_bank_return_cash_transaction_id: first_return.id).sole.price).to eq(400)
    expect(Investment.where(piggy_bank_return_cash_transaction_id: second_return.id).sole.price).to eq(200)
    expect(AuditOperation.where(source: :web, actor_id: user.id).count).to eq(2)
  end

  private

  def truncate_audit_storage
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE audit_versions, audit_operations RESTART IDENTITY CASCADE")
  end
end
