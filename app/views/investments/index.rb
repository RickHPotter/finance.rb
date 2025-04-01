# frozen_string_literal: true

module Views
  module Investments
    class Index < Views::Base
      attr_reader :current_user, :investments

      include Phlex::Rails::Helpers::TurboFrameTag

      def initialize(current_user:, investments:)
        @current_user = current_user
        @investments = investments
      end

      def view_template
        turbo_frame_tag :center_container do
          @investments.each do |investment|
            div(class: "investment", data: { id: investment.id }) do
              h1 { investment.attributes["description"] }

              span(class: "investment-month-year", data: { entity_transaction_target: "monthYearInvestment" }) do
                investment.month_year
              end

              span(class: "investment-month-year", data: { entity_transaction_target: "monthYearInvestment" }) do
                investment.price
              end
            end
          end
        end
      end
    end
  end
end
