# frozen_string_literal: true

module Views
  module V1
    module CashTransactions
      class New < Views::Base
        def initialize(current_user:, cash_transaction:)
          @current_user = current_user
          @cash_transaction = cash_transaction
        end

        def view_template
          turbo_frame_tag :center_container do
            div(class: "bg-white p-4 shadow-md rounded-lg") do
              if @cash_transaction.duplicate
                span(class: "rounded-sm shadow-md bg-orange-200 border border-1 border-orange-400 px-3") { I18n.t("gerund.duplicate") }
              else
                span(class: "rounded-sm shadow-md bg-sky-200 border border-1 border-sky-400 px-3") { I18n.t("gerund.new") }
              end

              render Form.new(current_user: @current_user, cash_transaction: @cash_transaction)
            end
          end
        end
      end
    end
  end
end
