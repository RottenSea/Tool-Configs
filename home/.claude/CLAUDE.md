## Tool Preferences

### Python

- `uv` over `pip`
- **Project workflow:**
  - `uv init` — create new project (generates `pyproject.toml`, `.python-version`, etc.)
  - `uv add <pkg>` — add dependency (updates `pyproject.toml` + lockfile + `.venv`)
  - `uv remove <pkg>` — remove dependency
  - `uv sync` — sync `.venv` with lockfile
  - `uv lock` — update lockfile without syncing
  - `uv run <script.py>` or `uv run -- <cmd>` — run in project environment (auto-syncs before run); auto-detects virtual environment in project root
  - `uv tree` — view dependency tree
  - `uv build` — build sdist + wheel into `dist/`
  - `uv publish` — publish to PyPI
- **Script workflow (no project):**
  - `uv run script.py` — run standalone script
  - `uv run --with <pkg> script.py` — run with ad-hoc dependency
  - `uv add --script script.py '<pkg>'` — declare inline deps (PEP 723 metadata)
  - `uv init --script script.py --python 3.12` — create script with inline metadata scaffold
- **Tool workflow (CLI tools like ruff, black):**
  - `uvx <tool>` or `uv tool run <tool>` — run tool in temp env
  - `uv tool install <tool>` — install tool system-wide (adds to PATH)
  - `uv tool list` / `uv tool uninstall` — manage installed tools
- **Python version management:**
  - `uv python install <version>` — install Python
  - `uv python list` / `uv python find` — list/find installed Pythons
  - `uv python pin <version>` — pin project to a Python version
- **pip-compatible interface (legacy):**
  - `uv venv` — create virtual environment
  - `uv pip install <pkg>` — install package
  - `uv pip compile` — compile requirements.in → requirements.txt
  - `uv pip sync` — sync env with requirements.txt
- **Utility:**
  - `uv self update` — update uv itself
  - `uv cache clean` — clean cache

### Node.js

- `pnpm` first
