# Performance Improvements for Issue #40

## Summary

This PR addresses the performance degradation that occurs after sending multiple messages in the Copilot Chat buffer, as reported in Issue #40.

## Performance Issues Identified

### 1. Excessive Syntax Highlighting Recalculation
**Problem:** The `apply_code_block_syntax()` function was being called on every text change event (`TextChanged`, `TextChangedI`, `BufEnter`), scanning the entire buffer to find and highlight code blocks.

**Solution:**
- Added 300ms timer-based debouncing to batch syntax highlighting updates
- The debouncing ensures syntax updates happen at most once per 300ms, regardless of typing speed
- This allows the user to continue typing without blocking on syntax calculations

**Performance Impact:** Reduces CPU usage during typing from O(n) on every keystroke to amortized O(1) with periodic O(n) updates (maximum once per 300ms).

### 2. Full Buffer Parsing on Every Message Submission
**Problem:** The `submit_message()` function was parsing and sending the entire message history to the API on every submission, causing exponential slowdown as conversations grew longer.

**Solution:**
- Added configurable message history limit (default: 20 messages)
- Only the most recent messages are sent to the API
- File references are consolidated efficiently using dictionary lookups (O(1)) instead of linear search (O(n))
- New configuration option: `g:copilot_chat_message_history_limit`

**Performance Impact:** Reduces message processing from O(n*m) to O(k*m) where k is the constant limit (20 by default). File consolidation improved from O(n²) to O(n).

### 3. Inefficient File Completion
**Problem:** The `check_for_macro()` function was calling `git ls-files` or `glob()` on every keystroke during file path completion.

**Solution:**
- Cache file list results for 5 seconds
- Reuse cached results during typing
- Invalidate cache after timeout to pick up new files

**Performance Impact:** Reduces system calls from once per keystroke to once per 5 seconds during file completion.

## Configuration

Users experiencing performance issues can further tune performance:

```vim
" Reduce message history for faster responses (trades context for speed)
let g:copilot_chat_message_history_limit = 10

" Or increase for more context (trades speed for better responses)
let g:copilot_chat_message_history_limit = 30
```

## Testing

Added `test/performance.vader` test suite to validate:
- Message history limiting works correctly
- Syntax highlighting can be triggered without errors
- File completion caching doesn't break functionality

## Backwards Compatibility

All changes are backwards compatible:
- Default behavior maintains reasonable performance for most users
- Users can opt-in to more aggressive performance tuning via configuration
- No breaking changes to existing functionality

## Recommendations

For users with very long chat sessions:
1. Use `:CopilotChatReset` periodically to clear history
2. Set `g:copilot_chat_message_history_limit` to a lower value (10-15)
3. Save important conversations with `:CopilotChatSave` before resetting
