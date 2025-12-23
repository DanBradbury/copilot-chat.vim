vim9script
import autoload 'copilot_chat/buffer.vim' as _buffer

export def CreateFile(outcome: dict<any>)
  var args = json_decode(outcome['arguments'])
  # remove the leading forward slash from the path
  var path = args['filePath'][1 : ]
  var content = args['content']

  # Must not overwrite an existing file
  if filereadable(path) == 1 || isdirectory(path) == 1
    echom 'create_file Error - file already exists: ' .. path
    return
  endif

  # Ensure parent directory exists
  var parent = fnamemodify(path, ':h')
  if parent !=# '' && isdirectory(parent) == 0
    mkdir(parent, 'p')
  endif

  writefile(split(content, "\n", 1), path)
enddef

export def ApplyPatch(outcome: dict<any>)
  var args = json_decode(outcome['arguments'])
  var patch_text = args['input']

  if match(patch_text, '^\*\*\* Begin Patch') != 0
    echom 'apply_patch: patch must start with "*** Begin Patch"'
    return
  endif

  # Split into lines
  var lines = split(patch_text, "\n", 1)
  var n = len(lines)
  var i = 0

  try
    while i < n
      var ln = lines[i]

      # Skip initial Begin Patch sentinel and blank lines
      if ln =~# '^\*\*\* Begin Patch'
        i += 1
        continue
      endif
      if ln =~# '^\*\*\* End Patch'
        break
      endif
      if ln =~# '^\\s*$'
        i += 1
        continue
      endif
      echom ln

      # Match Update
      if ln =~# '^\*\*\* Update File'
        #var path = substitute(ln, '^\*\*\* Update File: (\S\+)', '\1', '')
        var path = ln[18 : ]
        i += 1

        # Collect the section lines until next "*** " sentinel or end of patch
        var section = []
        while i < n && lines[i] !~# '^\*\*\* \\(Update\\|Delete\\|Add\\|End Patch\\)'
          call add(section, lines[i])
          i += 1
        endwhile

        # If file doesn't exist, error out
        if filereadable(path) == 0
          echom 'Update File Error - missing file: ' .. path
          continue
        endif

        # Naive update strategy:
        # - collect all lines in the section that start with '+' and use those as the new file content
        # - if there are no '+' lines, leave file unchanged
        var new_lines = []
        for s in section
          if strlen(s) > 0 && s[0] == '+'
            call add(new_lines, s[1 : ])
          endif
        endfor

        if len(new_lines) > 0
          # Ensure parent directory exists
          try
            call writefile(new_lines, path, 'b')
          catch
            echom 'Failed to write updated file: ' .. path
          endtry
        else
          # No '+' lines found - no change made
          echom 'Update for ' .. path .. ' contained no "+" lines; file left unchanged.'
        endif

        continue
      endif

      # Match Delete
      if ln =~# '^\*\*\* Delete File: \\(.\\+\\)'
        _buffer.AppendMessage('trying to delete')
        var path = substitute(ln, '^\*\*\* Delete File: \\(\\S\\+\\)', '\\1', '')
        i += 1

        if filereadable(path) == 0
          echom 'Delete File Error - missing file: ' .. path
          continue
        endif

        try
          delete(path)
          echom 'Deleted: ' .. path
        catch
          echom 'Failed to delete: ' .. path
        endtry
        continue
      endif

      # Match Add
      if ln =~# '^\\*\\*\\* Add File: \\(.\\+\\)'
        var path = substitute(ln, '^\\*\\*\\* Add File: \\(\\S\\+\\)', '\\1', '')
        i += 1

        if filereadable(path) == 1
          echom 'Add File Error - file already exists: ' .. path
          # consume section but don't overwrite
          while i < n && lines[i] !~# '^\\*\\*\\* \\(Update\\|Delete\\|Add\\|End Patch\\)'
            i += 1
          endwhile
          continue
        endif

        # Collect '+' lines for the new file content
        var add_lines = []
        while i < n && lines[i] !~# '^\\*\\*\\* \\(Update\\|Delete\\|Add\\|End Patch\\)'
          var s = lines[i]
          if strlen(s) > 0 && s[0] == '+'
            call add(add_lines, s[1 : ])
          endif
          i += 1
        endwhile

        try
          # create parent dirs if necessary
          # Vim's writefile won't create parent directories. We'll attempt to create them.
          var parent = fnamemodify(path, ':h')
          if parent !=# '' && isdirectory(parent) == 0
            call mkdir(parent, 'p')
          endif
          call writefile(add_lines, path, 'b')
          echom 'Added: ' .. path
        catch
          echom 'Failed to add file: ' .. path
        endtry
        continue
      endif

      # Unknown line encountered in patch parsing
      echom 'Unknown line while parsing patch: ' .. ln
      i += 1
    endwhile

    echom 'Done!'
  catch
    echom 'Exception while applying patch'
  endtry
enddef
