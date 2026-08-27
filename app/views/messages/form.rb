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
      class: "flex items-end gap-2 sm:gap-3",
      data: { chat_target: :form }
    ) do |f|
      f.text_area :body,
                  rows: 1,
                  autofocus: true,
                  placeholder: model_attribute(Message, :body_placeholder),
                  class: text_area_class,
                  data: { chat_target: :input, action: "keydown->chat#sendOnEnter" }

      f.submit action_message(:send),
               class: "min-h-14 w-24 shrink-0 rounded-xl border border-emerald-700 bg-emerald-600 px-4 py-3 text-sm font-semibold text-white shadow-sm " \
                      "transition-colors hover:border-emerald-800 hover:bg-emerald-700 focus-visible:outline-none focus-visible:ring-2 " \
                      "focus-visible:ring-emerald-500 " \
                      "focus-visible:ring-offset-2 sm:w-28 dark:border-emerald-400 dark:bg-emerald-500 dark:text-slate-950 dark:hover:border-emerald-300 " \
                      "dark:hover:bg-emerald-400 dark:focus-visible:ring-emerald-400 dark:focus-visible:ring-offset-slate-900"
    end
  end

  private

  def text_area_class
    "min-h-14 flex-1 resize-none rounded-xl border border-slate-300 bg-white px-4 py-3 text-sm leading-6 text-slate-900 shadow-sm outline-none " \
      "transition-colors placeholder:text-slate-400 hover:border-slate-400 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 " \
      "dark:border-slate-600 dark:bg-slate-950 dark:text-slate-100 dark:placeholder:text-slate-500 dark:hover:border-slate-500 " \
      "dark:focus:border-emerald-400 dark:focus:ring-emerald-400/20"
  end
end
