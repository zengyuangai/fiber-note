class NoteChannel < ApplicationCable::Channel
  def subscribed
    # initialize is not enough due to concurrent racing
    @note = Block.notes.find_or_create_by(
      id: params[:id],
      title: params[:title],
      is_note: true,
    )

    stream_for @note
  end

  # def unsubscribed
  # end

  # TODO
  # - handle new title empty
  # 
  # data:
  #   note:
  #     id
  #     title
  def update_title data
    old_title = @note.title
    title = data['note']['title']

    Blocks::UpdateTitleService.new(@note, title).perform!

    unless Block.with_any_tags(old_title).empty?
      Blocks::UpdateTagsService.new(old_title, title).perform!
    end

    broadcast_to @note, {
      event: 'title_updated',
      requested_at: data['requested_at']
    }
  rescue Blocks::UpdateTitleService::DuplicateTitleError
    broadcast_to @note, {
      event: 'title_duplicated',
      requested_at: data['requested_at'],
      data: {
        duplicated_title: title
      }
    }
  end

  # data:
  #   note:
  #     id
  #     blocks:
  #       [
  #         
  #       ]
  def update_blocks data
    child_blocks = data['note']['blocks']

    child_blocks.each do |block|
      Blocks::CreateOrUpdateService.new(block, @note).perform!
    end
    @note.update! child_block_ids: child_blocks.map{|b| b['attrs']['block_id'] }

    broadcast_to @note, { event: 'blocks_updated', requested_at: data['requested_at'] }
  end
end
