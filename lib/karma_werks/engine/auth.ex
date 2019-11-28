defmodule KarmaWerks.Engine.Auth do
  @moduledoc """
  Authentication management services
  """
  import ShorterMaps
  alias KarmaWerks.Engine.Helpers

  @type registration_input :: %{
          name: String.t(),
          email: String.t(),
          bio: String.t(),
          password: String.t()
        }

  @doc """
  Creates a new user.

  TODO: Use upsert for testing for uniqueness
  """
  @spec register_user(registration_input) :: {:ok, map()} | {:error, any()}
  def register_user(%{"name" => _, "email" => email, "bio" => _, "password" => _} = payload) do
    with {:email, nil} <- {:email, get_user_by_email(email)} do
      Dlex.mutate(:karma_werks, payload |> Map.merge(%{"type" => "User"}))
    else
      {:email, _} -> {:error, "User with email #{email} already exists"}
      _ -> {:error, "Error in registration"}
    end
  end

  @doc """
  Fetches the user with matching `uid`. Returns `nil` if user not found.
  """
  @spec get_user_by_uid(String.t()) :: map() | nil
  def get_user_by_uid(uid) do
    query = ~s/{
      result (func: uid(#{uid})) @recurse {
        uid
        name
        email
        bio
        password
        type
        groups : ~members
        description
        ~asignees
        ~owner
      }
    }/ |> Helpers.format()

    case Dlex.query(:karma_werks, query) do
      {:ok, %{"result" => [node]}} when map_size(node) > 1 -> node
      _ -> nil
    end
  end

  @doc """
  Fetches user(s) with matching criteria.
  """
  @spec get_user_by(String.t(), String.t()) :: {:ok, [map()]} | {:error, any}
  def get_user_by(attribute, value) do
    query = ~s/{
      result (func: eq(#{attribute}, "#{value}")) {
        uid
        name
        email
        bio
        type
      }
    }/ |> String.replace("\n", "")

    case Dlex.query(:karma_werks, query) do
      {:ok, %{"result" => result}} -> {:ok, result}
      error -> error
    end
  end

  @doc """
  Returns the user with matching `email`, `nil` otherwise.
  """
  @spec get_user_by_email(String.t()) :: nil | map()
  def get_user_by_email(email) do
    case get_user_by("email", email) do
      {:ok, [result]} -> result
      _ -> nil
    end
  end

  @doc """
  Deletes the user with matching `uid`.

  TODO: This function will go away
  """
  @spec delete_user(String.t()) :: {:ok, map()} | {:error, any()}
  def delete_user(uid) do
    Dlex.delete(:karma_werks, ~m/uid/)
  end

  @doc """
  Updates user matching `uid` based on data given in `params`.
  """
  @spec update_user(String.t(), map()) :: {:ok, map()} | {:error, any}
  def update_user(uid, fields) do
    uid
    |> get_user_by_uid()
    |> Map.merge(fields)
    |> (fn d -> Dlex.mutate(:karma_werks, d) end).()
  end

  @doc """
  Tests if the password succeeds for user with email `email`.
  """
  @spec authenticate(String.t(), String.t()) :: bool
  def authenticate(email, password) do
    query = ~s/{
      result (func: eq(email, "#{email}")) {
        checkpwd(password, "#{password}")
      }
    }/ |> Helpers.format()

    {:ok, %{"result" => [%{"checkpwd(password)" => result}]}} = Dlex.query(:karma_werks, query)

    result
  end

  @doc """
  Changes password of the user given old and new password and email. It will attempt to change
  password only if the old password manages to succeed for email given.
  """
  @spec change_password(String.t(), String.t(), String.t()) :: {:ok, map()} | {:error, any}
  def change_password(email, old_password, password) do
    if authenticate(email, old_password) do
      case get_user_by_email(email) do
        %{"uid" => uid} -> update_user(uid, ~m/password/)
        _ -> {:error, "Error"}
      end
    else
      {:error, "Wrong password provided"}
    end
  end

  def prefixed_keys(params, prefix) do
    params
    |> Map.to_list()
    |> Enum.map(fn {k, v} ->
      {prefix <> to_string(k), v}
    end)
    |> Enum.into(%{})
  end
end