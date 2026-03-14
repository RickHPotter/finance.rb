# frozen_string_literal: true

class BenchmarkingService
  class << self
    def benchmark(label)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      exception = nil
      result = nil

      begin
        result = yield
      rescue StandardError => e
        exception = e
        raise
      ensure
        finish_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        elapsed_ms = ((finish_time - start_time) * 1000).round(2)
        message = build_message(label, elapsed_ms, exception)
        benchmark_logger.info(message)
      end

      result
    end

    private

    def build_message(label, elapsed_ms, exception)
      base = "[BENCHMARK] #{label} took #{elapsed_ms}ms"
      if exception
        base + " (raised #{exception.class}: #{exception.message})"
      else
        base
      end
    end

    def benchmark_logger
      @benchmark_logger ||= begin
        path = Rails.root.join("log", "benchmarks_#{Rails.env}.log")
        logger = ActiveSupport::Logger.new(path, 10, 50 * 1024 * 1024)

        logger.formatter = proc do |severity, time, _progname, msg|
          ts = time.utc.iso8601(6)
          "#{ts} pid=#{Process.pid} #{severity}: #{msg}\n"
        end

        logger.level = Logger::INFO
        logger
      end
    end
  end
end
