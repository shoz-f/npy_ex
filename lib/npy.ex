defmodule Npy do
  @moduledoc """
  Reading and writing array to Python npy/npz format file.

  You can exchange matrix data - %Npy or %Nx.Tensor - with Python through npy/npz file.

  ## Examples
  You make a uniform random tensor and save it to "random.npy" under Elixir.

      [elixir]
      iex(1)> t = Nx.random_uniform({5,5})
      #Nx.Tensor<
        f32[5][5]
        [
          [0.9286868572235107, 0.8993584513664246, 0.09174104034900665, 0.1891217827796936, 0.3033398985862732],
          [0.6039875745773315, 0.1656373143196106, 0.6622694134712219, 0.4383099675178528, 0.2207845151424408],
          [0.08031792938709259, 0.05638507753610611, 0.4931488037109375, 0.6378694772720337, 0.5468790531158447],
          [0.6913296580314636, 0.5027941465377808, 0.05995653197169304, 0.3467581272125244, 0.8337613940238953],
          [0.48116567730903625, 0.7345675826072693, 0.4312438666820526, 0.5565636157989502, 0.27805331349372864]
        ]
      >
      iex(2)> Npy.save("random.npy", t)
      :ok

  And then, you can read "random.npy" in Python.

      [python]
      >>> import numpy as np
      >>> t = np.load("random.npy")
      >>> print(t)
      [[0.92868686 0.89935845 0.09174104 0.18912178 0.3033399 ]
       [0.6039876  0.16563731 0.6622694  0.43830997 0.22078452]
       [0.08031793 0.05638508 0.4931488  0.6378695  0.54687905]
       [0.69132966 0.50279415 0.05995653 0.34675813 0.8337614 ]
       [0.48116568 0.7345676  0.43124387 0.5565636  0.2780533 ]]
  """

  alias __MODULE__

  # npy data structure
  defstruct descr: "", fortran_order: false, shape: {}, data: <<>>

  @doc """
  Load array from npy/npz and convert it to %Npy.

  ## Parameters

    * fname : file name. `load/1` returns a list of %Npy for "xxx.npz".

  ## Examples

      iex> Npy.load("sample.npy")
      {:ok, %Npy{...}}

      iex> Npy.load("sample.npz")
      {:ok, [%Npy{...}, %Npy{...}, ...]}

 """
  def load(fname) do
    try do
      case Path.extname(fname) do
        ".npy" -> load_npy(fname, &from_bin!/1)
        ".npz" -> load_npz(fname, &from_bin!/1)
        _ -> {:error, "illegal file"}
      end
    rescue
      err in [ArgumentError] -> {:error, err.message}
    end
  end

  def load!(fname) do
    case load(fname) do
      {:ok, obj} -> obj
      {:error, _} -> raise "illegal file"
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

  @doc """
  Convert npy format binary to %Npy.

  ## Examples

      iex> Npy.from_bin!(npy_bin)
      %Npy{...}
  """
  def from_bin!(bin) do
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
  Save %Npy to npy file.

  ## Examples

      iex> Npy.save(%Npy{}, "sample.npy")
      :ok

  """
  def save(npy, fname) do
    File.write!(fname, to_bin(npy))
  end

  @doc """
  Save a list of %Npy to npz file.

  ## Examples

      iex> Npy.savez([%Npy{}, %Npy{}, ...], "sample.npz")
      {:ok, "sample.npz"}
  """
  def savez(npys, fname) when is_list(npys) do
    npz_list =
      if Keyword.keyword?(npys) do
        Enum.map(npys, fn {key, item} -> {Atom.to_charlist(key)++'.npy', to_bin(item)} end)
      else
        Enum.map(Enum.with_index(npys), fn {item, index} -> {'arr_#{index}.npy', to_bin(item)} end)
      end

    :zip.zip(fname, npz_list)
  end

  @doc """
  Save a %Npy to CSV file.

  For %Npy which has tow or one dimensonal shape.

  ## Examples

      iex> Npy.savecsv(%Npy{shape: {100, 20}}, "sample.csv")
  """
  def savecsv(npy, fname) do
    File.write!(fname, to_csv(npy))
  end

  @doc """
  Convert %Npy to npy binary.

  ## Examples

      iex> Npy.to_bin(%Npy{})
      <<....>>

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

  @doc """
  Convert %Npy to npy binary.

  ## Examples

      iex> Npy.to_bin(%Npy{})
      <<....>>

  """
  def to_csv(%Npy{descr: descr, shape: {_, x}, data: data}) do
    make_csv = fn flat_list, to_string ->
      Enum.chunk_every(flat_list, x)
      |> Enum.reduce("", fn row,acc ->
           acc <> (Enum.map(row, to_string) |> Enum.join(",")) <> "\n"
         end)
    end

    case descr do
      "<f4" -> make_csv.(for <<x::little-float-32 <- data>> do x end, &Float.to_string/1)
      "<i1" -> make_csv.(for <<x::signed-little-integer-8 <- data>> do x end, &Integer.to_string/1)
      "<i4" -> make_csv.(for <<x::signed-little-integer-32 <- data>> do x end, &Integer.to_string/1)
      "<u1" -> make_csv.(for <<x::little-integer-8 <- data>> do x end, &Integer.to_string/1)
      _ -> nil
    end
  end

  def to_csv(%Npy{shape: {y}}=npy) do
    to_csv(%Npy{npy| shape: {y, 1}})
  end

  @doc """
  Convert %Npy to a matrix list.

  ## Examples

      iex> Npy.to_list(%Npy{})
      [
        [
          [4.384970664978027, ...],
          ...
        ],
        ...
      ]
  """
  def to_list(%Npy{descr: descr, shape: shape, data: data}) do
    flat_list = case descr do
      "<f4" -> for <<x::little-float-32 <- data>> do x end
      "<i1" -> for <<x::signed-little-integer-8 <- data>> do x end
      "<i4" -> for <<x::signed-little-integer-32 <- data>> do x end
      "<u1" -> for <<x::little-integer-8 <- data>> do x end
      _ -> nil
    end

    if (flat_list), do: list_forming(Enum.reverse(Tuple.to_list(shape)), flat_list)
  end

  defp list_forming([_],          formed), do: formed
  defp list_forming([size|shape], formed), do: list_forming(shape, Enum.chunk_every(formed, size))

  @doc """
  Convert a matrix list to %Npy{descr: 'descr', ...}.

  ## Parameters

    * list : matrix list
    * descr : data type
      - `"<f4"` - float 32bit
      - `"<i1"` - integer 8bit
      - `"<i4"` - integer 32bit

  ## Examples

      iex> Npy.from_list([[[4.384970664978027, ...], ...], ...], "<f4")
      %Npy{...}
  """
  def from_list(list, descr) when length(list) > 0 do
    to_binary = case descr do
      "<f4" -> fn val,acc -> acc <> <<val::little-float-32>> end
      "<i1" -> fn val,acc -> acc <> <<val::little-integer-8>> end
      "<i4" -> fn val,acc -> acc <> <<val::little-integer-32>> end
      _ -> nil
    end

    if to_binary do
      %Npy{
        descr: descr,
        shape: List.to_tuple(calc_shape(list)),
        data:  Enum.reduce(List.flatten(list), <<>>, to_binary)
      }
    end
  end
  def from_list(_, _), do: nil

  defp calc_shape([item|_]=x), do: [Enum.count(x)|calc_shape(item)]
  defp calc_shape(_),          do: []

  # @doc """
  # Transpose axes.

  # ## Examples

  #     iex> Npy.transpose(npy, [2, 0, 1])
  # """
  # def transpose(%Nx.Tensor{}=tensor, axes) do
  #   Nx.transpose(tensor, axes: axes)
  # end

  # def transpose(%Npy{}=npy, axes) do
  #   npy2tensor(npy) |> transpose(axes) |> tensor2npy()
  # end

  @doc """
  """
  def squeeze(%Npy{shape: shape}=npy) do
    shape = Tuple.to_list(shape)
      |> Enum.filter(&(&1 != 1))
      |> List.to_tuple()
    %Npy{npy | shape: shape}
  end
end
