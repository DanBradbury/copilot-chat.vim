vim9script
import autoload 'copilot_chat/buffer.vim' as _buffer

def PreserveEol(path: string, lines: list<string>): list<string>
  var has_cr = 0
  if filereadable(path)
    var orig = readfile(path, 'b')
    for l in orig
      if l =~# '\r$'
        has_cr = 1
        break
      endif
    endfor
  endif

  if has_cr
    var out = []
    for l in lines
      add(out, l .. "\r")
    endfor
    return out
  endif
  return lines
enddef

def ShowDiff(path: string, new_lines: list<string>): number
  var tmp_old = tempname()
  var tmp_new = tempname()
  if filereadable(path)
    writefile(readfile(path), tmp_old, 'b')
  else
    writefile([], tmp_old, 'b')
  endif

  # write proposed content to tmp_new
  writefile(new_lines, tmp_new, 'b')

  # Open a new tab and show the two files in diff mode
  # We keep these buffers as nofile, nomodifiable and wipe on close so they don't pollute session.
  execute 'tabnew ' .. fnameescape(tmp_old)
  execute 'vert diffsplit ' .. fnameescape(tmp_new)

  # Set sane buffer options for both sides
  setlocal buftype=nofile bufhidden=wipe noswapfile nomodifiable
  wincmd l
  setlocal buftype=nofile bufhidden=wipe noswapfile nomodifiable
  wincmd p
  redraw!

  # Prompt user (1=Yes, 2=No, 3=Apply to all, 4=Abort)
  var choice = confirm('Apply change to ' .. path .. '?', '&Yes\n&No\n&Apply to all\n&Abort', 1)

  # Close the tab we opened
  execute 'tabclose'

  if choice == 3
    #let s:apply_all = 1
    return 1
  elseif choice == 1
    return 1
  elseif choice == 4
    #let s:abort_apply = 1
    return 0
  else
    return 0
  endif
enddef

export def CreateDirectory(outcome: dict<any>)
  var args = json_decode(outcome['arguments'])
  var path = args['dirPath'][1 : ]
  mkdir(path, 'p')
  echom 'Create directory called'
enddef

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

export def ApplyPatch(outcome: dict<any>): string
  var args = json_decode(outcome['arguments'])
  var patch_text = args['input']
  var updated_files = []

  if match(patch_text, '^\*\*\* Begin Patch') != 0
    echom 'apply_patch: patch must start with "*** Begin Patch"'
    return ''
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
        var path = ln[17 : ]
        if path[0] == '/'
          path = path[1 : ]
        endif
        add(updated_files, path)
        i += 1

        # Collect the section lines until next "*** " sentinel or end of patch
        var section = []
        while i < n && lines[i] !~# '^\*\*\* \(Update\|Delete\|Add\|End Patch\)'
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
          # TODO: finish diff confirmation
          #ShowDiff(path, new_lines)
          try
            writefile(PreserveEol(path, new_lines), path, 'b')
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
      if ln =~# '^\*\*\* Delete File'
        var path = ln[17 : ]
        if path[0] == '/'
          path = path[1 : ]
        endif
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
      if ln =~# '^\*\*\* Add File'
        var path = ln[15 : ]
        i += 1

        if filereadable(path) == 1
          echom 'Add File Error - file already exists: ' .. path
          # consume section but don't overwrite
          while i < n && lines[i] !~# '^\*\*\* \\(Update\\|Delete\\|Add\\|End Patch\\)'
            i += 1
          endwhile
          continue
        endif

        # Collect '+' lines for the new file content
        var add_lines = []
        while i < n && lines[i] !~# '^\*\*\* \(Update\|Delete\|Add\|End Patch\)'
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
          writefile(PreserveEol(path, add_lines), path, 'b')
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

    # TODO: show changed files with +/-
  catch
    echom 'Exception while applying patch'
  endtry
  return $'The following files were successfully edited:\n{join(updated_files, "\n")}\n'
enddef

export def ReadFile(outcome: dict<any>): string
  var args = json_decode(outcome['arguments'])
  var path = args['filePath']
  path = path[1 : ]
  var lines = readfile(path)
  return join(lines, "\n")
enddef
