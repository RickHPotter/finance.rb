# frozen_string_literal: true

module Views
  module Investments
    class New < Views::Base
      include Phlex::Rails::Helpers::TurboFrameTag

      def initialize(current_user:, investment:)
        @current_user = current_user
        @investment = investment
      end

      def view_template
        turbo_frame_tag :center_container do
          div(class: "bg-white p-4 shadow-md rounded-lg") do
            render Form.new(current_user: @current_user, investment: @investment)
          end
        end
      end
    end
  end
end
