# frozen_string_literal: true

class Views::Contexts::New < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  include ComponentsHelper
  include TranslateHelper

  attr_reader :form_context, :source_context

  def initialize(context:, source_context:)
    @form_context = context
    @source_context = source_context
  end

  def view_template
    turbo_frame_tag :context_overlay do
      div(class: "fixed inset-0 z-40 flex items-center justify-center bg-black/40 p-4") do
        div(class: "w-full max-w-lg rounded-lg border border-slate-200 bg-white p-6 shadow-xl") do
          div(class: "mb-5") do
            div(class: "min-w-0 text-left") do
              div(class: "flex justify-center") do
                div(class: form_badge_class(:new)) { I18n.t("gerund.new") }
              end
              p(class: "mt-3 text-left text-sm text-stone-500 wrap-break-words") { I18n.t("contexts.new.subtitle", source_name: source_context.name) }
            end
          end

          form_with(model: form_context, url: contexts_path, method: :post, class: "space-y-4") do |form|
            form.hidden_field :source_context_id, value: source_context.id

            div(class: "w-full") do
              form.text_field(
                :name,
                class: outdoor_input_class,
                autofocus: true,
                autocomplete: :off,
                data: { controller: "blinking-placeholder", text: I18n.t("contexts.form.name") }
              )
            end

            div do
              form.label :description, I18n.t("contexts.form.description"), class: "font-poetsen-one text-medium font-bold text-gray-500"
              form.text_area(
                :description,
                rows: 4,
                class: "mt-2 w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-black shadow-sm " \
                       "outline-hidden transition focus:border-sky-400 focus:ring-1 focus:ring-sky-400"
              )
            end

            div(class: "grid grid-cols-1 items-center justify-items-center gap-2 pt-2 sm:grid-flow-col sm:auto-cols-fr") do
              Button(type: :submit, class: "w-40 #{submit_button_class(:new)}") { action_message(:submit) }

              link_to(
                dismiss_contexts_path,
                class: "inline-flex min-w-40 items-center justify-center rounded-md border border-slate-300 bg-white px-4 py-2 " \
                       "text-sm font-semibold text-slate-700 shadow-sm transition hover:border-slate-400 hover:bg-slate-100",
                data: { turbo_frame: :context_overlay, turbo_prefetch: false }
              ) { I18n.t("contexts.form.cancel") }
            end
          end
        end
      end
    end
  end
end
