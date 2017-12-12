defmodule Machinery.Transition do
  @moduledoc """
  Machinery module responsible for control transitions,
  guard functions and callbacks (before and after).
  It's meant to be for internal use only.
  """

  @doc """
  Function responsible for checking if the transition from a state to another
  was specifically declared.
  """
  @spec declared_transition?(list, atom, atom) :: boolean
  def declared_transition?(transitions, current_state, next_state) do
    case Map.fetch(transitions, current_state) do
      {:ok, [_|_] = declared_states} -> Enum.member?(declared_states, next_state)
      {:ok, declared_state} -> declared_state == next_state
      :error -> false
    end
  end

  @doc """
  Default guard transition fallback to make sure all transitions are permitted
  unless another existing guard condition exists.
  It's meant to be for internal use only.
  """
  @spec guarded_transition?(module, struct, atom) :: boolean
  def guarded_transition?(module, struct, state) do
    run_or_fallback(&module.guard_transition/2, &guard_transition_fallback/2, struct, state)
  end

  @doc """
  Function responsible to run all before_transitions callbacks or
  fallback to a boilerplate behaviour. It's meant to be for internal use only.
  """
  @spec before_callbacks(struct, atom, module) :: struct
  def before_callbacks(struct, state, module) do
    run_or_fallback(&module.before_transition/2, &callbacks_fallback/2, struct, state)
  end

  @doc """
  Function responsible to run all after_transitions callbacks or
  fallback to a boilerplate behaviour. It's meant to be for internal use only.
  """
  @spec after_callbacks(struct, atom, module) :: struct
  def after_callbacks(struct, state, module) do
    run_or_fallback(&module.after_transition/2, &callbacks_fallback/2, struct, state)
  end

  # Private function that receives a function, a callback,
  # a struct and the related state. It tries to execute the function,
  # rescue for a couple of specific Exceptions and passes it forward
  # to the callback, that will re-raise it if not related to
  # guard_transition nor before | after call backs
  defp run_or_fallback(func, callback, struct, state) do
    func.(struct, state)
  rescue
    error in UndefinedFunctionError -> callback.(struct, error)
    error in FunctionClauseError -> callback.(struct, error)
  end

  defp callbacks_fallback(struct, error) do
    if error.function in [:after_transition, :before_transition] && error.arity == 2 do
      struct
    else
      raise error
    end
  end

  # If the exception passed id related to a specific signature of
  # guard_transition/2 it will fallback returning true and
  # allwoing the transition, otherwise it will raise the exception.
  defp guard_transition_fallback(_struct, error) do
    if error.function == :guard_transition && error.arity == 2 do
      true
    else
      raise error
    end
  end
end
