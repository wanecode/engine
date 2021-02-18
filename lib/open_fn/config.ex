defmodule OpenFn.Config do
  @moduledoc """
  Configuration for an Engine process, parse/1 expects either a schema-based
  path or a string.

  A config file has the following structure:

  ```yaml
  jobs:
    job-one:
      expression: >
        alterState((state) => {
          console.log("Hi there!")
          return state;
        })
      language_pack: '@openfn/language-common'
      trigger: trigger-one

  triggers:
    trigger-one:
      criteria: '{"foo": "bar"}'
    ...
  ```

  ## Top Level Elements

  ### jobs

  A list of jobs that can be executed, key'ed by their name.

  The jobs key name must be URL safe.

  **expression**

  A string representing the JS expression that gets executed.

  **language_pack**

  The module to be used when executing the job. The module parameter is expected
  to be compatible with NodeJS' `require` schemantics.
  Assuming the modules were installed via NPM, the parameter looks like this:
  `@openfn/language-common`.

  This gets passed to the `--language` option in the core runtime.

  **trigger**

  The name of the trigger defined elsewhere in to the configuration.

  ### triggers

  The list of available triggers. Like `jobs`, they are key'ed by a URL safe name.

  **criteria**

  A JSON style matcher, which performs a 'contains' operation.

  In this example JSON message, we want to trigger when it contains a specific
  key/value pair.

  ```
  {"foo": "bar", "baz": "quux"}
  ```
  A criteria of `{"foo": "bar"}` would satisfy this test.

  ```
  {"foo": "bar", "baz": {"quux": 5}}
  ```
  A criteria of `{"baz": {"quux": 5}}` would also match this test.

  **cron**

  A cron matcher, which gets triggered at the interval specified.

  """

  defstruct jobs: [], triggers: []
  @type t :: %__MODULE__{jobs: any(), triggers: any()}

  alias OpenFn.{CriteriaTrigger, CronTrigger, Job}

  def new(fields) do
    struct!(__MODULE__, fields)
  end

  def parse!(any) do
    {:ok, config} = parse(any)
    config
  end

  @doc """
  Parse a config YAML file from the filesystem.
  """
  def parse("file://" <> path) do
    YamlElixir.read_from_file(path)
    |> case do
      {:ok, data} ->
        {:ok, __MODULE__.from_map(data)}

      any ->
        any
    end
  end

  @doc """
  Parse a config string of YAML.
  """
  def parse(str) do
    {:ok, data} = YamlElixir.read_from_string(str)

    {:ok, data |> __MODULE__.from_map()}
  end

  @doc """
  Cast a serialisable map of config into a Config struct.
  """
  @spec from_map(map) :: Engine.Config.t()
  def from_map(data) do
    trigger_data = data["triggers"]
    job_data = data["jobs"]

    triggers =
      for {name, trigger_opts} <- trigger_data, into: [] do
        case Map.keys(trigger_opts) do
          ["criteria"] ->
            {:ok, criteria} = Jason.decode(Map.get(trigger_opts, "criteria"))
            %CriteriaTrigger{name: name, criteria: criteria}

          ["cron"] ->
            %CronTrigger{name: name, cron: Map.get(trigger_opts, "cron")}
        end
      end

    jobs =
      for {name, job_opts} <- job_data, into: [] do
        %Job{
          name: name,
          trigger: Map.get(job_opts, "trigger"),
          language_pack: Map.get(job_opts, "language_pack"),
          expression: Map.get(job_opts, "expression")
        }
      end

    %__MODULE__{
      jobs: jobs,
      triggers: triggers
    }
  end

  def jobs_for(%__MODULE__{} = config, triggers) do
    Enum.filter(config.jobs, fn j ->
      Enum.any?(triggers, fn t ->
        t.name == j.trigger
      end)
    end)
  end

  def triggers(%__MODULE__{} = config, type) do
    Enum.filter(
      config.triggers,
      case type do
        :cron -> fn t -> t.__struct__ == CronTrigger end
        :criteria -> fn t -> t.__struct__ == CriteriaTrigger end
      end
    )
  end
end
