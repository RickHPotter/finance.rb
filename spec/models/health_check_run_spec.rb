# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthCheckRun, type: :model do
  let(:user) { create(:user, :random, admin: true) }
  let(:context) { user.main_context }

  def build_run(**attributes)
    described_class.new(
      {
        user:,
        context:,
        check_key: "exchange_trio"
      }.merge(attributes)
    )
  end

  describe "[ persistence contract ]" do
    it "stores a queued latest result with normalized zero counts" do
      run = build_run(counts: { affected: 2 })

      expect(run.save).to be(true)
      expect(run).to have_attributes(
        execution_state: "queued",
        outcome: nil,
        error_code: nil
      )
      expect(run.generation_token).to match(/\A[0-9a-f-]{36}\z/)
      expect(run.counts).to eq(
        "affected" => 2,
        "failures" => 0,
        "warnings" => 0,
        "repairable" => 0,
        "read_only" => 0,
        "unavailable_actions" => 0
      )
    end

    it "uses string-backed execution and outcome enums" do
      started_at = Time.current
      run = build_run(
        execution_state: :completed,
        outcome: :healthy,
        started_at:,
        finished_at: started_at + 0.2.seconds,
        duration_ms: 200
      )

      expect(run).to be_valid
      expect(run.execution_state).to eq("completed")
      expect(run.outcome).to eq("healthy")
    end

    it "rejects unregistered checks and invalid execution vocabularies" do
      run = build_run(check_key: "unknown", execution_state: "other", outcome: "unknown")

      expect(run).not_to be_valid
      expect(run.errors).to include(:check_key, :execution_state, :outcome)
    end

    it "requires completed executions to have an outcome and other states not to have one" do
      completed = build_run(execution_state: :completed)
      running = build_run(execution_state: :running, outcome: :warning)

      expect(completed).not_to be_valid
      expect(completed.errors).to include(:outcome)
      expect(running).not_to be_valid
      expect(running.errors).to include(:outcome)
    end

    it "accepts only bounded nonnegative integer count fields" do
      negative = build_run(counts: { affected: -1 })
      fractional = build_run(counts: { affected: 1.5 })
      unknown = build_run(counts: { record_description: "sensitive" })

      expect(negative).not_to be_valid
      expect(fractional).not_to be_valid
      expect(unknown).not_to be_valid
      expect(negative.errors).to include(:counts)
      expect(fractional.errors).to include(:counts)
      expect(unknown.errors).to include(:counts)
    end

    it "requires a sanitized error code only for unavailable executions" do
      unavailable = build_run(execution_state: :unavailable, error_code: "scope_missing")
      missing = build_run(execution_state: :unavailable)
      leaked = build_run(execution_state: :unavailable, error_code: "SQL failed: SELECT *")
      queued = build_run(error_code: "unexpected_error")

      expect(unavailable).to be_valid
      expect(missing).not_to be_valid
      expect(leaked).not_to be_valid
      expect(queued).not_to be_valid
    end

    it "requires the context to belong to the result owner" do
      other_user = create(:user, :random, admin: true)
      run = build_run(context: other_user.main_context)

      expect(run).not_to be_valid
      expect(run.errors).to include(:context)
    end

    it "rejects timestamps that move backwards" do
      queued_at = Time.current
      run = build_run(queued_at:, started_at: queued_at - 1.second, finished_at: queued_at - 2.seconds)

      expect(run).not_to be_valid
      expect(run.errors).to include(:started_at, :finished_at)
    end
  end

  describe "[ latest scope uniqueness ]" do
    it "keeps one unfiltered result per check, user, and context" do
      build_run.save!
      duplicate = build_run

      expect(duplicate).not_to be_valid
      expect(duplicate.errors).to include(:check_key)
    end

    it "keeps independent latest results for explicitly connected users" do
      first_connected_user = create(:user, :random)
      second_connected_user = create(:user, :random)

      first = build_run(connected_user: first_connected_user)
      second = build_run(connected_user: second_connected_user)

      expect(first.save).to be(true)
      expect(second.save).to be(true)
    end

    it "removes a connected-user result without colliding with the unfiltered scope" do
      connected_user_id = User.insert_all!(
        [
          {
            email: Faker::Internet.unique.email,
            public_id: SecureRandom.uuid,
            created_at: Time.current,
            updated_at: Time.current
          }
        ],
        returning: %w[id]
      ).rows.dig(0, 0)
      connected_user = User.find(connected_user_id)
      unfiltered = build_run.tap(&:save!)
      connected = build_run(connected_user:).tap(&:save!)

      User.where(id: connected_user.id).delete_all

      expect(described_class.where(id: connected.id)).not_to exist
      expect(described_class.where(id: unfiltered.id)).to exist
    end

    it "backs both scope variants with partial unique indexes" do
      indexes = ActiveRecord::Base.connection.indexes(:health_check_runs).index_by(&:name)

      expect(indexes.fetch("idx_health_check_runs_unfiltered_scope")).to have_attributes(
        unique: true,
        where: "(connected_user_id IS NULL)"
      )
      expect(indexes.fetch("idx_health_check_runs_connected_scope")).to have_attributes(
        unique: true,
        where: "(connected_user_id IS NOT NULL)"
      )
    end
  end

  describe "[ operational data boundary ]" do
    it "updates latest execution data without creating financial audit history" do
      run = build_run.tap(&:save!)

      expect do
        Audit::Operation.run(actor: user, context:, source: :background_job) do
          run.update!(counts: { affected: 1 })
        end
      end.not_to change(AuditVersion, :count)
    end
  end
end

# == Schema Information
#
# Table name: health_check_runs
# Database name: primary
#
#  id                :bigint           not null, primary key
#  check_key         :string           not null, uniquely indexed => [user_id, context_id, connected_user_id], uniquely indexed => [user_id, context_id]
#  counts            :jsonb            not null
#  duration_ms       :bigint
#  error_code        :string(100)
#  execution_state   :string           default("queued"), not null, indexed => [updated_at]
#  finished_at       :datetime
#  generation_token  :uuid             not null
#  outcome           :string
#  queued_at         :datetime         not null
#  started_at        :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null, indexed => [execution_state]
#  connected_user_id :bigint           uniquely indexed => [check_key, user_id, context_id], indexed
#  context_id        :bigint           not null, uniquely indexed => [check_key, user_id, connected_user_id], uniquely indexed => [check_key, user_id], indexed
#  user_id           :bigint           not null, uniquely indexed => [check_key, context_id, connected_user_id], uniquely indexed => [check_key, context_id], indexed
#
# Indexes
#
#  idx_health_check_runs_connected_scope                      (check_key,user_id,context_id,connected_user_id) UNIQUE WHERE (connected_user_id IS NOT NULL)
#  idx_health_check_runs_unfiltered_scope                     (check_key,user_id,context_id) UNIQUE WHERE (connected_user_id IS NULL)
#  index_health_check_runs_on_connected_user_id               (connected_user_id)
#  index_health_check_runs_on_context_id                      (context_id)
#  index_health_check_runs_on_execution_state_and_updated_at  (execution_state,updated_at)
#  index_health_check_runs_on_user_id                         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (connected_user_id => users.id) ON DELETE => cascade
#  fk_rails_...  (context_id => contexts.id)
#  fk_rails_...  (user_id => users.id)
#
