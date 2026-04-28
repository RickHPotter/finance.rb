# frozen_string_literal: true

class Views::CashTransactions::FormSubmissionSkeleton < Views::Base
  def view_template
    div(class: "space-y-5", id: "cash_transaction_form_submission_skeleton") do
      div(class: "flex justify-center") do
        Skeleton(class: "h-7 w-28 rounded-sm")
      end

      div(class: "space-y-5") do
        Skeleton(class: "h-12 w-full rounded-md")
        Skeleton(class: "h-24 w-full rounded-lg")
      end

      div(class: "space-y-3") do
        div(class: "grid grid-cols-1 gap-3 lg:grid-cols-12") do
          div(class: "lg:col-span-2") do
            Skeleton(class: "h-10 w-full rounded-md")
          end

          div(class: "lg:col-span-3") do
            div(class: "grid grid-cols-2 gap-2") do
              2.times do
                Skeleton(class: "h-10 w-full rounded-md")
              end
            end
          end

          div(class: "lg:col-span-2") do
            Skeleton(class: "h-10 w-full rounded-md")
          end

          div(class: "space-y-2 lg:col-span-2") do
            Skeleton(class: "h-10 w-full rounded-md")
            Skeleton(class: "h-4 w-20 rounded-sm")
          end

          div(class: "lg:col-span-3") do
            div(class: "grid grid-cols-12 gap-1") do
              Skeleton(class: "col-span-1 h-10 w-full rounded-md lg:hidden")
              Skeleton(class: "col-span-7 h-10 w-full rounded-md")
              Skeleton(class: "col-span-1 h-10 w-full rounded-md")
              Skeleton(class: "col-span-3 h-10 w-full rounded-md")
            end
          end
        end
      end

      render_installments_skeleton

      div(class: "mb-2 grid grid-cols-1 gap-2 items-stretch md:grid-cols-2 md:gap-0") do
        render_collection_section_skeleton(border_class: "border-y border-purple-200 py-2 md:border-r md:pr-2")
        render_collection_section_skeleton(border_class: "border-y border-purple-200 py-2 md:border-l md:pl-2")
      end

      div(class: "space-y-3") do
        Skeleton(class: "mx-auto h-5 w-36 rounded-sm")

        div(class: "grid grid-cols-1 gap-2 sm:grid-flow-col sm:auto-cols-fr items-center justify-items-center mx-auto w-full") do
          3.times do
            Skeleton(class: "h-10 w-64 rounded-md")
          end
        end
      end
    end
  end

  private

  def render_installments_skeleton
    div(class: "space-y-2 border-t border-purple-200 py-1") do
      div(class: "grid grid-cols-[1.5rem_minmax(0,1fr)_1.5rem] items-stretch gap-3") do
        div(class: "grid grid-rows-2 gap-3") do
          Skeleton(class: "h-full min-h-12 w-full rounded-lg")
          Skeleton(class: "h-full min-h-12 w-full rounded-lg")
        end

        div(class: "overflow-hidden") do
          div(class: "flex -ml-1") do
            4.times do
              div(class: "min-w-0 shrink-0 grow-0 basis-full pl-3 md:basis-1/2 lg:basis-1/3 xl:basis-1/4") do
                div(class: "space-y-3 rounded-lg border border-purple-200 p-3") do
                  div(class: "flex justify-center") do
                    Skeleton(class: "h-5 w-16 rounded-sm")
                  end
                  Skeleton(class: "h-10 w-full rounded-md")
                  Skeleton(class: "h-10 w-4/5 rounded-md")
                end
              end
            end
          end
        end

        div(class: "grid grid-rows-2 gap-3") do
          Skeleton(class: "h-full min-h-12 w-full rounded-lg")
          Skeleton(class: "h-full min-h-12 w-full rounded-lg")
        end
      end
    end
  end

  def render_collection_section_skeleton(border_class:)
    div(class: border_class) do
      div(class: "grid grid-cols-[1.5rem_minmax(0,1fr)_1.5rem] items-stretch gap-2") do
        Skeleton(class: "h-full min-h-12 w-full rounded-lg bg-purple-100")

        div(class: "overflow-hidden") do
          div(class: "flex gap-2") do
            3.times do |index|
              width = %w[w-36 w-44 w-40][index]
              Skeleton(class: "h-12 #{width} shrink-0 rounded-sm bg-purple-100")
            end
          end
        end

        Skeleton(class: "h-full min-h-12 w-full rounded-lg bg-purple-100")
      end
    end
  end
end
