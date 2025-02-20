# frozen_string_literal: true

module Components
  class IconPicker < Base
    include Phlex::Rails::Helpers::AssetPath

    ICONS_PATH = "avatars"

    def initialize(form:, field:, &)
      super
      @form = form
      @field = field
      @value = form.object.send(field)
    end

    def view_template
      div(class: "relative", data: { controller: "icon-picker" }) do
        div(class: "relative", data: { action: "click->icon-picker#toggle" }) do
          raw @form.text_field(@field, type: :hidden, value: @value, readonly: true, data: { icon_picker_target: "selectedIcon" })

          div(class: "w-10 h-10 rounded-full border border-gray-300 flex items-center justify-center") do
            img(src: asset_path("#{ICONS_PATH}/#{@value}"), class: "w-10 h-10 rounded-full", data: { icon_picker_target: "iconIndicator" })
          end
        end

        div(class: "hidden absolute z-50 w-48 mt-2 p-2 left-1/2 -translate-x-1/2 bg-white rounded-lg shadow-lg border border-zinc-300 grid grid-cols-4 gap-2",
            data: { icon_picker_target: "iconOptionContainer" }) do
          avatar_files.each do |file|
            filename = File.basename(file)

            button type: "button",
                   class: "w-10 h-10 flex items-center justify-center p-1 rounded shadow-lg border hover:scale-110 transition-all ease-in-out duration-100
                           cursor-pointer hover:border-black focus:outline-none",
                   data: { action: "click->icon-picker#selectIcon", icon_picker_target: "iconOption", name: filename } do
              img(src: asset_path("#{ICONS_PATH}/#{filename}"), class: "w-full h-full object-contain")
            end
          end
        end
      end
    end

    private

    def avatar_files
      Dir.glob(Rails.root.join("app/assets/images/avatars/*.png")).reject { |f| f.ends_with?("/0.png") }.map { |file| File.basename(file) }
    end
  end
end
