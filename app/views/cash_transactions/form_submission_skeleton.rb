# frozen_string_literal: true

class Views::CashTransactions::FormSubmissionSkeleton < Views::Base
  def view_template
    div(class: "space-y-6", id: "cash_transaction_form_submission_skeleton") do
      div(class: "flex justify-center") do
        Skeleton(class: "h-7 w-28 rounded-sm")
      end

      div(class: "space-y-6") do
        Skeleton(class: "h-12 w-full rounded-md")
        Skeleton(class: "h-24 w-full rounded-lg")
      end

      div(class: "space-y-3") do
        div(class: "grid grid-cols-1 gap-3 lg:grid-cols-12") do
          div(class: "space-y-2 lg:col-span-2") do
            Skeleton(class: "h-10 w-full rounded-md")
          end

          div(class: "space-y-2 lg:col-span-3") do
            div(class: "grid grid-cols-2 gap-2") do
              2.times do
                Skeleton(class: "h-10 w-full rounded-md")
              end
            end
          end

          div(class: "space-y-2 lg:col-span-2") do
            Skeleton(class: "h-10 w-full rounded-md")
          end

          div(class: "space-y-2 lg:col-span-2") do
            Skeleton(class: "h-10 w-full rounded-md")
            Skeleton(class: "h-4 w-24 rounded-sm")
          end

          div(class: "space-y-2 lg:col-span-3") do
            div(class: "grid grid-cols-12 gap-1") do
              Skeleton(class: "col-span-1 h-10 w-full rounded-md lg:hidden")
              Skeleton(class: "col-span-7 h-10 w-full rounded-md")
              Skeleton(class: "col-span-1 h-10 w-full rounded-md")
              Skeleton(class: "col-span-3 h-10 w-full rounded-md")
            end
          end
        end
      end

      div(class: "space-y-2") do
        div(class: "grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-4") do
          4.times do
            div(class: "space-y-3 rounded-lg border border-gray-200 p-3") do
              Skeleton(class: "h-5 w-16 rounded-sm")
              Skeleton(class: "h-10 w-full rounded-md")
              Skeleton(class: "h-10 w-full rounded-md")
              Skeleton(class: "h-5 w-24 rounded-sm")
            end
          end
        end
      end

      section_strip_skeleton(widths: %w[w-36 w-44 w-40])
      section_strip_skeleton(widths: %w[w-44 w-48 w-40])

      div(class: "space-y-3") do
        Skeleton(class: "mx-auto h-5 w-32 rounded-sm")

        div(class: "grid grid-cols-1 gap-2 sm:grid-flow-col sm:auto-cols-fr items-center justify-items-center mx-auto w-full") do
          3.times do
            Skeleton(class: "h-10 w-64 rounded-md")
          end
        end
      end
    end
  end

  private

  def section_strip_skeleton(widths:)
    div(class: "space-y-2") do
      div(class: "flex gap-2 overflow-hidden pb-3") do
        widths.each do |width|
          Skeleton(class: "h-10 #{width} shrink-0 rounded-md")
        end
      end
    end
  end
end
