# frozen_string_literal: true

class Views::Messages::Form < Views::Base
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
      class: "flex items-end gap-3",
      data: { chat_target: :form }
    ) do |f|
      f.text_area :body,
                  rows: 1,
                  autofocus: true,
                  placeholder: model_attribute(Message, :body_placeholder),
                  class: text_area_class,
                  data: { chat_target: :input, action: "keydown->chat#sendOnEnter" }

      f.submit action_message(:send),
               class: "min-h-[3.5rem] w-28 shrink-0 rounded-2xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-white shadow-sm transition hover:bg-emerald-700"
    end
  end

  private

  def text_area_class
    "min-h-[3.5rem] flex-1 resize-none rounded-2xl border border-stone-300 " \
      "bg-white px-4 py-3 text-gray-800 shadow-sm focus:border-stone-500 " \
      "focus:outline-none focus:ring-2 focus:ring-stone-200"
  end
end
