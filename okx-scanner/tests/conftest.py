import os
import sys

# make the package importable when running `pytest` from the project root
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
