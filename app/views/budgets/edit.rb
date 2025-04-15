# frozen_string_literal: true

module Views
  module Budgets
    class Edit < Views::Base
      def initialize(current_user:, budget:)
        @current_user = current_user
        @budget = budget
      end

      def view_template
        turbo_frame_tag :center_container do
          div(class: "bg-white p-4 shadow-md rounded-lg") do
            render Form.new(current_user: @current_user, budget: @budget)
          end
        end
      end
    end
  end
end
