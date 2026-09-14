# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Concurrent Entity merge application" do
  self.use_transactional_tests = false

  before { truncate_audit_storage }
  after { truncate_audit_storage }

  it "serializes racing applies so the exact previewed graph is committed once" do
    user = create(:user, :random)
    context = user.main_context
    source = create(:entity, :random, user:)
    destination = create(:entity, :random, user:)
    transaction = create(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: create(:user_bank_account, :random, user:),
      entity_transactions: []
    )
    transaction.entity_transactions.create!(entity: source, price: 0, price_to_be_returned: 0, is_payer: false)
    preview = EntityMerges::Planner.new(actor: user, context:, source_id: source.id, destination_id: destination.id, mode: :strict).call
    token = EntityMerges::PreviewToken.generate(preview)

    ready = Queue.new
    release = Queue.new
    threads = 2.times.map do |index|
      Thread.new do
        ready << true
        wait_for_signal(release, description: "the entity merge race release")
        ActiveRecord::Base.connection_pool.with_connection do
          EntityMerges::Apply.new(
            actor: user,
            context:,
            source_id: source.id,
            token:,
            confirmed: true,
            mode: :strict,
            request_id: "concurrent-entity-merge-#{index}"
          ).call
        end
      end
    end
    2.times { wait_for_signal(ready, description: "an entity merge racer to become ready") }
    2.times { release << true }
    results = threads.map { |thread| thread_value(thread, description: "an entity merge racer") }

    expect(results.map(&:status)).to contain_exactly(:applied, :rejected)
    expect(results.filter_map(&:reason_code)).to contain_exactly("stale_preview")
    expect(Entity.exists?(source.id)).to be(false)
    expect(transaction.reload.entities).to contain_exactly(destination)
    expect(AuditOperation.where(source: :web, result: :committed).count).to eq(1)
  end

  private

  def truncate_audit_storage
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE audit_versions, audit_operations RESTART IDENTITY CASCADE")
  end
end
