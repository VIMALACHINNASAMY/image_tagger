defmodule ImageTagger.ReviewServer do
  @moduledoc """
  Server keeping track of all the images
  that are currently being reviewed.

  Implemented as a map of {<reviewer id> => image}
  """
  alias ExAws
  use GenServer

  @doc """
  Starts the ImageServer as a singleton registered
  with the name of the module.

  ## Examples
  iex> {:ok, pid} = ImageTagger.ReviewServer.start_link()
  {:ok, #PID<0.246.0>}

  """
  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc false
  def init(:ok) do
    {:ok, %{}}
  end

  # Moves the given image from src into the given folder.
  defp move_image_to_folder(image_src, folder) do
    bucket = Application.fetch_env!(:image_tagger, :bucket_name)
    name = Path.basename(image_src)
    image_dst = Path.join(folder, name)
    bucket |> ExAws.S3.put_object_copy(image_dst, bucket, image_src) |> ExAws.request()
    bucket |> ExAws.S3.delete_object(image_src) |> ExAws.request()
  end

  @doc """
  Archives the given image, copying it to the 'bad' folder.
  """
  def archive_image(image, :good) do
    folder = Application.fetch_env!(:image_tagger, :good_folder)
    move_image_to_folder(image, folder)
  end

  @doc """
  Archives the given image, copying it to the 'good' folder.
  """
  def archive_image(image, :bad) do
    folder = Application.fetch_env!(:image_tagger, :bad_folder)
    move_image_to_folder(image, folder)
  end

  @doc """
  Adds an image to the ReviewServer signifying that it
  is currently being reviewed.
  Returns :ok
  """
  def handle_call({:add_image, reviewer, image}, _from, state) do
    {:reply, :ok, Map.put(state, reviewer, image)}
  end

  @doc """
  Adds a review for an image, causing it to be removed
  from the ReviewServer and moved to the appropriate folder
  based on the review.

  Expects the reviewer and the review. The image will be found
  based on the reviewer's id.

  Returns: :ok
  """
  def handle_call({:review_image, reviewer, review}, _from, state) do
    if Map.has_key?(state, reviewer) do
      image = state[reviewer]
      archive_image(image, review)
    end
    {:reply, :ok, Map.delete(state, image)}
  end

  @doc """
  Returns the size of the state.
  """
  def handle_call(:get_count, _from, state) do
    {:reply, map_size(state), state}
  end

  @doc """
  Returns the size of the state.
  """
  def handle_call(:get_images, _from, state) do
    {:reply, Map.keys(state), state}
  end

  @doc """
  Removes the given reviewer from the state.
  """
  def handle_cast({:remove_reviewer, id}, state) do
    {:noreply, Map.delete(state, id)}
  end

  @doc """
  Retrieves the current amount of images in the ImageServer.

  ## Examples

  iex> ImageTagger.ReviewServer.get_count()
  5
  """
  def get_count() do
    GenServer.call(__MODULE__, :get_count)
  end

  @doc """
  Retrieves all the keys from the state,
  meaning all the keys for the images associated
  with all the active reviewers.

  ## Examples

  iex> ImageTagger.ReviewServer.get_count()
  5
  """
  def get_images() do
    GenServer.call(__MODULE__, :get_images)
  end

  @doc """
  Removes the reviewer associated with the given id from the state.

  ## Examples

  iex> ImageTagger.ReviewServer.remove_reviewer("reviewer_id")
  """
  def remove_reviewer(id) do
    GenServer.cast(__MODULE__, {:remove_reviewer, id})
  end


  @doc """
  Adds a review for an image.
  The image is removed from the ReviewServer and moved to
  a folder according to the reivew.

  ## Examples

  iex> ImageTagger.ReviewServer.review_image("some_user_id", :good)
  :ok
  iex> ImageTagger.ReviewServer.review_image("some_user_id", :bad)
  :ok
  """
  def review_image(reviewer, review) do
    GenServer.call(__MODULE__, {:review_image, reviewer, review})
  end


  @doc """
  Associates a reviewer with an image.
  currently being reviewed.

  ## Examples

  iex> ImageTagger.ReviewServer.add_image("some_user_id", "to_review/image1234.png")
  :ok
  """
  def add_image(reviewer, image) do
    GenServer.call(__MODULE__, {:add_image, reviewer, image})
  end
end
