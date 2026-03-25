# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CashInstallments", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:user_bank_account) { create(:user_bank_account, :random, user:, bank:) }
  let(:installment_date) { Time.zone.local(2026, 3, 10, 12, 0, 0) }

  before { sign_in user }

  def switch_to_context!(context)
    patch switch_context_path(context)
    expect(response).to redirect_to(root_path)
  end

  def create_shared_return_pair(sender:, receiver:, sender_context: sender.main_context, receiver_context: receiver.main_context) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    sender.entities.find_or_create_by!(entity_name: receiver.first_name.upcase) { |entity_record| entity_record.entity_user = receiver }
    receiver_counterpart = receiver.entities.find_or_create_by!(entity_name: sender.first_name.upcase) { |entity_record| entity_record.entity_user = sender }
    sender_bank_account = create(:user_bank_account, user: sender, bank: create(:bank, :random))
    receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))

    sender_transaction = create(
      :cash_transaction,
      user: sender,
      context: sender_context,
      user_bank_account: sender_bank_account,
      description: "Shared return",
      date: installment_date,
      month: 3,
      year: 2026,
      price: -1_000,
      category_transactions_attributes: [
        { category_id: sender.built_in_category("EXCHANGE RETURN").id }
      ],
      entity_transactions_attributes: [
        { entity_id: sender.entities.that_are_users.find_by(entity_user: receiver).id, is_payer: false, price: 0, price_to_be_returned: 0 }
      ],
      cash_installments_attributes: [
        { number: 1, date: installment_date, month: 3, year: 2026, price: -1_000, paid: false }
      ]
    )
    sender_transaction.cash_installments.destroy_all
    sender_transaction.cash_installments.create!(number: 1, date: installment_date, month: 3, year: 2026, price: -1_000, paid: false)
    sender_transaction.update_column(:cash_installments_count, 1)

    receiver_transaction = create(
      :cash_transaction,
      user: receiver,
      context: receiver_context,
      user_bank_account: receiver_bank_account,
      reference_transactable: sender_transaction,
      description: "Shared return",
      date: installment_date,
      month: 3,
      year: 2026,
      price: -1_000,
      category_transactions_attributes: [
        { category_id: receiver.built_in_category("BORROW RETURN").id }
      ],
      entity_transactions_attributes: [
        { entity_id: receiver_counterpart.id, is_payer: false, price: 0, price_to_be_returned: 0 }
      ],
      cash_installments_attributes: [
        { number: 1, date: installment_date, month: 3, year: 2026, price: -1_000, paid: false }
      ]
    )
    receiver_transaction.cash_installments.destroy_all
    receiver_transaction.cash_installments.create!(number: 1, date: installment_date, month: 3, year: 2026, price: -1_000, paid: false)
    receiver_transaction.update_column(:cash_installments_count, 1)

    [ sender_transaction, receiver_transaction ]
  end

  describe "[ #pay ]" do
    it "marks the installment as paid and splits the remainder when the paid amount is smaller" do
      cash_transaction = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date,
        month: 3,
        year: 2026,
        price: 1000,
        cash_installments: [
          build(
            :cash_installment,
            number: 1,
            date: installment_date,
            month: 3,
            year: 2026,
            price: 1000,
            paid: false
          )
        ]
      )
      cash_installment = cash_transaction.cash_installments.first

      expect do
        patch pay_cash_installment_path(cash_installment), params: {
          cash_installment: {
            date: Time.zone.local(2026, 3, 12, 12, 0, 0).strftime("%Y-%m-%dT%H:%M"),
            price: 600
          }
        }, headers: turbo_stream_headers
      end.to change(CashInstallment, :count).by(1)

      cash_installment.reload
      remainder = cash_transaction.cash_installments.where.not(id: cash_installment.id).order(:number).last

      expect(cash_installment).to be_paid
      expect(cash_installment.price).to eq(600)
      expect(cash_installment.date.to_date).to eq(Date.new(2026, 3, 12))
      expect(remainder.price).to eq(400)
      expect(remainder.date.to_date).to eq(Date.new(2026, 3, 11))
    end

    it "synchronizes paid state to the counterpart shared return and informs via assistant message" do
      sender = user
      receiver = create(:user, :random)
      sender_transaction, receiver_transaction = create_shared_return_pair(sender:, receiver:)

      patch pay_cash_installment_path(sender_transaction.cash_installments.first), params: {
        cash_installment: {
          date: installment_date.strftime("%Y-%m-%dT%H:%M"),
          price: -1_000
        }
      }, headers: turbo_stream_headers

      conversation = Conversation.for_users([ sender.id, receiver.id ]).assistant.order(:id).last
      message = conversation.messages.order(:id).last

      expect(response).to have_http_status(:ok)
      expect(sender_transaction.cash_installments.first.reload).to be_paid
      expect(receiver_transaction.cash_installments.first.reload).to be_paid
      expect(message.body).to eq("notification:paid_state")
      expect(JSON.parse(message.headers)).to include(
        "version" => "message_paid_state_v1",
        "event" => include("action" => "paid")
      )
    end

    it "synchronizes paid state inside the matching derived scenario only" do
      sender = user
      receiver = create(:user, :random)
      sender_derived = Logic::ContextCloneService.new(source_context: sender.main_context, name: "Sender Shared Paid State", scenario_key: "shared-paid-state").call
      receiver_derived = Logic::ContextCloneService.new(source_context: receiver.main_context, name: "Receiver Shared Paid State",
                                                        scenario_key: "shared-paid-state").call

      sender_transaction, receiver_transaction = create_shared_return_pair(
        sender:,
        receiver:,
        sender_context: sender_derived,
        receiver_context: receiver_derived
      )

      main_sender_transaction, main_receiver_transaction = create_shared_return_pair(sender:, receiver:)

      switch_to_context!(sender_derived)

      patch pay_cash_installment_path(sender_transaction.cash_installments.first), params: {
        cash_installment: {
          date: installment_date.strftime("%Y-%m-%dT%H:%M"),
          price: -1_000
        }
      }, headers: turbo_stream_headers

      conversation = Conversation.for_users([ sender.id, receiver.id ]).assistant.for_scenario(sender_derived.scenario_key).order(:id).last
      message = conversation.messages.order(:id).last

      expect(response).to have_http_status(:ok)
      expect(sender_transaction.cash_installments.first.reload).to be_paid
      expect(receiver_transaction.cash_installments.first.reload).to be_paid
      expect(main_sender_transaction.cash_installments.first.reload).not_to be_paid
      expect(main_receiver_transaction.cash_installments.first.reload).not_to be_paid
      expect(conversation).to be_present
      expect(message.body).to eq("notification:paid_state")
      expect(message.conversation.scenario_key).to eq(sender_derived.scenario_key)
      expect(JSON.parse(message.headers)).to include(
        "version" => "message_paid_state_v1",
        "event" => include("action" => "paid")
      )
    end

    it "fails clearly when the counterpart shared return cannot be resolved" do
      sender = user
      receiver = create(:user, :random)
      sender_transaction, receiver_transaction = create_shared_return_pair(sender:, receiver:)
      sender.entities.that_are_users.find_by!(entity_user: receiver).update_column(:entity_user_id, nil)

      patch pay_cash_installment_path(sender_transaction.cash_installments.first), params: {
        cash_installment: {
          date: installment_date.strftime("%Y-%m-%dT%H:%M"),
          price: -1_000
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(sender_transaction.cash_installments.first.reload).not_to be_paid
      expect(receiver_transaction.cash_installments.first.reload).not_to be_paid
      expect(response.body).to include(I18n.t("activerecord.errors.models.cash_installment.attributes.base.counterpart_paid_state_sync_missing"))
      expect(Message.where(body: "notification:paid_state")).to be_empty
    end
  end

  describe "[ #pay_multiple ]" do
    it "marks all selected installments as paid with the chosen date" do
      first = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 500, paid: false) ]
      ).cash_installments.first
      second = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date + 1.day,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date + 1.day, month: 3, year: 2026, price: 700, paid: false) ]
      ).cash_installments.first

      post pay_multiple_cash_installments_path, params: {
        ids: [ first.id, second.id ],
        cash_installment: {
          date: Time.zone.local(2026, 3, 20, 10, 0, 0).strftime("%Y-%m-%dT%H:%M")
        }
      }, headers: turbo_stream_headers

      expect(first.reload).to be_paid
      expect(second.reload).to be_paid
      expect(first.date.to_date).to eq(Date.new(2026, 3, 20))
      expect(second.date.to_date).to eq(Date.new(2026, 3, 20))
    end
  end

  describe "[ #transfer_multiple ]" do
    it "moves all selected installments to the chosen reference month" do
      first = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 500, paid: false) ]
      ).cash_installments.first
      second = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date + 1.day,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date + 1.day, month: 3, year: 2026, price: 700, paid: false) ]
      ).cash_installments.first

      post transfer_multiple_cash_installments_path, params: {
        ids: [ first.id, second.id ],
        reference_date: "2026-05",
        cash_installment: {
          date: Time.zone.local(2026, 5, 2, 9, 0, 0).strftime("%Y-%m-%dT%H:%M")
        }
      }, headers: turbo_stream_headers

      expect(first.reload.month).to eq(5)
      expect(first.year).to eq(2026)
      expect(second.reload.month).to eq(5)
      expect(second.year).to eq(2026)
      expect(first.date.to_date).to eq(Date.new(2026, 5, 2))
      expect(second.date.to_date).to eq(Date.new(2026, 5, 2))
      expect(first).not_to be_paid
      expect(second).not_to be_paid
    end
  end

  describe "[ context isolation ]" do
    it "keeps pay changes inside the derived context" do
      main_cash_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main installment isolation",
        date: installment_date,
        month: 3,
        year: 2026,
        price: 1000,
        cash_installments: [
          build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 1000, paid: false)
        ]
      )
      main_installment = main_cash_transaction.cash_installments.first

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Cash Installment Isolation"
      ).call
      derived_installment = derived_context.cash_installments.find_by!(
        cash_transaction: derived_context.cash_transactions.find_by!(description: main_cash_transaction.description),
        number: 1
      )

      switch_to_context!(derived_context)

      patch pay_cash_installment_path(derived_installment), params: {
        cash_installment: {
          date: Time.zone.local(2026, 3, 12, 12, 0, 0).strftime("%Y-%m-%dT%H:%M"),
          price: 600
        }
      }, headers: turbo_stream_headers

      expect(derived_installment.reload).to be_paid
      expect(derived_installment.price).to eq(600)
      expect(main_installment.reload).not_to be_paid
      expect(main_installment.price).to eq(1000)
    end

    it "keeps pay_multiple changes inside the derived context" do
      first_main = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main bulk installment one",
        date: installment_date,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 500, paid: false) ]
      ).cash_installments.first
      second_main = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main bulk installment two",
        date: installment_date + 1.day,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date + 1.day, month: 3, year: 2026, price: 700, paid: false) ]
      ).cash_installments.first

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Cash Installment Bulk Isolation"
      ).call
      first_derived = derived_context.cash_transactions.find_by!(description: "Main bulk installment one").cash_installments.first
      second_derived = derived_context.cash_transactions.find_by!(description: "Main bulk installment two").cash_installments.first

      switch_to_context!(derived_context)

      post pay_multiple_cash_installments_path, params: {
        ids: [ first_derived.id, second_derived.id ],
        cash_installment: {
          date: Time.zone.local(2026, 3, 20, 10, 0, 0).strftime("%Y-%m-%dT%H:%M")
        }
      }, headers: turbo_stream_headers

      expect(first_derived.reload).to be_paid
      expect(second_derived.reload).to be_paid
      expect(first_main.reload).not_to be_paid
      expect(second_main.reload).not_to be_paid
    end

    it "keeps transfer_multiple changes inside the derived context" do
      first_main = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main transfer installment one",
        date: installment_date,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 500, paid: false) ]
      ).cash_installments.first
      second_main = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main transfer installment two",
        date: installment_date + 1.day,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date + 1.day, month: 3, year: 2026, price: 700, paid: false) ]
      ).cash_installments.first

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Cash Installment Transfer Isolation"
      ).call
      first_derived = derived_context.cash_transactions.find_by!(description: "Main transfer installment one").cash_installments.first
      second_derived = derived_context.cash_transactions.find_by!(description: "Main transfer installment two").cash_installments.first

      switch_to_context!(derived_context)

      post transfer_multiple_cash_installments_path, params: {
        ids: [ first_derived.id, second_derived.id ],
        reference_date: "2026-05",
        cash_installment: {
          date: Time.zone.local(2026, 5, 2, 9, 0, 0).strftime("%Y-%m-%dT%H:%M")
        }
      }, headers: turbo_stream_headers

      expect(first_derived.reload.month).to eq(5)
      expect(second_derived.reload.month).to eq(5)
      expect(first_main.reload.month).to eq(3)
      expect(second_main.reload.month).to eq(3)
    end

    it "does not allow paying a main-context installment while switched to the derived context" do
      main_cash_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main inaccessible installment",
        date: installment_date,
        month: 3,
        year: 2026,
        price: 1000,
        cash_installments: [
          build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 1000, paid: false)
        ]
      )
      main_installment = main_cash_transaction.cash_installments.first

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Cash Installment Access Isolation"
      ).call

      switch_to_context!(derived_context)

      patch pay_cash_installment_path(main_installment), params: {
        cash_installment: {
          date: Time.zone.local(2026, 3, 12, 12, 0, 0).strftime("%Y-%m-%dT%H:%M"),
          price: 600
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
