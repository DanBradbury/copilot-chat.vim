# Contributing to copilot-chat.vim
Contributions are what makes the open source community such an amazing place to learn, inspire, and create. Any contributions you make are greatly appreciated.

## House rules
- Before submitting a new issue or PR, check if it already exists in issues or PRs.

## Developing
The development branch is `main`. This is the branch that all pull requests should be made against.

To develop locally:
1. Fork this repository on your own GitHub account and then clone it to your local device
2. Create a new branch
```
git checkout -b my_new_branch
```
3. Make changes in repo as required
4. Run `move.sh` to save changes to plugin location for testing

## Testing
Tests are written with vader and include the necessary mocking in `mocks.vader` to avoid the need token generation

### Running tests
```
vim '+Vader! test/*' && echo Success || echo Failure
```

## Linting
Linting is done with `vint`. This is a linter for Vim scripts that checks for common mistakes and style issues.
To install `vint`, you must have Python 3 installed. You can install `vint` using pip:

```
pip install setuptools vint
```

To check the formatting of your code:
```
vint .
```
If you get errors be sure to fix them before committing.

## Making a Pull Request
- If your PR refers to or fixes an issue, be sure to add `fixes #XXX` to the PR description. Replacing `XXX` with the respective issue number.

[issues]: https://github.com/DanBradbury/copilot-chat.vim/issues
[PRs]: https://github.com/DanBradbury/copilot-chat.vim/pulls
