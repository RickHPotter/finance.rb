# frozen_string_literal: true

class Views::Subscriptions::New < Views::Base
  attr_reader :current_user, :subscription

  def initialize(current_user:, subscription:)
    @current_user = current_user
    @subscription = subscription
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "flex min-h-[calc(100svh-22rem)] flex-col rounded-lg bg-white p-4 shadow-md") do
        render Views::Subscriptions::Form.new(current_user:, subscription:)
      end
    end
  end
end
