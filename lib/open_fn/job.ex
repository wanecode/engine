defmodule OpenFn.Job do
  defstruct [
    :name,
    :expression,
    :credential,
    :language_pack,
    :trigger
  ]

  def new(fields \\ []) do
    struct!(__MODULE__, fields)
  end
end
