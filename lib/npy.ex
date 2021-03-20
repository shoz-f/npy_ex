defmodule Npy do
  @moduledoc """
  Peeking *.npy files.
  """

  alias __MODULE__

  # npy data structure
  defstruct descr: "", fortran_order: false, shape: {}, data: <<>>

  @doc """
  load from npy/npz
  """
  def load(fname, mode \\ :npy) when mode in [:npy, :nx] do
    try do
      case {Path.extname(fname), mode} do
        {".npy", :npy} -> load_npy(fname, &from_bin!/1)
        {".npy", :nx } -> load_npy(fname, &(npy2tensor(from_bin!(&1))))
        {".npz", :npy} -> load_npz(fname, &from_bin!/1)
        {".npz", :nx } -> load_npz(fname, &(npy2tensor(from_bin!(&1))))
        _ -> {:error, "illegal file"}
      end
    rescue
      err in [ArgumentError] -> {:error, err.message}
    end
  end

  defp load_npy(fname, convert) do
    with {:ok, bin} <- File.read(fname) do
      {:ok, convert.(bin)}
    else
      err -> err
    end
  end

  defp load_npz(fname, convert) do
    with {:ok, flist} <- :zip.unzip(String.to_charlist(fname), [:memory]) do
      for {_, bin} <- flist do convert.(bin) end
    else
      err -> err
    end
  end

  defp from_bin!(bin) do
    with <<0x93, "NUMPY", major, _minor, rest::binary>> <- bin do
      {header, body} = case major do
        1 -> <<len::little-16, header::binary-size(len), body::binary>> = rest; {header, body}
        _ -> <<len::little-32, header::binary-size(len), body::binary>> = rest; {header, body}
        end

        descr = case Regex.run(~r/'descr': '([<=|>]?\w+)',/, header) do
          [_, descr] -> descr
          _ -> nil
        end
        fortran_order = case Regex.run(~r/'fortran_order': (True|False),/, header) do
          [_, "True" ] -> true
          [_, "False"] -> false
          _ -> nil
        end
        shape = case Regex.run(~r/'shape': \(((\d+,)|(\d+(, ?\d+)+))\),/, header) do
          [_, shape|_] -> String.split(shape, ~r/, ?/, trim: true) |> Enum.map(&String.to_integer/1) |> List.to_tuple()
          _ -> nil
        end

      %Npy{descr: descr, fortran_order: fortran_order, shape: shape, data: body}
    else
      _ -> raise ArgumentError, message: "illegal npy binary"
    end
  end

  @doc """
  save *.npy
  """
  def save(fname, npy_or_tensor) do
    File.write!(fname, to_bin(npy_or_tensor))
  end

  @doc """
  """
  def savez(fname, npys) when is_list(npys) do
    npz_list = if Keyword.keyword?(npys) do
        Enum.map(npys, fn {key, item} -> {Atom.to_charlist(key)++'.npy', to_bin(item)} end)
      else
        Enum.map(Enum.with_index(npys), fn {item, index} -> {'arr_#{index}.npy', to_bin(item)} end)
      end

    :zip.zip(fname, npz_list)
  end

  @doc """
  """
  def to_bin(%Npy{descr: descr, fortran_order: fortran_order, shape: shape, data: data}) do
    py_tuple = case shape do
      {one} -> "(#{one},)"
      more  -> "(#{Enum.join(Tuple.to_list(more), ", ")})"
    end

    header = "{'descr': '#{descr}', 'fortran_order': #{if fortran_order,do: "True",else: "False"}, 'shape': #{py_tuple}, }"
    header = header <> String.duplicate(" ", 63-rem(byte_size(header)+10, 64)) <> "\n"  # tail padding

    <<0x93,"NUMPY",1,0>> <> <<byte_size(header)::little-integer-16>> <> header <> data
  end

  def to_bin(%Nx.Tensor{}=tensor) do
    to_bin(tensor2npy(tensor))
  end

  @doc """
  convert %Npy{} to nested list
  """
  def to_list(%Npy{descr: descr, shape: shape, data: data}) do
    flat_list = case descr do
      "<f4" -> for <<x::little-float-32 <- data>> do x end
      "<i1" -> for <<x::little-integer-8 <- data>> do x end
      "<i4" -> for <<x::little-integer-32 <- data>> do x end
      _ -> nil
    end

    if (flat_list), do: list_forming(Enum.reverse(Tuple.to_list(shape)), flat_list)
  end

  defp list_forming([_],          formed), do: formed
  defp list_forming([size|shape], formed), do: list_forming(shape, Enum.chunk_every(formed, size))

  @doc """
  convert %Npy{} from nested list
  """
  def from_list(x, descr) when length(x) > 0 do
    to_binary = case descr do
      "<f4" -> fn x,acc -> acc <> <<x::little-float-32>> end
      "<i1" -> fn x,acc -> acc <> <<x::little-integer-8>> end
      "<i4" -> fn x,acc -> acc <> <<x::little-integer-32>> end
      _ -> nil
    end

    if to_binary do
      %Npy{
        descr: descr,
        shape: List.to_tuple(calc_shape(x)),
        data:  Enum.reduce(List.flatten(x), <<>>, to_binary)
      }
    end
  end
  def from_list(_, _), do: nil

  defp calc_shape([item|_]=x), do: [Enum.count(x)|calc_shape(item)]
  defp calc_shape(_),          do: []

  def tensor2npy(%Nx.Tensor{}=tensor) do
    %Npy{
      descr: case Nx.type(tensor) do
        {:s,  8} -> "<i1"
        {:s, 16} -> "<i2"
        {:s, 32} -> "<i4"
        {:s, 64} -> "<i8"
        {:u,  8} -> "<u1"
        {:u, 16} -> "<u2"
        {:u, 32} -> "<u4"
        {:u, 64} -> "<u8"
        {:f, 32} -> "<f4"
        {:f, 64} -> "<f8"
        {:bf,16} -> "<f2"
      end,
      fortran_order: false,
      shape: Nx.shape(tensor),
      data: Nx.to_binary(tensor)
    }
  end

  def npy2tensor(%Npy{}=npy) do
    type = case npy.descr do
      "<i1" -> {:s,  8}
      "<i2" -> {:s, 16}
      "<i4" -> {:s, 32}
      "<i8" -> {:s, 64}
      "<u1" -> {:u,  8}
      "<u2" -> {:u, 16}
      "<u4" -> {:u, 32}
      "<u8" -> {:u, 64}
      "<f4" -> {:f, 32}
      "<f8" -> {:f, 64}
      "<f2" -> {:bf,16}
    end

    Nx.from_binary(npy.data, type)
    |> Nx.reshape(npy.shape)
  end
end
