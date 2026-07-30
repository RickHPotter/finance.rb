# frozen_string_literal: true

class Views::AllocationMutationPreviews::Show < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :preview, :return_to

  def initialize(preview:, return_to: nil, frame_only: false)
    @preview = preview
    @return_to = return_to
    @frame_only = frame_only
  end

  def view_template
    return preview_frame if @frame_only

    main(class: "w-full px-2 py-2 sm:px-3") { preview_frame }
  end

  private

  def preview_frame
    turbo_frame_tag(
      "allocation_mutation_preview",
      data: { allocation_mutation_target: "previewFrame" }
    ) do
      section(class: "rounded-lg border border-slate-200 bg-white p-3 text-slate-900 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100") do
        header_section
        action_section
        counts_section
        reasons_section
        preview_actions
      end
    end
  end

  def header_section
    p(class: "text-xs font-semibold uppercase tracking-[0.18em] text-sky-700 dark:text-sky-300") do
      I18n.t("allocation_mutations.preview.eyebrow")
    end
    h1(class: "mt-1 text-xl font-bold") { I18n.t("allocation_mutations.preview.title") }
  end

  def action_section
    p(class: "mt-2 text-sm text-slate-600 dark:text-slate-300") do
      plain I18n.t(
        "allocation_mutations.actions.#{preview.action.allocation_type}.#{preview.action.operation}",
        source: preview.to_h[:source_label],
        destination: preview.to_h[:destination_label]
      )
    end
  end

  def counts_section
    dl(class: "mt-3 grid grid-cols-2 gap-2 sm:grid-cols-5") do
      metric("selected_rows", preview.selected_row_count)
      metric("unique_owners", preview.unique_owner_count)
      metric("affected", preview.affected_count)
      metric("noops", preview.noop_count)
      metric("conflicts", preview.conflict_count)
    end
  end

  def metric(key, value)
    div(class: "rounded-md bg-slate-50 p-2 dark:bg-slate-800") do
      dt(class: "text-2xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400") do
        I18n.t("allocation_mutations.preview.counts.#{key}")
      end
      dd(class: "mt-1 text-lg font-bold") { value.to_s }
    end
  end

  def reasons_section
    section(class: "mt-3 space-y-2", aria: { label: I18n.t("allocation_mutations.preview.reasons") }) do
      preview.reason_groups.each do |group|
        article(class: reason_class(group[:status])) do
          p(class: "text-sm font-semibold") { "#{group[:label]} · #{group[:count]}" }
          ul(class: "mt-1 flex flex-wrap gap-x-2 gap-y-1 text-xs opacity-80") do
            group[:owners].each do |owner|
              li do
                link_to(
                  owner[:label],
                  owner[:path],
                  class: "underline decoration-current/40 underline-offset-2 hover:decoration-current",
                  data: { turbo_frame: "_top", turbo_prefetch: false }
                )
              end
            end
          end
        end
      end
    end
  end

  def preview_actions
    div(
      class: "mt-3 flex items-center justify-between gap-2",
      data: { allocation_mutation_preview_actions: "true" }
    ) do
      back_button

      div(class: "flex flex-wrap justify-end gap-2") do
        apply_form(:strict, "strict") if preview.strict_apply_available?
        apply_form(:eligible_only, "eligible_only") if preview.eligible_only_available?
      end
    end
  end

  def back_button
    return standalone_back_link unless @frame_only

    button(
      type: :button,
      class: "min-h-10 rounded-md border border-slate-300 px-4 py-2 text-sm font-semibold hover:bg-slate-100 " \
             "dark:border-slate-700 dark:hover:bg-slate-800",
      data: { action: "click->allocation-mutation#backToForm" }
    ) do
      I18n.t("allocation_mutations.interface.back")
    end
  end

  def standalone_back_link
    link_to(
      I18n.t("allocation_mutations.interface.back"),
      canonical_index_path,
      class: "inline-flex min-h-10 items-center rounded-md border border-slate-300 px-4 py-2 text-sm font-semibold hover:bg-slate-100 " \
             "dark:border-slate-700 dark:hover:bg-slate-800",
      data: { turbo_frame: "_top", turbo_prefetch: false }
    )
  end

  def canonical_index_path
    case preview.owner_type
    when "CardTransaction" then card_transactions_path
    when "Budget" then budgets_path
    else cash_transactions_path
    end
  end

  def apply_form(mode, label_key)
    form_with(url: apply_allocation_mutations_path, method: :post) do |form|
      form.hidden_field(:apply_token, value: preview.apply_token, id: "allocation_mutation_#{mode}_token")
      form.hidden_field(:mode, value: mode)
      form.hidden_field(:allocation_confirmation, value: "1")
      form.hidden_field(:return_to, value: return_to) if return_to.present?
      form.submit(I18n.t("allocation_mutations.preview.apply.#{label_key}"), class: button_class(mode))
    end
  end

  def reason_class(status)
    base = "rounded-md border p-2"
    return "#{base} border-rose-300 bg-rose-50 text-rose-950 dark:border-rose-800 dark:bg-rose-950/30 dark:text-rose-100" if status == :conflict
    return "#{base} border-slate-200 bg-slate-50 text-slate-700 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-200" if status == :noop

    "#{base} border-emerald-300 bg-emerald-50 text-emerald-950 dark:border-emerald-800 dark:bg-emerald-950/30 dark:text-emerald-100"
  end

  def button_class(mode)
    colour = mode == :strict ? "bg-sky-700 hover:bg-sky-800" : "bg-amber-700 hover:bg-amber-800"
    "min-h-10 rounded-md px-4 py-2 text-sm font-bold text-white #{colour}"
  end
end
