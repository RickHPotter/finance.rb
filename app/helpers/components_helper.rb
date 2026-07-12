# frozen_string_literal: true

# Helper for Components
module ComponentsHelper
  # @return [String] tailwind class for input.
  #
  def input_class_without_icon
    "block w-full rounded-md border border-gray-300 bg-white text-gray-900 placeholder:text-gray-400 shadow-xs outline-hidden appearance-none
    text-[0.8rem] sm:text-sm focus:ring-1 focus:ring-indigo-600 focus-visible:outline-none disabled:cursor-not-allowed disabled:bg-gray-100
    dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100 dark:placeholder:text-slate-500 dark:focus:border-sky-500/50
    dark:focus:ring-2 dark:focus:ring-sky-500/60 dark:disabled:bg-slate-800 dark:disabled:opacity-40".squish
  end

  # @return [String] tailwind class for input.
  #
  def input_class
    "block w-full rounded-md border border-gray-300 bg-white ps-12 text-gray-900 placeholder:text-gray-400 shadow-xs outline-hidden appearance-none
    text-[0.8rem] sm:text-sm focus:ring-1 focus:ring-indigo-600 focus-visible:outline-none disabled:cursor-not-allowed disabled:bg-gray-100
    dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100 dark:placeholder:text-slate-500 dark:focus:border-sky-500/50
    dark:focus:ring-2 dark:focus:ring-sky-500/60 dark:disabled:bg-slate-800 dark:disabled:opacity-40".squish
  end

  # @return [String] tailwind class for input.
  #
  def outdoor_input_class
    "w-full rounded-lg border border-transparent bg-transparent px-4 py-3 text-center text-ellipsis text-2xl font-extrabold text-black
    lg:text-3xl xl:text-4xl 2xl:text-5xl focus:border-transparent focus:ring-0 focus:outline-hidden sm:tracking-tight
    dark:border-transparent dark:bg-transparent dark:font-semibold dark:text-slate-100 dark:placeholder:text-slate-600
    dark:focus:border-transparent dark:focus:ring-0".squish
  end

  # @return [String] tailwind class for readonly input.
  #
  def outdoor_readonly_input_class
    "w-full rounded-lg border border-transparent bg-transparent px-4 py-3 text-center text-ellipsis text-lg font-extrabold text-black
    lg:text-2xl xl:text-3xl 2xl:text-4xl focus:border-transparent focus:ring-0 focus:outline-hidden sm:tracking-tight caret-transparent
    dark:border-transparent dark:bg-transparent dark:font-semibold dark:text-slate-300 dark:focus:border-transparent dark:focus:ring-0".squish
  end

  # @return [String] tailwind class for label.
  #
  def label_class
    "mb-2 block text-sm font-medium text-gray-900 dark:text-slate-300"
  end

  # @return [String] tailwind class for form button.
  #
  def form_button_class(options)
    "flex w-full py-2 px-4 justify-center transition duration-500 hover:scale-[1.01] rounded-md border
    #{options[:colour][:border]} #{options[:colour][:bg]} text-sm font-graduate font-medium #{options[:colour][:text]}
    shadow-xs #{options[:colour][:hover][:bg]} #{options[:colour][:hover][:text]} focus:outline-hidden".squish
  end

  def modal_close_button_class
    "text-gray-400 bg-transparent hover:bg-gray-200 hover:text-gray-900 rounded-lg text-sm w-8 h-8 ms-auto " \
      "inline-flex justify-center items-center dark:text-slate-400 dark:hover:bg-slate-800 dark:hover:text-slate-100"
  end

  def bold_label(form, field, id = nil)
    id ||= "#{form.object.model_name.singular}_#{field}"

    form.label field, model_attribute(form.object, field).downcase, class: "font-poetsen-one text-medium font-bold text-gray-500 dark:text-slate-400", for: id
  end

  def thin_label(form, field)
    content_tag :span, model_attribute(form.object, field).downcase, class: "font-poetsen-one font-thin text-gray-500 dark:text-slate-400"
  end
end
