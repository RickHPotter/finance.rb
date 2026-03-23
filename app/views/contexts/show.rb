# frozen_string_literal: true

class Views::Contexts::Show < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :display_context, :current_context

  def initialize(context:, current_context:)
    @display_context = context
    @current_context = current_context
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "fixed inset-0 z-40 flex items-center justify-center bg-black/40 p-4") do
        div(class: "w-full max-w-2xl rounded-3xl bg-white p-6 shadow-xl") do
          div(class: "mb-5 flex items-start justify-between gap-4") do
            div do
              p(class: "text-xs font-semibold uppercase tracking-[0.2em] text-stone-500") { I18n.t("contexts.show.label") }
              h1(class: "mt-1 text-2xl font-semibold text-stone-900") { display_context.name }
              p(class: "mt-2 text-sm text-stone-500") { display_context.description.presence || I18n.t("contexts.index.no_description") }
            end

            link_to(
              contexts_path,
              class: "inline-flex size-9 items-center justify-center rounded-full border border-stone-200 text-stone-500 transition hover:bg-stone-100",
              data: { turbo_frame: :center_container, turbo_prefetch: false }
            ) { "x" }
          end

          div(class: "grid gap-3 md:grid-cols-3") do
            render_stat(I18n.t("contexts.show.stats.cash_transactions"), display_context.cash_transactions.count)
            render_stat(I18n.t("contexts.show.stats.card_transactions"), display_context.card_transactions.count)
            render_stat(I18n.t("contexts.show.stats.budgets"), display_context.budgets.count)
            render_stat(I18n.t("contexts.show.stats.investments"), display_context.investments.count)
            render_stat(I18n.t("contexts.show.stats.subscriptions"), display_context.subscriptions.count)
            render_stat(I18n.t("contexts.show.stats.references"), display_context.references.count)
          end

          div(class: "mt-6 flex flex-wrap justify-end gap-3") do
            link_to(
              new_context_path(source_context_id: display_context.id),
              class: "inline-flex items-center rounded-2xl border border-sky-300 px-4 py-2 text-sm font-medium text-sky-700 transition hover:bg-sky-50",
              data: { turbo_frame: :center_container, turbo_prefetch: false }
            ) { I18n.t("contexts.show.create_child") }

            if current_context != display_context
              button_to(
                switch_context_path(display_context),
                method: :patch,
                class: "inline-flex items-center rounded-2xl bg-emerald-500 px-4 py-2 text-sm font-semibold text-white transition hover:bg-emerald-600"
              ) { I18n.t("contexts.show.switch") }
            end
          end
        end
      end
    end
  end

  private

  def render_stat(label, value)
    div(class: "rounded-2xl border border-stone-200 bg-stone-50 px-4 py-3") do
      p(class: "text-[10px] font-semibold uppercase tracking-[0.18em] text-stone-500") { label }
      p(class: "mt-2 text-xl font-semibold text-stone-900") { value.to_s }
    end
  end
end
