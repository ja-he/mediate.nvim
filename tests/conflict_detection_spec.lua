local conflict = require('mediate.conflict')

describe('conflict detection', function()
  -- Helper to create a buffer with given lines
  local function create_buffer(lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    return bufnr
  end

  -- Helper to clean up buffer
  local function delete_buffer(bufnr)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  describe('parse_conflict', function()
    it('detects simple diff2 style conflict', function()
      local bufnr = create_buffer({
        '<<<<<<< HEAD',
        'ours line 1',
        'ours line 2',
        '=======',
        'theirs line 1',
        'theirs line 2',
        '>>>>>>> branch',
      })

      local result, err = conflict.parse_conflict(bufnr, 1)
      assert.is_nil(err)
      assert.is_not_nil(result)
      assert.is_false(result.is_diff3)
      assert.are.equal(1, result.start_line)
      assert.are.equal(7, result.end_line)
      assert.are.same({ 2, 3 }, result.ours_range)
      assert.are.same({ 5, 6 }, result.theirs_range)

      delete_buffer(bufnr)
    end)

    it('detects diff3 style conflict', function()
      local bufnr = create_buffer({
        '<<<<<<< HEAD',
        'ours line',
        '||||||| base',
        'base line',
        '=======',
        'theirs line',
        '>>>>>>> branch',
      })

      local result, err = conflict.parse_conflict(bufnr, 1)
      assert.is_nil(err)
      assert.is_not_nil(result)
      assert.is_true(result.is_diff3)
      assert.are.same({ 2, 2 }, result.ours_range)
      assert.are.same({ 4, 4 }, result.base_range)
      assert.are.same({ 6, 6 }, result.theirs_range)

      delete_buffer(bufnr)
    end)

    it('returns error when not starting at conflict marker', function()
      local bufnr = create_buffer({
        'not a conflict',
        '<<<<<<< HEAD',
      })

      local result, err = conflict.parse_conflict(bufnr, 1)
      assert.is_nil(result)
      assert.is_not_nil(err)
      assert.matches('not a conflict start marker', err)

      delete_buffer(bufnr)
    end)

    it('returns error for missing end marker', function()
      local bufnr = create_buffer({
        '<<<<<<< HEAD',
        'ours',
        '=======',
        'theirs',
      })

      local result, err = conflict.parse_conflict(bufnr, 1)
      assert.is_nil(result)
      assert.matches('could not find conflict end marker', err)

      delete_buffer(bufnr)
    end)

    it('handles conflict not starting at line 1', function()
      local bufnr = create_buffer({
        'some code',
        'more code',
        '<<<<<<< HEAD',
        'ours',
        '=======',
        'theirs',
        '>>>>>>> branch',
      })

      local result, err = conflict.parse_conflict(bufnr, 3)
      assert.is_nil(err)
      assert.are.equal(3, result.start_line)
      assert.are.equal(7, result.end_line)

      delete_buffer(bufnr)
    end)
  end)

  describe('extract_range', function()
    it('extracts lines from range', function()
      local bufnr = create_buffer({ 'a', 'b', 'c', 'd', 'e' })
      local result = conflict.extract_range(bufnr, { 2, 4 })
      assert.are.same({ 'b', 'c', 'd' }, result)
      delete_buffer(bufnr)
    end)

    it('handles empty range', function()
      local bufnr = create_buffer({ 'a', 'b', 'c' })
      local result = conflict.extract_range(bufnr, { 2, 1 })
      assert.are.same({}, result)
      delete_buffer(bufnr)
    end)
  end)

  describe('multiple-tests-example-case', function()
    local bufnr = create_buffer({
      '<<<<<<< HEAD (or current branch/ref)',
      'Your current changes',
      '=======',
      'Incoming changes',
      '>>>>>>> branch-name (or commit ref)',
      '```',
      '',
      '- `<<<<<<<` marks the start of the conflict (your version)',
      '- `=======` separates the two versions',
      '- `>>>>>>>` marks the end of the conflict (their version)',
      '',
      '## diff3 Style',
      '',
      'When configured with `git config merge.conflictStyle diff3`, you get a **3-way** view:',
      '```',
      '<<<<<<< HEAD',
      'Your current changes',
      '||||||| merged common ancestor',
      'Original base version',
      '=======',
      'Incoming changes',
      '>>>>>>> branch-name',
      '```',
      '',
      'The `|||||||` section shows the common ancestor (merge base), which helps understand what both sides changed.',
      '',
      '## zdiff3 Style',
      '',
      'The **zdiff3** style (available in Git 2.35+) is like diff3 but more concise:',
      '```',
      '<<<<<<< HEAD',
      'Your current changes',
      '||||||| merged common ancestor',
      'Only the conflicting parts of the base',
      '=======',
      'Incoming changes',
      '>>>>>>> branch-name',
    })

    it('can locate the first conflict', function()
      local result, err = conflict.parse_conflict(bufnr, 1)
      assert.is_nil(err)
      assert.is_not_nil(result)
      assert.is_false(result.is_diff3)
      assert.are.equal(1, result.start_line)
      assert.are.equal(5, result.end_line)
      assert.are.same({ 2, 2 }, result.ours_range)
      assert.are.same({ 4, 4 }, result.theirs_range)
    end)
    it('can locate the second conflict', function()
      local result, err = conflict.parse_conflict(bufnr, 16)
      assert.is_nil(err)
      assert.is_not_nil(result)
      assert.is_true(result.is_diff3)
      assert.are.equal(16, result.start_line)
      assert.are.equal(22, result.end_line)
      assert.are.same({ 17, 17 }, result.ours_range)
      assert.are.same({ 19, 19 }, result.base_range)
      assert.are.same({ 21, 21 }, result.theirs_range)
    end)
    it('can locate the third conflict', function()
      local result, err = conflict.parse_conflict(bufnr, 31)
      assert.is_nil(err)
      assert.is_not_nil(result)
      assert.is_true(result.is_diff3)
      assert.are.equal(31, result.start_line)
      assert.are.equal(37, result.end_line)
      assert.are.same({ 32, 32 }, result.ours_range)
      assert.are.same({ 34, 34 }, result.base_range)
      assert.are.same({ 36, 36 }, result.theirs_range)
    end)
    delete_buffer(bufnr)
  end)
end)
