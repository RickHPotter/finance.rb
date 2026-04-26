# frozen_string_literal: true

class Views::Investments::FormSubmissionSkeleton < Views::Base
  def view_template
    div(class: "space-y-6", id: "investment_form_submission_skeleton") do
      div(class: "flex justify-center") do
        Skeleton(class: "h-7 w-28 rounded-sm")
      end

      Skeleton(class: "h-12 w-full rounded-md")

      div(class: "grid grid-cols-1 gap-3 lg:grid-cols-4") do
        div(class: "space-y-2") do
          Skeleton(class: "h-10 w-full rounded-md")
        end

        div(class: "space-y-2") do
          Skeleton(class: "h-10 w-full rounded-md")
        end

        div(class: "space-y-2") do
          Skeleton(class: "h-10 w-full rounded-md")
          Skeleton(class: "h-4 w-20 rounded-sm")
        end

        div(class: "space-y-2") do
          Skeleton(class: "h-10 w-full rounded-md")
        end
      end

      div(class: "space-y-3") do
        Skeleton(class: "mx-auto h-5 w-32 rounded-sm")

        div(class: "grid grid-cols-1 gap-2 sm:grid-flow-col sm:auto-cols-fr") do
          3.times do
            Skeleton(class: "h-10 w-full rounded-md")
          end
        end
      end
    end
  end
end
