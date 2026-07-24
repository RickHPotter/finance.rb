# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Concurrent Health Check reruns" do
  self.use_transactional_tests = false

  let!(:admin) { create(:user, :random, admin: true) }

  before do
    HealthCheckRun.delete_all
    clear_enqueued_jobs
    allow(HealthCheck::Broadcaster).to receive(:call)
  end

  after do
    HealthCheckRun.delete_all
    clear_enqueued_jobs
    admin.entities.update_all(built_in: false)
    admin.destroy!
  end

  it "persists and enqueues only one generation when two requests race" do
    entry = HealthCheck::Registry.fetch("exchange_return")
    ready = Queue.new
    release = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          user = User.find(admin.id)
          scope = HealthCheck::Scope.new(user:, context: user.main_context)
          ready << true
          release.pop
          HealthCheck::RunCoordinator.new(scope:).call(entries: [ entry ]).first
        end
      end
    end
    2.times { ready.pop }
    2.times { release << true }
    schedules = threads.map(&:value)

    expect(schedules.map(&:reason)).to contain_exactly("queued", "already_running")
    expect(schedules.count(&:enqueued?)).to eq(1)
    expect(HealthCheckRun.where(user_id: admin.id, check_key: entry.key).count).to eq(1)
    expect(enqueued_jobs.count { |job| job[:job] == HealthCheck::RunJob }).to eq(1)
  end
end
