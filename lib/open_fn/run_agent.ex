defmodule OpenFn.RunAgent do
  use Agent

  alias OpenFn.Run

  defmodule StartOpts do
    @moduledoc false

    # Start Options for OpenFn.RunAgent

    @type t :: %__MODULE__{
            name: GenServer.server(),
            run: Run.t()
          }

    @enforce_keys [:name]
    defstruct @enforce_keys ++ [run: %Run{}]
  end

  @spec start_link(OpenFn.RunAgent.StartOpts.t()) :: {:error, any} | {:ok, pid}
  def start_link(%{name: name, run: run}) do
    Agent.start_link(fn -> run end, name: name)
  end

  def value(agent) do
    Agent.get(agent, & &1)
  end

  def increment do
    Agent.update(__MODULE__, &(&1 + 1))
  end

  def add_log_line(agent, {type, str}) do
    agent |> Agent.cast(&Run.add_log_line(&1, {type, str}))
  end

  def mark_started(agent) do
    agent |> Agent.update(&Run.mark_started/1)
  end

  def mark_finished(agent) do
    agent |> Agent.update(&Run.mark_finished/1)
  end

  def set_result(agent, result) do
    agent |> Agent.update(&Run.set_result(&1, result))
  end

  def add_run_spec(agent, run_spec) do
    agent |> Agent.update(&Run.add_run_spec(&1, run_spec))
  end
end
