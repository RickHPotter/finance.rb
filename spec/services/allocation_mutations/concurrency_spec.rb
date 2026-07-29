# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Concurrent allocation mutation application" do
  self.use_transactional_tests = false

  before { truncate_audit_storage }
  after { truncate_audit_storage }

  it "serializes racing retries and returns the one committed mutation operation" do
    user = create(:user, :random)
    context = user.main_context
    destination = create(:category, user:, category_name: "CONCURRENT DESTINATION")
    owner = create(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: create(:user_bank_account, :random, user:),
      category_transactions: []
    )
    action = AllocationMutations::Action.new(allocation_type: :category, operation: :add, destination_id: destination.id)
    preview = AllocationMutations::BatchPlanner.new(
      actor: user,
      context:,
      owner_type: "CashTransaction",
      owner_ids: [ owner.id ],
      action:
    ).call

    ready = Queue.new
    release = Queue.new
    threads = 2.times.map do |index|
      Thread.new do
        ready << true
        release.pop
        ActiveRecord::Base.connection_pool.with_connection do
          AllocationMutations::Apply.new(
            actor: user,
            context:,
            request_id: "concurrent-allocation-#{index}",
            token: preview.apply_token,
            mode: :strict,
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
    expect(results.map { |result| result.operation.id }.uniq.one?).to be(true)
    expect(owner.reload.categories).to contain_exactly(destination)
    expect(AuditOperation.where(source: :web, result: :committed).count).to eq(1)
    expect(AuditVersion.where(item_type: "CategoryTransaction", item_id: owner.category_transactions.ids).count).to eq(1)
  end

  private

  def truncate_audit_storage
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE audit_versions, audit_operations RESTART IDENTITY CASCADE")
  end
end
