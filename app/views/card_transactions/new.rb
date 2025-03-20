# frozen_string_literal: true

module Views
  module CardTransactions
    class New < Views::Base
      include Phlex::Rails::Helpers::TurboFrameTag
      def initialize(current_user:, card_transaction:) # rubocop:disable Lint/MissingSuper
        @current_user = current_user
        @card_transaction = card_transaction
      end

      def view_template
        turbo_frame_tag :center_container do
          div(class: "bg-white p-4 shadow-md rounded-lg") do
            render Form.new(current_user: @current_user, card_transaction: @card_transaction)
          end
        end
      end
    end
  end
end
