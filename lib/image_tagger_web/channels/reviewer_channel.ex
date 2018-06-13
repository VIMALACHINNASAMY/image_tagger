defmodule ImageTaggerWeb.ReviewerChannel do
  @moduledoc false
  alias ImageTagger
  alias ImageTaggerWeb.Presence
  alias ImageTaggerWeb.Presence.LeaveTracker
  use Phoenix.Channel

  @new_image_event "new_image"

  @doc false
  def join("reviewers:" <> id, _message, socket) do
    socket = assign(socket, :id, id)
    send(self(), :after_join)
    {:ok, socket}
  end

  @doc """
  Lets presence trakc the reviewers channel.
  This has the added benefit of allowing Presence to track the channel and handle
  potential crashes, in combination with the `LeaveTracker`.
  We merely track the Reviewers id.
  This combination of values allows us to clean up, should the Reviewers's channel crash.
  """
  def handle_info(:after_join, socket) do
    tracked = %{id: socket.assigns.id}
    {:ok, _} = Presence.track(socket, socket.assigns.id, tracked)
    LeaveTracker.track(socket.assigns.id)
    {:noreply, socket}
  end

  # Pushes an image associated with the given socket if one is available
  # in the ImageServer. Otherwise does nothing.
  defp try_push_image_to_socket(socket) do
    case ImageTagger.fetch_image_to_review(socket.assigns.id) do
      {:ok, url} ->
        count = ImageTagger.images_left()
        online = ImageTagger.reviewers_online()
        response = %{"url" => url, "count" => count, "online" => online}
        push(socket, @new_image_event, response)

      _otherwise ->
        {:noreply, socket}
    end
  end

  @doc false
  def handle_in("poll_image", _msg, socket) do
    try_push_image_to_socket(socket)
    {:noreply, socket}
  end

  @doc false
  def handle_in("submit_review", %{"review" => review_string, "auto_next" => get_next}, socket) do
    # expected to be either :good or :bad
    review = String.to_existing_atom(review_string)
    :ok = ImageTagger.review_image(socket.assigns.id, review)

    if get_next do
      try_push_image_to_socket(socket)
    end

    {:noreply, socket}
  end
end
