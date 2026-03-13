# frozen_string_literal: true

class Views::Categories::Popover < Views::Base
  attr_reader :items, :mobile, :target_ids, :trigger_label, :variant

  def initialize(items:, mobile:, target_ids:, trigger_label:, variant: :cash)
    @items = items
    @mobile = mobile
    @target_ids = target_ids
    @trigger_label = trigger_label
    @variant = variant
  end

  def view_template
    div(class: mobile ? mobile_container_class : desktop_container_class, data: { datatable_target: :category, id: target_ids }) do
      return if items.empty?

      mobile ? render_mobile : render_desktop
    end
  end

  private

  def render_mobile
    if items.one?
      render_pill(items.first, class: mobile_pill_class)
    else
      Popover(options: { placement: "top-end" }, class: "ml-auto") do
        PopoverTrigger(class: "w-full") do
          button(type: :button, class: mobile_trigger_button_class) do
            render_pill(items.first, class: mobile_pill_class)
            span(class: mobile_trigger_label_class) { trigger_label }
          end
        end

        PopoverContent(class: "z-50 !opacity-100 mr-2") do
          div(class: "flex max-w-56 flex-wrap justify-end gap-1") do
            items.each do |item|
              render_pill(item, class: mobile_pill_class)
            end
          end
        end
      end
    end
  end

  def render_desktop
    if items.one?
      render_pill(items.first, class: desktop_pill_class)
    else
      Popover(options: { placement: "right" }, class: "flex items-center justify-center gap-1") do
        PopoverTrigger(class: "w-full") do
          button(type: :button, class: "flex items-center justify-center gap-1") do
            render_pill(items.first, class: desktop_pill_class)
            span(class: desktop_counter_class) { "+#{items.count - 1}" }
          end
        end

        PopoverContent(class: "z-50 !opacity-100 ml-2") do
          div(class: "flex min-w-36 flex-col gap-2") do
            items.drop(1).each do |item|
              render_pill(item, class: desktop_pill_class)
            end
          end
        end
      end
    end
  end

  def render_pill(item, class:)
    span(class:, style: item[:style]) { item[:name] }
  end

  def mobile_container_class
    "ml-auto flex flex-wrap items-center justify-end gap-1"
  end

  def desktop_container_class
    "col-span-3 py-2 flex items-center justify-center gap-2"
  end

  def mobile_pill_class
    base_pill_class("text-xs")
  end

  def desktop_pill_class
    base_pill_class("text-sm")
  end

  def base_pill_class(size_class)
    "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1 #{size_class}"
  end

  def mobile_trigger_button_class
    "flex items-center justify-end gap-1"
  end

  def mobile_trigger_label_class
    "text-xs underline underline-offset-[3px] whitespace-nowrap"
  end

  def desktop_counter_class
    "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1 border-black text-sm"
  end
end
