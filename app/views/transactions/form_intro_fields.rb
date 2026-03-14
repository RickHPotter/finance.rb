# frozen_string_literal: true

class Views::Transactions::FormIntroFields < Views::Base
  include CacheHelper
  include ComponentsHelper
  include TranslateHelper

  attr_reader :form, :transaction, :description_class, :comment_disabled, :autofocus_target

  def initialize(form:, transaction:, description_class:, comment_disabled: false, autofocus_target: nil)
    @form = form
    @transaction = transaction
    @description_class = description_class
    @comment_disabled = comment_disabled
    @autofocus_target = autofocus_target
  end

  def view_template
    div(class: "w-full mb-6") do
      form.text_field :description,
                      class: description_class,
                      autofocus: autofocus_target == :description,
                      autocomplete: :off,
                      data: { controller: "blinking-placeholder", text: model_attribute(transaction, :description) }
    end

    div(class: "w-full mb-6") do
      cached_icon :quote
      form.text_area \
        :comment,
        class: "text-gray-500 p-4 ps-9 w-full border-1 border-gray-400 shadow-lg rounded-lg focus:ring-transparent focus:outline-none",
        disabled: comment_disabled,
        data: { controller: "text-area-autogrow blinking-placeholder", text: model_attribute(transaction, :comment_placeholder) }
    end
  end
end
