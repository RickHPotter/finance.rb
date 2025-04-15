# frozen_string_literal: true

class Views::Budgets::EntityFields < Views::Base
  include Phlex::Rails::Helpers::ContentTag
  include Phlex::Rails::Helpers::HiddenField
  include Phlex::Rails::Helpers::Object
  include Phlex::Rails::Helpers::Select

  attr_accessor :form

  def initialize(form:, entities:)
    @form = form
    @entities = entities
  end

  def view_template
    div(
      class: "nested-form-wrapper",
      data_new_record: form.object.new_record?
    ) do
      div(class: "flex space-x-12") do
        div(class: "flex w-1/4 flex-col my-6") do
          whitespace
          render Components::TextFieldComponent.new(
            form,
            :entity_id,
            @entities,
            type: :select
          )
        end
        whitespace
        content_tag :span,
                    form.object&.entity&.entity_name,
                    class: "entities_entity_name",
                    data: {
                      dynamic_description_target: :entity
                    }
        whitespace
        plain form.hidden_field :_destroy
        div(class: "flex w-1/4 flex-col my-6") do
          whitespace
          render Components::ButtonComponent.new(
            options: {
              label: action_model(:destroy, BudgetEntity),
              colour: :red,
              data: {
                action:
                  "nested-form#remove dynamic-description#updateDescription"
              }
            }
          )
        end
      end
    end
  end

  private

  def action_model(*args, **kwargs)
    # TODO: Implement me
  end

  def render(*args, **kwargs)
    # TODO: Implement me
  end
end
