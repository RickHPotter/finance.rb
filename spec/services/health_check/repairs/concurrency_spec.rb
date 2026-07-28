# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Concurrent Health Check repair application" do
  self.use_transactional_tests = false

  before { truncate_audit_storage }
  after { truncate_audit_storage }

  it "serializes racing requests and returns the one committed admin repair" do
    admin = create(:user, :random, admin: true)
    scope = HealthCheck::Scope.new(user: admin, context: admin.main_context)
    definition = instance_double(
      HealthCheck::Repairs::Registry::Definition,
      check_key: "exchange_trio",
      key: "canonical_reference"
    )
    preview = build_preview(scope:)

    allow_any_instance_of(HealthCheck::Repairs::Apply).to receive(:locked_preview).and_return(preview)
    allow_any_instance_of(HealthCheck::Repairs::Apply).to receive(:schedule_rerun).and_return(nil)
    allow_any_instance_of(HealthCheck::Repairs::Apply).to receive(:mutate!) do |service, current_preview|
      sleep(0.1)
      AuditOperation.create!(
        source: :admin_repair,
        result: :committed,
        actor_id: admin.id,
        context_id: scope.context.id,
        metadata: service.send(:operation_metadata, current_preview)
      )
    end

    ready = Queue.new
    release = Queue.new
    threads = 2.times.map do |index|
      Thread.new do
        ready << true
        release.pop
        ActiveRecord::Base.connection_pool.with_connection do
          HealthCheck::Repairs::Apply.new(
            definition:,
            scope:,
            request_id: "concurrent-#{index}",
            token: preview.apply_token,
            confirmed: true
          ).call
        end
      end
    end
    2.times { ready.pop }
    2.times { release << true }
    results = threads.map(&:value)

    expect(results.map(&:status)).to eq(%w[applied applied])
    expect(results.map(&:duplicate)).to contain_exactly(false, true)
    expect(results.map(&:operation_id).uniq.one?).to be(true)
    expect(AuditOperation.where(source: :admin_repair, result: :committed).count).to eq(1)
  end

  private

  def build_preview(scope:)
    change = HealthCheck::Repairs::Change.new(
      record_type: "CashTransaction",
      record_id: 41,
      attribute: "description",
      before: "Before",
      after: "After"
    )
    result = HealthCheck::Repairs::Result.new(
      finding_id: 41,
      state: "previewable",
      changes: [ change ]
    )
    HealthCheck::Repairs::Preview.new(
      check_key: "exchange_trio",
      repair_key: "canonical_reference",
      scope:,
      result:
    )
  end

  def truncate_audit_storage
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE audit_versions, audit_operations RESTART IDENTITY CASCADE")
  end
end
