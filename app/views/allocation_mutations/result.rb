# frozen_string_literal: true

class Views::AllocationMutations::Result < Views::Base
  attr_reader :result

  def initialize(result:, frame_only: false)
    @result = result
    @frame_only = frame_only
  end

  def view_template
    return result_frame if @frame_only

    main(class: "w-full px-2 py-2 sm:px-3") { result_frame }
  end

  private

  def result_frame
    turbo_frame_tag(
      "allocation_mutation_preview",
      data: { allocation_mutation_target: "previewFrame" }
    ) do
      section(
        class: result_class,
        data: {
          allocation_mutation_applied: result.applied?.to_s,
          allocation_mutation_owner_ids: result.impacts.map(&:owner_id).uniq.sort.to_json
        }
      ) do
        h1(class: "text-lg font-bold") { result_title }
        p(class: "mt-1 text-sm") { result_description }
        if result.operation.present?
          p(class: "mt-2 text-xs opacity-80") do
            I18n.t("allocation_mutations.apply.operation", operation_id: result.operation.id)
          end
        end
        retry_button unless result.applied?
      end
    end
  end

  def result_title
    I18n.t("allocation_mutations.apply.states.#{result.status}")
  end

  def result_description
    return I18n.t("allocation_mutations.apply.applied") if result.applied?

    I18n.t(
      "allocation_mutations.apply.reasons.#{result.reason_code}",
      default: I18n.t("allocation_mutations.apply.reasons.unexpected_failure")
    )
  end

  def retry_button
    button(
      type: :button,
      class: "mt-3 min-h-10 rounded-md border border-current/30 px-4 py-2 text-sm font-semibold hover:bg-black/5 dark:hover:bg-white/5",
      data: { action: "click->allocation-mutation#backToForm" }
    ) do
      I18n.t("allocation_mutations.interface.back")
    end
  end

  def result_class
    base = "rounded-lg border p-3"
    return "#{base} border-emerald-300 bg-emerald-50 text-emerald-950 dark:border-emerald-800 dark:bg-emerald-950/30 dark:text-emerald-100" if result.applied?
    return "#{base} border-amber-300 bg-amber-50 text-amber-950 dark:border-amber-800 dark:bg-amber-950/30 dark:text-amber-100" if result.rejected?

    "#{base} border-rose-300 bg-rose-50 text-rose-950 dark:border-rose-800 dark:bg-rose-950/30 dark:text-rose-100"
  end
end
