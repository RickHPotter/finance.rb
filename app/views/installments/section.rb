# frozen_string_literal: true

class Views::Installments::Section < Views::Base
  attr_reader :form, :association_name, :installments, :record_class

  def initialize(form:, association_name:, installments:, record_class:)
    @form = form
    @association_name = association_name
    @installments = installments
    @record_class = record_class
  end

  def view_template
    div(
      class: "border-t border-purple-200 py-2",
      data: {
        controller: "nested-form installment-lock installments-display",
        nested_form_wrapper_selector_value: ".nested-form-wrapper"
      }
    ) do
      template(data_nested_form_target: "template") do
        form.fields_for association_name, record_class.new, child_index: "NEW_RECORD" do |installment_fields|
          render_installment_item(installment_fields)
        end
      end

      div(
        class: "w-full min-w-0 relative group is-horizontal",
        role: "region",
        aria_roledescription: "carousel",
        data: { installments_display_target: "carouselRoot" }
      ) do
        div(class: "grid grid-cols-[1.875rem_minmax(0,1fr)_1.875rem] items-stretch gap-2") do
          div(class: "grid grid-rows-2 gap-3") do
            div(class: "hidden", data: { installments_display_target: "reduceSlot" }) do
              Button(
                type: :button,
                variant: :outline,
                class: "h-full min-h-14 w-full rounded-xl border border-slate-300 px-0 text-base",
                data: { action: "click->installments-display#toggle" }
              ) { "↑" }
            end

            div(class: "row-span-2", data: { installments_display_target: "prevSlot" }) do
              Button(
                type: :button,
                variant: :outline,
                class: "h-full min-h-14 w-full rounded-xl border border-slate-300 px-0 text-base",
                data: {
                  installments_display_target: "prevButton",
                  action: "click->installments-display#scrollPrev"
                }
              ) { "←" }
            end
          end

          div(class: "overflow-hidden", data: { installments_display_target: "viewport" }) do
            div(
              class: "flex -ml-3",
              data: {
                installments_display_target: "content",
                nested_form_target: "target",
                nested_form_insert: "beforeend"
              }
            ) do
              form.fields_for association_name, installments, include_id: false do |installment_fields|
                render_installment_item(installment_fields)
              end
            end
          end

          div(class: "grid grid-rows-2 gap-3") do
            div(data: { installments_display_target: "nextSlot" }) do
              Button(
                type: :button,
                variant: :outline,
                class: "h-full min-h-14 w-full rounded-xl border border-slate-300 px-0 text-base",
                data: {
                  installments_display_target: "nextButton",
                  action: "click->installments-display#scrollNext"
                }
              ) { "→" }
            end

            div(data: { installments_display_target: "expandSlot" }) do
              Button(
                type: :button,
                variant: :outline,
                class: "h-full min-h-14 w-full rounded-xl border border-slate-300 px-0 text-base",
                data: { action: "click->installments-display#toggle" }
              ) { "↓" }
            end
          end
        end
      end

      button(type: :button, class: :hidden, tabindex: -1, data: { reactive_form_target: :addInstallment, action: "nested-form#add" })
    end
  end

  private

  def render_installment_item(installment_fields)
    div(
      class: "min-w-0 shrink-0 grow-0 basis-full pl-3 md:basis-1/2 lg:basis-1/3 xl:basis-1/4",
      role: "group",
      aria_roledescription: "slide",
      data: { installments_display_target: "item" }
    ) do
      render Views::Installments::Fields.new(form: installment_fields)
    end
  end
end
