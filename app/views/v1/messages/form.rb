# frozen_string_literal: true

class Views::V1::Messages::Form < Views::Base
  attr_reader :conversation

  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::DOMID

  include TranslateHelper

  def initialize(conversation:)
    @conversation = conversation
  end

  def view_template
    form_with(
      model: [ conversation, Message.new ],
      id: dom_id(conversation, :messages),
      class: "flex items-center space-x-2",
      data: { chat_target: :form }
    ) do |f|
      f.text_area :body,
                  rows: 1,
                  autofocus: true,
                  placeholder: model_attribute(Message, :body_placeholder),
                  class: "flex-1 px-4 py-2 resize-none text-gray-800 border border-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500",
                  data: { chat_target: :input, action: "keydown->chat#sendOnEnter" }

      f.submit action_message(:send), class: "bg-green-500 hover:bg-green-600 text-white px-4 py-2.5 rounded-xs font-medium shadow"
    end
  end
end
