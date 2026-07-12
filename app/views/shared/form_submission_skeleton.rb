# frozen_string_literal: true

class Views::Shared::FormSubmissionSkeleton < Views::Base
  def view_template
    div(class: "space-y-6 dark:[&_.animate-pulse]:bg-slate-700") do
      div(class: "space-y-3") do
        Skeleton(class: "h-5 w-32 rounded-sm")
        Skeleton(class: "h-12 w-full rounded-md")
      end

      div(class: "grid grid-cols-1 gap-3 lg:grid-cols-12") do
        [
          "lg:col-span-3",
          "lg:col-span-3",
          "lg:col-span-3",
          "lg:col-span-3"
        ].each do |column_class|
          div(class: "space-y-2") do
            Skeleton(class: "h-4 w-16 rounded-sm")
            Skeleton(class: "h-11 w-full rounded-md #{column_class}")
          end
        end
      end

      2.times do |index|
        div(class: "space-y-3") do
          div(class: "flex items-center justify-between") do
            Skeleton(class: "h-4 #{index.zero? ? 'w-36' : 'w-32'} rounded-sm")
            Skeleton(class: "h-4 w-20 rounded-sm")
          end

          div(class: "space-y-2") do
            3.times do |row|
              div(class: "grid grid-cols-12 gap-2") do
                Skeleton(class: "col-span-5 h-16 rounded-md")
                Skeleton(class: "col-span-3 h-16 rounded-md")
                Skeleton(class: "col-span-2 h-16 rounded-md")
                Skeleton(class: "col-span-2 h-16 rounded-md #{'opacity-70' if row == 2}")
              end
            end
          end
        end
      end

      div(class: "space-y-3") do
        Skeleton(class: "h-4 w-28 rounded-sm")
        div(class: "grid grid-cols-2 gap-3 lg:grid-cols-4") do
          4.times do
            Skeleton(class: "h-24 w-full rounded-md")
          end
        end
      end

      div(class: "grid grid-cols-1 gap-2 sm:grid-flow-col sm:auto-cols-fr pt-2") do
        3.times do
          Skeleton(class: "h-10 w-full rounded-md")
        end
      end
    end
  end
end
