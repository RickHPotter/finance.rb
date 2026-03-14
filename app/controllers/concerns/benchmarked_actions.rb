# frozen_string_literal: true

module BenchmarkedActions
  extend ActiveSupport::Concern

  included do
    around_action :benchmark_crud_actions, only: %i[create update destroy]
  end

  private

  def benchmark_crud_actions(&)
    user_info = defined?(current_user) && current_user ? " user_id=#{current_user.id}" : ""
    label = "#{self.class.name}##{action_name}#{user_info}"

    BenchmarkingService.benchmark(label, &)
  end
end
