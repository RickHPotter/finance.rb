# frozen_string_literal: true

class Views::Entities::Popover < Views::Base
  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :items, :mobile, :target_ids, :trigger_label, :variant

  def initialize(items:, mobile:, target_ids:, trigger_label:, variant: :cash)
    @items = items
    @mobile = mobile
    @target_ids = target_ids
    @trigger_label = trigger_label
    @variant = variant
  end

  def view_template
    div(class: mobile ? mobile_container_class : desktop_container_class, data: { datatable_target: :entity, id: target_ids }) do
      return if items.empty?

      mobile ? render_mobile : render_desktop
    end
  end

  def render_mobile
    if items.one?
      items.each do |item|
        render_item(item, wrapper_class: mobile_item_wrapper_class, avatar_class: "size-6 mb-1", name_class: mobile_name_class)
      end
    else
      Popover(options: { placement: "top-end" }, class: "ml-auto w-full") do
        PopoverTrigger(class: "w-full") do
          button(class: mobile_trigger_button_class) do
            render_avatar_stack(items, avatar_class: "size-6", limit: 3)
            span(class: mobile_trigger_label_class) { trigger_label }
          end
        end

        PopoverContent(class: "z-50 !opacity-100 mr-2") do
          div(class: "flex flex-wrap justify-end gap-2 min-w-36") do
            items.each do |item|
              render_item(item, wrapper_class: mobile_item_wrapper_class, avatar_class: "size-6 mb-1", name_class: mobile_name_class)
            end
          end
        end
      end
    end
  end

  def render_desktop
    if items.one?
      button(class: desktop_single_button_class) do
        render_item(items.first, wrapper_class: desktop_item_wrapper_class, avatar_class: "size-5", name_class: "entity_entity_name")
      end
    else
      Popover(options: { placement: "left" }, class: "flex items-center justify-center") do
        PopoverTrigger(class: "w-full") do
          button(class: desktop_trigger_button_class) do
            render_avatar_stack(items, avatar_class: "size-5", limit: 2)
            span { "+" }
          end
        end

        PopoverContent(class: "z-50 !opacity-100 mr-2") do
          div(class: "flex flex-col gap-2 min-w-36") do
            items.each do |item|
              render_item(item, wrapper_class: desktop_item_wrapper_class, avatar_class: "size-5", name_class: "entity_entity_name")
            end
          end
        end
      end
    end
  end

  def render_item(item, wrapper_class:, avatar_class:, name_class:)
    if item[:href].present?
      Link(href: item[:href], size: :xs, class: wrapper_class, data: item[:data] || {}) do
        render_item_content(item, avatar_class:, name_class:)
      end
    else
      div(class: wrapper_class) do
        render_item_content(item, avatar_class:, name_class:)
      end
    end
  end

  def render_item_content(item, avatar_class:, name_class:)
    image_tag asset_path("avatars/#{item[:avatar_name]}"), class: "bg-white rounded-full #{avatar_class}"
    span(class: name_class) { item[:name] }
    span(class: item[:info_class]) { item[:info_text] } if item[:info_class].present?
  end

  def render_avatar_stack(items, avatar_class:, limit:)
    div(class: "flex items-center") do
      items.first(limit).each_with_index do |item, index|
        image_tag(
          asset_path("avatars/#{item[:avatar_name]}"),
          class: "bg-white rounded-full border border-white #{avatar_class} #{'-ml-2' if index.positive?}"
        )
      end
    end
  end

  def mobile_container_class
    "flex flex-wrap justify-end gap-2 ml-auto"
  end

  def desktop_container_class
    case variant
    when %i[card cash]
      "col-span-2 py-2 flex items-center justify-center flex-wrap gap-2"
    else
      "col-span-2 py-2 flex items-center justify-center flex-wrap gap-2 hover:opacity-65"
    end
  end

  def mobile_item_wrapper_class
    "flex flex-col items-center w-16 text-center text-inherit"
  end

  def desktop_item_wrapper_class
    case variant
    when :budget
      "flex items-center gap-2 text-xs text-black"
    else
      "flex items-center gap-2 text-xs text-inherit"
    end
  end

  def mobile_name_class
    "entity_entity_name truncate block max-w-full leading-tight"
  end

  def mobile_trigger_button_class
    case variant
    when %i[card cash]
      "w-full flex items-center justify-end gap-2 cursor-pointer"
    else
      "w-full flex flex-col items-center justify-end gap-2 cursor-pointer"
    end
  end

  def mobile_trigger_label_class
    case variant
    when %i[card cash]
      "text-xs underline underline-offset-[3px] whitespace-nowrap"
    else
      "entity_entity_name truncate block max-w-full leading-tight"
    end
  end

  def desktop_single_button_class
    case variant
    when :budget
      "flex items-center gap-2 rounded-md border border-white px-2 py-1 text-xs text-zinc-50"
    else
      "flex items-center gap-2 rounded-md border border-black px-2 py-1 text-xs text-black"
    end
  end

  def desktop_trigger_button_class
    desktop_single_button_class
  end
end
