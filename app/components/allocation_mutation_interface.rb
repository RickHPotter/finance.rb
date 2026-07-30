# frozen_string_literal: true

module Components
  class AllocationMutationInterface < Base
    include TranslateHelper
    include Phlex::Rails::Helpers::FormWith
    include Phlex::Rails::Helpers::TurboFrameTag

    MODAL_ID = "allocationMutationModal"
    ACTIONS = [
      %i[category add],
      %i[category remove],
      %i[category switch],
      %i[entity add],
      %i[entity remove],
      %i[entity switch]
    ].freeze

    attr_reader :current_user, :owner_type, :return_to, :selection_kind

    def self.bulk_action(selection_kind:)
      {
        name: "allocation",
        ids_kind: "record",
        selection_kind:,
        title: I18n.t("allocation_mutations.interface.launch_title"),
        label: I18n.t("allocation_mutations.interface.launch"),
        data: {
          action: "click->datatable#prepareBulkAction",
          modal_target: modal_id(selection_kind),
          modal_toggle: modal_id(selection_kind),
          allocation_mutation_launch: "true"
        }
      }
    end

    def self.modal_id(selection_kind)
      "#{MODAL_ID}_#{selection_kind.to_s.parameterize(separator: '_')}"
    end

    def initialize(current_user:, owner_type:, return_to:, selection_kind: "installment")
      @current_user = current_user
      @owner_type = owner_type.to_s
      @return_to = return_to
      @selection_kind = selection_kind.to_s
    end

    def view_template
      div(
        data: {
          controller: "allocation-mutation",
          allocation_mutation_default_action_value: "category_add",
          allocation_mutation_interface: true
        }
      ) do
        ModalShell(
          id: modal_id,
          title: I18n.t("allocation_mutations.interface.title"),
          options: modal_options
        ) do
          configuration
          loading_state
          turbo_frame_tag(
            "allocation_mutation_preview",
            class: "hidden",
            data: { allocation_mutation_target: "previewFrame" }
          )
        end
      end
    end

    private

    def modal_options
      {
        wrapper_class: "items-end p-0 sm:items-center sm:p-4",
        content_class: "max-h-[92svh] w-full overflow-y-auto rounded-b-none rounded-t-2xl p-4 sm:max-w-3xl sm:rounded-lg sm:p-6",
        close_label: I18n.t("allocation_mutations.interface.close"),
        close_button_data: {
          modal_hide: modal_id,
          action: "click->allocation-mutation#close"
        }
      }
    end

    def modal_id
      self.class.modal_id(selection_kind)
    end

    def configuration
      div(data: { allocation_mutation_target: "configuration" }) do
        p(class: "text-start text-sm text-slate-600 dark:text-slate-300") { I18n.t("allocation_mutations.interface.description") }
        action_picker
        preview_form
      end
    end

    def action_picker
      fieldset(class: "mt-4") do
        legend(class: field_label_class) { I18n.t("allocation_mutations.interface.action_label") }
        div(class: "mt-2 grid grid-cols-2 gap-2 sm:grid-cols-3") do
          ACTIONS.each do |allocation_type, operation|
            action_key = "#{allocation_type}_#{operation}"
            button(
              type: :button,
              class: action_button_class,
              aria: { pressed: (action_key == "category_add").to_s },
              data: {
                allocation_mutation_target: "actionButton",
                allocation_action_key: action_key,
                allocation_type:,
                allocation_operation: operation,
                action: "click->allocation-mutation#selectAction"
              }
            ) do
              I18n.t("allocation_mutations.interface.actions.#{action_key}")
            end
          end
        end
      end
    end

    def preview_form
      form_with(
        url: Rails.application.routes.url_helpers.preview_allocation_mutations_path,
        method: :post,
        class: "mt-4",
        data: {
          allocation_mutation_target: "form",
          action: "turbo:submit-start->allocation-mutation#previewStarted turbo:submit-end->allocation-mutation#previewFinished"
        }
      ) do |form|
        form.hidden_field("allocation_mutation[owner_type]", value: owner_type)
        form.hidden_field(
          "allocation_mutation[owner_ids][]",
          value: "",
          data: {
            allocation_mutation_target: "ownerIds",
            bulk_ids_input: true,
            bulk_ids_kind: "record",
            bulk_selection_kind: selection_kind
          }
        )
        form.hidden_field(
          "allocation_mutation[selected_row_count]",
          value: "0",
          data: {
            allocation_mutation_target: "rowCount",
            bulk_selected_row_count_input: true,
            bulk_ids_kind: "record",
            bulk_selection_kind: selection_kind
          }
        )
        form.hidden_field("allocation_mutation[return_to]", value: return_to)
        form.hidden_field(
          "allocation_mutation[action][allocation_type]",
          value: "category",
          data: { allocation_mutation_target: "allocationType" }
        )
        form.hidden_field(
          "allocation_mutation[action][operation]",
          value: "add",
          data: { allocation_mutation_target: "operation" }
        )
        form.hidden_field(
          "allocation_mutation[action][source_id]",
          value: "",
          data: { allocation_mutation_target: "sourceId" }
        )
        form.hidden_field(
          "allocation_mutation[action][destination_id]",
          value: "",
          data: { allocation_mutation_target: "destinationId" }
        )

        action_panels
        empty_selection

        button(
          type: :submit,
          class: "mt-4 min-h-11 w-full rounded-md bg-sky-700 px-4 py-2 text-sm font-bold text-white hover:bg-sky-800 " \
                 "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-500 disabled:cursor-not-allowed disabled:opacity-50",
          disabled: true,
          data: { allocation_mutation_target: "previewButton" }
        ) do
          I18n.t("allocation_mutations.interface.preview")
        end
      end
    end

    def action_panels
      ACTIONS.each do |allocation_type, operation|
        action_key = "#{allocation_type}_#{operation}"
        div(
          class: "mt-4 grid gap-3 sm:grid-cols-2 #{'hidden' unless action_key == 'category_add'}",
          data: { allocation_mutation_target: "panel", allocation_action_key: action_key }
        ) do
          allocation_combobox(allocation_type, action_key, :source) unless operation == :add
          allocation_combobox(allocation_type, action_key, :destination) unless operation == :remove
        end
      end
    end

    def allocation_combobox(allocation_type, action_key, role)
      label_id = "allocation_#{action_key}_#{role}_label"

      div(class: "text-start", role: "group", aria: { labelledby: label_id }) do
        p(id: label_id, class: field_label_class) do
          I18n.t("allocation_mutations.interface.#{role}")
        end
        div(class: "mt-1") do
          render Views::Shared::SingleSelectCombobox.new(
            name: "allocation_choice[#{action_key}][#{role}]",
            options: allocation_options(allocation_type),
            selected_value: nil,
            placeholder: I18n.t("allocation_mutations.interface.choose_#{allocation_type}"),
            term: I18n.t("allocation_mutations.interface.#{allocation_type}_term"),
            input_data: {
              allocation_role: role,
              allocation_action_key: action_key,
              action: "change->allocation-mutation#allocationChanged"
            }
          )
        end
      end
    end

    def allocation_options(allocation_type)
      @allocation_options ||= {}
      return @allocation_options.fetch(allocation_type) if @allocation_options.key?(allocation_type)

      records =
        if allocation_type == :category
          current_user.categories.active.where(built_in: false)
        else
          current_user.entities.active.where(built_in: false, entity_user_id: nil)
        end

      @allocation_options[allocation_type] = records.order(allocation_type == :category ? :category_name : :entity_name).map do |record|
        [ record.name, record.id, {} ]
      end
    end

    def empty_selection
      p(
        class: "mt-3 text-start text-xs font-semibold text-amber-700 dark:text-amber-300",
        data: { allocation_mutation_target: "emptyState" }
      ) do
        I18n.t("allocation_mutations.interface.empty_selection")
      end
    end

    def loading_state
      div(
        class: "hidden py-12 text-center",
        role: "status",
        aria: { live: "polite" },
        data: { allocation_mutation_target: "loading" }
      ) do
        div(class: "mx-auto size-8 animate-spin rounded-full border-4 border-slate-300 border-t-sky-600 dark:border-slate-700 dark:border-t-sky-400")
        p(class: "mt-3 text-sm font-semibold text-slate-600 dark:text-slate-300") { I18n.t("allocation_mutations.interface.loading") }
      end
    end

    def field_label_class
      "block text-start text-xs font-semibold uppercase tracking-[0.12em] text-slate-600 dark:text-slate-300"
    end

    def action_button_class
      "min-h-11 rounded-md border border-slate-300 bg-white px-3 py-2 text-sm font-semibold text-slate-700 transition-colors " \
        "hover:bg-slate-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-500 " \
        "aria-pressed:border-sky-600 aria-pressed:bg-sky-50 aria-pressed:text-sky-900 " \
        "dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800 " \
        "dark:aria-pressed:border-sky-400 dark:aria-pressed:bg-sky-950/40 dark:aria-pressed:text-sky-100"
    end
  end
end
