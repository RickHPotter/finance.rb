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
      expect(response.body).not_to include(I18n.t("settings.tabs.exchange_return_audit"))
      expect(response.body).to include(preview_naming_convention_path)
    end

    it "shows the admin audit tabs for admin users" do
      user.update!(admin: true)

      get settings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("settings.tabs.exchange_audit"))
      expect(response.body).to include(I18n.t("settings.tabs.exchange_return_audit"))
      expect(response.body).to include(I18n.t("settings.tabs.card_exchange_projection_audit"))
      expect(response.body).to include(I18n.t("settings.tabs.piggy_bank_audit"))
      expect(response.body).to include(exchange_audit_admin_settings_path)
      expect(response.body).to include(exchange_return_audit_admin_settings_path)
      expect(response.body).to include(card_exchange_projection_audit_admin_settings_path)
      expect(response.body).to include(piggy_bank_audit_admin_settings_path)
    end
  end

  describe "[ GET /admin/settings/exchange_return_audit ]" do
    before { sign_in user }

    it "returns not found for non-admin users" do
      get exchange_return_audit_admin_settings_path, headers: { "Turbo-Frame" => "settings_exchange_return_audit_content" }

      expect(response).to have_http_status(:not_found)
    end

    it "renders successfully for admin users" do
      user.update!(admin: true)

      get exchange_return_audit_admin_settings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("settings.exchange_return_audit.title"))
      expect(response.body).to include(I18n.t("settings.exchange_audit.issue_buckets.title"))
      expect(response.body).to include(exchange_return_audit_issue_bucket_admin_settings_path(issue_code: "installments_total_mismatch"))
    end

    it "renders an issue bucket lazily" do
      user.update!(admin: true)
      expect(Logic::ExchangeReturnAudit).to receive(:new).with(
        current_user: user,
        current_context: user.main_context,
        issue_filter: "installments_total_mismatch",
        status_filter: "pending",
        transaction_ids: nil
      ).and_call_original

      get exchange_return_audit_issue_bucket_admin_settings_path(issue_code: "installments_total_mismatch"),
          headers: { "Turbo-Frame" => "settings_exchange_return_audit_installments_total_mismatch_content" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("settings.exchange_return_audit.issue_codes.installments_total_mismatch"))
    end

    it "renders a fee action for source allocation mismatches with negative calculated fees" do
      user.update!(admin: true)
      audit = instance_double(
        Logic::ExchangeReturnAudit,
        call: [
          {
            id: 10_021,
            description: "CONTA CLARO",
            date: Time.zone.parse("2026-07-09"),
            month_year: "JUL <26>",
            context: { name: user.main_context.name },
            paid: false,
            price: 7_296,
            installments_sum: 7_296,
            exchange_rows_sum: 7_296,
            linked_source_rows: [],
            message_replay_rows: [],
            card_bound_projection_rows: [],
            issues: [ "source_allocation_mismatch" ],
            source_allocation_rows: [
              {
                transactable_type: "CashTransaction",
                transactable_id: 10_021,
                description: "CONTA CLARO",
                transaction_total: 7_296,
                allocation_total: 7_600,
                missing_amount: -304,
                issue_code: "entity_allocation_mismatch",
                friend_notification_intent: "loan",
                entity_transaction_id: 44,
                current_price: 7_600,
                current_return_price: 7_600,
                loan_return_percentage: 100,
                matched_loan_return_percentage: 104.1667.to_d,
                calculated_loan_return_percentage: 100,
                calculated_price: 7_296
              }
            ]
          }
        ]
      )
      allow(Logic::ExchangeReturnAudit).to receive(:new).and_return(audit)

      get exchange_return_audit_issue_bucket_admin_settings_path(issue_code: "source_allocation_mismatch"),
          headers: { "Turbo-Frame" => "settings_exchange_return_audit_source_allocation_mismatch_content" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("settings.exchange_return_audit.actions"))
      expect(response.body).to include(I18n.t("settings.exchange_return_audit.stale_rows.current_value"))
      expect(response.body).to include(I18n.t("settings.exchange_return_audit.stale_rows.corrected_value"))
      expect(response.body).to include(I18n.t("settings.exchange_return_audit.stale_rows.match_return_percentage", value: "R$ 76.00", percentage: "104.1667%"))
      expect(response.body).to include(I18n.t("settings.exchange_return_audit.stale_rows.apply_corrected_value", value: "R$ 72.96", percentage: "100.0%"))
      expect(response.body).to include("loan_return_percentage=104.1667")
      expect(response.body).to include("loan_return_percentage=100")
      expect(response.body).to include("price=7296")
    end

    it "renders a return percentage match action for reimbursement source allocation mismatches" do
      user.update!(admin: true)
      audit = instance_double(
        Logic::ExchangeReturnAudit,
        call: [
          {
            id: 4_873,
            description: "ENTRADA LOTE",
            date: Time.zone.parse("2026-07-09"),
            month_year: "JUL <26>",
            context: { name: user.main_context.name },
            paid: false,
            price: 333_600,
            installments_sum: 333_600,
            exchange_rows_sum: 333_600,
            linked_source_rows: [],
            message_replay_rows: [],
            card_bound_projection_rows: [],
            issues: [ "source_allocation_mismatch" ],
            source_allocation_rows: [
              {
                transactable_type: "CashTransaction",
                transactable_id: 4_864,
                description: "ENTRADA LOTE",
                transaction_total: 667_200,
                allocation_total: 333_600,
                missing_amount: 333_600,
                issue_code: "missing_moi_allocation",
                friend_notification_intent: "reimbursement",
                entity_transaction_id: 13_815,
                current_price: 333_600,
                current_return_price: 333_600,
                loan_return_percentage: 100,
                matched_loan_return_percentage: 50.to_d,
                calculated_loan_return_percentage: 100,
                calculated_price: 667_200
              }
            ]
          }
        ]
      )
      allow(Logic::ExchangeReturnAudit).to receive(:new).and_return(audit)

      get exchange_return_audit_issue_bucket_admin_settings_path(issue_code: "source_allocation_mismatch"),
          headers: { "Turbo-Frame" => "settings_exchange_return_audit_source_allocation_mismatch_content" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("settings.exchange_return_audit.actions"))
      expect(response.body).to include(I18n.t("settings.exchange_return_audit.stale_rows.match_return_percentage", value: "R$ 3,336.00", percentage: "50.0%"))
      expect(response.body).to include("loan_return_percentage=50")
      expect(response.body).not_to include(I18n.t("settings.exchange_return_audit.stale_rows.apply_corrected_value", value: "R$ 6,672.00", percentage: "100.0%"))
    end

    it "stores the supplied source allocation return percentage and corrected prices" do
      user.update!(admin: true)
      source = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: create(:user_bank_account, user:),
        friend_notification_intent: "loan",
        category_transactions_attributes: [ { category_id: user.built_in_category("EXCHANGE").id } ]
      )
      entity_transaction = source.entity_transactions.create!(
        entity: create(:entity, user:),
        is_payer: true,
        price: 7_600,
        price_to_be_returned: 7_600
      )

      patch mark_exchange_return_source_as_fee_admin_settings_path(
        entity_transaction_id: entity_transaction.id,
        issue_code: "source_allocation_mismatch",
        loan_return_percentage: "100",
        price: "7296",
        price_to_be_returned: "7296"
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('id="settings_exchange_return_audit_source_allocation_mismatch_content"')
      expect(entity_transaction.reload).to have_attributes(
        loan_return_percentage: 100.to_d,
        price: 7_296,
        price_to_be_returned: 7_296
      )
    end

    it "stores the supplied source allocation return percentage without changing corrected prices" do
      user.update!(admin: true)
      source = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: create(:user_bank_account, user:),
        friend_notification_intent: "loan",
        category_transactions_attributes: [ { category_id: user.built_in_category("EXCHANGE").id } ]
      )
      entity_transaction = source.entity_transactions.create!(
        entity: create(:entity, user:),
        is_payer: true,
        price: 7_600,
        price_to_be_returned: 7_600
      )

      patch mark_exchange_return_source_as_fee_admin_settings_path(
        entity_transaction_id: entity_transaction.id,
        issue_code: "source_allocation_mismatch",
        loan_return_percentage: "104.1667"
      )

      expect(response).to have_http_status(:success)
      expect(entity_transaction.reload).to have_attributes(
        loan_return_percentage: 104.1667.to_d,
        price: 7_600,
        price_to_be_returned: 7_600
      )
    end

    it "removes only the affected audit card on turbo source allocation actions that resolve the issue" do
      user.update!(admin: true)
      exchange_category = user.built_in_category("EXCHANGE")
      exchange_return_category = user.built_in_category("EXCHANGE RETURN")
      bank_account = create(:user_bank_account, user:)
      entity = create(:entity, user:)

      exchange_return = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        cash_transaction_type: "Exchange",
        description: "Shared return",
        price: 3_336,
        cash_installments: [ build(:cash_installment, number: 1, price: 3_336) ]
      )
      exchange_return.categories = [ exchange_return_category ]
      exchange_return.save!

      source = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        friend_notification_intent: "reimbursement",
        price: -6_672,
        category_transactions_attributes: [ { category_id: exchange_category.id } ]
      )
      source.entity_transactions.destroy_all
      entity_transaction = source.entity_transactions.create!(
        entity:,
        is_payer: true,
        price: 3_336,
        price_to_be_returned: 3_336,
        loan_return_percentage: 100,
        exchanges_count: 1
      )
      Exchange.insert({
                        entity_transaction_id: entity_transaction.id,
                        cash_transaction_id: exchange_return.id,
                        exchange_type: Exchange.exchange_types.fetch(:monetary),
                        bound_type: "standalone",
                        number: 1,
                        price: 3_336,
                        starting_price: 3_336,
                        date: exchange_return.date,
                        month: exchange_return.month,
                        year: exchange_return.year,
                        exchanges_count: 1,
                        created_at: Time.current,
                        updated_at: Time.current
                      })

      patch mark_exchange_return_source_as_fee_admin_settings_path(
        entity_transaction_id: entity_transaction.id,
        issue_code: "source_allocation_mismatch",
        loan_return_percentage: "50"
      ), headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%[action="remove"])
      expect(response.body).to include(%[target="exchange_return_audit_row_#{exchange_return.id}"])
      expect(response.body).not_to include(%[settings_exchange_return_audit_source_allocation_mismatch_content])
      expect(entity_transaction.reload.loan_return_percentage).to eq(50.to_d)
    end
  end

  describe "[ GET /admin/settings/card_exchange_projection_audit ]" do
    before { sign_in user }

    it "returns not found for non-admin users" do
      get card_exchange_projection_audit_admin_settings_path

      expect(response).to have_http_status(:not_found)
    end

    it "renders successfully for admin users" do
      user.update!(admin: true)

      get card_exchange_projection_audit_admin_settings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("settings.card_exchange_projection_audit.title"))
      expect(response.body).to include(I18n.t("settings.card_exchange_projection_audit.filters.pending"))
      expect(response.body).to include(I18n.t("settings.card_exchange_projection_audit.filters.paid"))
    end

    it "round-trips the paid status filter" do
      user.update!(admin: true)

      get card_exchange_projection_audit_admin_settings_path, params: { status_filter: "paid" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('name="status_filter" value="paid"')
    end
  end

  describe "[ GET /admin/settings/piggy_bank_audit ]" do
    before { sign_in user }

    it "returns not found for non-admin users" do
      get piggy_bank_audit_admin_settings_path

      expect(response).to have_http_status(:not_found)
    end

    it "renders the read-only audit for admin users" do
      user.update!(admin: true)

      get piggy_bank_audit_admin_settings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("settings.piggy_bank_audit.title"))
      expect(response.body).to include(I18n.t("settings.piggy_bank_audit.empty"))
    end
  end

  describe "[ GET /admin/settings/exchange_return_audit_misplaced_loans ]" do
    before { sign_in user }

    it "returns not found for non-admin users" do
      get exchange_return_audit_misplaced_loans_admin_settings_path

      expect(response).to have_http_status(:not_found)
    end

    it "renders successfully for admin users" do
      user.update!(admin: true)

      get exchange_return_audit_misplaced_loans_admin_settings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("settings.exchange_audit.issue_buckets.misplaced_loans.title"))
    end

    it "removes only the converted misplaced-loan card on turbo conversion" do
      user.update!(admin: true)
      audit = instance_double(
        Logic::MisplacedLoanExchangeAudit,
        convert!: { source_id: 4_864, updated_message_count: 2 }
      )
      expect(audit).not_to receive(:call)
      allow(Logic::MisplacedLoanExchangeAudit).to receive(:new).with(current_user: user, connected_user_id: nil).and_return(audit)

      patch convert_misplaced_loan_admin_settings_path,
            params: { source_transaction_id: 4_864 },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%[target="settings_exchange_return_audit_misplaced_loans_result"])
      expect(response.body).to include(%[action="remove"])
      expect(response.body).to include(%[target="misplaced_loan_row_4864"])
      expect(response.body).not_to include(%[settings_exchange_return_audit_misplaced_loans_content])
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

    it "offers intent conversion for loan rows missing receiver exchange return" do
      user.update!(admin: true)
      counterpart = create(:user, :random)
      allow(Logic::ExchangeTrioAudit).to receive(:new).with(current_user: user).and_return(
        instance_double(
          Logic::ExchangeTrioAudit,
          call: [
            {
              status: "pending",
              message: { id: 96, conversation_id: 2, actionable: false, action: "edit", scenario_key: nil, body: "Updated transaction" },
              sender: { id: user.id, first_name: user.first_name, email: user.email },
              receiver: { id: counterpart.id, first_name: counterpart.first_name, email: counterpart.email },
              chain_kind: "loan_chain",
              source: { id: 4565, type: "CashTransaction", description: "Source", user_id: user.id, current_reference: nil, expected_reference: nil,
                        reference_status: "ok", category_names: [ "EXCHANGE" ], entity_names: [ "GIGI" ] },
              middle: nil,
              middle_candidates: [],
              middle_candidates_count: 0,
              receiver_candidates: [],
              receiver_candidates_count: 0,
              end_kind: "loan_receiver_combo",
              end_transactions: [ nil, nil ],
              intent: "loan",
              issues: [ "missing_receiver_exchange_return" ],
              proposed_changes: []
            }
          ]
        )
      )

      get exchange_audit_admin_settings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("settings.exchange_audit.convert_loan_intent_button"))
      expect(response.body).to include(convert_exchange_audit_loan_intent_admin_settings_path)
    end

    it "disables intent conversion for loan rows owned by the connected user" do
      user.update!(admin: true)
      counterpart = create(:user, :random)
      allow(Logic::ExchangeTrioAudit).to receive(:new).with(current_user: user).and_return(
        instance_double(
          Logic::ExchangeTrioAudit,
          call: [
            {
              status: "pending",
              message: { id: 96, conversation_id: 2, actionable: false, action: "edit", scenario_key: nil, body: "Updated transaction" },
              sender: { id: counterpart.id, first_name: counterpart.first_name, email: counterpart.email },
              receiver: { id: user.id, first_name: user.first_name, email: user.email },
              chain_kind: "loan_chain",
              source: { id: 4565, type: "CashTransaction", description: "Source", user_id: counterpart.id, current_reference: nil, expected_reference: nil,
                        reference_status: "ok", category_names: [ "EXCHANGE" ], entity_names: [ "GIGI" ] },
              middle: nil,
              middle_candidates: [],
              middle_candidates_count: 0,
              receiver_candidates: [],
              receiver_candidates_count: 0,
              end_kind: "loan_receiver_combo",
              end_transactions: [ nil, nil ],
              intent: "loan",
              issues: [ "missing_receiver_exchange_return" ],
              proposed_changes: []
            }
          ]
        )
      )

      get exchange_audit_admin_settings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("settings.exchange_audit.convert_loan_intent_button"))
      expect(response.body).to include(I18n.t("settings.exchange_audit.convert_loan_intent_owner_only"))
      expect(response.body).not_to include(convert_exchange_audit_loan_intent_admin_settings_path)
    end

    it "renders unavailable feedback when intent conversion cannot be applied" do
      user.update!(admin: true)
      audit = instance_double(
        Logic::MisplacedLoanExchangeAudit,
        convert_exchange_audit_issue!: { status: "unavailable", source_id: 4565, reason: "owner_only", updated_message_count: 0 }
      )
      allow(Logic::MisplacedLoanExchangeAudit).to receive(:new).with(current_user: user, connected_user_id: nil).and_return(audit)
      allow(Logic::ExchangeTrioAudit).to receive(:new).with(current_user: user).and_return(
        instance_double(Logic::ExchangeTrioAudit, call: [])
      )

      patch convert_exchange_audit_loan_intent_admin_settings_path, params: { source_transaction_id: 4565 }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("settings.exchange_audit.intent_conversion_result.unavailable.owner_only", source_id: 4565))
    end

    it "removes only the affected exchange-audit row on turbo intent conversion" do
      user.update!(admin: true)
      audit = instance_double(
        Logic::MisplacedLoanExchangeAudit,
        convert_exchange_audit_issue!: { status: "converted", source_id: 4565, updated_message_count: 2 }
      )
      allow(Logic::MisplacedLoanExchangeAudit).to receive(:new).with(current_user: user, connected_user_id: nil).and_return(audit)
      expect(Logic::ExchangeTrioAudit).not_to receive(:new)

      patch convert_exchange_audit_loan_intent_admin_settings_path,
            params: { source_transaction_id: 4565 },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%[target="settings_exchange_audit_intent_conversion_result"])
      expect(response.body).to include(%[action="remove"])
      expect(response.body).to include(%[target="exchange_audit_row_4565"])
      expect(response.body).not_to include(%[settings_exchange_audit_content])
    end

    it "round-trips middle option selections through the audit route" do
      user.update!(admin: true)
      counterpart = create(:user, :random, first_name: "Rikki", email: "rikki@example.com")
      unrelated_user = create(:user, :random)
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
            receiver: { id: counterpart.id, first_name: counterpart.first_name, email: counterpart.email },
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
              entity_user_ids: [ unrelated_user.id ]
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
                entity_user_ids: [ unrelated_user.id ]
              ),
              transaction_payload.call(
                id: 4570,
                description: "Second middle",
                date: "2026-03-20",
                context_id: 1,
                month_year: "MAR <26>",
                category_names: [ "EXCHANGE RETURN" ],
                entity_names: [ "GABRIEL" ],
                entity_user_ids: [ counterpart.id ]
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

      expect(Logic::ExchangeTrioAudit).to receive(:new).with(current_user: user).and_return(audit_service)

      get exchange_audit_admin_settings_path, params: { middle_overrides: { "4565" => "4570" } }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('name="middle_overrides[4565]"')
      expect(response.body).to include(I18n.t("settings.exchange_audit.apply_button"))
      expect(response.body).to include(I18n.t("settings.exchange_audit.middle_selection.submit"))
      expect(response.body).to include("Second middle")
      expect(response.body).to include("#{I18n.t('settings.exchange_audit.entities')}: GABRIEL")
    end

    it "round-trips receiver-side option selections through the audit route" do
      user.update!(admin: true)
      counterpart = create(:user, :random, first_name: "Gisax", email: "gisax@example.com")
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
            receiver: { id: counterpart.id, first_name: counterpart.first_name, email: counterpart.email },
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
              entity_user_ids: [ counterpart.id ],
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
                entity_user_ids: [ counterpart.id ],
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

      expect(Logic::ExchangeTrioAudit).to receive(:new).with(current_user: user).and_return(audit_service)

      get exchange_audit_admin_settings_path, params: { receiver_overrides: { "4094" => "3702" } }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('name="receiver_overrides[4094]"')
      expect(response.body).to include(I18n.t("settings.exchange_audit.receiver_selection.submit"))
      expect(response.body).to include("TABLET (NIVER GABY)")
      expect(response.body).to include("#{I18n.t('settings.exchange_audit.categories')}: BORROW RETURN, GIFT")
      expect(response.body).to include('<option value="3702" selected>')
      expect(response.body).to include(I18n.t("settings.exchange_audit.apply_button"))
    end

    it "auto-selects the friend-entity middle option when there is a unique receiver match" do
      user.update!(admin: true)
      counterpart = create(:user, :random, first_name: "Rikki", email: "rikki@example.com")
      unrelated_user = create(:user, :random)
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
            receiver: { id: counterpart.id, first_name: counterpart.first_name, email: counterpart.email },
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
              entity_user_ids: [ unrelated_user.id ]
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
                entity_user_ids: [ unrelated_user.id ]
              ),
              transaction_payload.call(
                id: 4570,
                description: "Second middle",
                date: "2026-03-20",
                context_id: 1,
                month_year: "MAR <26>",
                category_names: [ "EXCHANGE RETURN" ],
                entity_names: [ "GABRIEL" ],
                entity_user_ids: [ counterpart.id ]
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

      expect(Logic::ExchangeTrioAudit).to receive(:new).with(current_user: user).and_return(audit_service)

      get exchange_audit_admin_settings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('<option value="4570" selected>')
      expect(response.body).to include("CashTransaction #4570")
    end

    it "applies one selected audit row for admin users" do
      user.update!(admin: true)
      counterpart = create(:user, :random)
      allow(Logic::ExchangeTrioAudit).to receive(:new).with(current_user: user).and_return(
        instance_double(
          Logic::ExchangeTrioAudit,
          call: [
            {
              status: "pending",
              message: { id: 96, conversation_id: 2, actionable: false, action: "edit", scenario_key: nil, body: "Updated transaction",
                         created_at: Time.zone.parse("2026-02-20") },
              sender: { id: user.id, first_name: user.first_name, email: user.email },
              receiver: { id: counterpart.id, first_name: counterpart.first_name, email: counterpart.email },
              chain_kind: "shared_return_chain",
              source: { id: 4565, type: "CashTransaction", description: "Source", user_id: user.id, current_reference: nil, expected_reference: nil,
                        reference_status: "ok" },
              middle: nil,
              middle_candidates: [],
              middle_candidates_count: 0,
              receiver_candidates: [],
              receiver_candidates_count: 0,
              end_kind: "shared_return",
              end_transactions: [ nil ],
              intent: "reimbursement",
              issues: [ "missing_middle" ],
              proposed_changes: []
            }
          ]
        )
      )
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

    it "removes only the affected exchange-audit row on turbo apply when the row becomes done" do
      user.update!(admin: true)
      audit_service = instance_double(
        Logic::ExchangeTrioAudit,
        call: [
          {
            status: "done",
            message: { id: 96, conversation_id: 2, actionable: false, action: "edit", scenario_key: nil, body: "Updated transaction",
                       created_at: Time.zone.parse("2026-02-20") },
            sender: { id: user.id, first_name: user.first_name, email: user.email },
            receiver: { id: 999, first_name: "Gigi", email: "gigi@example.com" },
            chain_kind: "shared_return_chain",
            source: { id: 4565, type: "CashTransaction", description: "Source", user_id: user.id, current_reference: nil, expected_reference: nil,
                      reference_status: "ok" },
            middle: nil,
            middle_candidates: [],
            middle_candidates_count: 0,
            receiver_candidates: [],
            receiver_candidates_count: 0,
            end_kind: "shared_return",
            end_transactions: [ nil ],
            intent: "reimbursement",
            issues: [],
            proposed_changes: []
          }
        ]
      )
      expect(Logic::ExchangeTrioAudit).to receive(:new).once.with(current_user: user).and_return(audit_service)
      expect(Logic::ExchangeChainReferenceRunner).to receive(:new).with(
        source_transaction_ids: [ 4565 ],
        dry_run: false,
        middle_overrides: {},
        receiver_overrides: {}
      ).and_return(
        instance_double(
          Logic::ExchangeChainReferenceRunner,
          call: { updated_row_count: 1, skipped: [], updates: [], candidate_count: 1, supported_count: 1, updated_change_count: 1, skipped_count: 0, dry_run: false }
        )
      )

      patch apply_exchange_audit_admin_settings_path,
            params: { source_transaction_id: 4565 },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%[target="settings_exchange_audit_apply_result"])
      expect(response.body).to include(%[action="remove"])
      expect(response.body).to include(%[target="exchange_audit_row_4565"])
      expect(response.body).not_to include(%[settings_exchange_audit_content])
    end

    it "scopes the audit to one connected user at a time and shows the connection summary" do
      user.update!(admin: true)
      counterpart = create(:user, :random, first_name: "Rikki", email: "rikki@example.com")
      other_counterpart = create(:user, :random, first_name: "Pat", email: "pat@example.com")
      user.entities.create!(entity_name: "LUIS", entity_user: counterpart)
      counterpart.entities.create!(entity_name: "GIGI", entity_user: user)
      user.entities.create!(entity_name: "PATRICIA", entity_user: other_counterpart)
      other_counterpart.entities.create!(entity_name: "GISAX", entity_user: user)
      audit_service = instance_double(
        Logic::ExchangeTrioAudit,
        call: [
          {
            status: "pending",
            message: { id: 96, conversation_id: 2, actionable: false, action: "edit", scenario_key: nil, body: "Updated transaction",
                       created_at: Time.zone.parse("2026-02-20") },
            sender: { id: user.id, first_name: user.first_name, email: user.email },
            receiver: { id: counterpart.id, first_name: counterpart.first_name, email: counterpart.email },
            chain_kind: "shared_return_chain",
            source: { id: 4565, type: "CashTransaction", description: "Source", user_id: user.id, current_reference: nil, expected_reference: nil,
                      reference_status: "ok" },
            middle: nil,
            middle_candidates: [],
            middle_candidates_count: 0,
            receiver_candidates: [],
            receiver_candidates_count: 0,
            end_kind: "shared_return",
            end_transactions: [ nil ],
            intent: "reimbursement",
            issues: %w[missing_middle missing_receiver_reference],
            proposed_changes: []
          },
          {
            status: "done",
            message: { id: 97, conversation_id: 3, actionable: false, action: "edit", scenario_key: nil, body: "Other relationship",
                       created_at: Time.zone.parse("2026-02-10") },
            sender: { id: user.id, first_name: user.first_name, email: user.email },
            receiver: { id: other_counterpart.id, first_name: other_counterpart.first_name, email: other_counterpart.email },
            chain_kind: "shared_return_chain",
            source: { id: 5000, type: "CashTransaction", description: "Other source", user_id: user.id, current_reference: nil, expected_reference: nil,
                      reference_status: "ok" },
            middle: nil,
            middle_candidates: [],
            middle_candidates_count: 0,
            receiver_candidates: [],
            receiver_candidates_count: 0,
            end_kind: "shared_return",
            end_transactions: [ nil ],
            intent: "reimbursement",
            issues: [],
            proposed_changes: []
          }
        ]
      )

      expect(Logic::ExchangeTrioAudit).to receive(:new).with(current_user: user).and_return(audit_service)

      get exchange_audit_admin_settings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("settings.exchange_audit.connection_scope.title"))
      expect(response.body).to include(I18n.t("settings.exchange_audit.connection_summary.title", name: counterpart.first_name))
      expect(response.body).to include("LUIS")
      expect(response.body).to include("GIGI")
      expect(response.body).to include("Updated transaction")
      expect(response.body).not_to include("Other relationship")
    end
  end
end
