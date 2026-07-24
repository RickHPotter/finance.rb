# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health Check dashboard", type: :request do
  let(:admin) { create(:user, :random, admin: true) }

  it "requires authentication" do
    get healthcheck_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "returns not found without disclosing the workspace to an ordinary user" do
    user = create(:user, :random)
    sign_in user

    get healthcheck_path

    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include(I18n.t("health_check.title"))
  end

  it "renders the selected context and every registry entry for an administrator" do
    selected_context = create(:context, user: admin, name: "July forecast")
    create_completed_run(check_key: "exchange_return", outcome: "warning", context: selected_context)
    sign_in admin
    patch switch_context_path(selected_context)

    get healthcheck_path

    document = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:success)
    expect(response.body).to include(admin.full_name, selected_context.name)
    expect(document.css("[id^='health_check_check_']").count).to eq(HealthCheck::Registry.entries.count)
    expect(HealthCheck::Registry.entries.map { |entry| I18n.t(entry.title_key) }).to all(satisfy { |title| response.body.include?(title) })
    expect(document.at_css("#health_check_status_exchange_return").text.strip).to eq(I18n.t("health_check.states.warning"))
    expect(document.css("a[href='#{healthcheck_path}']").text).to include(I18n.t("tabs.health_check"))
    expect(document.css("a[href='#{audit_operations_path}']").text).to include(I18n.t("health_check.history.action"))
    expect(document.css("a[href='#{healthcheck_runs_path}']").text).to include(I18n.t("health_check.actions.run_all"))
    expect(document.css("a[data-turbo-method='post'][href^='/healthcheck/checks/']").count).to eq(HealthCheck::Registry.entries.count)
    expect(document.css("a[href^='/healthcheck/checks/']:not([data-turbo-method])").count).to eq(HealthCheck::Registry.entries.count)
    expect(response.body).not_to include("health_check_findings_")
  end

  it "renders the workspace in the administrator's Portuguese locale" do
    admin.update!(locale: :"pt-BR")
    sign_in admin

    get healthcheck_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include(I18n.t("health_check.title", locale: :"pt-BR"))
    expect(response.body).to include(I18n.t("health_check.checks.piggy_bank.title", locale: :"pt-BR"))
    expect(response.body).to include(I18n.t("health_check.reasons.never_run", locale: :"pt-BR"))
  end

  it "subscribes through a signed stream isolated to the selected scope" do
    sign_in admin

    get healthcheck_path

    source = Nokogiri::HTML(response.body).at_css("turbo-cable-stream-source")
    expect(source).to be_present
    expect(Turbo::StreamsChannel.verified_stream_name(source["signed-stream-name"])).to eq(
      HealthCheck::Stream.name(user_id: admin.id, context_id: admin.main_context.id, connected_user_id: nil)
    )
  end

  it "uses a validated selected connection only for relationship summaries" do
    connected_user = create(:user, :random)
    admin.entities.create!(entity_name: "CONNECTED USER", entity_user: connected_user)
    create_completed_run(check_key: "exchange_return", outcome: "healthy")
    create_completed_run(check_key: "exchange_trio", outcome: "warning", connected_user:)
    sign_in admin

    get healthcheck_path, params: { connected_user_id: connected_user.id }

    document = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:success)
    expect(response.body).to include(connected_user.full_name)
    expect(document.at_css("#health_check_status_exchange_return").text.strip).to eq(I18n.t("health_check.states.healthy"))
    expect(document.at_css("#health_check_status_exchange_trio").text.strip).to eq(I18n.t("health_check.states.warning"))
  end

  it "renders a never-run dashboard without evaluating details or enqueuing work" do
    sign_in admin
    HealthCheck::Registry.entries.each do |entry|
      expect(entry.runner).not_to receive(:new)
      expect(entry.details).not_to receive(:new)
    end

    expect { get healthcheck_path }.not_to have_enqueued_job

    document = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:success)
    expect(document.at_css("#health_check_overview_unavailable").text).to include(HealthCheck::Registry.entries.count.to_s)
    expect(document.css("[id^='health_check_reason_']").map { |node| node.text.strip }).to all(eq(I18n.t("health_check.reasons.never_run")))
    expect(response.body).to include(preview_healthcheck_naming_convention_path)
    expect(response.body).to include("healthcheck_naming_convention_content")
    expect(response.body).not_to include("settings_")
  end

  it "distinguishes a completed healthy result from checks that have never run" do
    sign_in admin
    create_completed_run(check_key: "exchange_trio", outcome: "healthy")

    get healthcheck_path

    document = Nokogiri::HTML(response.body)
    expect(document.at_css("#health_check_overview_healthy").text).to include("1")
    expect(document.at_css("#health_check_overview_unavailable").text).to include("4")
    expect(document.at_css("#health_check_status_exchange_trio").text.strip).to eq(I18n.t("health_check.states.healthy"))
    expect(document.at_css("#health_check_reason_exchange_trio")).to be_nil
    expect(document.at_css("#health_check_reason_exchange_return").text.strip).to eq(I18n.t("health_check.reasons.never_run"))
  end

  it "hides the Health Check navigation entry from an ordinary user" do
    user = create(:user, :random)
    sign_in user

    get contexts_path

    document = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:success)
    expect(document.css("a[href='#{healthcheck_path}']")).to be_empty
  end

  it "keeps ordinary-user audit history access unchanged" do
    user = create(:user, :random)
    sign_in user

    get audit_operations_path

    expect(response).to have_http_status(:success)
  end

  it "does not replace the process-level Rails health endpoint" do
    get rails_health_check_path

    expect(response).to have_http_status(:success)
  end

  def create_completed_run(check_key:, outcome:, context: admin.main_context, connected_user: nil)
    HealthCheckRun.create!(
      user: admin,
      context:,
      connected_user:,
      check_key:,
      execution_state: "completed",
      outcome:,
      counts: {},
      started_at: 1.second.ago,
      finished_at: Time.current,
      duration_ms: 1_000
    )
  end
end
