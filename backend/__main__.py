from .env import load_env

load_env()

from .cli import main

if __name__ == "__main__":
    raise SystemExit(main())