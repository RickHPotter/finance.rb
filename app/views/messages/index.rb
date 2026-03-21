# frozen_string_literal: true

class Views::Messages::Index < Views::Base
  attr_reader :messages

  def initialize(messages:)
    @messages = messages
  end

  def view_template
    messages.each do |message|
      render Views::Messages::Message.new(message:)
    end
  end
end
