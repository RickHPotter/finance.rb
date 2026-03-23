# frozen_string_literal: true

class Views::Contexts::New < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :form_context, :source_context

  def initialize(context:, source_context:)
    @form_context = context
    @source_context = source_context
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "fixed inset-0 z-40 flex items-center justify-center bg-black/40 p-4") do
        div(class: "w-full max-w-lg rounded-3xl bg-white p-6 shadow-xl") do
          div(class: "mb-5 flex items-start justify-between gap-4") do
            div do
              h1(class: "text-lg font-semibold text-stone-900") { I18n.t("contexts.new.title") }
              p(class: "mt-2 text-sm text-stone-500") { I18n.t("contexts.new.subtitle", source_name: source_context.name) }
            end

            link_to(
              contexts_path,
              class: "inline-flex size-9 items-center justify-center rounded-full border border-stone-200 text-stone-500 transition hover:bg-stone-100",
              data: { turbo_frame: :center_container, turbo_prefetch: false }
            ) { "x" }
          end

          form_with(model: form_context, url: contexts_path, method: :post, class: "space-y-4") do |form|
            form.hidden_field :source_context_id, value: source_context.id

            div do
              form.label :name, I18n.t("contexts.form.name"), class: "mb-2 block text-sm font-medium text-stone-700"
              form.text_field :name, class: "w-full rounded-2xl border border-stone-300 px-4 py-3 text-sm text-stone-900"
            end

            div do
              form.label :description, I18n.t("contexts.form.description"), class: "mb-2 block text-sm font-medium text-stone-700"
              form.text_area :description, rows: 4, class: "w-full rounded-2xl border border-stone-300 px-4 py-3 text-sm text-stone-900"
            end

            div(class: "flex justify-end gap-3 pt-2") do
              link_to(
                contexts_path,
                class: "inline-flex items-center rounded-2xl border border-stone-300 px-4 py-2 text-sm font-medium text-stone-700 transition hover:bg-stone-100",
                data: { turbo_frame: :center_container, turbo_prefetch: false }
              ) { I18n.t("contexts.form.cancel") }

              form.submit I18n.t("contexts.form.create"),
                          class: "inline-flex items-center rounded-2xl bg-sky-500 px-4 py-2 text-sm font-semibold text-white transition hover:bg-sky-600"
            end
          end
        end
      end
    end
  end
end
