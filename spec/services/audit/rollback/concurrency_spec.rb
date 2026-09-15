# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Concurrent audit rollback application", :non_transactional do
  self.use_transactional_tests = false

  before { truncate_audit_storage }
  after { truncate_audit_storage }

  it "serializes duplicate requests and returns the first committed result" do
    actor_id = 910_001
    actor = instance_double(User, id: actor_id, admin?: true)
    operation = AuditOperation.create!(source: :web, result: :committed)
    digest = Digest::SHA256.hexdigest("concurrent-rollback")
    token = Audit::Rollback::PreviewToken.generate(operation_id: operation.id, digest:, actor_id:)
    preview = instance_double(Audit::Rollback::Preview, digest:, state: "previewable", confirmation_required?: false)
    compensation_started = Queue.new
    release_compensation = Queue.new

    allow_any_instance_of(Audit::Rollback::Apply).to receive(:locked_preview).and_return(preview)
    allow_any_instance_of(Audit::Rollback::Apply).to receive(:compensate!) do |service|
      compensation_started << true
      wait_for_signal(release_compensation, description: "the audit rollback compensation release")
      rollback_operation = AuditOperation.create!(
        source: :rollback,
        result: :committed,
        actor_id:,
        rollback_of_operation_id: service.operation.id,
        metadata: { "preview_digest" => digest, "idempotency_key" => "concurrent-test" }
      )
      Audit::Rollback::ApplyResult.new(status: "applied", operation: rollback_operation, reason_code: nil, duplicate: false)
    end

    ready = Queue.new
    release = Queue.new
    threads = 2.times.map do |index|
      Thread.new do
        ready << true
        wait_for_signal(release, description: "the audit rollback race release")
        ActiveRecord::Base.connection_pool.with_connection do
          Audit::Rollback::Apply.new(
            operation: AuditOperation.find(operation.id),
            actor:,
            context: nil,
            request_id: "concurrent-#{index}",
            token:
          ).call
        end
      end
    end
    2.times { wait_for_signal(ready, description: "an audit rollback racer to become ready") }
    2.times { release << true }
    wait_for_signal(compensation_started, description: "the first audit rollback compensation to start")
    release_compensation << true
    results = threads.map { |thread| thread_value(thread, description: "an audit rollback racer") }

    expect(results.map(&:status)).to eq(%w[applied applied])
    expect(results.map(&:duplicate)).to contain_exactly(false, true)
    expect(results.map { |result| result.operation.id }.uniq.one?).to be(true)
    expect(AuditOperation.where(source: :rollback, result: :committed, rollback_of_operation_id: operation.id).count).to eq(1)
  end

  def truncate_audit_storage
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE audit_versions, audit_operations RESTART IDENTITY CASCADE")
  end
end
