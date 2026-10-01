defmodule Raifu.Terminal do
  @moduledoc """
  Terminal settings and the ANSI escape sequences used to draw.
  """

  @doc """
  The size of the terminal behind `device` as `{columns, rows}`, or
  `fallback` when it is not a terminal.
  """
  @spec size(IO.device(), {pos_integer(), pos_integer()}) :: {pos_integer(), pos_integer()}
  def size(device \\ :stdio, fallback \\ {80, 24}) do
    # :stdio is Elixir's name for Erlang's :standard_io.
    device = if device == :stdio, do: :standard_io, else: device

    with {:ok, columns} <- :io.columns(device),
         {:ok, rows} <- :io.rows(device) do
      {columns, rows}
    else
      _not_a_terminal -> fallback
    end
  end

  @doc """
  Puts the terminal in raw mode: key presses are received one by one, as soon
  as they are typed, and are not echoed. Relies on the `-noshell` raw mode
  introduced in OTP 28, so it only works outside of IEx.

  That raw mode keeps signal keys on, so this also runs `stty -isig`: Ctrl+C
  then reaches us as a key press, instead of stopping the whole VM in its
  break menu.
  """
  @spec raw_mode() :: :ok | {:error, term()}
  def raw_mode do
    with :ok <- :shell.start_interactive({:noshell, :raw}) do
      stty(["-isig"])
    end
  end

  @doc "Brings the terminal back from raw mode."
  @spec cooked_mode() :: :ok | {:error, term()}
  def cooked_mode do
    stty(["isig"])
    :shell.start_interactive({:noshell, :cooked})
  end

  # Best effort: without stty, Ctrl+C keeps its default behaviour. With
  # :nouse_stdio, the port talks to stty through other file descriptors, so
  # stty inherits the standard input of the VM: our terminal.
  defp stty(args) do
    case System.find_executable("stty") do
      nil ->
        :ok

      stty ->
        port = Port.open({:spawn_executable, stty}, [:nouse_stdio, :exit_status, args: args])

        receive do
          {^port, {:exit_status, _status}} -> :ok
        end
    end
  end

  @doc "Switches to the alternate screen and hides the cursor."
  @spec enter() :: iodata()
  def enter, do: ["\e[?1049h", "\e[?25l", clear()]

  @doc "Switches back to the main screen and shows the cursor."
  @spec leave() :: iodata()
  def leave, do: [reset(), clear(), "\e[?25h", "\e[?1049l"]

  @doc "Clears the screen."
  @spec clear() :: iodata()
  def clear, do: [reset(), "\e[2J"]

  @doc "Moves the cursor to `row` and `column`, both starting at 1."
  @spec move(pos_integer(), pos_integer()) :: iodata()
  def move(row, column), do: ["\e[", Integer.to_string(row), ?;, Integer.to_string(column), ?H]

  @doc "Resets colors and styles."
  @spec reset() :: iodata()
  def reset, do: "\e[0m"

  @doc "Clears from the cursor to the end of the line, with the current background."
  @spec clear_line() :: iodata()
  def clear_line, do: "\e[K"

  @doc """
  Wraps a frame so that terminals supporting synchronized output display it
  all at once, without tearing. Others ignore these sequences.
  """
  @spec synchronized(iodata()) :: iodata()
  def synchronized(frame), do: ["\e[?2026h", frame, "\e[?2026l"]
end
