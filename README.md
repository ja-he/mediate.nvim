# mediate.nvim

A very simple Neovim plugin to help you with manual Git conflict resolution.

| Status                         |
| ------                         |
| `Work in Progress, but usable` |

---

## Development

_this section carried over from [nvim-lua-plugin-template](https://github.com/nvim-lua/nvim-lua-plugin-template)_

### Run tests


Running tests requires [plenary.nvim][plenary] to be checked out in the parent directory of *this* repository.
You can then run:

```bash
nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal.vim'}"
```

Or if you want to run a single test file:

```bash
nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/path_to_file.lua {minimal_init = 'tests/minimal.vim'}"
```


[nvim-lua-guide]: https://github.com/nanotee/nvim-lua-guide
[plenary]: https://github.com/nvim-lua/plenary.nvim
