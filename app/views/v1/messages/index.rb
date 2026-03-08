# frozen_string_literal: true

class Views::V1::Messages::Index < Views::Base
  attr_reader :messages

  def initialize(messages:)
    @messages = messages
  end

  def view_template
    messages.includes(:superseded_by).each do |message|
      render Views::V1::Messages::Message.new(message:)
    end
  end
end
