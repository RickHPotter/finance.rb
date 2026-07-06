# frozen_string_literal: true

class Views::Contexts::Show < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::LinkTo

  include ComponentsHelper

  attr_reader :display_context, :current_context

  def initialize(context:, current_context:)
    @display_context = context
    @current_context = current_context
  end

  def view_template
    turbo_frame_tag :context_overlay do
      div(class: "fixed inset-0 z-40 flex items-center justify-center bg-black/40 p-4") do
        div(class: modal_card_class) do
          div(class: "mb-5 flex items-start justify-between gap-4") do
            div(class: "min-w-0 flex-1 text-left") do
              p(class: "text-left text-xs font-semibold uppercase tracking-[0.2em] text-stone-500 dark:text-slate-400") { I18n.t("contexts.show.label") }
              h1(class: "mt-1 text-left text-2xl font-semibold text-stone-900 wrap-break-word dark:text-slate-100") { display_context.name }
              p(class: "mt-2 text-left text-sm text-stone-500 wrap-break-word dark:text-slate-400") do
                display_context.description.presence || I18n.t("contexts.index.no_description")
              end
              if display_context.archived?
                span(class: "mt-3 inline-flex rounded-full bg-stone-500 px-3 py-1 text-2xs font-semibold uppercase tracking-[0.18em] text-white") do
                  I18n.t("contexts.index.archived")
                end
              end
            end

            link_to(
              dismiss_contexts_path,
              class: close_button_class,
              data: { turbo_frame: :context_overlay, turbo_prefetch: false }
            ) { "x" }
          end

          div(class: "grid gap-3 sm:grid-cols-2 md:grid-cols-3") do
            render_stat(I18n.t("contexts.show.stats.cash_transactions"), display_context.cash_transactions.count)
            render_stat(I18n.t("contexts.show.stats.card_transactions"), display_context.card_transactions.count)
            render_stat(I18n.t("contexts.show.stats.budgets"), display_context.budgets.count)
            render_stat(I18n.t("contexts.show.stats.investments"), display_context.investments.count)
            render_stat(I18n.t("contexts.show.stats.subscriptions"), display_context.subscriptions.count)
            render_stat(I18n.t("contexts.show.stats.references"), display_context.references.count)
          end

          div(class: "mt-6 grid gap-3 sm:flex sm:flex-wrap sm:justify-end") do
            unless display_context.archived?
              link_to(
                new_context_path(source_context_id: display_context.id),
                class: "inline-flex min-w-40 items-center justify-center rounded-md border border-purple-500 bg-purple-100 px-4 py-2 " \
                       "text-center text-sm font-semibold text-purple-900 shadow-sm transition hover:border-purple-400 hover:bg-purple-500 hover:text-white",
                data: { turbo_frame: :context_overlay, turbo_prefetch: false }
              ) { I18n.t("contexts.show.create_child") }
            end

            if display_context.derived? && !display_context.archived?
              button_to(
                archive_context_path(display_context),
                method: :patch,
                form: { data: { turbo: false } },
                data: { turbo: false, turbo_prefetch: false },
                class: archive_button_class
              ) { I18n.t("contexts.show.archive") }
            elsif display_context.derived?
              button_to(
                unarchive_context_path(display_context),
                method: :patch,
                form: { data: { turbo: false } },
                data: { turbo: false, turbo_prefetch: false },
                class: "inline-flex min-w-40 items-center justify-center rounded-md border border-emerald-500 bg-emerald-100 px-4 py-2 " \
                       "text-center text-sm font-semibold text-emerald-900 shadow-sm transition hover:border-emerald-400 hover:bg-emerald-500 hover:text-white"
              ) { I18n.t("contexts.show.unarchive") }
            end

            if display_context.removable?
              LinkWithConfirmation(
                id: "context_destroy_#{display_context.id}",
                text: I18n.t("contexts.show.destroy"),
                link_params: {
                  href: context_path(display_context),
                  id: "delete_context_#{display_context.id}",
                  variant: :outline,
                  class: "min-w-40 #{destroy_button_class}",
                  data: { turbo_method: :delete, turbo_frame: "_top" }
                }
              )
            end

            if current_context != display_context && !display_context.archived?
              button_to(
                switch_context_path(display_context),
                method: :patch,
                form: { data: { turbo: false } },
                data: { turbo: false, turbo_prefetch: false },
                class: "inline-flex min-w-40 items-center justify-center rounded-md border border-sky-900 bg-sky-500 px-4 py-2 " \
                       "text-center text-sm font-semibold text-white shadow-sm transition hover:border-sky-500 hover:bg-sky-100 hover:text-sky-900"
              ) { I18n.t("contexts.show.switch") }
            end
          end
        end
      end
    end
  end

  private

  def render_stat(label, value)
    div(class: "rounded-lg border border-stone-200 bg-stone-50 px-4 py-3 text-left dark:border-slate-700 dark:bg-slate-900") do
      p(class: "text-left text-2xs font-semibold uppercase tracking-[0.18em] text-stone-500 dark:text-slate-400") { label }
      p(class: "mt-2 text-xl font-semibold text-stone-900 dark:text-slate-100") { value.to_s }
    end
  end

  def modal_card_class
    "max-h-[90vh] w-full max-w-2xl overflow-y-auto rounded-lg border border-slate-200 bg-white p-4 shadow-xl " \
      "dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100 dark:shadow-black/40 sm:p-6"
  end

  def close_button_class
    "inline-flex size-8 items-center justify-center rounded-sm border border-slate-300 bg-white text-slate-600 shadow-sm transition " \
      "hover:border-slate-400 hover:bg-slate-100 hover:text-slate-900 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-300 " \
      "dark:hover:bg-slate-800 dark:hover:text-slate-100"
  end

  def archive_button_class
    "inline-flex min-w-40 items-center justify-center rounded-md border border-stone-400 bg-white px-4 py-2 text-center text-sm " \
      "font-semibold text-stone-700 shadow-sm transition hover:border-stone-500 hover:bg-stone-100 dark:border-slate-700 " \
      "dark:bg-slate-900 dark:text-slate-300 dark:hover:bg-slate-800"
  end
end
