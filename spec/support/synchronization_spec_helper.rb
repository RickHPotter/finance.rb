# frozen_string_literal: true

require "timeout"

module SynchronizationSpecHelper
  SYNCHRONIZATION_TIMEOUT = 5

  def wait_for_signal(queue, description:, timeout: SYNCHRONIZATION_TIMEOUT)
    Timeout.timeout(timeout) { queue.pop }
  rescue Timeout::Error
    raise Timeout::Error, "Timed out after #{timeout}s waiting for #{description}"
  end

  def thread_value(thread, description:, timeout: SYNCHRONIZATION_TIMEOUT)
    Timeout.timeout(timeout) { thread.value }
  rescue Timeout::Error
    raise Timeout::Error, "Timed out after #{timeout}s waiting for #{description}"
  end

  def join_thread(thread, description:, timeout: SYNCHRONIZATION_TIMEOUT)
    Timeout.timeout(timeout) { thread.join }
  rescue Timeout::Error
    raise Timeout::Error, "Timed out after #{timeout}s joining #{description}"
  end
end

RSpec.configure do |config|
  config.include SynchronizationSpecHelper
end
