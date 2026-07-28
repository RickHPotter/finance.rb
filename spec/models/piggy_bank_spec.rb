# frozen_string_literal: true

require "rails_helper"

RSpec.describe PiggyBank, type: :model do
  let(:user) { create(:user, :random) }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }

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

  it "blocks source destruction after return history is paid" do
    source = build_source
    source.save!
    source.piggy_bank.return_cash_transaction.cash_installments.first.update!(paid: true)

    expect(source.destroy).to be(false)
    expect(source.errors.of_kind?(:base, :piggy_bank_paid_history_locked)).to be(true)
  end

  it "blocks direct projection changes after return history is paid" do
    source = build_source
    source.save!
    piggy_bank = source.piggy_bank
    piggy_bank.return_cash_transaction.cash_installments.first.update!(paid: true)

    expect(piggy_bank.update(return_price: 5_500)).to be(false)
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
end

# == Schema Information
#
# Table name: piggy_banks
# Database name: primary
#
#  id                         :bigint           not null, primary key
#  return_date                :datetime         not null
#  return_price               :integer          not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  return_cash_transaction_id :bigint           indexed
#  source_cash_transaction_id :bigint           not null, uniquely indexed
#
# Indexes
#
#  index_piggy_banks_on_return_cash_transaction_id  (return_cash_transaction_id)
#  index_piggy_banks_on_source_cash_transaction_id  (source_cash_transaction_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (return_cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (source_cash_transaction_id => cash_transactions.id)
#
