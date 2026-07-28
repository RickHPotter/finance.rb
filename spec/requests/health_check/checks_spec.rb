# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health Check details", type: :request do
  let(:admin) { create(:user, :random, admin: true) }

  it "requires authentication and hides details from ordinary users" do
    get healthcheck_check_path("piggy_bank")
    expect(response).to redirect_to(new_user_session_path)

    sign_in create(:user, :random)
    get healthcheck_check_path("piggy_bank")

    expect(response).to have_http_status(:not_found)
  end

  it "returns not found for unknown checks and unrelated connected-user scope" do
    unrelated_user = create(:user, :random)
    sign_in admin

    get healthcheck_check_path("unknown")
    expect(response).to have_http_status(:not_found)

    get healthcheck_check_path("exchange_trio"), params: { connected_user_id: unrelated_user.id }
    expect(response).to have_http_status(:not_found)
  end

  it "evaluates only the selected provider and labels summary time separately from live time" do
    run = create_completed_run(check_key: "piggy_bank")
    page = build_page(records: [], evaluated_at: run.finished_at + 1.minute)
    provider = instance_double(HealthCheck::Checks::PiggyBankDetails, call: page)
    expect(HealthCheck::Checks::PiggyBankDetails).to receive(:new).and_return(provider)
    (HealthCheck::Registry.entries.map(&:details) - [ HealthCheck::Checks::PiggyBankDetails ]).each do |details|
      expect(details).not_to receive(:new)
    end
    sign_in admin

    get healthcheck_check_path("piggy_bank")

    document = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:success)
    expect(document.at_css("#health_check_details_empty")).to be_present
    expect(response.body).to include(I18n.l(run.finished_at, format: :shorter))
    expect(response.body).to include(I18n.l(page.evaluated_at, format: :shorter))
    expect(response.body).to include(I18n.t("health_check.details.live_notice"))
  end

  it "defaults to 25 findings and caps a requested page size at 100" do
    rows = 120.times.map do |index|
      {
        id: index + 1,
        description: "Piggy finding #{index + 1}",
        date: Time.zone.today,
        principal: 100,
        valuation_delta: 0,
        expected_total: 100,
        recorded_total: 50,
        issues: [ "grouped_principal_drift" ]
      }
    end
    audit = instance_double(Logic::PiggyBankAudit, call: rows)
    allow(Logic::PiggyBankAudit).to receive(:new).and_return(audit)
    sign_in admin

    get healthcheck_check_path("piggy_bank")
    default_document = Nokogiri::HTML(response.body)

    get healthcheck_check_path("piggy_bank"), params: { per_page: 500 }
    bounded_document = Nokogiri::HTML(response.body)

    expect(default_document.css("#health_check_findings_piggy_bank article").size).to eq(25)
    expect(bounded_document.css("#health_check_findings_piggy_bank article").size).to eq(100)
  end

  it "retains connected-user scope and filters in pagination links without broadening a context-only provider" do
    connected_user = create(:user, :random)
    admin.entities.create!(entity_name: "CONNECTED", entity_user: connected_user)
    record = {
      id: 91,
      description: "Return finding",
      date: Time.zone.today,
      paid: true,
      price: 100,
      installments_sum: 90,
      exchange_rows_sum: 100,
      source_allocation_rows: [],
      issues: [ "installments_total_mismatch" ],
      health_check: { repairable: false, unavailable_reason: "paid_history" }
    }
    page = HealthCheck::Page.new(
      records: [ record ],
      pagination: { number: 1, per_page: 25, total_count: 30 },
      filters: {
        status_filter: "paid",
        issue_filter: "installments_total_mismatch",
        per_page: 25
      },
      evaluated_at: Time.current
    )
    provider = instance_double(HealthCheck::Checks::ExchangeReturnDetails, call: page)
    expect(HealthCheck::Checks::ExchangeReturnDetails).to receive(:new) do |scope:, filters:|
      expect(scope).to be_all_connections
      expect(filters.to_h).to include(
        "status_filter" => "paid",
        "issue_filter" => "installments_total_mismatch"
      )
      provider
    end
    sign_in admin

    get healthcheck_check_path("exchange_return"), params: {
      connected_user_id: connected_user.id,
      status_filter: "paid",
      issue_filter: "installments_total_mismatch"
    }

    next_link = Nokogiri::HTML(response.body).css("nav a").find { |node| node.text.include?(I18n.t("navigation.next")) }
    document = Nokogiri::HTML(response.body)
    stream_source = document.at_css("turbo-cable-stream-source")
    query = Rack::Utils.parse_nested_query(URI.parse(next_link["href"]).query)
    expect(response.body).to include(connected_user.full_name)
    expect(Turbo::StreamsChannel.verified_stream_name(stream_source["signed-stream-name"])).to eq(
      HealthCheck::Stream.name(user_id: admin.id, context_id: admin.main_context.id, connected_user_id: connected_user.id)
    )
    expect(document.at_css("#health_check_check_exchange_return")).to be_present
    expect(next_link["data-turbo-action"]).to eq("advance")
    expect(next_link["data-turbo-frame"]).to eq("_top")
    expect(query).to include(
      "connected_user_id" => connected_user.id.to_s,
      "status_filter" => "paid",
      "issue_filter" => "installments_total_mismatch",
      "page" => "2"
    )
  end

  it "renders unavailable, failed, and empty detail states distinctly without exposing errors" do
    entry = HealthCheck::Registry.fetch("piggy_bank")
    sign_in admin

    unavailable_provider = instance_double(entry.details)
    allow(unavailable_provider).to receive(:call).and_raise(HealthCheck::Checks::Pending::AdapterUnavailable, "pending_adapter")
    allow(entry.details).to receive(:new).and_return(unavailable_provider)
    get healthcheck_check_path(entry.key)
    expect(Nokogiri::HTML(response.body).at_css("#health_check_details_unavailable")).to be_present

    internal_error = RuntimeError.new("SELECT secret financial payload")
    failed_provider = instance_double(entry.details)
    allow(failed_provider).to receive(:call).and_raise(internal_error)
    allow(entry.details).to receive(:new).and_return(failed_provider)
    allow(Rails.error).to receive(:report)
    get healthcheck_check_path(entry.key)
    expect(Nokogiri::HTML(response.body).at_css("#health_check_details_failed")).to be_present
    expect(response.body).not_to include("SELECT", "secret financial payload")
    expect(Rails.error).to have_received(:report).with(
      internal_error,
      handled: true,
      severity: :error,
      context: hash_including(component: "health_check_details", check_key: entry.key)
    )

    empty_provider = instance_double(entry.details, call: build_page(records: []))
    allow(entry.details).to receive(:new).and_return(empty_provider)
    get healthcheck_check_path(entry.key)
    expect(Nokogiri::HTML(response.body).at_css("#health_check_details_empty")).to be_present
  end

  it "escapes financial descriptions rendered by a live provider" do
    record = {
      id: 45,
      description: "<script>window.stolen = true</script>",
      date: Time.zone.today,
      principal: 100,
      valuation_delta: 0,
      expected_total: 100,
      recorded_total: 50,
      issues: [ "grouped_principal_drift" ],
      health_check: { repairable: false, unavailable_reason: "diagnostic_only" }
    }
    provider = instance_double(HealthCheck::Checks::PiggyBankDetails, call: build_page(records: [ record ]))
    allow(HealthCheck::Checks::PiggyBankDetails).to receive(:new).and_return(provider)
    sign_in admin

    get healthcheck_check_path("piggy_bank")

    document = Nokogiri::HTML(response.body)
    expect(document.css("#health_check_findings_piggy_bank script")).to be_empty
    expect(response.body).to include("&lt;script&gt;window.stolen = true&lt;/script&gt;")
  end

  it "renders the relationship, card, and misplaced-intent detail presenters" do
    sign_in admin
    records_by_key = {
      "exchange_trio" => {
        status: "pending",
        source: { id: 11, type: "CashTransaction", description: "Reference source", date: Time.zone.today },
        message: { id: 21, conversation_id: 31 },
        chain_kind: "shared_return_chain",
        intent: "reimbursement",
        issues: [ "missing_middle" ],
        warnings: [],
        proposed_changes: [],
        health_check: { repairable: false, unavailable_reason: "no_canonical_change" }
      },
      "card_exchange_projection" => {
        id: 12,
        description: "Card projection",
        date: Time.zone.today,
        paid: false,
        card_price: 500,
        expected_total: 500,
        actual_total: 400,
        actual_rows: [],
        issues: [ "payer_exchange_total_mismatch" ],
        warnings: [ "projection_shape_mismatch" ],
        health_check: { repairable: false, unavailable_reason: "diagnostic_only" }
      },
      "misplaced_exchange_intent" => {
        source_id: 13,
        description: "Misplaced source",
        date: Time.zone.today,
        month_year: "07/2026",
        transaction_total: 500,
        entity_return_total: 300,
        delta: 200,
        message_ids: [ 41, 42 ],
        health_check: { repairable: true }
      }
    }

    records_by_key.each do |key, record|
      details = HealthCheck::Registry.fetch(key).details
      allow(details).to receive(:new).and_return(instance_double(details, call: build_page(records: [ record ])))

      get healthcheck_check_path(key)

      expect(response).to have_http_status(:success)
      expect(Nokogiri::HTML(response.body).at_css("#health_check_findings_#{key} article")).to be_present
    end
  end

  it "routes every repairable detail action through preview and exposes no Piggy Bank repair control" do
    repairable_record = {
      source_id: 13,
      description: "Misplaced source",
      date: Time.zone.today,
      month_year: "07/2026",
      transaction_total: 500,
      entity_return_total: 300,
      delta: 200,
      message_ids: [ 41 ],
      health_check: {
        repairable: true,
        preview_actions: [ { finding_id: 13 } ]
      }
    }
    piggy_record = {
      id: 14,
      description: "Piggy finding",
      date: Time.zone.today,
      principal: 100,
      valuation_delta: 10,
      expected_total: 100,
      recorded_total: 90,
      issues: [ "grouped_principal_drift" ],
      health_check: {
        repairable: false,
        unavailable_reason: "diagnostic_only"
      }
    }
    allow(HealthCheck::Checks::MisplacedExchangeIntentDetails).to receive(:new).and_return(
      instance_double(HealthCheck::Checks::MisplacedExchangeIntentDetails, call: build_page(records: [ repairable_record ]))
    )
    allow(HealthCheck::Checks::PiggyBankDetails).to receive(:new).and_return(
      instance_double(HealthCheck::Checks::PiggyBankDetails, call: build_page(records: [ piggy_record ]))
    )
    sign_in admin

    get healthcheck_check_path("misplaced_exchange_intent")
    preview_link = Nokogiri::HTML(response.body).at_css("a[data-turbo-method='post'][href*='/repairs/convert_to_reimbursement/preview']")
    expect(preview_link).to be_present
    expect(preview_link["href"]).to include("finding_id=13")

    get healthcheck_check_path("piggy_bank")
    expect(response.body).not_to include("/repairs/")
  end

  def build_page(records:, evaluated_at: Time.current)
    HealthCheck::Page.new(
      records:,
      pagination: { number: 1, per_page: 25, total_count: records.size },
      filters: {},
      evaluated_at:
    )
  end

  def create_completed_run(check_key:)
    HealthCheckRun.create!(
      user: admin,
      context: admin.main_context,
      check_key:,
      execution_state: "completed",
      outcome: "failing",
      counts: { affected: 1, failures: 1 },
      started_at: 2.minutes.ago,
      finished_at: 1.minute.ago,
      duration_ms: 1_000
    )
  end
end
