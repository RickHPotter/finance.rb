# frozen_string_literal: true

require "rails_helper"

RSpec.describe PiggyBank, type: :model do
  let(:user) { create(:user, :random) }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let(:investment_type) { create(:investment_type, :random) }

  def build_source(price: -5_000, return_price: 5_000, return_date: 3.months.from_now)
    build(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account: account,
      description: "Emergency reserve",
      price:,
      cash_installments: [ build(:cash_installment, number: 1, price:, date: Time.zone.now) ],
      category_transactions: [ CategoryTransaction.new(category: user.built_in_category("PIGGY BANK")) ],
      entity_transactions: [ EntityTransaction.new(entity:, price: 0, price_to_be_returned: 0, is_payer: false) ],
      piggy_bank: described_class.new(return_price:, return_date:)
    )
  end

  def build_attached_source(return_transaction, price: -2_000, return_price: 2_000, attached_entity: entity)
    build_source(price:, return_price:, return_date: return_transaction.date).tap do |source|
      source.entity_transactions = [ EntityTransaction.new(entity: attached_entity, price: 0, price_to_be_returned: 0, is_payer: false) ]
      source.piggy_bank.return_cash_transaction = return_transaction
    end
  end

  def create_valuation(return_transaction, price:)
    create(
      :investment,
      user:,
      context: user.main_context,
      user_bank_account: account,
      investment_type:,
      description: "Observed Piggy Bank adjustment",
      price:,
      date: Date.new(2026, 9, 15),
      month: 9,
      year: 2026,
      piggy_bank_return_cash_transaction: return_transaction
    )
  end

  it "creates one linked positive return transaction atomically" do
    source = build_source

    expect { source.save! }.to change(described_class, :count).by(1).and change(CashTransaction, :count).by(2)

    piggy_bank = source.reload.piggy_bank
    return_transaction = piggy_bank.return_cash_transaction

    expect(return_transaction).to have_attributes(
      user:,
      context: user.main_context,
      user_bank_account: account,
      description: source.description,
      price: 5_000,
      cash_transaction_type: "PiggyBank",
      reference_transactable: source
    )
    expect(return_transaction.categories.pluck(:category_name)).to eq([ "PIGGY BANK RETURN" ])
    expect(return_transaction.entities).to contain_exactly(entity)
    expect(return_transaction.cash_installments.size).to eq(1)
    expect(return_transaction.cash_installments.first).to have_attributes(price: 5_000, paid: false)
  end

  it "groups source, return, and valuation history under one causal operation" do
    source = build_source
    valuation = nil

    Audit::Operation.run(actor: user, context: user.main_context, source: :web) do
      source.save!
      valuation = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account: account,
        investment_type: create(:investment_type, :random),
        description: "Recognized Piggy Bank profit",
        price: 500,
        date: Time.zone.today,
        piggy_bank_return_cash_transaction: source.piggy_bank.return_cash_transaction
      )
    end

    root_version = AuditVersion.find_by!(item: source, event: :create)
    versions = AuditVersion.where(operation_id: root_version.operation_id)
    expect(versions.where(item: source.piggy_bank)).to exist
    expect(versions.where(item: source.piggy_bank.return_cash_transaction)).to exist
    expect(versions.where(item: valuation)).to exist
    expect(versions.where(mutation_source: :piggy_bank_sync)).to exist
    expect(versions.pluck(:owner_id).uniq).to eq([ user.id ])
    expect(versions.pluck(:context_id).uniq).to eq([ user.main_context.id ])
  end

  it "rejects zero and negative projected return values" do
    expect(build_source(return_price: 0)).not_to be_valid
    expect(build_source(return_price: -1)).not_to be_valid
  end

  it "rejects a source that is not negative" do
    source = build_source(price: 5_000)

    expect(source).not_to be_valid
    expect(source.errors.of_kind?(:price, :piggy_bank_source_negative)).to be(true)
  end

  it "rejects a source without exactly one entity" do
    source = build_source
    source.entity_transactions.clear

    expect(source).not_to be_valid
    expect(source.errors.of_kind?(:base, :piggy_bank_requires_one_entity)).to be(true)
  end

  it "synchronizes an unpaid return date and value" do
    source = build_source
    source.save!
    piggy_bank = source.piggy_bank
    new_date = 4.months.from_now.change(sec: 0)

    piggy_bank.update!(return_date: new_date, return_price: 5_500)

    return_transaction = piggy_bank.return_cash_transaction.reload
    expect(return_transaction).to have_attributes(date: new_date, price: 5_500)
    expect(return_transaction.cash_installments.first).to have_attributes(date: new_date, price: 5_500)
  end

  it "preserves a stored return timestamp when its minute-only form value is unchanged" do
    source = build_source
    source.save!
    piggy_bank = source.piggy_bank
    precise_date = Time.zone.local(2026, 11, 30, 9, 15, 59) + 0.999_999
    piggy_bank.update_column(:return_date, precise_date)
    piggy_bank.reload
    persisted_date = piggy_bank.return_date

    piggy_bank.return_date = "2026-11-30T09:15"

    expect(piggy_bank.return_date).to eq(persisted_date)
    expect(piggy_bank).not_to be_changed
  end

  it "blocks source destruction after return history is paid" do
    source = build_source
    source.save!
    source.piggy_bank.return_cash_transaction.cash_installments.first.update!(paid: true)

    expect(source.destroy).to be(false)
    expect(source.errors.of_kind?(:base, :piggy_bank_paid_history_locked)).to be(true)
  end

  it "allows a return value change after partial payment and preserves paid history" do
    source = build_source
    source.save!
    piggy_bank = source.piggy_bank
    return_transaction = piggy_bank.return_cash_transaction
    original_installment = return_transaction.cash_installments.first
    original_installment.update!(price: 1_000, starting_price: 1_000, paid: true)
    Logic::Manipulation::CashInstallment.new(original_installment).split_installment(return_transaction.date, 4_000)

    expect(piggy_bank.update(return_price: 5_500)).to be(true)
    expect(return_transaction.reload.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ 1_000, true ], [ 4_500, false ] ])
  end

  it "rejects a return value below the amount already paid" do
    source = build_source
    source.save!
    piggy_bank = source.piggy_bank
    return_transaction = piggy_bank.return_cash_transaction
    original_installment = return_transaction.cash_installments.first
    original_installment.update!(price: 1_000, starting_price: 1_000, paid: true)
    Logic::Manipulation::CashInstallment.new(original_installment).split_installment(return_transaction.date, 4_000)

    expect(piggy_bank.update(return_price: 500)).to be(false)
    expect(piggy_bank.errors.of_kind?(:return_price, :insufficient_for_paid_history)).to be(true)
    expect(return_transaction.reload.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ 1_000, true ], [ 4_000, false ] ])
  end

  it "continues to block return date changes after return history is paid" do
    source = build_source
    source.save!
    piggy_bank = source.piggy_bank
    piggy_bank.return_cash_transaction.cash_installments.first.update!(paid: true)

    expect(piggy_bank.update(return_date: piggy_bank.return_date + 1.day)).to be(false)
    expect(piggy_bank.errors.of_kind?(:base, :paid_history_locked)).to be(true)
  end

  it "preserves a partial return split when its source is saved later" do
    source = build_source
    source.save!
    return_transaction = source.piggy_bank.return_cash_transaction
    original_installment = return_transaction.cash_installments.first
    payment_date = 1.month.from_now

    original_installment.update!(date: payment_date, month: payment_date.month, year: payment_date.year, price: 1_000, paid: true)
    Logic::Manipulation::CashInstallment.new(original_installment).split_installment(source.piggy_bank.return_date, 4_000)

    source.update!(comment: "Keep the split")

    expect(return_transaction.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ 1_000, true ], [ 4_000, false ] ])
  end

  it "removes an unpaid projection when the source category is removed" do
    source = build_source
    source.save!
    return_id = source.piggy_bank.return_cash_transaction_id
    source.category_transactions.first.mark_for_destruction

    source.save!

    expect(source.reload.piggy_bank).to be_nil
    expect(CashTransaction.exists?(return_id)).to be(false)
  end

  it "duplicates configuration into a fresh source and generated return" do
    source = build_source
    source.save!

    duplicate = CashTransaction.duplicate(source.id)
    duplicate.save!

    expect(duplicate.piggy_bank).to have_attributes(return_date: source.piggy_bank.return_date, return_price: source.piggy_bank.return_price)
    expect(duplicate.piggy_bank.id).not_to eq(source.piggy_bank.id)
    expect(duplicate.piggy_bank.return_cash_transaction_id).not_to eq(source.piggy_bank.return_cash_transaction_id)
    expect(duplicate.piggy_bank.return_cash_transaction.cash_installments).to all(have_attributes(paid: false))
  end

  it "allows grouped source links without deleting a shared return prematurely" do
    first_source = build_source
    first_source.save!
    shared_return = first_source.piggy_bank.return_cash_transaction
    second_source = build_attached_source(shared_return)

    second_source.save!

    expect(shared_return.reload.piggy_bank_return_links.count).to eq(2)
    expect(shared_return).to have_attributes(price: 7_000)
    expect(shared_return.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ 7_000, false ] ])
    expect { second_source.destroy! }.not_to change(CashTransaction.where(id: shared_return.id), :count)
    expect(shared_return.reload.piggy_bank_return_links.count).to eq(1)
    expect(shared_return).to have_attributes(price: 5_000)
    expect(shared_return.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ 5_000, false ] ])
  end

  it "uses persisted contribution baselines and signed valuations for a grouped return" do
    first_source = build_source(price: -5_000, return_price: 5_500)
    first_source.save!
    shared_return = first_source.piggy_bank.return_cash_transaction
    second_source = build_attached_source(shared_return, price: -2_000, return_price: 2_200)
    second_source.save!

    create_valuation(shared_return, price: 800)
    create_valuation(shared_return, price: -300)

    expect(shared_return.piggy_bank_return_links.sum(:return_price)).to eq(7_700)
    expect(shared_return.piggy_bank_investments.sum(:price)).to eq(500)
    expect(shared_return.reload).to have_attributes(price: 8_200, starting_price: 8_200, paid: false)
    expect(shared_return.cash_installments.sole).to have_attributes(price: 8_200, starting_price: 8_200, paid: false)
  end

  it "preserves several paid splits while later gains and losses change only the unpaid remainder" do
    source = build_source
    source.save!
    shared_return = source.piggy_bank.return_cash_transaction
    first_paid = shared_return.cash_installments.sole
    first_paid.update!(price: 1_000, starting_price: 1_000, paid: true)
    Logic::Manipulation::CashInstallment.new(first_paid).split_installment(shared_return.date, 4_000)
    second_paid = shared_return.cash_installments.order(:number).last
    second_paid.update!(price: 1_500, starting_price: 1_500, paid: true)
    Logic::Manipulation::CashInstallment.new(second_paid).split_installment(shared_return.date, 2_500)
    paid_before = shared_return.cash_installments.where(paid: true).order(:number).map do |installment|
      installment.attributes.slice("id", "number", "date", "month", "year", "price", "starting_price", "paid")
    end

    create_valuation(shared_return, price: 800)
    create_valuation(shared_return, price: -300)

    paid_after = shared_return.cash_installments.where(paid: true).order(:number).map do |installment|
      installment.attributes.slice("id", "number", "date", "month", "year", "price", "starting_price", "paid")
    end
    expect(paid_after).to eq(paid_before)
    expect(shared_return.reload).to have_attributes(price: 5_500, starting_price: 5_500, paid: false)
    expect(shared_return.cash_installments.where(paid: true).sum(:price)).to eq(2_500)
    expect(shared_return.cash_installments.where(paid: false).pluck(:price, :paid)).to eq([ [ 3_000, false ] ])
  end

  it "rejects attaching a contribution from another bank entity" do
    first_source = build_source
    first_source.save!
    other_entity = create(:entity, :random, user:)
    second_source = build_attached_source(first_source.piggy_bank.return_cash_transaction, attached_entity: other_entity)

    expect(second_source).not_to be_valid
    expect(second_source.piggy_bank.errors.of_kind?(:return_cash_transaction, :entity_mismatch)).to be(true)
  end

  it "rejects attaching to a fully settled group" do
    first_source = build_source
    first_source.save!
    first_source.cash_installments.update_all(paid: true)
    shared_return = first_source.piggy_bank.return_cash_transaction
    shared_return.cash_installments.update_all(paid: true)
    second_source = build_attached_source(shared_return)

    expect(second_source).not_to be_valid
    expect(second_source.piggy_bank.errors.of_kind?(:return_cash_transaction, :closed)).to be(true)
  end

  it "lists only open return groups for the selected bank entity" do
    open_source = build_source
    open_source.save!
    open_return = open_source.piggy_bank.return_cash_transaction
    closed_source = build_source(price: -3_000, return_price: 3_000)
    closed_source.save!
    closed_source.cash_installments.update_all(paid: true)
    closed_return = closed_source.piggy_bank.return_cash_transaction
    closed_return.cash_installments.update_all(paid: true)

    results = CashTransaction.open_piggy_bank_returns_for(user:, context: user.main_context, entity_id: entity.id)

    expect(results).to include(open_return)
    expect(results).not_to include(closed_return)
  end

  it "adds a contribution to the unpaid remainder of a partially paid group" do
    first_source = build_source
    first_source.save!
    shared_return = first_source.piggy_bank.return_cash_transaction
    original_installment = shared_return.cash_installments.first
    original_installment.update!(price: 1_000, paid: true)
    Logic::Manipulation::CashInstallment.new(original_installment).split_installment(shared_return.date, 4_000)

    build_attached_source(shared_return).save!

    expect(shared_return.reload).to have_attributes(price: 7_000, paid: false)
    expect(shared_return.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ 1_000, true ], [ 6_000, false ] ])
  end

  it "destroys an unpaid generated return with its source" do
    source = build_source
    source.save!
    return_id = source.piggy_bank.return_cash_transaction_id

    expect { source.destroy! }.to change(described_class, :count).by(-1)
    expect(CashTransaction.exists?(return_id)).to be(false)
  end

  describe "IOF availability tracking" do
    it "proposes default iof_exempt_on as source contribution date + 30 calendar days on creation" do
      source = build_source
      source.date = Date.new(2026, 8, 1)
      source.save!

      expect(source.piggy_bank.iof_exempt_on).to eq(Date.new(2026, 8, 31))
      expect(source.piggy_bank.iof_status(Date.new(2026, 8, 15))).to eq(:waiting)
      expect(source.piggy_bank.iof_status(Date.new(2026, 8, 31))).to eq(:available)
      expect(source.piggy_bank.iof_status(Date.new(2026, 9, 5))).to eq(:available)
    end

    it "allows a custom iof_exempt_on date upon creation" do
      source = build_source
      source.date = Date.new(2026, 8, 1)
      source.piggy_bank.iof_exempt_on = Date.new(2026, 8, 20)
      source.save!

      expect(source.piggy_bank.reload.iof_exempt_on).to eq(Date.new(2026, 8, 20))
    end

    it "allows iof_exempt_on to be explicitly set to nil on creation" do
      source = build_source
      source.date = Date.new(2026, 8, 1)
      source.piggy_bank.iof_exempt_on = nil
      source.save!

      expect(source.piggy_bank.reload.iof_exempt_on).to be_nil
      expect(source.piggy_bank.iof_status).to eq(:not_recorded)
      expect(source.piggy_bank.iof_not_recorded?).to be(true)
    end

    it "preserves legacy records with blank iof_exempt_on without forced backfill" do
      source = build_source
      source.save!
      source.piggy_bank.update_columns(iof_exempt_on: nil)

      reloaded = described_class.find(source.piggy_bank.id)
      expect(reloaded.iof_exempt_on).to be_nil
      expect(reloaded.iof_status).to eq(:not_recorded)
      expect(reloaded).to be_valid
    end

    it "maintains independent availability clocks when multiple contributions share one return group" do
      first_source = build_source(price: -2_000, return_price: 2_000)
      first_source.date = Date.new(2026, 7, 1)
      first_source.save!
      shared_return = first_source.piggy_bank.return_cash_transaction

      second_source = build_attached_source(shared_return, price: -3_000, return_price: 3_000)
      second_source.date = Date.new(2026, 8, 1)
      second_source.save!

      first_link = first_source.piggy_bank
      second_link = second_source.piggy_bank

      expect(first_link.iof_exempt_on).to eq(Date.new(2026, 7, 31))
      expect(second_link.iof_exempt_on).to eq(Date.new(2026, 8, 31))

      reference_date = Date.new(2026, 8, 15)
      expect(first_link.iof_status(reference_date)).to eq(:available)
      expect(first_link.iof_exempt?(reference_date)).to be(true)
      expect(second_link.iof_status(reference_date)).to eq(:waiting)
      expect(second_link.iof_waiting?(reference_date)).to be(true)
    end

    it "does not alter return_date, return_price, or installments when iof_exempt_on changes" do
      source = build_source
      source.date = Date.new(2026, 8, 1)
      source.save!
      piggy_bank = source.piggy_bank
      return_transaction = piggy_bank.return_cash_transaction

      original_return_date = return_transaction.date
      original_return_price = return_transaction.price
      original_installments = return_transaction.cash_installments.order(:number).pluck(:id, :date, :price)

      piggy_bank.update!(iof_exempt_on: Date.new(2026, 9, 15))

      return_transaction.reload
      expect(return_transaction.date).to eq(original_return_date)
      expect(return_transaction.price).to eq(original_return_price)
      expect(return_transaction.cash_installments.order(:number).pluck(:id, :date, :price)).to eq(original_installments)
    end

    it "does not alter iof_exempt_on when return_date changes" do
      source = build_source
      source.date = Date.new(2026, 8, 1)
      source.save!
      piggy_bank = source.piggy_bank

      expect do
        piggy_bank.update!(return_date: piggy_bank.return_date + 10.days)
      end.not_to(change { piggy_bank.reload.iof_exempt_on })
    end

    it "blocks iof_exempt_on changes when return history has been paid" do
      source = build_source
      source.date = Date.new(2026, 8, 1)
      source.save!
      piggy_bank = source.piggy_bank
      piggy_bank.return_cash_transaction.cash_installments.first.update!(paid: true)

      expect(piggy_bank.update(iof_exempt_on: Date.new(2026, 9, 15))).to be(false)
      expect(piggy_bank.errors.of_kind?(:base, :paid_history_locked)).to be(true)
    end

    it "creates financial audit version when iof_exempt_on is updated" do
      source = build_source
      source.date = Date.new(2026, 8, 1)
      source.save!
      piggy_bank = source.piggy_bank

      expect do
        Audit::Operation.run(actor: user, context: user.main_context, source: :web) do
          piggy_bank.update!(iof_exempt_on: Date.new(2026, 9, 20))
        end
      end.to change(AuditVersion, :count).by(1)
    end
  end
end

# == Schema Information
#
# Table name: piggy_banks
# Database name: primary
#
#  id                         :bigint           not null, primary key
#  iof_exempt_on              :date             indexed
#  return_date                :datetime         not null
#  return_price               :integer          not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  return_cash_transaction_id :bigint           indexed
#  source_cash_transaction_id :bigint           not null, uniquely indexed
#
# Indexes
#
#  index_piggy_banks_on_iof_exempt_on               (iof_exempt_on)
#  index_piggy_banks_on_return_cash_transaction_id  (return_cash_transaction_id)
#  index_piggy_banks_on_source_cash_transaction_id  (source_cash_transaction_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (return_cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (source_cash_transaction_id => cash_transactions.id)
#
