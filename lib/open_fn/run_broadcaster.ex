defmodule OpenFn.RunBroadcaster do
  @moduledoc """
  Responsible for taking a Message, CronTrigger or FlowTrigger and matching
  it to a Job.
  """
  use GenServer

  alias OpenFn.{Config, Matcher, RunDispatcher, Run}

  defmodule StartOpts do
    @moduledoc false

    # Start Options for Quantum.Executor

    @type t :: %__MODULE__{
            config: Config.t(),
            run_dispatcher: GenServer.name(),
            name: GenServer.name()
          }

    @enforce_keys [:name, :run_dispatcher]
    defstruct @enforce_keys ++ [config: %Config{}]
  end

  def start_link(%StartOpts{} = opts) do
    state =
      opts
      |> Map.take([:config, :run_dispatcher])

    GenServer.start_link(__MODULE__, state, name: opts.name)
  end

  def init(config) do
    IO.puts("RunBroadcaster started")
    {:ok, config}
  end

  def handle_call({:handle_message, message}, _from, state) do
    %{config: config, run_dispatcher: run_dispatcher} = state

    triggers = Matcher.get_matches(Config.triggers(config, :criteria), message)

    runs = Config.jobs_for(config, triggers)
    |> Enum.map(fn job ->
      Run.new(job: job, initial_state: message.body)
    end)
    |> Enum.map(&RunDispatcher.invoke_run(run_dispatcher, &1))

    {:reply, runs, state}
  end

  def handle_message(server, message) do
    GenServer.call(server, {:handle_message, message})
  end
end
