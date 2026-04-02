# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings", type: :request do
  let(:user) { create(:user, :random) }

  describe "[ GET /settings ]" do
    before { sign_in user }

    it "renders successfully" do
      get settings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("settings.tabs.naming"))
      expect(response.body).not_to include(I18n.t("settings.tabs.exchange_audit"))
      expect(response.body).to include(preview_naming_convention_path)
    end

    it "shows the admin exchange audit tab for admin users" do
      user.update!(admin: true)

      get settings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("settings.tabs.exchange_audit"))
      expect(response.body).to include(exchange_audit_admin_settings_path)
    end
  end

  describe "[ GET /admin/settings/exchange_audit ]" do
    before { sign_in user }

    it "returns not found for non-admin users" do
      get exchange_audit_admin_settings_path

      expect(response).to have_http_status(:not_found)
    end

    it "renders successfully for admin users" do
      user.update!(admin: true)

      get exchange_audit_admin_settings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("settings.exchange_audit.title"))
    end

    it "round-trips middle candidate selections through the audit route" do
      user.update!(admin: true)
      transaction_payload = lambda do |id:, description:, date:, context_id:, month_year:,
                                       category_names:, entity_names:, entity_user_ids: [],
                                       expected_reference: nil|
        {
          id:,
          type: "CashTransaction",
          description:,
          date: Time.zone.parse(date),
          price: -1_500,
          context_id:,
          month_year:,
          category_names:,
          entity_names:,
          entity_user_ids:,
          current_reference: nil,
          expected_reference:,
          reference_status: expected_reference.present? ? "mismatch" : "missing"
        }
      end
      audit_service = instance_double(
        Logic::ExchangeTrioAudit,
        call: [
          {
            status: "pending",
            message: { id: 96, conversation_id: 2, actionable: false, action: "edit", scenario_key: nil, body: "Updated transaction" },
            sender: { id: user.id, first_name: user.first_name, email: user.email },
            receiver: { id: 999, first_name: "Rikki", email: "rikki@example.com" },
            chain_kind: "shared_return_chain",
            source: transaction_payload.call(
              id: 4565,
              description: "Source",
              date: "2026-01-20",
              context_id: 1,
              month_year: "JAN <26>",
              category_names: [ "EXCHANGE" ],
              entity_names: [ "RIKKI" ]
            ).merge(reference_status: "ok"),
            middle: transaction_payload.call(
              id: 4568,
              description: "First middle",
              date: "2026-02-20",
              context_id: 1,
              month_year: "FEB <26>",
              category_names: [ "EXCHANGE RETURN" ],
              entity_names: [ "RIKKI" ],
              entity_user_ids: [ 77 ]
            ),
            middle_candidates: [
              transaction_payload.call(
                id: 4568,
                description: "First middle",
                date: "2026-02-20",
                context_id: 1,
                month_year: "FEB <26>",
                category_names: [ "EXCHANGE RETURN" ],
                entity_names: [ "RIKKI" ],
                entity_user_ids: [ 77 ]
              ),
              transaction_payload.call(
                id: 4570,
                description: "Second middle",
                date: "2026-03-20",
                context_id: 1,
                month_year: "MAR <26>",
                category_names: [ "EXCHANGE RETURN" ],
                entity_names: [ "GABRIEL" ],
                entity_user_ids: [ 999 ]
              )
            ],
            middle_candidates_count: 2,
            end_kind: "shared_return",
            end_transactions: [
              transaction_payload.call(
                id: 4579,
                description: "Receiver return",
                date: "2026-01-20",
                context_id: 2,
                month_year: "JAN <26>",
                category_names: [ "BORROW RETURN" ],
                entity_names: [ "GISAX" ],
                expected_reference: { id: 4570, type: "CashTransaction" }
              )
            ],
            intent: "reimbursement",
            issues: [ "receiver_shared_return_reference_mismatch" ],
            proposed_changes: [
              {
                node_key: "receiver_shared_return",
                transaction: { id: 4579, type: "CashTransaction", description: "Receiver return", user_id: 999 },
                from_reference: nil,
                to_reference: { id: 4570, type: "CashTransaction" },
                action: "set_reference"
              }
            ]
          }
        ]
      )

      expect(Logic::ExchangeTrioAudit).to receive(:new).with(no_args).and_return(audit_service)

      get exchange_audit_admin_settings_path, params: { middle_overrides: { "4565" => "4570" } }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('name="middle_overrides[4565]"')
      expect(response.body).to include(I18n.t("settings.exchange_audit.apply_button"))
      expect(response.body).to include(I18n.t("settings.exchange_audit.middle_selection.submit"))
      expect(response.body).to include("Second middle")
      expect(response.body).to include("#{I18n.t('settings.exchange_audit.entities')}: GABRIEL")
    end

    it "round-trips receiver-side candidate selections through the audit route" do
      user.update!(admin: true)
      transaction_payload = lambda do |id:, description:, date:, context_id:, month_year:,
                                       category_names:, entity_names:, entity_user_ids: [],
                                       expected_reference: nil, price: -1_500, installment_signature: [ [ 1, 1_500 ] ]|
        {
          id:,
          type: "CashTransaction",
          description:,
          date: Time.zone.parse(date),
          price:,
          context_id:,
          month_year:,
          category_names:,
          entity_names:,
          entity_user_ids:,
          installment_signature:,
          current_reference: nil,
          expected_reference:,
          reference_status: expected_reference.present? ? "missing" : "ok"
        }
      end
      audit_service = instance_double(
        Logic::ExchangeTrioAudit,
        call: [
          {
            status: "pending",
            message: { id: 133, conversation_id: 2, actionable: false, action: "create", scenario_key: nil, body: "Created transaction" },
            sender: { id: user.id, first_name: user.first_name, email: user.email },
            receiver: { id: 999, first_name: "Gisax", email: "gisax@example.com" },
            chain_kind: "shared_return_chain",
            source: {
              id: 4094,
              type: "CardTransaction",
              description: "Source card",
              user_id: user.id,
              current_reference: nil,
              expected_reference: nil,
              reference_status: "ok"
            },
            middle: transaction_payload.call(
              id: 2152,
              description: "Sender return",
              date: "2025-08-29",
              context_id: 1,
              month_year: "AUG <25>",
              category_names: [ "EXCHANGE RETURN" ],
              entity_names: [ "GIGI" ],
              entity_user_ids: [ 999 ],
              price: 45_000,
              installment_signature: Array.new(12) { |index| [ index + 1, 3_750 ] }
            ).merge(reference_status: "ok", current_reference: { id: 4094, type: "CardTransaction" }, expected_reference: { id: 4094, type: "CardTransaction" }),
            middle_candidates: [
              transaction_payload.call(
                id: 2152,
                description: "Sender return",
                date: "2025-08-29",
                context_id: 1,
                month_year: "AUG <25>",
                category_names: [ "EXCHANGE RETURN" ],
                entity_names: [ "GIGI" ],
                entity_user_ids: [ 999 ],
                price: 45_000,
                installment_signature: Array.new(12) { |index| [ index + 1, 3_750 ] },
                expected_reference: { id: 4094, type: "CardTransaction" }
              )
            ],
            middle_candidates_count: 1,
            receiver_candidates: [
              transaction_payload.call(
                id: 3702,
                description: "TABLET (NIVER GABY)",
                date: "2025-09-01",
                context_id: 2,
                month_year: "SEP <25>",
                category_names: [ "BORROW RETURN", "GIFT" ],
                entity_names: %w[LUIS GABY],
                price: -45_000,
                installment_signature: Array.new(12) { |index| [ index + 1, 3_750 ] }
              )
            ],
            receiver_candidates_count: 1,
            end_kind: "shared_return",
            end_transactions: [ nil ],
            intent: nil,
            issues: [ "missing_receiver_reference" ],
            proposed_changes: []
          }
        ]
      )

      expect(Logic::ExchangeTrioAudit).to receive(:new).with(no_args).and_return(audit_service)

      get exchange_audit_admin_settings_path, params: { receiver_overrides: { "4094" => "3702" } }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('name="receiver_overrides[4094]"')
      expect(response.body).to include(I18n.t("settings.exchange_audit.receiver_selection.submit"))
      expect(response.body).to include("TABLET (NIVER GABY)")
      expect(response.body).to include("#{I18n.t('settings.exchange_audit.categories')}: BORROW RETURN, GIFT")
      expect(response.body).to include('<option value="3702" selected>')
      expect(response.body).to include(I18n.t("settings.exchange_audit.apply_button"))
    end

    it "auto-selects the friend-entity middle candidate when there is a unique receiver match" do
      user.update!(admin: true)
      transaction_payload = lambda do |id:, description:, date:, context_id:, month_year:,
                                       category_names:, entity_names:, entity_user_ids: [],
                                       expected_reference: nil|
        {
          id:,
          type: "CashTransaction",
          description:,
          date: Time.zone.parse(date),
          price: -1_500,
          context_id:,
          month_year:,
          category_names:,
          entity_names:,
          entity_user_ids:,
          current_reference: nil,
          expected_reference:,
          reference_status: expected_reference.present? ? "mismatch" : "missing"
        }
      end
      audit_service = instance_double(
        Logic::ExchangeTrioAudit,
        call: [
          {
            status: "pending",
            message: { id: 96, conversation_id: 2, actionable: false, action: "edit", scenario_key: nil, body: "Updated transaction" },
            sender: { id: user.id, first_name: user.first_name, email: user.email },
            receiver: { id: 999, first_name: "Rikki", email: "rikki@example.com" },
            chain_kind: "shared_return_chain",
            source: transaction_payload.call(
              id: 4565,
              description: "Source",
              date: "2026-01-20",
              context_id: 1,
              month_year: "JAN <26>",
              category_names: [ "EXCHANGE" ],
              entity_names: [ "RIKKI" ]
            ).merge(reference_status: "ok"),
            middle: transaction_payload.call(
              id: 4568,
              description: "First middle",
              date: "2026-02-20",
              context_id: 1,
              month_year: "FEB <26>",
              category_names: [ "EXCHANGE RETURN" ],
              entity_names: [ "OTHER" ],
              entity_user_ids: [ 77 ]
            ),
            middle_candidates: [
              transaction_payload.call(
                id: 4568,
                description: "First middle",
                date: "2026-02-20",
                context_id: 1,
                month_year: "FEB <26>",
                category_names: [ "EXCHANGE RETURN" ],
                entity_names: [ "OTHER" ],
                entity_user_ids: [ 77 ]
              ),
              transaction_payload.call(
                id: 4570,
                description: "Second middle",
                date: "2026-03-20",
                context_id: 1,
                month_year: "MAR <26>",
                category_names: [ "EXCHANGE RETURN" ],
                entity_names: [ "GABRIEL" ],
                entity_user_ids: [ 999 ]
              )
            ],
            middle_candidates_count: 2,
            end_kind: "shared_return",
            end_transactions: [
              transaction_payload.call(
                id: 4579,
                description: "Receiver return",
                date: "2026-01-20",
                context_id: 2,
                month_year: "JAN <26>",
                category_names: [ "BORROW RETURN" ],
                entity_names: [ "GISAX" ],
                expected_reference: { id: 4570, type: "CashTransaction" }
              )
            ],
            intent: "reimbursement",
            issues: %w[multiple_middle_candidates receiver_shared_return_reference_mismatch],
            proposed_changes: [
              {
                node_key: "receiver_shared_return",
                transaction: { id: 4579, type: "CashTransaction", description: "Receiver return", user_id: 999 },
                from_reference: nil,
                to_reference: { id: 4568, type: "CashTransaction" },
                action: "set_reference"
              }
            ]
          }
        ]
      )

      expect(Logic::ExchangeTrioAudit).to receive(:new).with(no_args).and_return(audit_service)

      get exchange_audit_admin_settings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('<option value="4570" selected>')
      expect(response.body).to include("CashTransaction #4570")
    end

    it "applies one selected audit row for admin users" do
      user.update!(admin: true)
      allow(Logic::ExchangeTrioAudit).to receive(:new).and_return(instance_double(Logic::ExchangeTrioAudit, call: []))
      expect(Logic::ExchangeChainReferenceRunner).to receive(:new).with(
        source_transaction_ids: [ 4565 ],
        dry_run: false,
        middle_overrides: { 4565 => 4570 },
        receiver_overrides: { 4565 => 4579 }
      ).and_return(
        instance_double(
          Logic::ExchangeChainReferenceRunner,
          call: { updated_row_count: 1, skipped: [], updates: [], candidate_count: 1, supported_count: 1, updated_change_count: 1, skipped_count: 0, dry_run: false }
        )
      )

      patch apply_exchange_audit_admin_settings_path,
            params: { source_transaction_id: 4565, middle_overrides: { "4565" => "4570" }, receiver_overrides: { "4565" => "4579" } }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("settings.exchange_audit.apply_result.updated", count: 1))
    end
  end
end
