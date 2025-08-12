# frozen_string_literal: true

module Views
  module CashTransactions
    class New < Views::Base
      def initialize(current_user:, cash_transaction:)
        @current_user = current_user
        @cash_transaction = cash_transaction
      end

      def view_template
        turbo_frame_tag :center_container do
          div(class: "bg-white p-4 shadow-md rounded-lg") do
            render Form.new(current_user: @current_user, cash_transaction: @cash_transaction)
          end
        end
      end
    end
  end
end
