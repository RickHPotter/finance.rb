# frozen_string_literal: true

module Components
  class IconPicker < Base
    include Phlex::Rails::Helpers::AssetPath
    include TranslateHelper

    ICONS_PATH = "avatars"
    PEOPLE_ICONS_PATH = "avatars/people"
    DOGS_ICONS_PATH = "avatars/dogs"

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

          div(class: "size-20 rounded-lg border border-gray-300 flex items-center justify-center") do
            img(src: asset_path("#{ICONS_PATH}/#{@value}"), class: "size-18", data: { icon_picker_target: "iconIndicator" })
          end
        end

        div(class: "hidden absolute z-50 w-72 mt-2 left-1/2 -translate-x-1/2 bg-white rounded-lg shadow-lg border border-zinc-300",
            data: { icon_picker_target: "iconOptionContainer" }) do
          tabs
          people_container
          dogs_container
        end
      end
    end

    def tabs
      div(class: "flex border-b border-gray-300") do
        button type: "button",
               class: "w-1/2 p-2 text-center font-semibold border-b-2 border-transparent data-[active=true]:border-black data-[active=true]:text-black text-gray-500",
               data: { action: "click->icon-picker#switchTab", tab: :people, icon_picker_target: "tabButton" } do
          model_attribute(Entity, :people)
        end
        button type: "button",
               class: "w-1/2 p-2 text-center font-semibold border-b-2 border-transparent data-[active=true]:border-black data-[active=true]:text-black text-gray-500",
               data: { action: "click->icon-picker#switchTab", tab: :dogs, icon_picker_target: "tabButton" } do
          model_attribute(Entity, :dogs)
        end
      end
    end

    def people_container
      div(class: "grid grid-cols-5 gap-2 p-2 data-[active=false]:hidden", data: { icon_picker_target: "iconContainer", tab: "people" }) do
        people_avatar_files.each do |file|
          filename = File.basename(file)

          button type: "button",
                 class: "size-12 flex items-center justify-center rounded shadow-lg border hover:scale-110 transition-all ease-in-out duration-100
                  cursor-pointer hover:border-black focus:outline-none",
                 data: { action: "click->icon-picker#selectIcon", icon_picker_target: "iconOption", name: filename } do
            img(src: asset_path("#{PEOPLE_ICONS_PATH}/#{filename}"), class: "w-full h-full object-contain")
          end
        end
      end
    end

    def dogs_container
      div(class: "grid grid-cols-5 gap-2 p-2 hidden", data: { icon_picker_target: "iconContainer", tab: "dogs" }) do
        dogs_avatar_files.each do |file|
          filename = File.basename(file)

          button type: "button",
                 class: "size-12 flex items-center justify-center rounded shadow-lg border hover:scale-110 transition-all ease-in-out duration-100
                             cursor-pointer hover:border-black focus:outline-none",
                 data: { action: "click->icon-picker#selectIcon", icon_picker_target: "iconOption", name: filename } do
            img(src: asset_path("#{DOGS_ICONS_PATH}/#{filename}"), class: "w-full h-full object-contain")
          end
        end
      end
    end

    private

    def people_avatar_files
      Dir.glob(Rails.root.join("app/assets/images/avatars/people/*.png")).reject { |f| f.ends_with?("/0.png") }.map { |file| File.basename(file) }
    end

    def dogs_avatar_files
      Dir.glob(Rails.root.join("app/assets/images/avatars/dogs/*.png")).map { |file| File.basename(file) }
    end
  end
end
