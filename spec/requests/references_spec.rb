# frozen_string_literal: true

require "rails_helper"

RSpec.describe "References", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }
  let(:user_bank_account) { create(:user_bank_account, :random, user:, bank:) }
  let(:user_card) { create(:user_card, :random, user:, card:) }
  let(:reference) { create(:reference, user_card:) }

  before { sign_in user }

  def switch_to_context!(context)
    patch switch_context_path(context)
    expect(response).to redirect_to(root_path)
  end

  describe "[ #index ]" do
    it "returns the card references as json" do
      reference

      get user_card_references_path(user_card)

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).pluck("id")).to include(reference.id)
    end
  end

  describe "[ #edit ]" do
    it "renders successfully" do
      get edit_user_card_reference_path(user_card, reference)

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ #update ]" do
    it "updates the reference and redirects to the user card edit page" do
      patch user_card_reference_path(user_card, reference), params: {
        reference: {
          reference_closing_date: Date.new(2026, 3, 7),
          reference_date: Date.new(2026, 3, 15)
        }
      }

      expect(reference.reload.reference_closing_date).to eq(Date.new(2026, 3, 7))
      expect(reference.reference_date).to eq(Date.new(2026, 3, 15))
      expect(response).to redirect_to(edit_user_card_path(user_card))
    end
  end

  describe "[ #merge ]" do
    it "renders successfully" do
      get merge_user_card_references_path(user_card, id: reference.id)

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ context isolation ]" do
    it "keeps reference reads and updates scoped to the derived context" do
      main_reference = create(
        :reference,
        context: user.main_context,
        user_card:,
        month: 3,
        year: 2026,
        reference_date: Date.new(2026, 3, 15),
        reference_closing_date: Date.new(2026, 3, 7)
      )

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Reference Isolation"
      ).call
      derived_reference = derived_context.references.find_by!(user_card:, month: 3, year: 2026)
      persisted_main_closing_date = main_reference.reload.reference_closing_date
      persisted_main_reference_date = main_reference.reference_date

      switch_to_context!(derived_context)

      get user_card_references_path(user_card)

      returned_ids = JSON.parse(response.body).pluck("id")
      expect(returned_ids).to include(derived_reference.id)
      expect(returned_ids).not_to include(main_reference.id)

      patch user_card_reference_path(user_card, derived_reference), params: {
        reference: {
          reference_closing_date: Date.new(2026, 3, 9),
          reference_date: Date.new(2026, 3, 17)
        }
      }

      expect(derived_reference.reload.reference_closing_date).to eq(Date.new(2026, 3, 9))
      expect(derived_reference.reference_date).to eq(Date.new(2026, 3, 17))
      expect(main_reference.reload.reference_closing_date).to eq(persisted_main_closing_date)
      expect(main_reference.reference_date).to eq(persisted_main_reference_date)
    end

    it "does not allow updating a main-context reference while switched to the derived context" do
      main_reference = create(
        :reference,
        context: user.main_context,
        user_card:,
        month: 3,
        year: 2026,
        reference_date: Date.new(2026, 3, 15),
        reference_closing_date: Date.new(2026, 3, 7)
      )
      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Reference Access Isolation"
      ).call

      switch_to_context!(derived_context)

      patch user_card_reference_path(user_card, main_reference), params: {
        reference: {
          reference_closing_date: Date.new(2026, 3, 9),
          reference_date: Date.new(2026, 3, 17)
        }
      }

      expect(response).to have_http_status(:not_found)
    end

    it "merges references only inside the derived context when unpaid invoices exist there" do
      user_card.update!(due_date_day: 12, days_until_due_date: 5)
      card_payment_category = user.built_in_category("CARD PAYMENT")

      main_march_reference = create(
        :reference,
        context: user.main_context,
        user_card:,
        month: 3,
        year: 2026,
        reference_date: Date.new(2026, 3, 12),
        reference_closing_date: Date.new(2026, 3, 7)
      )
      main_april_reference = create(
        :reference,
        context: user.main_context,
        user_card:,
        month: 4,
        year: 2026,
        reference_date: Date.new(2026, 4, 12),
        reference_closing_date: Date.new(2026, 4, 7)
      )

      march_invoice = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        user_card:,
        description: "March Invoice",
        cash_transaction_type: "CardInstallment",
        date: Date.new(2026, 3, 12),
        month: 3,
        year: 2026,
        price: -1000,
        paid: false
      )
      march_invoice.categories = [ card_payment_category ]
      march_invoice.save!

      april_invoice = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        user_card:,
        description: "April Invoice",
        cash_transaction_type: "CardInstallment",
        date: Date.new(2026, 4, 12),
        month: 4,
        year: 2026,
        price: -1200,
        paid: false
      )
      april_invoice.categories = [ card_payment_category ]
      april_invoice.save!

      march_card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "March Purchase",
        date: Date.new(2026, 2, 10),
        month: 3,
        year: 2026,
        price: -1000,
        paid: false
      )
      march_card_transaction.card_installments.first.update!(cash_transaction: march_invoice, month: 3, year: 2026)

      april_card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "April Purchase",
        date: Date.new(2026, 3, 10),
        month: 4,
        year: 2026,
        price: -1200,
        paid: false
      )
      april_card_transaction.card_installments.first.update!(cash_transaction: april_invoice, month: 4, year: 2026)

      main_april_closing_date = main_april_reference.reference_closing_date
      main_march_invoice_date = user_card.unpaid_invoices(context: user.main_context).find_by!(month: 3, year: 2026).date
      main_april_invoice_date = user_card.unpaid_invoices(context: user.main_context).find_by!(month: 4, year: 2026).date

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Reference Merge Isolation"
      ).call

      switch_to_context!(derived_context)

      derived_march_reference = user_card.references.find_by!(context: derived_context, month: 3, year: 2026)
      derived_april_reference = user_card.references.find_by!(context: derived_context, month: 4, year: 2026)

      post perform_merge_user_card_references_path(user_card), params: {
        source_reference_date: "2026-03",
        target_reference_date: "2026-04"
      }

      expect(response).to redirect_to(edit_user_card_path(user_card))

      expect(Reference.exists?(derived_march_reference.id)).to be(false)
      expect(Reference.exists?(main_march_reference.id)).to be(true)

      derived_april_reference.reload
      expect(derived_april_reference.reference_closing_date).to eq(derived_march_reference.reference_closing_date)
      expect(main_april_reference.reload.reference_closing_date).to eq(main_april_closing_date)

      expect(user_card.unpaid_invoices(context: derived_context).find_by(month: 3, year: 2026)).to be_nil
      expect(user_card.unpaid_invoices(context: derived_context).find_by(month: 4, year: 2026)).to be_present

      expect(user_card.unpaid_invoices(context: user.main_context).find_by!(month: 3, year: 2026).date).to eq(main_march_invoice_date)
      expect(user_card.unpaid_invoices(context: user.main_context).find_by!(month: 4, year: 2026).date).to eq(main_april_invoice_date)

      expect(march_card_transaction.reload.context).to eq(user.main_context)
      expect(april_card_transaction.reload.context).to eq(user.main_context)
    end

    it "updates invoice dates only inside the derived context when editing a reference with unpaid invoices in both contexts" do
      user_card.update!(due_date_day: 12, days_until_due_date: 5)
      card_payment_category = user.built_in_category("CARD PAYMENT")

      main_reference = create(
        :reference,
        context: user.main_context,
        user_card:,
        month: 3,
        year: 2026,
        reference_date: Date.new(2026, 3, 12),
        reference_closing_date: Date.new(2026, 3, 7)
      )

      main_invoice = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        user_card:,
        description: "March Invoice",
        cash_transaction_type: "CardInstallment",
        date: Date.new(2026, 3, 12),
        month: 3,
        year: 2026,
        price: -1000,
        paid: false
      )
      main_invoice.categories = [ card_payment_category ]
      main_invoice.save!

      main_card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "March Purchase",
        date: Date.new(2026, 2, 10),
        month: 3,
        year: 2026,
        price: -1000,
        paid: false
      )
      main_card_transaction.card_installments.first.update!(cash_transaction: main_invoice, month: 3, year: 2026)

      persisted_main_invoice_date = main_invoice.reload.date
      persisted_main_installment_date = main_invoice.cash_installments.first.date
      persisted_main_reference_date = main_reference.reference_date
      persisted_main_reference_closing_date = main_reference.reference_closing_date

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Reference Update Isolation"
      ).call

      derived_reference = user_card.references.find_by!(context: derived_context, month: 3, year: 2026)
      derived_invoice = user_card.unpaid_invoices(context: derived_context).find_by!(month: 3, year: 2026)

      switch_to_context!(derived_context)

      patch user_card_reference_path(user_card, derived_reference), params: {
        reference: {
          reference_closing_date: Date.new(2026, 3, 11),
          reference_date: Date.new(2026, 3, 16)
        }
      }

      expect(response).to redirect_to(edit_user_card_path(user_card))

      expect(derived_reference.reload.reference_date).to eq(Date.new(2026, 3, 16))
      expect(derived_reference.reference_closing_date).to eq(Date.new(2026, 3, 11))
      expect(derived_invoice.reload.date.to_date).to eq(Date.new(2026, 3, 16))
      expect(derived_invoice.cash_installments.first.reload.date.to_date).to eq(Date.new(2026, 3, 16))

      expect(main_reference.reload.reference_date).to eq(persisted_main_reference_date)
      expect(main_reference.reference_closing_date).to eq(persisted_main_reference_closing_date)
      expect(main_invoice.reload.date).to eq(persisted_main_invoice_date)
      expect(main_invoice.cash_installments.first.reload.date).to eq(persisted_main_installment_date)
      expect(main_card_transaction.reload.context).to eq(user.main_context)
    end
  end
end
