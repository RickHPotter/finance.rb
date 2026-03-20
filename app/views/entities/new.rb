# frozen_string_literal: true

class Views::Entities::New < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :current_user, :entity

  def initialize(current_user:, entity:)
    @current_user = current_user
    @entity = entity
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "bg-white p-4 shadow-md rounded-lg") do
        div(class: "flex justify-between mb-8") do
          link_to(
            pluralise_model(Entity, 2),
            entities_path,
            class: "py-2 px-3 rounded-sm border border-sky-900 bg-blue-600 hover:bg-blue-800 transition-colors text-white shadow-lg font-thin",
            data: { turbo_frame: "_top" }
          )
        end

        render Views::Entities::Form.new(current_user:, entity:)
      end
    end
  end
end
