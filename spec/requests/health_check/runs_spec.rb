# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health Check runs", type: :request do
  let(:admin) { create(:user, :random, admin: true) }

  before do
    allow(HealthCheck::Broadcaster).to receive(:call)
  end

  it "requires authentication for run-all and per-check requests" do
    post healthcheck_runs_path
    expect(response).to redirect_to(new_user_session_path)

    post healthcheck_check_run_path("exchange_return")
    expect(response).to redirect_to(new_user_session_path)
  end

  it "returns not found for ordinary users without enqueuing work" do
    user = create(:user, :random)
    sign_in user

    expect { post healthcheck_runs_path }.not_to have_enqueued_job(HealthCheck::RunJob)
    expect(response).to have_http_status(:not_found)

    expect { post healthcheck_check_run_path("exchange_return") }.not_to have_enqueued_job(HealthCheck::RunJob)
    expect(response).to have_http_status(:not_found)
  end

  it "queues one independent job per eligible registry check without evaluating adapters" do
    sign_in admin
    expect(HealthCheck::Checks::Pending).not_to receive(:new)

    expect do
      post healthcheck_runs_path
    end.to have_enqueued_job(HealthCheck::RunJob).exactly(HealthCheck::Registry.entries.count).times

    expect(response).to redirect_to(healthcheck_path)
    expect(response).to have_http_status(:see_other)
    expect(admin.health_check_runs.pluck(:check_key)).to contain_exactly(*HealthCheck::Registry.keys)

    follow_redirect!
    document = Nokogiri::HTML(response.body)
    expect(document.css("[id^='health_check_status_']").map { |node| node.text.strip }).to all(eq(I18n.t("health_check.states.running")))
  end

  it "queues only the selected check" do
    sign_in admin

    expect do
      post healthcheck_check_run_path("piggy_bank")
    end.to have_enqueued_job(HealthCheck::RunJob).once

    expect(response).to have_http_status(:see_other)
    expect(admin.health_check_runs.pluck(:check_key)).to eq([ "piggy_bank" ])
  end

  it "does not enqueue a duplicate generation while a check is queued" do
    sign_in admin
    post healthcheck_check_run_path("exchange_return")
    run = admin.health_check_runs.find_by!(check_key: "exchange_return")
    token = run.generation_token
    clear_enqueued_jobs

    expect do
      post healthcheck_check_run_path("exchange_return")
    end.not_to have_enqueued_job(HealthCheck::RunJob)

    expect(run.reload.generation_token).to eq(token)
    expect(admin.health_check_runs.where(check_key: "exchange_return").count).to eq(1)
  end

  it "returns not found for an unknown check" do
    sign_in admin

    expect { post healthcheck_check_run_path("unknown") }.not_to have_enqueued_job(HealthCheck::RunJob)

    expect(response).to have_http_status(:not_found)
    expect(admin.health_check_runs).to be_empty
  end

  it "returns not found for an unrelated connected-user scope" do
    unrelated_user = create(:user, :random)
    sign_in admin

    expect do
      post healthcheck_check_run_path("exchange_trio"), params: { connected_user_id: unrelated_user.id }
    end.not_to have_enqueued_job(HealthCheck::RunJob)

    expect(response).to have_http_status(:not_found)
    expect(admin.health_check_runs).to be_empty
  end

  it "persists a selected connection only for relationship checks" do
    connected_user = create(:user, :random)
    admin.entities.create!(entity_name: "CONNECTED USER", entity_user: connected_user)
    sign_in admin

    post healthcheck_check_run_path("exchange_trio"), params: { connected_user_id: connected_user.id }
    post healthcheck_check_run_path("exchange_return"), params: { connected_user_id: connected_user.id }

    expect(admin.health_check_runs.find_by!(check_key: "exchange_trio").connected_user_id).to eq(connected_user.id)
    expect(admin.health_check_runs.find_by!(check_key: "exchange_return").connected_user_id).to be_nil
  end

  it "lets every queued job reach its own unavailable result independently" do
    sign_in admin

    perform_enqueued_jobs do
      post healthcheck_runs_path
    end

    expect(response).to have_http_status(:see_other)
    expect(admin.health_check_runs.count).to eq(HealthCheck::Registry.entries.count)
    expect(admin.health_check_runs.pluck(:execution_state).uniq).to eq([ "unavailable" ])
    expect(admin.health_check_runs.pluck(:error_code).uniq).to eq([ "adapter_unavailable" ])
  end
end
