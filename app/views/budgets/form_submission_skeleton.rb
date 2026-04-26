# frozen_string_literal: true

class Views::Budgets::FormSubmissionSkeleton < Views::Base
  def view_template
    div(class: "space-y-6", id: "budget_form_submission_skeleton") do
      div(class: "flex justify-center") do
        Skeleton(class: "h-7 w-28 rounded-sm")
      end

      Skeleton(class: "h-14 w-full rounded-md")

      div(class: "grid grid-cols-1 gap-3 lg:grid-cols-4") do
        4.times do |index|
          div(class: "space-y-2") do
            Skeleton(class: "h-4 #{index == 2 ? 'w-24' : 'w-20'} rounded-sm")
            Skeleton(class: "h-10 w-full rounded-md")
          end
        end
      end

      div(class: "mx-auto grid max-w-3xl grid-cols-1 gap-3 lg:grid-cols-2") do
        2.times do |index|
          div(class: "space-y-2") do
            Skeleton(class: "h-4 #{index.zero? ? 'w-36' : 'w-16'} rounded-sm")
            Skeleton(class: "h-5 w-5 rounded-sm")
          end
        end
      end

      div(class: "flex justify-center gap-2 overflow-hidden pb-3") do
        Skeleton(class: "h-20 w-40 shrink-0 rounded-md")
      end

      div(class: "grid grid-cols-1 gap-2 lg:flex") do
        5.times do
          Skeleton(class: "h-7 w-full rounded-md")
        end
      end
    end
  end
end
