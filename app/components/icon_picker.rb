# frozen_string_literal: true

module Components
  class IconPicker < Base
    include Phlex::Rails::Helpers::AssetPath

    include TranslateHelper

    ICONS_PATH = "avatars"
    PEOPLE_ICONS_PATH = "avatars/people"
    PEOPLE_2_ICONS_PATH = "avatars/people_2"
    DOGS_ICONS_PATH = "avatars/dogs"
    CATS_ICONS_PATH = "avatars/cats"
    ANIMALS_ICONS_PATH = "avatars/animals"
    ENTITIES_ICONS_PATH = "avatars/entities"
    COUNTRIES_ICONS_PATH = "avatars/countries"
    DEFAULT_TAB = "people"
    TABS = [
      { key: "people", label: :people_one, path: PEOPLE_ICONS_PATH },
      { key: "people_2", label: :people_two, path: PEOPLE_2_ICONS_PATH },
      { key: "dogs", label: :dogs, path: DOGS_ICONS_PATH },
      { key: "cats", label: :cats, path: CATS_ICONS_PATH },
      { key: "animals", label: :animals, path: ANIMALS_ICONS_PATH },
      { key: "entities", label: :entity_icons, path: ENTITIES_ICONS_PATH },
      { key: "countries", label: :countries, path: COUNTRIES_ICONS_PATH }
    ].freeze

    def initialize(form:, field:, &)
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

        div(
          class: "hidden absolute z-50 mt-2 left-1/2 w-[min(90vw,42rem)] -translate-x-1/2 rounded-lg border border-zinc-300 bg-white shadow-lg",
          data: { icon_picker_target: "iconOptionContainer" }
        ) do
          tabs
          TABS.each { |tab| icon_container(tab) }
        end
      end
    end

    def tabs
      button_class = "flex-1 border-b-2 border-transparent p-2 text-center text-sm font-semibold text-gray-500 " \
                     "data-[active=true]:border-black data-[active=true]:text-black"

      div(class: "flex overflow-x-auto border-b border-gray-300") do
        TABS.each do |tab|
          button type: "button",
                 class: button_class,
                 data: {
                   action: "click->icon-picker#switchTab",
                   tab: tab[:key],
                   icon_picker_target: "tabButton",
                   active: active_tab == tab[:key]
                 } do
            model_attribute(Entity, tab[:label])
          end
        end
      end
    end

    def icon_container(tab)
      div(
        class: "max-h-[24rem] overflow-y-auto p-2 #{'hidden' unless active_tab == tab[:key]}",
        data: { icon_picker_target: "iconContainer", tab: tab[:key] }
      ) do
        div(class: "grid grid-cols-[repeat(auto-fill,minmax(2.5rem,1fr))] gap-2") do
          avatar_files(tab[:key]).each do |file|
            filename = File.basename(file)

            button type: "button",
                   class: "size-10 flex items-center justify-center rounded border shadow-sm transition-all duration-100 ease-in-out hover:scale-110
                           hover:border-black focus:outline-none",
                   data: { action: "click->icon-picker#selectIcon", icon_picker_target: "iconOption", name: filename } do
              img(src: asset_path("#{tab[:path]}/#{filename}"), class: "h-full w-full object-contain")
            end
          end
        end
      end
    end

    private

    def active_tab
      tab = @value.to_s.split("/").first
      TABS.any? { |item| item[:key] == tab } ? tab : DEFAULT_TAB
    end

    def avatar_files(tab)
      files = Dir.glob(Rails.root.join("app/assets/images/avatars/#{tab}/*.png")).map { |file| File.basename(file) }.sort_by(&:downcase)

      tab == "people" ? files.reject { |filename| filename == "0.png" } : files
    end
  end
end
