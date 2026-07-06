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
    div(class: "mb-6 w-full") do
      form.text_field :description,
                      class: description_class,
                      autofocus: autofocus_target == :description,
                      autocomplete: :off,
                      data: { controller: "blinking-placeholder", text: model_attribute(transaction, :description) }
    end

    div(class: "mb-6 w-full text-gray-500 dark:text-slate-500") do
      cached_icon :quote
      form.text_area \
        :comment,
        class: comment_input_class,
        disabled: comment_disabled,
        data: { controller: "text-area-autogrow blinking-placeholder", text: model_attribute(transaction, :comment_placeholder) }
    end
  end

  private

  def comment_input_class
    "w-full rounded-lg border border-gray-400 bg-white p-4 ps-9 text-gray-500 shadow-lg focus:ring-transparent focus:outline-none " \
      "dark:border-slate-700 dark:bg-slate-800/60 dark:text-slate-300 dark:italic dark:placeholder:text-slate-500 " \
      "dark:focus:border-sky-500/50 dark:focus:ring-2 dark:focus:ring-sky-500/60 dark:disabled:cursor-not-allowed dark:disabled:opacity-40"
  end
end
