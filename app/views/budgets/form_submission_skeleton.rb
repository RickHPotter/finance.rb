# frozen_string_literal: true

class Views::Budgets::FormSubmissionSkeleton < Views::Base
  def view_template
    div(class: "space-y-5", id: "budget_form_submission_skeleton") do
      div(class: "flex justify-center") do
        Skeleton(class: "h-7 w-28 rounded-sm")
      end

      Skeleton(class: "h-16 w-full rounded-md")

      div(class: "grid grid-cols-1 gap-3 lg:grid-cols-4 lg:gap-2") do
        4.times do |index|
          div(class: "space-y-2 text-center #{index == 3 ? 'mb-0' : 'mb-3 lg:mb-0'}") do
            Skeleton(class: "mx-auto h-4 #{label_width_for(index)} rounded-sm")

            if index == 3
              div(class: "flex gap-x-1") do
                Skeleton(class: "h-10 w-1/6 rounded-md lg:hidden")
                Skeleton(class: "h-10 w-5/6 rounded-md lg:w-full")
              end
            else
              Skeleton(class: "h-10 w-full rounded-md")
            end
          end
        end
      end

      div(class: "grid grid-cols-1 gap-2 sm:grid-cols-3") do
        3.times do |index|
          div(class: "flex flex-col items-center space-y-2 text-center") do
            Skeleton(class: "h-4 #{checkbox_label_width_for(index)} rounded-sm")
            Skeleton(class: "h-5 w-5 rounded-sm")
          end
        end
      end

      div(class: "mb-2 grid grid-cols-1 gap-3 items-stretch md:grid-cols-2 md:gap-0") do
        render_collection_section_skeleton(border_class: "border-y py-2 md:border-r md:pr-2")
        render_collection_section_skeleton(border_class: "border-y py-2 md:border-l md:pl-2")
      end

      div(class: "grid grid-cols-1 sm:grid-flow-col sm:auto-cols-fr items-center justify-items-center gap-2 mx-auto w-full") do
        4.times do
          Skeleton(class: "h-10 w-64 rounded-md")
        end
      end
    end
  end

  private

  def label_width_for(index)
    %w[w-24 w-20 w-28 w-16][index]
  end

  def checkbox_label_width_for(index)
    %w[w-20 w-40 w-16][index]
  end

  def render_collection_section_skeleton(border_class:)
    div(class: border_class) do
      div(class: "grid min-h-14 grid-cols-[1.5rem_minmax(0,1fr)_1.5rem] items-stretch gap-2") do
        Skeleton(class: "h-full min-h-12 w-full rounded-lg bg-slate-100")

        div(class: "min-h-14 overflow-hidden") do
          div(class: "flex min-h-14 -ml-2 items-center") do
            2.times do |index|
              Skeleton(class: "ml-2 h-12 #{collection_item_width_for(index)} shrink-0 rounded-sm bg-slate-100")
            end
          end
        end

        Skeleton(class: "h-full min-h-12 w-full rounded-lg bg-slate-100")
      end
    end
  end

  def collection_item_width_for(index)
    %w[w-40 w-48][index]
  end
end
