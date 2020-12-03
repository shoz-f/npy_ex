defmodule Npy do
  @moduledoc """
  Peeking *.npy files.
  """

  alias __MODULE__

  # npy data structure
  defstruct descr: "", fortran_order: false, shape: [], data: <<>>

  @doc """
  load *.npy
  """
  def load(fname) do
    res = File.open(fname, [:read], fn file ->
      with <<0x93, "NUMPY", major, _minor>> <- IO.binread(file, 8)
      do
        header_len = case major do
          1 -> <<len::little-16>> = IO.binread(file, 2); len
          _ -> <<len::little-32>> = IO.binread(file, 4); len
        end

        header = IO.binread(file, header_len)
        descr = case Regex.run(~r/'descr': '([<=|>]?\w+)',/, header) do
          [_, descr] -> descr
          _ -> nil
        end
        fortran_order = case Regex.run(~r/'fortran_order': (True|False),/, header) do
          [_, "True" ] -> true
          [_, "False"] -> false
          _ -> nil
        end
        shape = case Regex.run(~r/'shape': \((\d+(,\s*\d+)*)\),/, header) do
          [_, shape|_] -> String.split(shape, ~r/,\s*/) |> Enum.map(&String.to_integer/1)
          _ -> nil
        end

        {:ok, %Npy{descr: descr, fortran_order: fortran_order, shape: shape, data: IO.binread(file, :all)}}
      else
        _ -> {:error, "illegal npy file"}
      end
    end)

    case res do
      {:ok, fun_res} -> fun_res
      err -> err
    end
  end

  @doc """
  save *.npy
  """
  def save(fname, %Npy{}=npy) do
    meta =
      "{'descr': '#{npy.descr}', 'fortran_order': #{if npy.fortran_order,do: "True",else: "False"}, 'shape': (#{Enum.join(npy.shape, ", ")}), }"
      |> (&(&1 <> String.duplicate(" ", 63-rem(byte_size(&1)+10, 64)) <> "\n")).()
      |> (&(<<0x93,"NUMPY",1,0,byte_size(&1)::little-integer-16>> <> &1)).()

    with {:ok, file} <- File.open(fname, [:write])
    do
      IO.binwrite(file, meta)
      IO.binwrite(file, npy.data)
      File.close(file)
    end
  end

  @doc """
  convert %Npy{} to nested list
  """
  def to_list(%Npy{descr: descr, shape: shape, data: data}) do
    flat_list = case descr do
      "<f4" -> for <<x::little-float-32 <- data>> do x end
      "<i4" -> for <<x::little-integer-32 <- data>> do x end
      _ -> nil
    end

    if (flat_list), do: list_forming(Enum.reverse(shape), flat_list)
  end
  def to_list(_), do: nil

  defp list_forming([_],          formed), do: formed
  defp list_forming([size|shape], formed), do: list_forming(shape, Enum.chunk_every(formed, size))

  @doc """
  convert %Npy{} from nested list
  """
  def from_list(x, descr) when length(x) > 0 do
    to_binary = case descr do
      "<f4" -> fn x,acc -> acc <> <<x::little-float-32>> end
      "<i4" -> fn x,acc -> acc <> <<x::little-integer-32>> end
      _ -> nil
    end

    if to_binary do
      %Npy{
        descr: descr,
        shape: calc_shape(x),
        data:  Enum.reduce(List.flatten(x), <<>>, to_binary)
      }
    end
  end
  def from_list(_, _), do: nil

  defp calc_shape([item|_]=x), do: [Enum.count(x)|calc_shape(item)]
  defp calc_shape(_),          do: []
end
